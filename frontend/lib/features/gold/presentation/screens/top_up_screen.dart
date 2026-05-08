import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';

// ── Constants ─────────────────────────────────────────────────

const _packages = [10, 20, 50, 100, 200, 500];
const _vndPerGold = 1000;

// ── Screen ────────────────────────────────────────────────────

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  // step: select | qr
  String _step = 'select';
  int _selectedGold = 50;
  bool _creating = false;

  // QR step state
  String? _orderCode;
  String? _qrUrl;
  int? _amountVnd;

  // Confirm state: idle | checking | success | fail
  String _confirmStatus = 'idle';
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _createOrder() async {
    setState(() => _creating = true);
    try {
      final res = await ref.read(apiClientProvider).dio.post(
            '/users/me/gold/topup/create',
            data: {'gold_amount': _selectedGold},
          );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _orderCode = data['order_code'] as String;
        _qrUrl = data['qr_url'] as String;
        _amountVnd = data['amount_vnd'] as int;
        _step = 'qr';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo đơn: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _confirmPayment() async {
    if (_orderCode == null) return;
    setState(() => _confirmStatus = 'checking');
    try {
      final res = await ref.read(apiClientProvider).dio
          .get('/users/me/gold/topup/$_orderCode');
      final status = (res.data as Map<String, dynamic>)['status'] as String;
      if (status == 'completed') {
        setState(() => _confirmStatus = 'success');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.pop(true); // pop with refresh signal
      } else {
        setState(() => _confirmStatus = 'fail');
      }
    } catch (_) {
      if (mounted) setState(() => _confirmStatus = 'fail');
    }
  }

  void _backToSelect() {
    _pollTimer?.cancel();
    setState(() {
      _step = 'select';
      _orderCode = null;
      _qrUrl = null;
      _amountVnd = null;
      _confirmStatus = 'idle';
    });
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FF),
        surfaceTintColor: Colors.transparent,
        title: Text(
          _step == 'select' ? 'Nạp Gold' : 'Thanh toán chuyển khoản',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _step == 'qr'
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _backToSelect,
              )
            : BackButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
      ),
      body: _step == 'select' ? _buildSelect() : _buildQr(),
    );
  }

  // ── Step 1: Select gold amount ────────────────────────────────

  Widget _buildSelect() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Exchange rate info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B6AF0), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFF5A623), size: 28),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tỷ lệ quy đổi', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    SizedBox(height: 2),
                    Text('1.000₫ = 1 Gold', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Chọn số Gold muốn nạp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),

          // Package grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _packages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (_, i) => _PackageCard(
              gold: _packages[i],
              selected: _selectedGold == _packages[i],
              onTap: () => setState(() => _selectedGold = _packages[i]),
            ),
          ),

          const SizedBox(height: 24),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                _SummaryRow('Số Gold nhận', '$_selectedGold Gold', valueColor: const Color(0xFF6366F1)),
                const Divider(height: 20),
                _SummaryRow('Số tiền cần chuyển',
                    '${(_selectedGold * _vndPerGold).toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}₫',
                    valueColor: const Color(0xFFF59E0B), bold: true),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _creating ? null : _createOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B6AF0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _creating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Tiếp tục →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Step 2: QR ───────────────────────────────────────────────

  Widget _buildQr() {
    final vnd = _amountVnd ?? 0;
    final vndStr = vnd.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QR image
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDDE0FF), width: 2),
                boxShadow: [BoxShadow(color: const Color(0xFF5B6AF0).withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(12),
              child: _qrUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _qrUrl!,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(width: 240, height: 240, child: Center(child: CircularProgressIndicator()));
                        },
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 240,
                          height: 240,
                          child: Center(child: Icon(Icons.qr_code_2, size: 80, color: Color(0xFF5B6AF0))),
                        ),
                      ),
                    )
                  : const SizedBox(width: 240, height: 240, child: Center(child: CircularProgressIndicator())),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Quét mã QR bằng app ngân hàng để chuyển khoản',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ),

          const SizedBox(height: 16),

          // Order info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE0FF)),
            ),
            child: Column(
              children: [
                _SummaryRow('Số Gold nhận', '$_selectedGold Gold', valueColor: const Color(0xFF6366F1)),
                const SizedBox(height: 8),
                _SummaryRow('Số tiền', '$vndStr₫', valueColor: const Color(0xFFF59E0B), bold: true),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mã đơn hàng', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _orderCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép mã đơn'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Row(
                        children: [
                          Text(_orderCode ?? '', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B), letterSpacing: 2)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            children: [
                              const TextSpan(text: 'Nhập đúng mã '),
                              TextSpan(text: _orderCode ?? '', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' vào nội dung chuyển khoản'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          ElevatedButton(
            onPressed: (_confirmStatus == 'checking' || _confirmStatus == 'success') ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B6AF0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: switch (_confirmStatus) {
              'checking' => const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Đang kiểm tra...', style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
              'success' => const Text('✅ Nạp Gold thành công!', style: TextStyle(fontWeight: FontWeight.bold)),
              _ => const Text('🔄 Xác nhận đã thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            },
          ),

          if (_confirmStatus == 'fail') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Text(
                'Chưa xác nhận được giao dịch. Nếu đã chuyển khoản, hãy đợi vài giây rồi thử lại.',
                style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final int gold;
  final bool selected;
  final VoidCallback onTap;
  const _PackageCard({required this.gold, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vnd = gold * _vndPerGold;
    final vndStr = vnd >= 1000
        ? '${(vnd ~/ 1000)}K₫'
        : '$vnd₫';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5B6AF0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF5B6AF0) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFF5B6AF0).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on_rounded,
                color: selected ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B), size: 24),
            const SizedBox(height: 4),
            Text('$gold Gold',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected ? Colors.white : const Color(0xFF1E293B))),
            Text(vndStr,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white70 : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor ?? const Color(0xFF1E293B), fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
