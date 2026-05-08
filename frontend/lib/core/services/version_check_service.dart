import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';

class VersionCheckService {
  static Future<void> check(BuildContext context) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final info = await PackageInfo.fromPlatform();
      final res = await dio.get('/app/config');
      final data = res.data as Map<String, dynamic>;

      final current = info.version;
      final minVersion = data['app_min_version'] as String? ?? '1.0.0';
      final latestVersion = data['app_latest_version'] as String? ?? '1.0.0';
      final storeUrl = Platform.isAndroid
          ? data['android_store_url'] as String? ?? ''
          : data['ios_store_url'] as String? ?? '';

      if (storeUrl.isEmpty) return;

      final isForce = _compare(current, minVersion) < 0;
      final isSoft = !isForce && _compare(current, latestVersion) < 0;

      if (!isForce && !isSoft) return;
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(isForce: isForce, storeUrl: storeUrl),
      );
    } catch (_) {
      // Silent fail — never block the app due to a version-check network error.
    }
  }

  /// Negative → a < b (needs update), 0 → equal, positive → a > b.
  static int _compare(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final diff = (i < pa.length ? pa[i] : 0) - (i < pb.length ? pb[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }
}

class _UpdateDialog extends StatelessWidget {
  final bool isForce;
  final String storeUrl;

  const _UpdateDialog({required this.isForce, required this.storeUrl});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForce,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF5B6AF0)),
            SizedBox(width: 10),
            Text('Cập nhật ứng dụng'),
          ],
        ),
        content: Text(
          isForce
              ? 'Phiên bản này không còn được hỗ trợ. Vui lòng cập nhật để tiếp tục sử dụng ShopHo.'
              : 'Đã có phiên bản mới của ShopHo. Cập nhật ngay để trải nghiệm các tính năng mới nhất!',
        ),
        actions: [
          if (!isForce)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Để sau'),
            ),
          ElevatedButton(
            onPressed: () => launchUrl(
              Uri.parse(storeUrl),
              mode: LaunchMode.externalApplication,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B6AF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cập nhật ngay'),
          ),
        ],
      ),
    );
  }
}
