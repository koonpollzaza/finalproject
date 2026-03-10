import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home.dart';
import 'food.dart';
import 'cart.dart';
import 'menu_food.dart';
import 'package:finalproject/history.dart';

class DrinkPage extends StatefulWidget {
  const DrinkPage({super.key});

  @override
  State<DrinkPage> createState() => _DrinkPageState();
}

class _DrinkPageState extends State<DrinkPage> {
  int _currentIndex = 1;

  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection('stores')
      .where('shopType', isEqualTo: 'drink')
      .where('isBanned', isEqualTo: false)
      .where('approvalStatus', isEqualTo: 'approved');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.cyan,
        title: const Text(
          "ร้านเครื่องดื่ม",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            return const _InfoBox('ยังไม่มีร้านเครื่องดื่มที่ได้รับการอนุมัติ');
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
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,

        onTap: (index) async {

          if (index == _currentIndex) return;

          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FoodPage()),
            );
          }

          else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          }

          else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          }

          else if (index == 4) {

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
              icon: Icon(Icons.restaurant_menu),
              label: "อาหาร"),

          BottomNavigationBarItem(
              icon: Icon(Icons.local_drink),
              label: "เครื่องดื่ม"),

          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: "ตะกร้า"),

          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: "ประวัติ"),

          BottomNavigationBarItem(
              icon: Icon(Icons.logout),
              label: "ออกจากระบบ"),
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

    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 170,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.store, size: 60),
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: const [
                      Icon(Icons.local_drink, color: Colors.blue),
                      SizedBox(width: 6),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {

  final String msg;

  const _ErrorBox(this.msg);

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        msg,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {

  final String msg;

  const _InfoBox(this.msg);

  @override
  Widget build(BuildContext context) {

    return Center(
      child: Text(
        msg,
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}