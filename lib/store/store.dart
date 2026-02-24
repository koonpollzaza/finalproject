import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_menu.dart';
import 'history_store.dart';
import '../login.dart';

class StoreHomePage extends StatefulWidget {
  const StoreHomePage({super.key});

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  int _currentIndex = 1;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? orderListener;
  bool _listenerStarted = false;

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadStoreByOwnerUid(
      String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  /// 🔔 ฟังออเดอร์
  void listenNewOrders(String storeId) {
    if (_listenerStarted) return;
    _listenerStarted = true;

    orderListener?.cancel();

    orderListener = FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('payment', isEqualTo: 'success')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("🔔 มีออเดอร์ใหม่ชำระเงินแล้ว"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: "ดู",
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoryStorePage(storeId: storeId), // ✅ ส่ง storeId
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    orderListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Future.microtask(() {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _loadStoreByOwnerUid(user.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snap.data == null) {
          return const Scaffold(
            body: Center(child: Text("บัญชีนี้ยังไม่ได้สร้างร้านค้า")),
          );
        }

        final storeDoc = snap.data!;
        final storeRef = storeDoc.reference;
        final storeId = storeRef.id;
        final storeName = storeDoc.data()!['name'] ?? 'ร้านของฉัน';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          listenNewOrders(storeId);
        });

        final menusQuery =
            storeRef.collection('menus').orderBy('name', descending: false);

        return Scaffold(
          appBar: AppBar(
            title: Text('ร้าน: $storeName'),
          ),

          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: menusQuery.snapshots(),
            builder: (context, menuSnap) {
              if (!menuSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = menuSnap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('ยังไม่มีเมนูในร้านนี้'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final m = docs[i].data();
                  final name = m['name'] ?? "";
                  final img = m['imageUrl'] ?? "";
                  final price =
                      (m['price'] as num?)?.toDouble() ?? 0.0;

                  return Card(
                    child: ListTile(
                      leading: img.isNotEmpty
                          ? Image.network(img, width: 56, height: 56)
                          : const Icon(Icons.fastfood),
                      title: Text(name),
                      subtitle:
                          Text('ราคา ${price.toStringAsFixed(2)} บาท'),
                    ),
                  );
                },
              );
            },
          ),

          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant), label: 'เพิ่มเมนู'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'ประวัติ'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.logout), label: 'ออก'),
            ],
            onTap: (index) async {
              setState(() => _currentIndex = index);

              if (index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMenuPage(storeRef: storeRef),
                  ),
                );
              } else if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        HistoryStorePage(storeId: storeId), // ✅ ส่ง storeId
                  ),
                );
              } else if (index == 2) {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              }
            },
          ),
        );
      },
    );
  }
}