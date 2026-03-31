import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

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
  Uint8List? _imageBytes; // ✅ เก็บ bytes
  bool _saving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  /// เลือกรูป
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (image != null) {
      final bytes = await image.readAsBytes(); // ✅ อ่านทันที

      setState(() {
        _picked = image;
        _imageBytes = bytes; // ✅ เก็บไว้ใช้
      });
    }
  }

  /// 🔥 resize รูป
  Future<Uint8List> _resizeImage(Uint8List data) async {
    final original = img.decodeImage(data);
    if (original == null) return data;

    final resized = img.copyResize(
      original,
      width: 800,
    );

    return Uint8List.fromList(
      img.encodeJpg(resized, quality: 80),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรูปเมนู')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final name = _nameCtl.text.trim();
      final price = double.parse(_priceCtl.text.trim());

      final newDoc = widget.storeRef.collection('menus').doc();

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('stores')
          .child(widget.storeRef.id)
          .child('menus')
          .child('${newDoc.id}.jpg');

      /// ✅ resize ก่อน upload
      final resizedBytes = await _resizeImage(_imageBytes!);

      /// ✅ upload
      await storageRef.putData(
        resizedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final imageUrl = await storageRef.getDownloadURL();

      /// ✅ save firestore
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
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.black12),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("เพิ่มเมนูใหม่"),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          /// รูปเมนู
          GestureDetector(
            onTap: _saving ? null : _pickImage,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: _imageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_imageBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageBytes == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 40, color: Colors.grey),
                              SizedBox(height: 10),
                              Text("แตะเพื่อเลือกรูปเมนู"),
                            ],
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),

          const SizedBox(height: 25),

          /// ฟอร์ม
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: InputDecoration(
                    labelText: "ชื่อเมนู",
                    border: border,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "กรอกชื่อเมนู" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "ราคา (บาท)",
                    border: border,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "กรอกราคา";
                    final d = double.tryParse(v.trim());
                    if (d == null || d < 0) return "กรอกราคาให้ถูกต้อง";
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                /// ปุ่มบันทึก
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _saving ? "กำลังบันทึก..." : "บันทึกเมนู",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
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