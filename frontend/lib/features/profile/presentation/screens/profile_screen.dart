import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/auth_state.dart';

// ── Models ──────────────────────────────────────────────────

class _Building {
  final String id;
  final String name;
  _Building({required this.id, required this.name});
  factory _Building.fromJson(Map<String, dynamic> j) =>
      _Building(id: j['id'] as String, name: j['name'] as String);
}

class _AptOption {
  final String id;
  final String name;
  final String address;
  final String? imageUrl;
  final List<_Building> buildings;
  _AptOption({required this.id, required this.name, required this.address, this.imageUrl, required this.buildings});
  factory _AptOption.fromJson(Map<String, dynamic> j) => _AptOption(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String,
        imageUrl: j['image_url'] as String?,
        buildings: (j['buildings'] as List).map((b) => _Building.fromJson(b as Map<String, dynamic>)).toList(),
      );
}

// ── Providers ─────────────────────────────────────────────

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(apiClientProvider).dio.get('/users/me');
  return res.data as Map<String, dynamic>;
});

final _aptListProvider = FutureProvider.autoDispose<List<_AptOption>>((ref) async {
  final res = await ref.read(apiClientProvider).dio.get('/users/apartments');
  return (res.data as List).map((e) => _AptOption.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Profile screen ────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_meProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (me) => _ProfileBody(me: me),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final Map<String, dynamic> me;
  const _ProfileBody({required this.me});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    authTokenNotifier.value = null; // triggers GoRouter redirect → /login
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = me['display_name'] as String? ?? me['username'] as String? ?? '---';
    final username = me['username'] as String? ?? '---';
    final gold = (me['gold_balance'] as num?)?.toStringAsFixed(0) ?? '--';

    final aptMap = me['apartment'] as Map<String, dynamic>?;
    final aptName = aptMap?['name'] as String?;
    final aptAddress = aptMap?['address'] as String?;
    final aptBuilding = me['apt_building'] as String?;
    final aptFloor = me['apt_floor'];
    final aptRoom = me['apt_room'] as String?;
    final aptBuildingCount = ((aptMap?['buildings'] as List?)?.length ?? 0);

    String aptLine1 = 'Chưa cập nhật';
    String? aptLine2;
    if (aptName != null) {
      final showBuilding = aptBuilding != null && aptBuildingCount > 1;
      aptLine1 = showBuilding ? '$aptName – Toà $aptBuilding' : aptName;
      final parts = [
        if (aptAddress != null) aptAddress,
        if (aptFloor != null) 'Tầng $aptFloor',
        if (aptRoom != null) 'Phòng $aptRoom',
      ];
      if (parts.isNotEmpty) aptLine2 = parts.join(' – ');
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar + name
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF5B6AF0),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('@$username', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Gold balance
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
              const Icon(Icons.monetization_on_rounded, color: Color(0xFFF5A623), size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Số dư Gold', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('$gold Gold', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Info card
        Card(
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => _ApartmentPickerScreen(me: me)),
                  );
                  if (ok == true) ref.invalidate(_meProvider);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.home_outlined, color: Color(0xFF5B6AF0)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Căn hộ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(aptLine1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                            if (aptLine2 != null)
                              Text(aptLine2, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: Color(0xFF5B6AF0)),
                title: const Text('Tài khoản', style: TextStyle(fontSize: 12, color: Colors.grey)),
                subtitle: Text(username, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Logout
        OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ── Apartment picker screen (pushed via Navigator) ────────

class _ApartmentPickerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> me;
  const _ApartmentPickerScreen({required this.me});

  @override
  ConsumerState<_ApartmentPickerScreen> createState() => _ApartmentPickerScreenState();
}

class _ApartmentPickerScreenState extends ConsumerState<_ApartmentPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _query = '';
  _AptOption? _selected;
  String? _selectedBuilding;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final aptMap = widget.me['apartment'] as Map<String, dynamic>?;
    if (aptMap != null) {
      _selected = _AptOption(
        id: aptMap['id'] as String,
        name: aptMap['name'] as String,
        address: aptMap['address'] as String,
        imageUrl: aptMap['image_url'] as String?,
        buildings: [],
      );
    }
    _selectedBuilding = widget.me['apt_building'] as String?;
    final floor = widget.me['apt_floor'];
    if (floor != null) _floorCtrl.text = floor.toString();
    _roomCtrl.text = widget.me['apt_room'] as String? ?? '';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _floorCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) return;
    final apts = ref.read(_aptListProvider).value ?? [];
    final fullApt = apts.firstWhere((a) => a.id == _selected!.id, orElse: () => _selected!);
    if (fullApt.buildings.length > 1 && _selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn toà nhà'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).dio.patch('/users/me', data: {
        'apartment_id': _selected!.id,
        'apt_building': _selectedBuilding,
        'apt_floor': int.tryParse(_floorCtrl.text.trim()),
        'apt_room': _roomCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map ? e.response?.data['detail'] : null) ?? 'Lưu thất bại';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aptsAsync = ref.watch(_aptListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn căn hộ'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _selected == null ? null : _save,
              child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc địa chỉ...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
            ),
            // Apartment list
            Expanded(
              child: aptsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (apts) {
                  final filtered = _query.isEmpty
                      ? apts
                      : apts.where((a) =>
                          a.name.toLowerCase().contains(_query) ||
                          a.address.toLowerCase().contains(_query)).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Không tìm thấy căn hộ nào.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final apt = filtered[i];
                      final isSelected = _selected?.id == apt.id;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AptTile(
                            apt: apt,
                            isSelected: isSelected,
                            onTap: () => setState(() {
                              _selected = apt;
                              if (!isSelected) _selectedBuilding = null;
                            }),
                          ),
                          if (isSelected && apt.buildings.length > 1)
                            _BuildingSelector(
                              buildings: apt.buildings,
                              selected: _selectedBuilding,
                              onSelect: (b) => setState(() => _selectedBuilding = b),
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            // Floor & room — always visible at bottom
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vị trí của bạn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _floorCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Tầng *',
                            hintText: 'VD: 5',
                            prefixIcon: const Icon(Icons.layers_outlined),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nhập số tầng';
                            if (int.tryParse(v.trim()) == null) return 'Phải là số';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _roomCtrl,
                          decoration: InputDecoration(
                            labelText: 'Phòng *',
                            hintText: 'VD: 502',
                            prefixIcon: const Icon(Icons.door_front_door_outlined),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập mã phòng' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Apartment tile ────────────────────────────────────────

class _AptTile extends StatelessWidget {
  final _AptOption apt;
  final bool isSelected;
  final VoidCallback onTap;
  const _AptTile({required this.apt, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B6AF0) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? const Color(0xFFEEF0FF) : Colors.white,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
              child: apt.imageUrl != null
                  ? Image.network(apt.imageUrl!, width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(apt.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(apt.address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (apt.buildings.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${apt.buildings.length} toà: ${apt.buildings.map((b) => b.name).join(', ')}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF5B6AF0)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.check_circle, color: Color(0xFF5B6AF0)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 72, height: 72,
    color: Colors.grey.shade100,
    child: const Icon(Icons.apartment_outlined, color: Colors.grey, size: 28),
  );
}

// ── Building selector ─────────────────────────────────────

class _BuildingSelector extends StatelessWidget {
  final List<_Building> buildings;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _BuildingSelector({required this.buildings, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FF),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: const Color(0xFF5B6AF0), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.apartment, size: 14, color: Color(0xFF5B6AF0)),
            const SizedBox(width: 4),
            Text(
              selected == null ? 'Chọn toà nhà (bắt buộc)' : 'Toà nhà',
              style: TextStyle(
                fontSize: 12,
                color: selected == null ? Colors.red.shade700 : const Color(0xFF5B6AF0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: buildings.map((b) {
              final isSel = selected == b.name;
              return GestureDetector(
                onTap: () => onSelect(b.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF5B6AF0) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF5B6AF0)),
                  ),
                  child: Text(
                    b.name,
                    style: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF5B6AF0),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
