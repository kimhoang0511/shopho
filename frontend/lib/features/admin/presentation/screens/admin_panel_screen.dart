import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';

// ── Models ──────────────────────────────────────────────────

class ApartmentBuilding {
  final String id;
  final String name;
  ApartmentBuilding({required this.id, required this.name});
  factory ApartmentBuilding.fromJson(Map<String, dynamic> j) =>
      ApartmentBuilding(id: j['id'] as String, name: j['name'] as String);
}

class Apartment {
  final String id;
  final String name;
  final String address;
  final String? imageUrl;
  final List<ApartmentBuilding> buildings;
  Apartment({required this.id, required this.name, required this.address, this.imageUrl, required this.buildings});
  factory Apartment.fromJson(Map<String, dynamic> j) => Apartment(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String,
        imageUrl: j['image_url'] as String?,
        buildings: (j['buildings'] as List).map((b) => ApartmentBuilding.fromJson(b as Map<String, dynamic>)).toList(),
      );
}

// ── Provider ─────────────────────────────────────────────────

final _apartmentsProvider = FutureProvider.autoDispose<List<Apartment>>((ref) async {
  final dio = ref.read(apiClientProvider).dio;
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'admin_token');
  final res = await dio.get('/admin/apartments', options: Options(headers: {'Authorization': 'Bearer $token'}));
  return (res.data as List).map((e) => Apartment.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Apartment> _filter(List<Apartment> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((a) =>
      a.name.toLowerCase().contains(q) ||
      a.address.toLowerCase().contains(q),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final apts = ref.watch(_apartmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý căn hộ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất admin',
            onPressed: () async {
              const storage = FlutterSecureStorage();
              await storage.delete(key: 'admin_token');
              if (context.mounted) context.go('/admin/login');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Thêm căn hộ'),
        onPressed: () async {
          final ok = await _showApartmentDialog(context, ref, null);
          if (ok == true) ref.invalidate(_apartmentsProvider);
        },
      ),
      body: apts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('$e'),
            TextButton(onPressed: () => ref.invalidate(_apartmentsProvider), child: const Text('Thử lại')),
          ]),
        ),
        data: (all) {
          final list = _filter(all);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc địa chỉ căn hộ...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${list.length} kết quả', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? Center(child: Text(
                        all.isEmpty ? 'Chưa có căn hộ nào. Nhấn + để thêm.' : 'Không tìm thấy kết quả.',
                        style: const TextStyle(color: Colors.grey),
                      ))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ApartmentCard(
                          apt: list[i],
                          onEdit: () async {
                            final ok = await _showApartmentDialog(context, ref, list[i]);
                            if (ok == true) ref.invalidate(_apartmentsProvider);
                          },
                          onDelete: () async {
                            final ok = await _confirmDelete(context, list[i].name);
                            if (ok == true) {
                              await _deleteApartment(ref, list[i].id);
                              ref.invalidate(_apartmentsProvider);
                            }
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────

class _ApartmentCard extends StatelessWidget {
  final Apartment apt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ApartmentCard({required this.apt, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ảnh căn hộ
        if (apt.imageUrl != null)
          SizedBox(
            width: double.infinity,
            height: 160,
            child: Image.network(
              apt.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: Colors.grey.shade100,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 100,
            color: Colors.grey.shade100,
            child: const Icon(Icons.apartment_outlined, color: Colors.grey, size: 40),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(apt.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(apt.address, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.edit_outlined, color: Color(0xFF5B6AF0)), onPressed: onEdit, tooltip: 'Sửa'),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete, tooltip: 'Xoá'),
            ]),
            if (apt.buildings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Các toà:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: apt.buildings.map((b) => Chip(
                  label: Text(b.name, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFFEEF0FF),
                  side: BorderSide.none,
                )).toList(),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Dialog thêm / sửa ───────────────────────────────────────

Future<bool?> _showApartmentDialog(BuildContext context, WidgetRef ref, Apartment? apt) {
  final nameCtrl = TextEditingController(text: apt?.name ?? '');
  final addressCtrl = TextEditingController(text: apt?.address ?? '');
  final buildingCtrl = TextEditingController();
  final buildings = <String>[...?apt?.buildings.map((b) => b.name)];
  final formKey = GlobalKey<FormState>();
  File? pickedImage;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(apt == null ? 'Thêm căn hộ' : 'Sửa căn hộ'),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Ảnh preview + chọn ảnh
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 72, maxWidth: 1080, maxHeight: 1080);
                    if (picked != null) setState(() => pickedImage = File(picked.path));
                  },
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: pickedImage != null
                        ? Image.file(pickedImage!, fit: BoxFit.cover)
                        : apt?.imageUrl != null
                            ? Image.network(apt!.imageUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imgPlaceholder())
                            : _imgPlaceholder(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pickedImage != null ? 'Ảnh mới đã chọn' : 'Nhấn để chọn ảnh căn hộ',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên căn hộ', hintText: 'VD: Origraden'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên căn hộ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Địa chỉ', hintText: 'VD: 36 Nguyễn Cơ Thạch, Hà Nội'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập địa chỉ' : null,
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: buildingCtrl,
                      decoration: const InputDecoration(labelText: 'Thêm toà', hintText: 'VD: CT1'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF5B6AF0)),
                    onPressed: () {
                      final v = buildingCtrl.text.trim();
                      if (v.isNotEmpty && !buildings.contains(v)) {
                        setState(() { buildings.add(v); buildingCtrl.clear(); });
                      }
                    },
                  ),
                ]),
                if (buildings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: buildings.map((b) => Chip(
                      label: Text(b),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => buildings.remove(b)),
                      backgroundColor: const Color(0xFFEEF0FF),
                      side: BorderSide.none,
                    )).toList(),
                  ),
                ],
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final savedId = await _saveApartment(ref, apt?.id, nameCtrl.text.trim(), addressCtrl.text.trim(), buildings);
              if (pickedImage != null && savedId != null) {
                await _uploadApartmentImage(ref, savedId, pickedImage!);
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: Text(apt == null ? 'Thêm' : 'Lưu'),
          ),
        ],
      ),
    ),
  );
}

