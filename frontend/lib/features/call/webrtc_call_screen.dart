import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api/api_client.dart';

enum _CallStatus { waiting, connected }

class WebRtcCallScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String counterpartName;
  final bool isCaller;

  const WebRtcCallScreen({
    super.key,
    required this.orderId,
    required this.counterpartName,
    required this.isCaller,
  });

  @override
  ConsumerState<WebRtcCallScreen> createState() => _WebRtcCallScreenState();
}

class _WebRtcCallScreenState extends ConsumerState<WebRtcCallScreen> {
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();
  final _recorderController = StreamController<Uint8List>();
  StreamSubscription? _recorderSub;
  bool _recorderOpen = false;
  bool _playerOpen = false;
  bool _stopped = false;

  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speaker = true;
  _CallStatus _status = _CallStatus.waiting;

  static const _sampleRate = 16000;
  static const _bufferSize = 8192;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    if (_stopped) return;
    _stopped = true;
    _durationTimer?.cancel();
    _wsSub?.cancel();
    _recorderSub?.cancel();
    _ws?.sink.close();
    if (_recorderOpen) {
      _recorderOpen = false;
      _recorder.stopRecorder().then((_) => _recorder.closeRecorder()).ignore();
    }
    if (_playerOpen) {
      _playerOpen = false;
      _player.stopPlayer().then((_) => _player.closePlayer()).ignore();
    }
    _recorderController.close().ignore();
  }

  Future<void> _init() async {
    // Configure audio session for voice call (speaker by default)
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    // Open recorder
    await _recorder.openRecorder();
    _recorderOpen = true;

    // Open player and start streaming mode
    await _player.openPlayer();
    _playerOpen = true;
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: true,
      numChannels: 1,
      sampleRate: _sampleRate,
      bufferSize: _bufferSize,
    );

    // Connect to audio relay WebSocket
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token') ?? '';
    _ws = WebSocketChannel.connect(
      Uri.parse('$wsBaseUrl/ws/orders/${widget.orderId}/audio?token=$token'),
    );

    _wsSub = _ws!.stream.listen(
      (raw) async {
        if (raw is List<int>) {
          // Audio bytes from peer → feed to player
          if (_playerOpen) {
            _player.uint8ListSink?.add(Uint8List.fromList(raw));
          }
        } else if (raw is String) {
          final msg = json.decode(raw) as Map<String, dynamic>;
          switch (msg['type'] as String?) {
            case 'start':
              await _startMic();
              if (mounted) {
                setState(() => _status = _CallStatus.connected);
                _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                  if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
                });
              }
            case 'hangup':
              _hangup(sendSignal: false);
          }
        }
      },
      onDone: () => _hangup(sendSignal: false),
      onError: (_) => _hangup(sendSignal: false),
    );
  }

  Future<void> _startMic() async {
    // Recorder writes PCM16 bytes into the stream controller's sink
    await _recorder.startRecorder(
      codec: Codec.pcm16,
      toStream: _recorderController.sink,
      sampleRate: _sampleRate,
      numChannels: 1,
      bufferSize: _bufferSize,
    );
    // Forward mic bytes to WebSocket (skip when muted)
    _recorderSub = _recorderController.stream.listen((chunk) {
      if (!_muted) _ws?.sink.add(chunk);
    });
  }

  Future<void> _hangup({bool sendSignal = true}) async {
    if (_stopped) return;
    if (sendSignal) _ws?.sink.add(json.encode({'type': 'hangup'}));
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() => setState(() => _muted = !_muted);

  Future<void> _toggleSpeaker() async {
    final next = !_speaker;
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: next
          ? AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth
          : AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: next
            ? AndroidAudioUsage.media
            : AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
    setState(() => _speaker = next);
  }

  String get _statusLabel => switch (_status) {
        _CallStatus.waiting =>
          widget.isCaller ? 'Đang đổ chuông...' : 'Đang kết nối...',
        _CallStatus.connected => _fmt(_elapsed),
      };

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _hangup(),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A3E),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 60),

              // Avatar + name + status
              Column(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor:
                        const Color(0xFF5B6AF0).withValues(alpha: 0.3),
                    child: Text(
                      widget.counterpartName.isNotEmpty
                          ? widget.counterpartName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.counterpartName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              // Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleBtn(
                      icon: _muted ? Icons.mic_off : Icons.mic,
                      label: _muted ? 'Bỏ tắt' : 'Tắt mic',
                      onTap: _toggleMute,
                    ),
                    _HangupBtn(onTap: () => _hangup()),
                    _CircleBtn(
                      icon: _speaker ? Icons.volume_up : Icons.volume_off,
                      label: _speaker ? 'Loa ngoài' : 'Tai nghe',
                      onTap: () => _toggleSpeaker(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _HangupBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _HangupBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          const Text('Kết thúc', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
