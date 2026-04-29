import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'store/food.dart';
import 'store/drink.dart';
import 'store/cart.dart';
import 'history.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  bool isLoading = true;
  List<String> imageUrls = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderSubscription;

  final Set<String> _shownDeliverySuccess = {};
  final Set<String> _shownRiderAccepted = {};

  @override
  void initState() {
    super.initState();
    _loadStoreImages();
    _listenOrderStatusInApp();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadStoreImages() async {
    try {
      final storage = FirebaseStorage.instance;

      final files = [
        'image_store/Logo1.jpg',
        'image_store/milk.png',
      ];

      List<String> urls = [];

      for (var path in files) {
        final ref = storage.ref(path);
        final url = await ref.getDownloadURL();
        urls.add(url);
      }

      if (!mounted) return;
      setState(() {
        imageUrls = urls;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('โหลดรูปไม่สำเร็จ: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showInAppMessage(String message, {Color? color}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _listenOrderStatusInApp() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final orderId = doc.id;

        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        final riderStatus =
            (data['riderStatus'] ?? '').toString().trim().toLowerCase();

        if (riderStatus == 'success' &&
            !_shownRiderAccepted.contains(orderId)) {
          _shownRiderAccepted.add(orderId);
          _showInAppMessage(
            'ไรเดอร์รับงานของคุณแล้ว',
            color: Colors.orange,
          );
        }

        if (status == 'success' &&
            !_shownDeliverySuccess.contains(orderId)) {
          _shownDeliverySuccess.add(orderId);
          _showInAppMessage(
            'จัดส่งสำเร็จ',
            color: Colors.green,
          );
        }
      }
    }, onError: (error) {
      debugPrint('ฟังสถานะ orders ไม่สำเร็จ: $error');
    });
  }

  void _openStore(int index) {
    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FoodPage()),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DrinkPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.cyan,
        title: const Text(
          'Food Delivery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderSection(),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'หมวดหมู่ร้านค้า',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'เลือกหมวดหมู่เพื่อดูร้านค้า',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (imageUrls.isEmpty)
                    const _EmptyImageBox()
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: imageUrls.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.88,
                        ),
                        itemBuilder: (context, index) {
                          final isFood = index == 0;

                          return _CategoryCard(
                            imageUrl: imageUrls[index],
                            title: isFood ? 'ร้านกับข้าวแม่' : 'Milk Cafe',
                            subtitle: 'แตะเพื่อเลือกเมนู',
                            icon: isFood
                                ? Icons.restaurant_menu
                                : Icons.local_drink,
                            onTap: () => _openStore(index),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          setState(() => _currentIndex = index);

          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodPage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DrinkPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          } else if (index == 4) {
            _confirmLogout(context);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'อาหาร',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_drink),
            label: 'เครื่องดื่ม',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'ตะกร้า',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'ประวัติ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'ออกจากระบบ',
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
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

    if (ok == true && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.cyan, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'สวัสดี 👋',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'อยากกินอะไรดีวันนี้?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22),
      elevation: 5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 50,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.58),
                        Colors.black.withOpacity(0.08),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(
                        icon,
                        color: Colors.cyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyImageBox extends StatelessWidget {
  const _EmptyImageBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          const Text('ยังไม่มีรูปหมวดหมู่ร้านค้า'),
        ],
      ),
    );
  }
}