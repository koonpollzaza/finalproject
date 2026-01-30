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
            appBar: AppBar(
              title: const Text("หน้าร้านค้า"),
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
                )
              ],
            ),
            body: const Center(
              child: Text(
                "บัญชีนี้ยังไม่ได้สร้างร้านค้า\n(ไม่พบ stores.ownerUid = uid)",
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
                    (route) => false,
                  );
                },
              ),
            ],
          ),

          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ชื่อร้าน: $storeName',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Store ID: $storeId',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: menusQuery.snapshots(),
                  builder: (context, menuSnap) {
                    if (menuSnap.hasError) {
                      return Center(
                          child: Text('โหลดเมนูผิดพลาด: ${menuSnap.error}'));
                    }
                    if (!menuSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = menuSnap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('ยังไม่มีเมนูในร้านนี้'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final m = d.data();
                        final name = m['name']?.toString() ?? "";
                        final img = m['imageUrl']?.toString() ?? "";
                        final price = (m['price'] is num)
                            ? (m['price'] as num).toDouble()
                            : double.tryParse('${m['price']}') ?? 0.0;

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side:
                                const BorderSide(color: Colors.black12),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: img.isNotEmpty
                                  ? Image.network(
                                      img,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      width: 56,
                                      height: 56,
                                      child: const Icon(Icons.fastfood),
                                    ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                'ราคา: ${price.toStringAsFixed(2)} บาท'),
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
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant), label: 'เพิ่มเมนู'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'ประวัติคำสั่งซื้อ'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
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
