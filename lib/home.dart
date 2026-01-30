import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'store/food.dart';
import 'store/drink.dart';
import 'store/cart.dart';
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

  @override
  void initState() {
    super.initState();
    _loadStoreImages();
  }

  Future<void> _loadStoreImages() async {
    try {
      final storage = FirebaseStorage.instance;

      final files = [
        'image_store/KAMU-01.jpg',
        'image_store/KFC.png',
        'image_store/Logo1.jpg',
        'image_store/Logo1.png',
      ];

      List<String> urls = [];

      for (var path in files) {
        final ref = storage.ref(path);
        final url = await ref.getDownloadURL();
        urls.add(url);
      }

      setState(() {
        imageUrls = urls;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('โหลดรูปไม่สำเร็จ: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("หน้าหลัก"),
        backgroundColor: Colors.cyan[300],
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ร้านค้ายอดฮิต',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: GridView.builder(
                      itemCount: imageUrls.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image_not_supported),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.cyan[200],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.black54,
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
