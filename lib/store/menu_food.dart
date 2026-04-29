// lib/menu_food.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cart.dart';

class StoreDetailPage extends StatelessWidget {
  final String id, name, imageUrl, description;

  const StoreDetailPage({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final menusRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(id)
        .collection('menus');

    return Scaffold(
      body: Column(
        children: [
          Stack(
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 220,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.store, size: 80),
                      ),
                    ),
              Positioned(
                top: 40,
                left: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: menusRef.orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("ยังไม่มีเมนูในร้านนี้"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data();

                    final menuId = docs[i].id;
                    final menuName = (data['name'] ?? '').toString();

                    final price = (data['price'] is num)
                        ? (data['price'] as num).toDouble()
                        : double.tryParse('${data['price']}') ?? 0.0;

                    final menuImage = (data['imageUrl'] ?? '').toString();

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: menuImage.isNotEmpty
                              ? Image.network(
                                  menuImage,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.fastfood),
                                    );
                                  },
                                )
                              : Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.fastfood),
                                ),
                        ),
                        title: Text(
                          menuName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${price.toStringAsFixed(0)} บาท",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuItemPage(
                                storeId: id,
                                menuId: menuId,
                                name: menuName,
                                price: price,
                                imageUrl: menuImage,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MenuItemPage extends StatefulWidget {
  final String storeId, menuId, name, imageUrl;
  final double price;

  const MenuItemPage({
    super.key,
    required this.storeId,
    required this.menuId,
    required this.name,
    required this.imageUrl,
    required this.price,
  });

  @override
  State<MenuItemPage> createState() => _MenuItemPageState();
}

class _MenuItemPageState extends State<MenuItemPage> {
  int qty = 1;
  bool adding = false;

  String _formatPhoneNumber(String phone) {
    phone = phone.trim().replaceAll(' ', '').replaceAll('-', '');

    if (phone.startsWith('+66')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('66')) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  Future<void> _addToCart() async {
    setState(() => adding = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final phoneRaw = prefs.getString('loginPhone') ?? '';
      final loginPhone = _formatPhoneNumber(phoneRaw);

      if (loginPhone.isEmpty) {
        throw Exception("กรุณาเข้าสู่ระบบก่อน");
      }

      final docId = '${loginPhone}_${widget.storeId}_${widget.menuId}';

      final ref = FirebaseFirestore.instance.collection('cart').doc(docId);

      await ref.set({
        'storeId': widget.storeId,
        'userPhone': loginPhone,
        'menuId': widget.menuId,
        'name': widget.name,
        'price': widget.price,
        'imageUrl': widget.imageUrl,
        'qty': FieldValue.increment(qty),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เพิ่ม ${widget.name} x$qty แล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.price * qty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          widget.imageUrl.isNotEmpty
              ? Image.network(
                  widget.imageUrl,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 260,
                      color: Colors.grey[300],
                      child: const Icon(Icons.fastfood, size: 80),
                    );
                  },
                )
              : Container(
                  height: 260,
                  color: Colors.grey[300],
                  child: const Icon(Icons.fastfood, size: 80),
                ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "${widget.price.toStringAsFixed(0)} บาท",
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () {
                        if (qty > 1) {
                          setState(() => qty--);
                        }
                      },
                    ),
                    Text(
                      "$qty",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => setState(() => qty++),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: adding ? null : _addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: adding
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      "เพิ่มลงตะกร้า • ${total.toStringAsFixed(0)} บาท",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}