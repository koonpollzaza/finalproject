import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home.dart';
import 'drink.dart';
import 'cart.dart';
import 'menu_food.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});
  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  int _currentIndex = 0;

  /// ✅ Query ใหม่ (เพิ่ม approvalStatus)
  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection('stores')
      .where('shopType', isEqualTo: 'food')
      .where('isBanned', isEqualTo: false)
      .where('approvalStatus', isEqualTo: 'approved');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ร้านอาหาร"),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorBox('FIRESTORE ERROR:\n${snap.error}');
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const _InfoBox(
              'ยังไม่มีร้านที่ได้รับการอนุมัติ',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;

              final name = (d['name'] ?? '') as String;
              final imageUrl = (d['imageUrl'] ?? '') as String? ?? '';
              final desc = (d['description'] ?? '') as String? ?? '';

              return _StoreCard(
                name: name.isEmpty ? '(ไม่มีชื่อร้าน)' : name,
                imageUrl: imageUrl,
                description: desc,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreDetailPage(
                        id: id,
                        name: name,
                        imageUrl: imageUrl,
                        description: desc,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.cyan[200],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.black54,
        onTap: (index) async {
          if (index == _currentIndex) return;

          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DrinkPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          } else if (index == 3) {
            final ok = await _confirmLogout(context);
            if (ok == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ออกจากระบบเรียบร้อย')),
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            }
          }

          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu), label: "อาหาร"),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_drink), label: "เครื่องดื่ม"),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: "ตะกร้า"),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: "ออกจากระบบ"),
        ],
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ออกจากระบบ')),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String description;
  final VoidCallback? onTap;

  const _StoreCard({
    required this.name,
    required this.imageUrl,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                child: Image.network(
                  imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imageFallback(),
                ),
              )
            else
              _imageFallback(),
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 18, horizontal: 12),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
        height: 150,
        color: Colors.grey[400],
        alignment: Alignment.center,
        child: const Icon(Icons.store, size: 40),
      );
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox(this.msg);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          msg,
          style: const TextStyle(color: Colors.red),
        ),
      );
}

class _InfoBox extends StatelessWidget {
  final String msg;
  const _InfoBox(this.msg);

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(msg, textAlign: TextAlign.center));
}
