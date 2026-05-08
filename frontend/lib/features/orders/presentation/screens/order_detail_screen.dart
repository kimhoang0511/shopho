import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/services/call_service.dart';
import '../../data/orders_repository.dart';
import '../../domain/order_model.dart';

// ─── Countdown helper ────────────────────────────────────────

String _remainingLabel(Duration remaining) {
  if (remaining.isNegative) return 'Đã hết hạn';
  if (remaining.inHours >= 1) {
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    return 'Còn lại $h giờ${m > 0 ? ' $m phút' : ''}';
  }
  if (remaining.inMinutes >= 1) return 'Còn lại ${remaining.inMinutes} phút';
  return 'Còn lại ${remaining.inSeconds} giây';
}

String _expiryLabel(OrderDetail order) {
  if (order.status != OrderStatus.pending) return '—';
  return _remainingLabel(order.expiresAt.difference(DateTime.now()));
}

String _deliveryLabel(OrderDetail order) {
  final deadline = order.estimatedDeliveryAt;
  if (deadline == null) return '—';
  return _remainingLabel(deadline.difference(DateTime.now()));
}

final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, String>(
  (ref, id) => ref.read(ordersRepositoryProvider).getOrder(id),
);

final _currentUserIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return storage.read(key: 'user_id');
});

