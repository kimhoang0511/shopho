import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiClientProvider).dio.get('/users/me');
  return res.data as Map<String, dynamic>;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('ShopHo', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GoldCard(),
              const SizedBox(height: 24),

              // ── App intro ────────────────────────────────────
              const _AppIntro(),
              const SizedBox(height: 24),

              // ── Action cards ─────────────────────────────────
              Text('Bạn muốn làm gì?', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.search_rounded,
                      bgIcon: Icons.local_shipping_rounded,
                      label: 'Tìm đơn mua/ship hộ',
                      subtitle: 'Tiếp nhận đơn & kiếm gold',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B6AF0), Color(0xFF3B4DD8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shadowColor: const Color(0xFF5B6AF0),
                      onTap: () => context.push('/orders/browse'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.receipt_long_rounded,
                      bgIcon: Icons.inventory_2_rounded,
                      label: 'Tạo đơn - cần người mua/ship hộ giúp',
                      subtitle: 'Quản lý đơn đã tạo',
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFD4861A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shadowColor: const Color(0xFFF5A623),
                      onTap: () => context.push('/orders/my-created'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Gold card ────────────────────────────────────────────────

class _GoldCard extends ConsumerWidget {
  const _GoldCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = ref.watch(_meProvider).whenOrNull(
      data: (me) => (me['gold_balance'] as num?)?.toStringAsFixed(0),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6AF0), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: Color(0xFFF5A623), size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Số dư Gold', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                gold != null ? '$gold Gold' : '-- Gold',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── App intro ────────────────────────────────────────────────

class _AppIntro extends StatelessWidget {
  const _AppIntro();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B6AF0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'ShopHo là gì?',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF3B3F8C)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kết nối người đang cần giúp đỡ mua/ship hàng hộ với người sẵn sàng mua/ship hộ ở trong cùng khu căn hộ - toà nhà - chung cư với nhau. '
            'Người cần giúp tiết kiệm thời gian, người mua/ship hộ kiếm thêm thu nhập. Giá ship hộ người tạo đơn tự đặt, người mua/ship hộ có thể deal giá',
            style: tt.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: _FeatureChip(icon: Icons.local_shipping_outlined,  label: 'Ship tận nơi')),
              SizedBox(width: 8),
              Expanded(child: _FeatureChip(icon: Icons.monetization_on_outlined, label: 'Kiếm Gold')),
              SizedBox(width: 8),
              Expanded(child: _FeatureChip(icon: Icons.schedule_rounded,         label: 'Nhanh & tiện')),
              SizedBox(width: 8),
              Expanded(child: _FeatureChip(icon: Icons.people_alt_outlined,      label: 'Cộng đồng')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: const Color(0xFF5B6AF0).withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF5B6AF0)),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF3B3F8C)),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Action card ──────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final IconData bgIcon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.bgIcon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: shadowColor.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Stack(
            children: [
              // Decorative circle – top right
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              // Decorative circle – bottom left
              Positioned(
                left: -12,
                bottom: -12,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Large background icon
              Positioned(
                right: -10,
                bottom: -6,
                child: Icon(bgIcon, size: 96, color: Colors.white.withValues(alpha: 0.13)),
              ),
              // Foreground content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
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
