import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