Widget _imgPlaceholder() => const Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 36),
    SizedBox(height: 4),
    Text('Chọn ảnh', style: TextStyle(color: Colors.grey, fontSize: 12)),
  ],
);

Future<bool?> _confirmDelete(BuildContext context, String name) => showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Xoá căn hộ'),
    content: Text('Bạn có chắc muốn xoá "$name"?\nTất cả toà nhà sẽ bị xoá theo.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Xoá'),
      ),
    ],
  ),
);

// ── API helpers ───────────────────────────────────────────────

Future<String?> _saveApartment(WidgetRef ref, String? id, String name, String address, List<String> buildings) async {
  final dio = ref.read(apiClientProvider).dio;
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'admin_token');
  final opts = Options(headers: {'Authorization': 'Bearer $token'});
  final body = {'name': name, 'address': address, 'buildings': buildings};
  final Response res;
  if (id == null) {
    res = await dio.post('/admin/apartments', data: body, options: opts);
  } else {
    res = await dio.put('/admin/apartments/$id', data: body, options: opts);
  }
  return (res.data as Map<String, dynamic>?)?['id'] as String?;
}

Future<void> _uploadApartmentImage(WidgetRef ref, String aptId, File image) async {
  final dio = ref.read(apiClientProvider).dio;
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'admin_token');
  final ext = image.path.split('.').last.toLowerCase();
  final mime = ext == 'jpg' ? 'jpeg' : ext;
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(
      image.path,
      contentType: MediaType('image', mime),
    ),
  });
  await dio.post(
    '/admin/apartments/$aptId/image',
    data: formData,
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
}

Future<void> _deleteApartment(WidgetRef ref, String id) async {
  final dio = ref.read(apiClientProvider).dio;
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'admin_token');
  await dio.delete('/admin/apartments/$id', options: Options(headers: {'Authorization': 'Bearer $token'}));
}
