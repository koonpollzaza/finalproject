import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text('username'),
              SizedBox(height: 6),
              TextField(decoration: InputDecoration(filled: true, fillColor: Colors.grey, border: InputBorder.none)),
              SizedBox(height: 14),
              Text('password'),
              SizedBox(height: 6),
              TextField(obscureText: true, decoration: InputDecoration(filled: true, fillColor: Colors.grey, border: InputBorder.none)),
              SizedBox(height: 14),
              Text('confirm password'),
              SizedBox(height: 6),
              TextField(obscureText: true, decoration: InputDecoration(filled: true, fillColor: Colors.grey, border: InputBorder.none)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: null, // TODO: ใส่ลอจิกสมัครสมาชิก
                child: Text('สร้างบัญชี'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
