import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// หน้าที่ต้องมี
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

  /// โหลดร้านจาก ownerUid เท่านั้น
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

  /// 🔔 ฟังออเดอร์ที่ชำระเงินแล้ว
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
        // ใช้ added เพื่อกันแจ้งเตือนย้อนหลัง
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
                        builder: (_) => const HistoryStorePage()),
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
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snap.hasError) {
          return Scaffold(
              body: Center(child: Text('โหลดข้อมูลผิดพลาด: ${snap.error}')));
        }

        if (!snap.hasData || snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("หน้าร้านค้า")),
            body: const Center(
              child: Text(
                "บัญชีนี้ยังไม่ได้สร้างร้านค้า",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final storeDoc = snap.data!;
        final storeRef = storeDoc.reference;
        final storeId = storeRef.id;
        final data = storeDoc.data()!;
        final storeName = data['name'] ?? 'ร้านของฉัน';

        // 🔔 เริ่มฟังออเดอร์หลัง build เสร็จ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          listenNewOrders(storeId);
        });

        final menusQuery =
            storeRef.collection('menus').orderBy('name', descending: false);

        return Scaffold(
          appBar: AppBar(
            title: Text('ร้าน: $storeName'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Store ID: $storeId',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Divider(),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: menusQuery.snapshots(),
                  builder: (context, menuSnap) {
                    if (!menuSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final docs = menuSnap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('ยังไม่มีเมนูในร้านนี้'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final m = docs[i].data();
                        final name = m['name'] ?? "";
                        final img = m['imageUrl'] ?? "";
                        final price = (m['price'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          child: ListTile(
                            leading: img.isNotEmpty
                                ? Image.network(
                                    img,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.fastfood),
                            title: Text(name),
                            subtitle: Text(
                                'ราคา ${price.toStringAsFixed(2)} บาท'),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
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
                    builder: (_) => const HistoryStorePage(),
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
