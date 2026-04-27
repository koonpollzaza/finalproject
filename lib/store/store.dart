import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_menu.dart';
import 'history_store.dart';
import 'pending_store.dart';
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
  String? _currentListeningStoreId;

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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ลบไม่สำเร็จ: $e")),
      );
    }
  }

  Future<void> _toggleStoreStatus({
    required DocumentReference<Map<String, dynamic>> storeRef,
    required bool currentStatus,
  }) async {
    try {
      await storeRef.update({
        'isOpen': !currentStatus,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus ? "✅ เปิดร้านแล้ว" : "❌ ปิดร้านแล้ว",
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เปลี่ยนสถานะร้านไม่สำเร็จ: $e")),
      );
    }
  }

  void listenNewOrders(String storeId) {
    if (_listenerStarted && _currentListeningStoreId == storeId) return;

    _listenerStarted = true;
    _currentListeningStoreId = storeId;

    orderListener?.cancel();

    orderListener = FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .where('payment', isEqualTo: 'success')
        .where('status', isEqualTo: 'pending')
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
                      builder: (_) => PendingStorePage(storeId: storeId),
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .where('ownerUid', isEqualTo: user.uid)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("บัญชีนี้ยังไม่ได้สร้างร้านค้า")),
          );
        }

        final storeDoc = snap.data!.docs.first;
        final storeRef = storeDoc.reference;
        final storeId = storeRef.id;
        final storeData = storeDoc.data();

        final storeName = storeData['name'] ?? 'ร้านของฉัน';
        final isOpen = storeData['isOpen'] ?? false;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          listenNewOrders(storeId);
        });

        final menusQuery =
            storeRef.collection('menus').orderBy('name', descending: false);

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(storeName),
                const SizedBox(height: 2),
                Text(
                  isOpen ? 'สถานะร้าน: เปิด' : 'สถานะร้าน: ปิด',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOpen ? Colors.green.shade100 : Colors.red.shade100,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            backgroundColor: Colors.orange,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOpen ? "เปิด" : "ปิด",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: isOpen,
                      activeColor: Colors.green,
                      onChanged: (_) {
                        _toggleStoreStatus(
                          storeRef: storeRef,
                          currentStatus: isOpen,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOpen ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOpen ? Icons.storefront : Icons.store_mall_directory,
                      color: isOpen ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOpen
                            ? 'ร้านของคุณเปิดอยู่'
                            : 'ร้านของคุณปิดอยู่',
                        style: TextStyle(
                          color: isOpen ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: menusQuery.snapshots(),
                  builder: (context, menuSnap) {
                    if (menuSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!menuSnap.hasData) {
                      return const Center(child: Text('ไม่พบข้อมูลเมนู'));
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
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.white,
                                            child: const Icon(Icons.fastfood),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.white,
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
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("ลบเมนู"),
                                      content: const Text("คุณต้องการลบเมนูนี้หรือไม่"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("ยกเลิก"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteMenu(docs[i].reference);
                                          },
                                          child: const Text(
                                            "ลบ",
                                            style: TextStyle(color: Colors.red),
                                          ),
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
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: Colors.orange,
            unselectedItemColor: Colors.grey,
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
                icon: Icon(Icons.pending_actions),
                label: 'รอดำเนินการ',
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
                    builder: (_) => PendingStorePage(storeId: storeId),
                  ),
                );
              } else if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SelectLocationStorePage(storeId: storeId),
                  ),
                );
              } else if (index == 4) {
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