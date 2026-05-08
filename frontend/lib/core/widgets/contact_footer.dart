import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

final appConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiClientProvider).dio.get('/app/config');
  return res.data as Map<String, dynamic>;
});

class ContactFooter extends ConsumerWidget {
  const ContactFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    if (config.isLoading) return const SizedBox.shrink();

    final zalo = config.whenOrNull(data: (d) => d['zalo_contact'] as String?);
    if (zalo == null || zalo.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: zalo));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép số Zalo'), duration: Duration(seconds: 2)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE0FF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF0068FF)),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF3B3F8C)),
                  children: [
                    const TextSpan(text: 'Góp ý hoặc báo lỗi? Nhắn Zalo: '),
                    TextSpan(
                      text: zalo,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0068FF)),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
