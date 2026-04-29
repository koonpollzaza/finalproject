import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home.dart';
import 'store/store.dart';
import 'store/rider.dart';
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

  String? _loginRole;

  String? _logoUrl;
  bool _logoLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('logos/logo_login.png');
      final url = await ref.getDownloadURL();

      if (!mounted) return;

      setState(() {
        _logoUrl = url;
        _logoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _logoLoading = false;
      });

      debugPrint('load logo error: $e');
    }
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _otpCtl.dispose();
    super.dispose();
  }

  String _formatPhoneLocal(String raw) {
    String phone = raw.trim().replaceAll(' ', '').replaceAll('-', '');

    if (phone.startsWith('+66')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('66')) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  String _formatPhoneFirebase(String raw) {
    final phone = _formatPhoneLocal(raw);

    if (phone.startsWith('0')) {
      return '+66${phone.substring(1)}';
    }

    return phone;
  }

  List<String> _phoneSearchKeys(String raw) {
    final phone = _formatPhoneLocal(raw);

    if (phone.startsWith('0')) {
      final noZero = phone.substring(1);

      return [
        phone,
        '+66$noZero',
        '66$noZero',
      ];
    }

    return [phone];
  }

  Future<void> _loginByRole() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final localPhone = _formatPhoneLocal(_phoneCtl.text);

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', whereIn: _phoneSearchKeys(localPhone))
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _showSnack('ไม่พบข้อมูลผู้ใช้ กรุณาสมัครสมาชิกก่อน');
        return;
      }

      final userDoc = userQuery.docs.first;
      final data = userDoc.data();

      final role = (data['role'] ?? 'member').toString().toLowerCase();

      final displayName = (data['displayName'] ??
              data['fullname'] ??
              data['fullName'] ??
              data['name'] ??
              '')
          .toString();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('loginPhone', localPhone);
      await prefs.setString('loginRole', role);
      await prefs.setString('loginUserDocId', userDoc.id);
      await prefs.setString('loginDisplayName', displayName);

      _loginRole = role;

      if (role == 'member') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        return;
      }

      if (role == 'store' || role == 'rider') {
        await _sendOtpForStoreOrRider(localPhone);
        return;
      }

      _showSnack('ไม่รู้จักประเภทผู้ใช้: $role');
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendOtpForStoreOrRider(String localPhone) async {
    final phone = _formatPhoneFirebase(localPhone);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final cred =
              await FirebaseAuth.instance.signInWithCredential(credential);

          if (cred.user != null) {
            await _afterLogin(cred.user!);
          }
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

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);

      if (cred.user == null) {
        _showSnack('เข้าสู่ระบบไม่สำเร็จ');
        return;
      }

      await _afterLogin(cred.user!);
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthMessage(e));
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _afterLogin(User user) async {
    final uid = user.uid;

    final userSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!userSnap.exists) {
      _showSnack('ยังไม่พบข้อมูลผู้ใช้');
      return;
    }

    final data = userSnap.data()!;
    final role =
        _loginRole ?? (data['role'] ?? 'member').toString().toLowerCase();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('loginUid', uid);
    await prefs.setString('loginRole', role);
    await prefs.setString(
      'loginPhone',
      _formatPhoneLocal(
        (data['phone'] ?? user.phoneNumber ?? _phoneCtl.text).toString(),
      ),
    );

    if (!mounted) return;

    if (role == 'member') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
      return;
    }

    if (role == 'store') {
      final storeQuery = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (storeQuery.docs.isEmpty) {
        _showSnack('ไม่พบข้อมูลร้านค้า');
        return;
      }

      final status =
          (storeQuery.docs.first.data()['approvalStatus'] ?? 'pending')
              .toString();

      if (status == 'pending') {
        _showSnack('ร้านค้าของคุณกำลังรอการอนุมัติจากแอดมิน');
        await FirebaseAuth.instance.signOut();
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StoreHomePage()),
      );
      return;
    }

    if (role == 'rider') {
      final riderQuery = await FirebaseFirestore.instance
          .collection('riders')
          .where('userUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (riderQuery.docs.isEmpty) {
        _showSnack('ไม่พบข้อมูลไรเดอร์');
        return;
      }

      final status =
          (riderQuery.docs.first.data()['approvalStatus'] ?? 'pending')
              .toString();

      if (status == 'pending') {
        _showSnack('บัญชีไรเดอร์ของคุณกำลังรอการอนุมัติ');
        await FirebaseAuth.instance.signOut();
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RiderHomePage(riderId: uid),
        ),
      );
      return;
    }

    _showSnack('ไม่รู้จักประเภทผู้ใช้');
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
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    if (_logoLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: SizedBox(
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_logoUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Image.network(
                          _logoUrl!,
                          height: 300,
                          fit: BoxFit.contain,
                        ),
                      ),

                    const Text("เบอร์โทรศัพท์"),
                    const SizedBox(height: 5),

                    TextFormField(
                      controller: _phoneCtl,
                      keyboardType: TextInputType.phone,
                      enabled: !_codeSent,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: border,
                        hintText: 'เบอร์โทรศัพท์',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'กรอกเบอร์โทรศัพท์';
                        }

                        final phone = _formatPhoneLocal(v);

                        if (phone.length != 10 || !phone.startsWith('0')) {
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
                            horizontal: 12,
                            vertical: 14,
                          ),
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
                                _loginByRole();
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
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_codeSent ? "ยืนยัน OTP" : "เข้าสู่ระบบ"),
                    ),

                    const SizedBox(height: 15),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Center(
                        child: Text(
                          "สมัครสมาชิก",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}