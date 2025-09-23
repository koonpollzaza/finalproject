import 'package:flutter/material.dart';
import 'home.dart'; // import หน้า HomePage


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // ให้เริ่มต้นเข้าหน้า HomePage
      home: const HomePage(),
    );
  }
}