final _proposalsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, orderId) => ref.read(ordersRepositoryProvider).fetchProposals(orderId),
);

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final currentUserId = ref.watch(_currentUserIdProvider).valueOrNull;

    Color? bgColor;
    String appBarTitle = 'Chi tiết đơn';
    final _loadedOrder = orderAsync.valueOrNull;
    bool showContact = false;
    if (currentUserId != null && _loadedOrder != null) {
      final isCreatorUser = _loadedOrder.creatorId == currentUserId;
      final isShipperUser = _loadedOrder.shipperId == currentUserId;
      if (isCreatorUser) {
        bgColor = const Color(0xFFFFF4E8);
        appBarTitle = 'Đơn của tôi';
      } else if (isShipperUser) {
        bgColor = const Color(0xFFECF0FF);
        appBarTitle = 'Đơn tiếp nhận';
      } else {
        appBarTitle = 'Đơn đang chờ tiếp nhận';
      }
      showContact = (isCreatorUser || isShipperUser) &&
          (_loadedOrder.status == OrderStatus.accepted ||
           _loadedOrder.status == OrderStatus.delivering);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }),
        actions: [
          if (showContact)
            IconButton(
              icon: Transform.scale(scaleX: -1, child: const Icon(Icons.phone)),
              tooltip: 'Gọi điện',
              onPressed: () => _callContact(context, ref, orderId),
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (order) => _OrderDetailBody(order: order),
      ),
    );
  }

  Future<void> _callContact(BuildContext context, WidgetRef ref, String orderId) async {
    // Fetch contact info first
    Map<String, dynamic>? contact;
    try {
      final res = await ref.read(apiClientProvider).dio.get('/orders/$orderId/contact');
      contact = res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Không thể tải thông tin liên hệ');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (!context.mounted) return;

    final phone = contact['phone'] as String?;
    final dio = ref.read(apiClientProvider).dio;

    // Show option sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Chọn hình thức liên hệ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _CallOptionTile(
                icon: Icons.phone_in_talk_outlined,
                iconColor: const Color(0xFF5B6AF0),
                label: 'Gọi qua ứng dụng',
                subtitle: 'Kết nối trực tiếp P2P, miễn phí',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  // Request mic permission first
                  final granted = await CallService.requestMicPermission();
                  if (!granted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cần quyền microphone để thực hiện cuộc gọi')),
                      );
                    }
                    return;
                  }
                  // Initiate call → backend sends FCM to recipient + returns caller token
                  try {
                    final res = await dio.post('/orders/$orderId/call');
                    final counterpartName = res.data['counterpart_name'] as String? ?? 'Đối phương';
                    final livekitUrl = res.data['livekit_url'] as String? ?? '';
                    final token = res.data['token'] as String? ?? '';
                    final callId = res.data['call_id'] as String? ?? '';
                    if (context.mounted) {
                      context.push(
                        '/call/$orderId',
                        extra: {
                          'name': counterpartName,
                          'livekit_url': livekitUrl,
                          'token': token,
                          'call_id': callId,
                        },
                      );
                    }
                  } on DioException catch (e) {
                    final msg = extractApiError(e, 'Không thể thực hiện cuộc gọi');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              _CallOptionTile(
                icon: Icons.phone_outlined,
                iconColor: Colors.green,
                label: 'Gọi điện thoại',
                subtitle: phone ?? 'Chưa có số điện thoại',
                enabled: phone != null && phone.isNotEmpty,
                onTap: phone != null && phone.isNotEmpty
                    ? () async {
                        Navigator.pop(sheetCtx);
                        final uri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerStatefulWidget {
  final OrderDetail order;
  const _OrderDetailBody({required this.order});

  @override
  ConsumerState<_OrderDetailBody> createState() => _OrderDetailBodyState();
}

class _OrderDetailBodyState extends ConsumerState<_OrderDetailBody> {
  bool _accepting = false;
  bool _delivering = false;
  bool _shipperCancelling = false;
  bool _completing = false;
  bool _reducingGold = false;
  bool _disputing = false;
  bool _proposing = false;
  bool _renewing = false;

  // Safe pop: when opened from notification (_router.go) the stack is empty,
  // Navigator.pop would cause a black screen — fall back to home instead.
  void _safeBack() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/home');
    }
  }

  Future<void> _acceptOrder() async {
    final estimatedMinutes = await showDialog<int>(
      context: context,
      builder: (_) => _AcceptOrderDialog(order: widget.order),
    );
    if (estimatedMinutes == null) return;

    setState(() => _accepting = true);
    try {
      await ref.read(ordersRepositoryProvider).acceptOrder(
        widget.order.id,
        estimatedMinutes: estimatedMinutes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã nhận đơn! Gold sẽ được cộng sau khi người đặt xác nhận hoặc chờ trong 1 giờ.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/orders/my-shipped');
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Nhận đơn thất bại');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _creatorCancelAccepted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ đơn đã được nhận'),
        content: const Text(
          '⚠️ Lưu ý: Hãy liên hệ với người nhận đơn trước khi thực hiện huỷ để tránh gây bất tiện.\n\n'
          'Bạn có chắc chắn muốn huỷ đơn này không?\nGold khoá sẽ được hoàn trả lại cho bạn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Quay lại')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận huỷ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(ordersRepositoryProvider).cancelOrder(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã huỷ đơn. Gold đã được hoàn trả.'), backgroundColor: Colors.orange),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Huỷ đơn thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    }
  }

  Future<void> _creatorCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ đơn'),
        content: const Text('Bạn có chắc muốn huỷ đơn này không?\nGold đã khoá sẽ được hoàn trả lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(ordersRepositoryProvider).cancelOrder(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã huỷ đơn thành công'), backgroundColor: Colors.orange),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Huỷ đơn thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    }
  }

  Future<void> _renewOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đặt lại đơn'),
        content: const Text('Đơn sẽ được kích hoạt lại với cùng nội dung và thời hạn ban đầu.\nGold sẽ được khoá lại từ số dư của bạn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _renewing = true);
    try {
      await ref.read(ordersRepositoryProvider).renewOrder(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đặt lại đơn thành công!'), backgroundColor: Colors.green),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Đặt lại thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  Future<void> _completeOrder() async {
    final result = await showDialog<_CompleteOrderResult>(
      context: context,
      builder: (_) => _CompleteOrderDialog(originalGold: widget.order.goldReward),
    );
    if (result == null) return;

    setState(() => _completing = true);
    try {
      await ref.read(ordersRepositoryProvider).completeOrder(
        widget.order.id,
        bonusGold: result.bonusGold > 0 ? result.bonusGold : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đơn hoàn thành! Gold đã được chuyển cho người ship.'), backgroundColor: Colors.green),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Thao tác thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _confirmDelivery() async {
    final acceptedAt = widget.order.acceptedAt;
    if (acceptedAt != null && DateTime.now().difference(acceptedAt).inMinutes < 5) {
      final remaining = 5 - DateTime.now().difference(acceptedAt).inMinutes;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng chờ thêm khoảng $remaining phút trước khi xác nhận hoàn thành.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final adjustedGold = await showDialog<double>(
      context: context,
      builder: (_) => _DeliveryConfirmDialog(originalGold: widget.order.goldReward),
    );
    if (adjustedGold == null) return;

    setState(() => _delivering = true);
    try {
      await ref.read(ordersRepositoryProvider).deliverOrder(
        widget.order.id,
        adjustedGold: adjustedGold != widget.order.goldReward ? adjustedGold : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận giao hàng! Chờ người đặt xác nhận.'), backgroundColor: Colors.blue),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Thao tác thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _delivering = false);
    }
  }

  Future<void> _disputeOrder() async {
    final total = widget.order.goldReward.toInt();
    final shipperGold = total ~/ 2;
    final creatorGold = total - shipperGold;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xung đột'),
        content: Text(
          'Đang có xung đột giữa 2 bên.\n\n'
          'Bạn nên chủ động liên hệ với người mua/ship hộ để giải quyết trước.\n\n'
          'Nếu không thể giải quyết và xác nhận trạng thái "xung đột", '
          'người mua/ship hộ sẽ nhận $shipperGold Gold, '
          'bạn sẽ được hoàn lại $creatorGold Gold.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Quay lại giải quyết')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận xung đột'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _disputing = true);
    try {
      await ref.read(ordersRepositoryProvider).disputeOrder(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xác nhận xung đột. Gold được chia đôi giữa hai bên.'),
            backgroundColor: Colors.deepOrange,
          ),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Thao tác thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _disputing = false);
    }
  }

  Future<void> _reduceGold() async {
    final newGold = await showDialog<double>(
      context: context,
      builder: (_) => _DeliveryConfirmDialog(
        originalGold: widget.order.goldReward,
        title: 'Giảm giá gold',
        subtitle: 'Bạn có thể giảm số gold nhận được.\nPhần chênh lệch sẽ được hoàn trả cho người đặt.',
        confirmLabel: 'Xác nhận giảm',
      ),
    );
    if (newGold == null) return;

    setState(() => _reducingGold = true);
    try {
      await ref.read(ordersRepositoryProvider).reduceGold(widget.order.id, newGold);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật gold thưởng: ${newGold.toStringAsFixed(0)} Gold'), backgroundColor: Colors.blue),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Thao tác thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _reducingGold = false);
    }
  }

  Future<void> _shipperCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ đơn đã nhận'),
        content: const Text('Bạn có chắc muốn huỷ đơn này không?\nGold sẽ được hoàn trả lại cho người đặt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Huỷ đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _shipperCancelling = true);
    try {
      final result = await ref.read(ordersRepositoryProvider).shipperCancelOrder(widget.order.id);
      if (mounted) {
        final reopened = result.status == OrderStatus.pending;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reopened
                ? 'Đã huỷ nhận đơn. Đơn được mở lại để shipper khác có thể nhận.'
                : 'Đã huỷ đơn. Gold hoàn trả cho người đặt.'),
            backgroundColor: Colors.orange,
          ),
        );
        _safeBack();
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Huỷ đơn thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _shipperCancelling = false);
    }
  }

  Future<void> _proposeGold() async {
    final proposed = await showDialog<double>(
      context: context,
      builder: (_) => _ProposeGoldDialog(currentGold: widget.order.goldReward),
    );
    if (proposed == null) return;

    setState(() => _proposing = true);
    try {
      await ref.read(ordersRepositoryProvider).proposeGold(widget.order.id, proposed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã gửi đề nghị ${proposed.toStringAsFixed(0)} Gold'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      final msg = extractApiError(e, 'Gửi đề nghị thất bại');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xảy ra lỗi, vui lòng thử lại'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _proposing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final cs = Theme.of(context).colorScheme;
    final isPending = order.status == OrderStatus.pending;
    final isAccepted = order.status == OrderStatus.accepted;
    final isDelivering = order.status == OrderStatus.delivering;
    final isExpired = order.status == OrderStatus.expired;
    final currentUserId = ref.watch(_currentUserIdProvider).valueOrNull;
    final isShipper = currentUserId != null && order.shipperId == currentUserId;
    final isCreator = currentUserId != null && order.creatorId == currentUserId;
    final canCreatorCancelAccepted = isCreator &&
        isAccepted &&
        order.acceptedAt != null &&
        DateTime.now().difference(order.acceptedAt!).inMinutes < 5;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Images
              if (order.images.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: order.images.length,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(order.images[i].publicUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Note
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ghi chú đơn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(order.note, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Participants card
              _ParticipantsCard(order: order),
              const SizedBox(height: 12),

              // Ship address card
              _ShipAddressCard(order: order),
              const SizedBox(height: 12),

              // Info grid
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(Icons.monetization_on_outlined, 'Trả gold ship',
                          '${order.goldReward.toStringAsFixed(0)} Gold',
                          valueStyle: TextStyle(color: cs.tertiary, fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(height: 24),
                      if (order.status != OrderStatus.delivering && order.status != OrderStatus.completed) ...[
                        _timerRow(order, cs),
                        const Divider(height: 24),
                      ],
                      if (order.status == OrderStatus.delivering && order.deliveringAt != null) ...[
                        _InfoRow(
                          Icons.schedule_outlined,
                          'Gold tự động chuyển lúc',
                          _formatTime(order.deliveringAt!.add(const Duration(hours: 1)).toLocal()),
                          valueStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 24),
                      ],
                      _InfoRow(Icons.info_outline, 'Trạng thái', _statusLabel(order.status),
                          valueStyle: TextStyle(color: _statusColor(order.status), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // Dispute result card
              if (order.status == OrderStatus.disputed) ...[
                const SizedBox(height: 12),
                _DisputeResultCard(goldReward: order.goldReward, isCreator: isCreator),
              ],

              // Proposals card (creator, pending)
              if (isCreator && isPending) ...[
                const SizedBox(height: 12),
                _ProposalsCard(
                  orderId: order.id,
                  currentGold: order.goldReward,
                  proposalsAsync: ref.watch(_proposalsProvider(order.id)),
                  onAccept: (proposalId) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref.read(ordersRepositoryProvider).acceptProposal(order.id, proposalId);
                      ref.invalidate(_proposalsProvider(order.id));
                      if (mounted) _safeBack();
                    } on DioException catch (e) {
                      final msg = extractApiError(e, 'Thao tác thất bại');
                      if (mounted) messenger.showSnackBar(SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red));
                    }
                  },
                ),
              ],
            ],
          ),
        ),

        // Shipper: accept button (pending, not creator)
        if (isPending && !isCreator)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.icon(
              onPressed: _accepting ? null : _acceptOrder,
              icon: _accepting
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_accepting ? 'Đang xử lý...' : 'Xác nhận mua/ship hộ đơn này'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        // Shipper: propose gold increase (pending, not creator)
        if (isPending && !isCreator)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: OutlinedButton.icon(
              onPressed: _proposing ? null : _proposeGold,
              icon: _proposing
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.trending_up_rounded, size: 18),
              label: Text(_proposing ? 'Đang gửi...' : 'Đề nghị tăng gold'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B6000),
                side: const BorderSide(color: Color(0xFFD4A017)),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        // Creator: cancel + edit (pending)
        if (isCreator && isPending)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _creatorCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Huỷ đơn'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await context.push('/orders/${order.id}/edit');
                      if (!mounted) return;
                      _safeBack();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Sửa đơn'),
                  ),
                ),
              ],
            ),
          ),

        // Creator: cancel accepted order within 5-minute grace period
        if (canCreatorCancelAccepted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: _creatorCancelAccepted,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Huỷ đơn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        // Creator: confirm completion (accepted or delivering)
        if (isCreator && (isAccepted || isDelivering))
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, isDelivering ? 8 : 24),
            child: FilledButton.icon(
              onPressed: _completing ? null : _completeOrder,
              icon: _completing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_outlined),
              label: Text(_completing ? 'Đang xử lý...' : 'Xác nhận đã nhận hàng'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        // Creator: dispute (only when delivering)
        if (isCreator && isDelivering)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: OutlinedButton.icon(
              onPressed: _disputing ? null : _disputeOrder,
              icon: _disputing
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.report_problem_outlined, size: 18),
              label: Text(_disputing ? 'Đang xử lý...' : 'Vẫn chưa hoàn thành'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        // Creator: renew expired order
        if (isCreator && isExpired)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: FilledButton.icon(
              onPressed: _renewing ? null : _renewOrder,
              icon: _renewing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh_rounded),
              label: Text(_renewing ? 'Đang xử lý...' : 'Đặt lại đơn'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        // Shipper actions (accepted or delivering)
        if (isShipper && (isAccepted || isDelivering))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: isDelivering
                      ? OutlinedButton.icon(
                          onPressed: _reducingGold ? null : _reduceGold,
                          icon: _reducingGold
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.remove_circle_outline, size: 18),
                          label: const Text('Giảm giá gold'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                        )
                      : OutlinedButton.icon(
                          onPressed: _shipperCancelling ? null : _shipperCancel,
                          icon: _shipperCancelling
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Huỷ đơn'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (isDelivering || _delivering) ? null : _confirmDelivery,
                    icon: _delivering
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(isDelivering ? 'Chờ xác nhận' : 'Báo đã giao hàng'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDelivering ? Colors.grey : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _timerRow(OrderDetail order, ColorScheme cs) {
    switch (order.status) {
      case OrderStatus.pending:
        final expired = order.expiresAt.isBefore(DateTime.now());
        return _InfoRow(
          Icons.timer_outlined,
          'Thời hạn còn lại',
          _expiryLabel(order),
          valueStyle: expired ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold) : null,
        );
      case OrderStatus.accepted:
        if (order.estimatedDeliveryAt != null) {
          final overdue = order.estimatedDeliveryAt!.isBefore(DateTime.now());
          return _InfoRow(
            Icons.delivery_dining_outlined,
            'Thời gian giao hàng',
            _deliveryLabel(order),
            valueStyle: overdue
                ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                : const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          );
        }
        return _InfoRow(Icons.timer_outlined, 'Nhận đơn lúc',
            order.acceptedAt != null ? _formatTime(order.acceptedAt!) : '—');
      default:
        return _InfoRow(Icons.timer_outlined, 'Hết hạn lúc', _formatTime(order.expiresAt));
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} '
        '${local.day}/${local.month}/${local.year}';
  }

  String _statusLabel(OrderStatus s) => switch (s) {
    OrderStatus.pending    => 'Đang chờ',
    OrderStatus.accepted   => 'Đã nhận - đang xử lý',
    OrderStatus.delivering => 'Đã báo giao',
    OrderStatus.completed  => 'hoàn thành',
    OrderStatus.cancelled  => 'Đã huỷ',
    OrderStatus.expired    => 'Hết hạn',
    OrderStatus.disputed   => 'Xung đột',
  };

  Color _statusColor(OrderStatus s) => switch (s) {
    OrderStatus.pending    => Colors.orange,
    OrderStatus.accepted   => Colors.blue,
    OrderStatus.delivering => Colors.teal,
    OrderStatus.completed  => Colors.green,
    OrderStatus.cancelled  => Colors.red,
    OrderStatus.expired    => Colors.grey,
    OrderStatus.disputed   => Colors.deepOrange,
  };
}

// ─── Participants card ────────────────────────────────────────

class _ParticipantsCard extends StatelessWidget {
  final OrderDetail order;
  const _ParticipantsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final creator = order.creator;
    final shipper = order.shipper;
    if (creator == null && shipper == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thành viên', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            if (creator != null)
              _PersonRow(
                icon: Icons.person_outline,
                label: 'Người đặt',
                name: creator.name,
                color: Colors.indigo,
              ),
            if (creator != null && shipper != null)
              const Divider(height: 20),
            if (shipper != null)
              _PersonRow(
                icon: Icons.delivery_dining_outlined,
                label: 'Mua/ship hộ',
                name: shipper.name,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String name;
  final Color color;
  const _PersonRow({required this.icon, required this.label, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ],
    );
  }
}

// ─── Ship address card ────────────────────────────────────────

class _ShipAddressCard extends StatelessWidget {
  final OrderDetail order;
  const _ShipAddressCard({required this.order});

  List<String> _lines() {
    final apt = order.shipApartmentName;
    final b = order.shipBuilding;
    final f = order.shipFloor;
    final r = order.shipRoom;
    final address = switch (order.shipLocation) {
      ShipLocationType.building => [if (b != null) 'Toà $b'],
      ShipLocationType.floor => [
        if (b != null) 'Toà $b',
        if (f != null) 'Tầng $f',
      ],
      ShipLocationType.room => [
        if (b != null) 'Toà $b',
        if (f != null) 'Tầng $f',
        if (r != null) 'Phòng $r',
      ],
    };
    return [if (apt != null) apt, ...address];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B6AF0).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(order.shipLocation.icon, color: const Color(0xFF5B6AF0), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Địa chỉ nhận hàng',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B6AF0), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (lines.isEmpty)
                  const Text('Chưa cập nhật địa chỉ', style: TextStyle(color: Colors.red, fontSize: 13))
                else
                  ...lines.map((l) => Text(l, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Complete order dialog ────────────────────────────────────

class _CompleteOrderResult {
  final double bonusGold;
  _CompleteOrderResult(this.bonusGold);
}

class _CompleteOrderDialog extends StatefulWidget {
  final double originalGold;
  const _CompleteOrderDialog({required this.originalGold});

  @override
  State<_CompleteOrderDialog> createState() => _CompleteOrderDialogState();
}

class _CompleteOrderDialogState extends State<_CompleteOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.originalGold.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _bonus {
    final n = double.tryParse(_ctrl.text.trim()) ?? widget.originalGold;
    return (n - widget.originalGold).clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác nhận hoàn thành'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gold sẽ được chuyển cho người ship ngay lập tức.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Tổng gold thưởng',
                suffixText: 'Gold',
                prefixIcon: const Icon(Icons.monetization_on_outlined),
                helperText: 'Gốc: ${widget.originalGold.toStringAsFixed(0)} Gold · Chỉ được tăng thêm',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null) return 'Vui lòng nhập số hợp lệ';
                if (n < widget.originalGold) return 'Không được thấp hơn ${widget.originalGold.toStringAsFixed(0)} Gold';
                return null;
              },
            ),
            if (_bonus > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Thưởng thêm: +${_bonus.toStringAsFixed(0)} Gold',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _CompleteOrderResult(_bonus));
            }
          },
          child: const Text('Xác nhận hoàn thành'),
        ),
      ],
    );
  }
}

// ─── Delivery confirm dialog ─────────────────────────────────

class _DeliveryConfirmDialog extends StatefulWidget {
  final double originalGold;
  final String title;
  final String subtitle;
  final String confirmLabel;

  const _DeliveryConfirmDialog({
    required this.originalGold,
    this.title = 'Xác nhận đã giao hàng',
    this.subtitle = 'Gold sẽ được cộng sau khi người đặt xác nhận hoặc chờ trong 1 giờ.',
    this.confirmLabel = 'Xác nhận đã giao',
  });

  @override
  State<_DeliveryConfirmDialog> createState() => _DeliveryConfirmDialogState();
}

class _DeliveryConfirmDialogState extends State<_DeliveryConfirmDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.originalGold.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subtitle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Điều chỉnh giảm gold không?',
                suffixText: 'Gold',
                prefixIcon: const Icon(Icons.monetization_on_outlined),
                helperText: 'Tối đa ${widget.originalGold.toStringAsFixed(0)} Gold · Tối thiểu 2 Gold',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null) return 'Vui lòng nhập số hợp lệ';
                if (n < 2) return 'Tối thiểu 2 Gold';
                if (n > widget.originalGold) return 'Không được vượt quá ${widget.originalGold.toStringAsFixed(0)} Gold';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, double.parse(_ctrl.text.trim()));
            }
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

