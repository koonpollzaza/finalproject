import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'home.dart';          // สำหรับลูกค้า
import 'store.dart';   // หน้าหลักของร้านค้า
import 'register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Page',
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _loading = true);
  try {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailCtl.text.trim(),
      password: _passCtl.text,
    );
    final uid = cred.user!.uid;

    // 1) ถ้าโปรเจ็กต์ของคุณบางร้านใช้ docId=uid จะเช็คแบบนี้ก่อน (เร็วสุด)
    final docById = await FirebaseFirestore.instance
        .collection('stores')
        .doc(uid)
        .get();

    bool isStore = false;

    if (docById.exists &&
        (docById.data()?['role']?.toString().toLowerCase() == 'store')) {
      isStore = true;
    } else {
      // 2) โครงที่คุณใช้อยู่: docId สุ่ม -> query ด้วย ownerUid + role
      final q = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerUid', isEqualTo: uid)
          .where('role', isEqualTo: 'store')
          .limit(1)
          .get();

      isStore = q.docs.isNotEmpty;
    }

    if (!mounted) return;
    if (isStore) {
      // 🔸 ร้านค้า
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StoreHomePage()),
      );
    } else {
      // 🔹 ลูกค้า
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  } on FirebaseAuthException catch (e) {
    _showSnack(_friendlyAuthMessage(e));
  } catch (e) {
    _showSnack('เกิดข้อผิดพลาด: $e');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}



  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'อีเมลไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีถูกปิดใช้งาน';
      case 'user-not-found':
      case 'wrong-password':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
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
                  const Text("อีเมล"),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: border,
                      hintText: 'you@example.com',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกอีเมล' : null,
                  ),
                  const SizedBox(height: 15),
                  const Text("รหัสผ่าน"),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _passCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade200,
                      border: border,
                      hintText: '••••••••',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'กรอกรหัสผ่าน' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
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
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("เข้าสู่ระบบ"),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Center(
                      child: Text(
                        "สมัครสมาชิก",
                        style: TextStyle(decoration: TextDecoration.underline),
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
