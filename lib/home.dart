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
        'image_store/Logo1.png',
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Food Delivery",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan,
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyan, Colors.blueAccent],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "สั่งอาหารง่ายๆ\nส่งถึงหน้าบ้าน",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ร้านค้ายอดฮิต',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () => _openStore(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      imageUrls[index],
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    index == 0
                                        ? "ร้านอาหาร"
                                        : "ร้านเครื่องดื่ม",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
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

  void _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ'),
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