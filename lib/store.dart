import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StoreHomePage extends StatelessWidget {
  const StoreHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ยังไม่ได้ล็อกอิน')));
    }

    final storeFuture = FirebaseFirestore.instance
        .collection('stores')
        .where('ownerUid', isEqualTo: user.uid)
        .where('role', isEqualTo: 'store')
        .limit(1)
        .get();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: storeFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}')));
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data!.docs.isEmpty) {
          return const Scaffold(body: Center(child: Text('ยังไม่ได้สร้างร้าน / ไม่พบสิทธิ์ร้านค้า')));
        }

        final storeDoc = snap.data!.docs.first;
        final storeRef = storeDoc.reference;
        final storeName = (storeDoc.data()['name'] ?? 'ร้านของฉัน').toString();
        final menusRef = storeRef.collection('menus').orderBy('name');

        return Scaffold(
          appBar: AppBar(
            title: const Text('หน้าร้านค้า'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มเมนู'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddMenuPage(storeRef: storeRef),
                ),
              );
            },
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text('เมนูของ: $storeName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: menusRef.snapshots(),
                  builder: (context, menuSnap) {
                    if (menuSnap.hasError) {
                      return Center(child: Text('โหลดเมนูผิดพลาด: ${menuSnap.error}'));
                    }
                    if (!menuSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = menuSnap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('ยังไม่มีเมนูในร้านนี้'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = docs[i].data();
                        final name = (m['name'] ?? '').toString();
                        final img  = (m['imageUrl'] ?? '').toString();
                        final price = (m['price'] is num)
                            ? (m['price'] as num).toDouble()
                            : double.tryParse('${m['price']}') ?? 0.0;

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black12),
                          ),
                          child: ListTile(
                            leading: img.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      img, width: 56, height: 56, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                                    ),
                                  )
                                : const CircleAvatar(child: Icon(Icons.fastfood)),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('ราคา: ${price.toStringAsFixed(2)} บาท'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// -----------------------------
/// หน้าเพิ่มเมนู
/// -----------------------------
class AddMenuPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> storeRef;
  const AddMenuPage({super.key, required this.storeRef});

  @override
  State<AddMenuPage> createState() => _AddMenuPageState();
}

class _AddMenuPageState extends State<AddMenuPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _priceCtl = TextEditingController();
  XFile? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      setState(() => _picked = image);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปเมนู')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final name = _nameCtl.text.trim();
      final price = double.parse(_priceCtl.text.trim());

      // เตรียม doc ใหม่ใน subcollection `menus`
      final newDoc = widget.storeRef.collection('menus').doc();

      // อัปโหลดรูป
      final file = File(_picked!.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('stores')
          .child(widget.storeRef.id)
          .child('menus')
          .child('${newDoc.id}.jpg');

      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      // เขียนข้อมูลเมนู
      await newDoc.set({
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มเมนูเรียบร้อย')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black12),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มเมนูใหม่')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // รูปตัวอย่าง
          GestureDetector(
            onTap: _saving ? null : _pickImage,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  image: _picked != null
                      ? DecorationImage(
                          image: FileImage(File(_picked!.path)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _picked == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo, size: 36),
                            SizedBox(height: 8),
                            Text('แตะเพื่อเลือกรูปเมนู'),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: InputDecoration(
                    labelText: 'ชื่อเมนู',
                    border: border,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'กรอกชื่อเมนู' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'ราคา (บาท)',
                    border: border,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'กรอกราคา';
                    final d = double.tryParse(v.trim());
                    if (d == null || d < 0) return 'กรอกราคาให้ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกเมนู'),
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
