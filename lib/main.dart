import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// หน้า Login
import 'package:finalproject/login.dart';

// หน้าแต่ละ role
import 'package:finalproject/home.dart';
import 'package:finalproject/store/store.dart';
import 'package:finalproject/store/rider.dart';

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
      debugShowCheckedModeBanner: false,
      title: 'Final Project',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getPageByRole(User user) async {
    final uid = user.uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        return const LoginPage();
      }

      final data = doc.data();
      final role = data?['role']?.toString().toLowerCase();

      // 👤 USER
      if (role == 'users' || role == 'user' || role == 'member') {
        return const HomePage();
      }

      // 🏪 STORE
      if (role == 'stores' || role == 'store') {
        return const StoreHomePage();
      }

      // 🚴 RIDER
      if (role == 'riders' || role == 'rider') {
        return RiderHomePage(
          riderId: uid, // 🔥 สำคัญมาก
        );
      }

      // ❌ role ไม่ถูกต้อง
      await FirebaseAuth.instance.signOut();
      return const LoginPage();
    } catch (e) {
      debugPrint('Role error: $e');
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ ยังไม่ login
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // ✅ login แล้ว → เช็ค role
        return FutureBuilder<Widget>(
          future: _getPageByRole(snapshot.data!),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error: ${roleSnap.error}'),
                ),
              );
            }

            return roleSnap.data ?? const LoginPage();
          },
        );
      },
    );
  }
}