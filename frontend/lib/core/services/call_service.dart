import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  /// Called when recipient accepts an incoming call from callkit UI.
  /// Navigate to WebRtcCallScreen with isCaller=false.
  static void Function(String orderId, String callerName)? _onCallAccepted;

  static Future<void> init({
    required void Function(String orderId, String callerName) onCallAccepted,
  }) async {
    _onCallAccepted = onCallAccepted;
    FlutterCallkitIncoming.onEvent.listen(_handleEvent);
  }

  static void _handleEvent(CallEvent? event) async {
    if (event == null) return;
    switch (event.event) {
      case Event.actionCallAccept:
        final extra = event.body['extra'] as Map?;
        final orderId = extra?['order_id'] as String?;
        final callerName = extra?['caller_name'] as String? ?? 'Người gọi';
        if (orderId != null) _onCallAccepted?.call(orderId, callerName);
        break;
      case Event.actionCallDecline:
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        await FlutterCallkitIncoming.endAllCalls();
        break;
      default:
        break;
    }
  }

  static Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String orderId,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'ShopHo',
      type: 0,
      duration: 30000,
      extra: {'order_id': orderId, 'caller_name': callerName},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        actionColor: '#5B6AF0',
        incomingCallNotificationChannelName: 'Cuộc gọi đến',
        missedCallNotificationChannelName: 'Cuộc gọi nhỡ',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Request mic permission. Returns true if granted.
  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('[CallService] Microphone permission denied');
      return false;
    }
    return true;
  }
}
