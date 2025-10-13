import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController(); // ใช้ช่อง "username" เป็นอีเมล
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();

  bool loading = false;
  bool obscure1 = true;
  bool obscure2 = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final pass2 = pass2Ctrl.text;

    // ตรวจข้อมูลเบื้องต้น
    if (email.isEmpty || pass.isEmpty || pass2.isEmpty) {
      _toast('กรุณากรอกข้อมูลให้ครบ');
      return;
    }
    if (!email.contains('@')) {
      _toast('โปรดกรอกอีเมลให้ถูกต้อง');
      return;
    }
    if (pass.length < 6) {
      _toast('รหัสผ่านต้องยาวอย่างน้อย 6 ตัวอักษร');
      return;
    }
    if (pass != pass2) {
      _toast('รหัสผ่านไม่ตรงกัน');
      return;
    }

    setState(() => loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // ตั้ง displayName เป็นส่วนหน้าของอีเมล (เช่น name@… -> name)
      final displayName = email.split('@').first;
      await cred.user?.updateDisplayName(displayName);

      _toast('สมัครสมาชิกสำเร็จ');
      if (mounted) Navigator.pop(context); // กลับไปหน้า Login
    } on FirebaseAuthException catch (e) {
      _toast(_mapAuthError(e));
    } catch (e) {
      _toast('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้ไปแล้ว';
      case 'invalid-email':
        return 'อีเมลไม่ถูกต้อง';
      case 'weak-password':
        return 'รหัสผ่านอ่อนเกินไป';
      case 'operation-not-allowed':
        return 'ยังไม่ได้เปิดใช้ Email/Password ใน Firebase Console';
      default:
        return 'สมัครสมาชิกไม่สำเร็จ (${e.code})';
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('username (ใช้เป็นอีเมล)'),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.grey,
                    border: InputBorder.none,
                    hintText: 'name@example.com',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('password'),
                const SizedBox(height: 6),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure1,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey,
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure1 = !obscure1),
                      icon: Icon(
                          obscure1 ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('confirm password'),
                const SizedBox(height: 6),
                TextField(
                  controller: pass2Ctrl,
                  obscureText: obscure2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey,
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure2 = !obscure2),
                      icon: Icon(
                          obscure2 ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: loading ? null : _register,
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('สร้างบัญชี'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
