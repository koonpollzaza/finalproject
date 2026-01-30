import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // ⬅️ เพิ่ม

import 'home.dart';            // member ลูกค้า
import 'store/store.dart';     // store ร้านค้า
import 'store/rider.dart';     // rider คนส่ง
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _phoneCtl = TextEditingController();
  final _otpCtl = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;
  String? _verificationId;

  // ====== สำหรับโลโก้จาก Firebase Storage ======
  String? _logoUrl;
  bool _logoLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      // path: logos/login.png
      final ref = FirebaseStorage.instance.ref().child('logos/logo_login.png');
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _logoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _logoLoading = false;
      debugPrint('load logo error: $e');
    }
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _otpCtl.dispose();
    super.dispose();
  }

  /// แปลงเบอร์ 0812345678 → +66812345678
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
    if (!_formKey.currentState!.validate()) return;

    final phone = _formatPhone(_phoneCtl.text);

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final cred =
              await FirebaseAuth.instance.signInWithCredential(credential);
          await _afterLogin(cred.user!);
        },
        verificationFailed: (FirebaseAuthException e) {
          _showSnack(_friendlyAuthMessage(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
          });
          _showSnack('ส่งรหัส OTP แล้ว กรุณากรอกที่ด้านล่าง');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthMessage(e));
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtpAndLogin() async {
    if (_verificationId == null) {
      _showSnack('ยังไม่ได้ส่งรหัส OTP');
      return;
    }
    if (_otpCtl.text.trim().length < 4) {
      _showSnack('กรุณากรอกรหัส OTP');
      return;
    }

    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtl.text.trim(),
      );

      final cred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await _afterLogin(cred.user!);
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthMessage(e));
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================================
  // ใช้ userId (uid) แยก role แล้วแยกหน้า
  // ================================
  Future<void> _afterLogin(User user) async {
    final uid = user.uid; // = userId ที่เราเก็บไว้ตอน register

    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!snap.exists) {
      _showSnack('ยังไม่พบข้อมูลผู้ใช้ใน users/$uid');
      return;
    }

    final data = snap.data()!;
    final role = (data['role'] ?? 'member').toString().toLowerCase();

    if (!mounted) return;

    switch (role) {
      case 'store':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StoreHomePage()),
        );
        break;

      case 'rider':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RiderHomePage(riderId: uid),
          ),
        );
        break;  


      case 'member':
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;
    }
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
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
        return 'ล็อกอินไม่สำเร็จ (${e.code})';
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    );

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // ====== แสดงโลโก้จาก Firebase Storage ======
                  if (_logoLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else if (_logoUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Image.network(
                        _logoUrl!,
                        height: 420,
                        fit: BoxFit.contain,
                      ),
                    ),

                  const Text("เบอร์โทรศัพท์"),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: border,
                      hintText: 'เบอร์โทรศัพท์',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'กรอกเบอร์โทรศัพท์';
                      }
                      if (v.trim().length < 9) {
                        return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  if (_codeSent) ...[
                    const Text("รหัส OTP"),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _otpCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: border,
                        hintText: 'รหัส OTP',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_codeSent) {
                              _verifyOtpAndLogin();
                            } else {
                              _sendOtp();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_codeSent ? "ยืนยัน OTP" : "ส่งรหัส OTP"),
                  ),

                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Center(
                      child: Text(
                        "สมัครสมาชิก",
                        style: TextStyle(
                            decoration: TextDecoration.underline),
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
