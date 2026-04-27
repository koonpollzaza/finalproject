import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finalproject/login.dart';
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.cyan,
        title: const Text(
          "ร้านเครื่องดื่ม",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: const BoxDecoration(
              color: Colors.cyan,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(26),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลือกเครื่องดื่มที่คุณชอบ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ร้านที่เปิดอยู่สามารถกดเข้าไปเลือกเมนูได้',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                    'ยังไม่มีร้านเครื่องดื่มที่ได้รับการอนุมัติ',
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
                    final isOpen = (d['isOpen'] ?? false) == true;

                    return _StoreCard(
                      name: name.isEmpty ? '(ไม่มีชื่อร้าน)' : name,
                      imageUrl: imageUrl,
                      description: desc,
                      isOpen: isOpen,
                      onTap: isOpen
                          ? () {
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
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'ร้านนี้ปิดอยู่ ยังไม่สามารถเข้าได้',
                                  ),
                                ),
                              );
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) async {
          if (index == _currentIndex) return;

          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FoodPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          } else if (index == 4) {
            final ok = await _confirmLogout(context);

            if (ok == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ออกจากระบบเรียบร้อย')),
              );

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            }
          }

          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: "อาหาร",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_drink),
            label: "เครื่องดื่ม",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "ตะกร้า",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "ประวัติ",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: "ออกจากระบบ",
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String description;
  final bool isOpen;
  final VoidCallback? onTap;

  const _StoreCard({
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.isOpen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isOpen ? 1 : 0.58,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      child: imageUrl.isNotEmpty
                          ? ColorFiltered(
                              colorFilter: isOpen
                                  ? const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.multiply,
                                    )
                                  : ColorFilter.mode(
                                      Colors.grey.withOpacity(0.65),
                                      BlendMode.saturation,
                                    ),
                              child: Image.network(
                                imageUrl,
                                height: 185,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _ImagePlaceholder(isOpen: isOpen);
                                },
                              ),
                            )
                          : _ImagePlaceholder(isOpen: isOpen),
                    ),
                    Container(
                      height: 185,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _StatusBadge(isOpen: isOpen),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        )
                      else
                        Text(
                          'ไม่มีรายละเอียดร้าน',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            isOpen
                                ? Icons.touch_app
                                : Icons.lock_clock_outlined,
                            size: 18,
                            color: isOpen ? Colors.cyan : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isOpen
                                  ? 'แตะเพื่อดูเมนูเครื่องดื่ม'
                                  : 'ร้านปิดชั่วคราว',
                              style: TextStyle(
                                color: isOpen ? Colors.cyan : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: isOpen
                                ? Colors.grey.shade500
                                : Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isOpen,
  });

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'เปิดอยู่' : 'ร้านปิด',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.isOpen,
  });

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 185,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: Icon(
        Icons.local_drink,
        size: 64,
        color: isOpen ? Colors.grey.shade700 : Colors.grey.shade500,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;

  const _ErrorBox(this.msg);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: SelectableText(
          msg,
          style: const TextStyle(color: Colors.red),
        ),
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
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_drink,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              msg,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}