import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final phoneCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final nameCtrl = TextEditingController(); // ชื่อ / ชื่อร้านค้า

  bool loading = false;
  bool codeSent = false;
  String? verificationId;

  String _selectedRole = 'member'; // member, store, rider

  //  รูปโลโก้ร้าน (ใช้เฉพาะตอน role = store)
  File? _storeImageFile;

  //  ประเภทร้าน (เฉพาะตอน store) : food / drink
  String _shopType = 'food';

  @override
  void dispose() {
    phoneCtrl.dispose();
    otpCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  /// แปลง 0812345678 -> +66812345678
  String _formatPhone(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('+')) return s;
    if (s.startsWith('0')) {
      return '+66${s.substring(1)}';
    }
    return '+66$s';
  }

  Future<void> _sendOtp() async {
    final phoneRaw = phoneCtrl.text.trim();
    final name = nameCtrl.text.trim();

    if (name.isEmpty) {
      _toast('กรุณากรอกชื่อ / ชื่อร้านค้า');
      return;
    }

    if (phoneRaw.isEmpty) {
      _toast('กรุณากรอกเบอร์โทรศัพท์');
      return;
    }
    if (phoneRaw.length < 9) {
      _toast('เบอร์โทรศัพท์ไม่ถูกต้อง');
      return;
    }

    final phone = _formatPhone(phoneRaw);

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // auto verify (ส่วนใหญ่ใน Android)
          final cred =
              await FirebaseAuth.instance.signInWithCredential(credential);
          await _afterRegister(cred.user);
        },
        verificationFailed: (FirebaseAuthException e) {
          _toast(_mapAuthError(e));
        },
        codeSent: (String vId, int? resendToken) {
          setState(() {
            verificationId = vId;
            codeSent = true;
          });
          _toast('ส่งรหัส OTP แล้ว กรุณากรอกในช่องด้านล่าง');
        },
        codeAutoRetrievalTimeout: (String vId) {
          verificationId = vId;
        },
      );
    } on FirebaseAuthException catch (e) {
      _toast(_mapAuthError(e));
    } catch (e) {
      _toast('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (verificationId == null) {
      _toast('ยังไม่ได้ส่งรหัส OTP');
      return;
    }
    if (otpCtrl.text.trim().length < 4) {
      _toast('กรุณากรอกรหัส OTP');
      return;
    }

    setState(() => loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpCtrl.text.trim(),
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);

      await _afterRegister(cred.user);
    } on FirebaseAuthException catch (e) {
      _toast(_mapAuthError(e));
    } catch (e) {
      _toast('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _afterRegister(User? user) async {
    if (user == null) {
      _toast('ไม่สามารถสมัครสมาชิกได้');
      return;
    }

    final uid = user.uid;
    final phone = user.phoneNumber ?? _formatPhone(phoneCtrl.text.trim());
    final displayName = nameCtrl.text.trim();

    String? storeId;
    String? riderId;
    String? storeLogoUrl;

    // ถ้าเป็นร้านค้า ให้สร้าง stores/{storeId}
    if (_selectedRole == 'store') {
      final storeRef =
          await FirebaseFirestore.instance.collection('stores').add({
        'name': displayName,
        'ownerUid': uid,
        'phone': phone,
        'shopType': _shopType, //  ประเภทร้าน
        'isBanned': false, //  ค่าเริ่มต้นไม่ถูกแบน
        'approvalStatus': 'pending', //  ค่าเริ่มต้นรออนุมัติ
        'createdAt': FieldValue.serverTimestamp(),
      });
      storeId = storeRef.id;

      //  ถ้ามีเลือกรูปร้าน ให้ upload ขึ้น Storage แล้วเก็บ imageUrl
      if (_storeImageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('stores')
              .child(storeId)
              .child('logo.jpg');

          await storageRef.putFile(_storeImageFile!);
          storeLogoUrl = await storageRef.getDownloadURL();

          await storeRef.update({'imageUrl': storeLogoUrl});
        } catch (e) {
          debugPrint('upload store logo error: $e');
        }
      }
    }

    // ถ้าเป็นไรเดอร์ ให้สร้าง riders/{riderId}
    if (_selectedRole == 'rider') {
      final riderRef =
          await FirebaseFirestore.instance.collection('riders').add({
        'name': displayName,
        'userUid': uid,
        'phone': phone,
        'isBanned': false, // ค่าเริ่มต้นไม่ถูกแบน
        'approvalStatus': 'pending', //  ค่าเริ่มต้นไม่ถูกแบน
        'createdAt': FieldValue.serverTimestamp(),
      });
      riderId = riderRef.id;
    }

    // บันทึกข้อมูลลง Firestore collection 'users'
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'displayName': displayName,
      'phone': phone,
      'role': _selectedRole, // store / member / rider
      'userId': uid,
      'storeId': storeId, // null ถ้าไม่ใช่ store
      'riderId': riderId, // null ถ้าไม่ใช่ rider
      'isBanned': false, //  สมาชิกใหม่ทุกคน isBanned = false
      if (storeLogoUrl != null) 'storeLogoUrl': storeLogoUrl,
      if (_selectedRole == 'store')
        'shopType': _shopType, //  เก็บใน users ด้วย
    }, SetOptions(merge: true));

    _toast('สมัครสมาชิกสำเร็จ');
    if (mounted) Navigator.pop(context); // กลับไปหน้า Login
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
      case 'missing-phone-number':
        return 'กรุณากรอกเบอร์โทรศัพท์';
      case 'invalid-verification-code':
        return 'รหัส OTP ไม่ถูกต้อง';
      case 'session-expired':
        return 'รหัส OTP หมดอายุ กรุณาขอใหม่';
      case 'too-many-requests':
        return 'พยายามบ่อยเกินไป ลองใหม่ภายหลัง';
      default:
        return 'สมัครสมาชิกไม่สำเร็จ (${e.code})';
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade200,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  //  เลือกรูปร้านจากแกลเลอรี่
  Future<void> _pickStoreImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _storeImageFile = File(picked.path);
      });
    } catch (e) {
      debugPrint('pick image error: $e');
      _toast('เลือกภาพไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: const Text('สมัครสมาชิก'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // หัวข้อด้านบน
                  const Text(
                    'สร้างบัญชีใหม่',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'กรอกข้อมูลให้ครบถ้วนเพื่อสมัครสมาชิก',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Role
                  const Text('ประเภทผู้ใช้ (Role)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'store',
                          child: Text('store - ร้านค้า'),
                        ),
                        DropdownMenuItem(
                          value: 'member',
                          child: Text('member - ลูกค้า'),
                        ),
                        DropdownMenuItem(
                          value: 'rider',
                          child: Text('rider - คนส่ง'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedRole = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ ถ้าเป็นร้านค้า แสดงส่วนเลือกรูปโลโก้ + dropdown ประเภรร้าน
                  if (_selectedRole == 'store') ...[
                    const Text('โลโก้ร้านค้า'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _storeImageFile != null
                              ? FileImage(_storeImageFile!)
                              : null,
                          child: _storeImageFile == null
                              ? const Icon(
                                  Icons.storefront,
                                  size: 32,
                                  color: Colors.white70,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : _pickStoreImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('เลือกรูปร้านค้า'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('ประเภทร้านค้า'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _shopType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'food',
                            child: Text('ร้านอาหาร'),
                          ),
                          DropdownMenuItem(
                            value: 'drink',
                            child: Text('ร้านเครื่องดื่ม'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _shopType = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ชื่อ / ชื่อร้านค้า
                  const Text('ชื่อ / ชื่อร้านค้า'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: _inputDecoration(
                      _selectedRole == 'store'
                          ? 'เช่น ร้านก๋วยเตี๋ยวพี่เอ'
                          : 'เช่น ชื่อ-นามสกุล',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // เบอร์โทรศัพท์
                  const Text('เบอร์โทรศัพท์'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('เบอร์ติดต่อ'),
                  ),
                  const SizedBox(height: 16),

                  if (codeSent) ...[
                    const Text('รหัส OTP'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('กรอกรหัส OTP ที่ได้รับ'),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 20),

                  // ปุ่ม
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading
                          ? null
                          : () {
                              if (codeSent) {
                                _verifyOtp();
                              } else {
                                _sendOtp();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              codeSent
                                  ? 'ยืนยัน OTP และสมัครสมาชิก'
                                  : 'ส่งรหัส OTP',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
