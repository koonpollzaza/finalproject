import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_menu.dart';
import 'history_store.dart';
import 'select_location_store.dart';
import '../login.dart';

class StoreHomePage extends StatefulWidget {
  const StoreHomePage({super.key});

  @override
  State<StoreHomePage> createState() => _StoreHomePageState();
}

class _StoreHomePageState extends State<StoreHomePage> {
  int _currentIndex = 0;

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

  /// 🔴 ลบเมนู
  Future<void> _deleteMenu(DocumentReference docRef) async {
    try {
      await docRef.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ลบเมนูเรียบร้อย"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ลบไม่สำเร็จ: $e")),
      );
    }
  }

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
              action: SnackBarAction(
                label: "ดู",
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryStorePage(storeId: storeId),
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

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _loadStoreByOwnerUid(user.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.data == null) {
          return const Scaffold(
            body: Center(child: Text("บัญชีนี้ยังไม่ได้สร้างร้านค้า")),
          );
        }

        final storeDoc = snap.data!;
        final storeRef = storeDoc.reference;
        final storeId = storeRef.id;
        final storeName = storeDoc.data()?['name'] ?? 'ร้านของฉัน';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          listenNewOrders(storeId);
        });

        final menusQuery =
            storeRef.collection('menus').orderBy('name', descending: false);

        return Scaffold(
          backgroundColor: Colors.grey[100],

          appBar: AppBar(
            title: Text(storeName),
            centerTitle: true,
            backgroundColor: Colors.orange,
          ),

          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: menusQuery.snapshots(),
            builder: (context, menuSnap) {
              if (!menuSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = menuSnap.data!.docs;

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'ยังไม่มีเมนูในร้าน',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final m = docs[i].data();

                  final name = m['name'] ?? "";
                  final img = m['imageUrl'] ?? "";
                  final price = (m['price'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),

                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: img.isNotEmpty
                              ? Image.network(
                                  img,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 70,
                                  height: 70,
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                  child: const Icon(Icons.fastfood),
                                ),
                        ),

                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        subtitle: Text(
                          "ราคา ${price.toStringAsFixed(2)} บาท",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        /// 🔴 ปุ่มลบเมนู
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("ลบเมนู"),
                                content:
                                    const Text("คุณต้องการลบเมนูนี้หรือไม่"),
                                actions: [
                                  TextButton(
                                    child: const Text("ยกเลิก"),
                                    onPressed: () =>
                                        Navigator.pop(context),
                                  ),
                                  TextButton(
                                    child: const Text(
                                      "ลบ",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteMenu(docs[i].reference);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.orange,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box),
                label: 'เพิ่มเมนู',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'ประวัติ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on),
                label: 'ตำแหน่งร้าน',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.logout),
                label: 'ออก',
              ),
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
                    builder: (_) => HistoryStorePage(storeId: storeId),
                  ),
                );
              } else if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SelectLocationStorePage(storeId: storeId),
                  ),
                );
              } else if (index == 3) {
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