// ─── Accept order dialog ──────────────────────────────────────

class _AcceptOrderDialog extends StatefulWidget {
  final OrderDetail order;
  const _AcceptOrderDialog({required this.order});

  @override
  State<_AcceptOrderDialog> createState() => _AcceptOrderDialogState();
}

class _AcceptOrderDialogState extends State<_AcceptOrderDialog> {
  static const _prefKey = 'accept_order_estimated_minutes';

  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefKey);
    if (saved != null && mounted) {
      _ctrl.text = saved.toString();
    }
  }

  Future<void> _saveAndPop(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, minutes);
    if (mounted) Navigator.pop(context, minutes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác nhận nhận đơn'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.order.note}"',
              style: const TextStyle(fontStyle: FontStyle.italic),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Bạn sẽ nhận được ${widget.order.goldReward.toStringAsFixed(0)} Gold.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Ước lượng thời gian giao',
                suffixText: 'phút',
                prefixIcon: Icon(Icons.timer_outlined),
                helperText: 'Nhập số phút dự kiến bạn sẽ giao đơn này',
                helperMaxLines: 2,
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'Vui lòng nhập số phút hợp lệ (≥ 1)';
                if (n > 300) return 'Tối đa 300 phút';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _saveAndPop(int.parse(_ctrl.text.trim()));
            }
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Xác nhận nhận đơn'),
        ),
      ],
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow(this.icon, this.label, this.value, {this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Propose gold dialog ──────────────────────────────────────

class _ProposeGoldDialog extends StatefulWidget {
  final double currentGold;
  const _ProposeGoldDialog({required this.currentGold});

  @override
  State<_ProposeGoldDialog> createState() => _ProposeGoldDialogState();
}

class _ProposeGoldDialogState extends State<_ProposeGoldDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đề nghị tăng gold'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mức hiện tại: ${widget.currentGold.toStringAsFixed(0)} Gold',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Mức đề nghị',
                suffixText: 'Gold',
                prefixIcon: Icon(Icons.trending_up_rounded),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null) return 'Vui lòng nhập số hợp lệ';
                if (n <= widget.currentGold) return 'Phải cao hơn ${widget.currentGold.toStringAsFixed(0)} Gold';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, double.parse(_ctrl.text.trim()));
            }
          },
          child: const Text('Gửi đề nghị'),
        ),
      ],
    );
  }
}

// ─── Proposals card (creator view) ───────────────────────────

class _ProposalsCard extends StatelessWidget {
  final String orderId;
  final double currentGold;
  final AsyncValue<List<Map<String, dynamic>>> proposalsAsync;
  final Future<void> Function(String proposalId) onAccept;

  const _ProposalsCard({
    required this.orderId,
    required this.currentGold,
    required this.proposalsAsync,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return proposalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (proposals) {
        if (proposals.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4A017).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFF8B6000)),
                    const SizedBox(width: 6),
                    Text(
                      'Đề nghị tăng gold (${proposals.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B6000),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 14, endIndent: 14),
              ...proposals.map((p) {
                final proposerName = p['proposer_name'] as String? ?? 'Ẩn danh';
                final proposedGold = (p['proposed_gold'] as num).toDouble();
                final proposalId = p['id'] as String;
                final diff = proposedGold - currentGold;
                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFECF0FF),
                    child: Icon(Icons.person_outline, size: 18, color: Color(0xFF5B6AF0)),
                  ),
                  title: Text(proposerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '+${diff.toStringAsFixed(0)} Gold so với hiện tại',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${proposedGold.toStringAsFixed(0)} Gold',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B6000),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => onAccept(proposalId),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5B6AF0),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Chấp nhận'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Call option tile ─────────────────────────────────────────

class _DisputeResultCard extends StatelessWidget {
  final double goldReward;
  final bool isCreator;

  const _DisputeResultCard({required this.goldReward, required this.isCreator});

  @override
  Widget build(BuildContext context) {
    final total = goldReward.toInt();
    final shipperGold = total ~/ 2;
    final creatorGold = total - shipperGold;

    return Card(
      color: Colors.deepOrange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.balance_outlined, color: Colors.deepOrange, size: 18),
                const SizedBox(width: 8),
                const Text('Kết quả xung đột',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ],
            ),
            const SizedBox(height: 12),
            _DisputeRow(
              label: 'Người tạo đơn nhận lại',
              gold: creatorGold,
              highlight: isCreator,
            ),
            const SizedBox(height: 8),
            _DisputeRow(
              label: 'Người ship nhận',
              gold: shipperGold,
              highlight: !isCreator,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisputeRow extends StatelessWidget {
  final String label;
  final int gold;
  final bool highlight;

  const _DisputeRow({required this.label, required this.gold, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        Row(
          children: [
            Text(
              '$gold Gold',
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 15 : 13,
                color: highlight ? Colors.deepOrange : Colors.grey.shade600,
              ),
            ),
            if (highlight) ...[
              const SizedBox(width: 4),
              const Text('← bạn', style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
            ],
          ],
        ),
      ],
    );
  }
}

class _CallOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _CallOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? iconColor : Colors.grey;
    return Material(
      color: effectiveColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: effectiveColor, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: enabled ? Colors.black87 : Colors.grey,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const Spacer(),
              if (enabled)
                Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
