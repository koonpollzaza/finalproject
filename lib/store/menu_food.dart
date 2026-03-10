// lib/menu_food.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          /// HEADER ร้าน
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

          /// ชื่อร้าน
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
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

          /// รายการเมนู
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: menusRef.orderBy('name').snapshots(),
              builder: (context, snapshot) {
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
                              fontWeight: FontWeight.bold),
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

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("กรุณาเข้าสู่ระบบก่อน");
    }

    final uid = user.uid;
    final docId = '${uid}_${widget.storeId}_${widget.menuId}';

    final ref = FirebaseFirestore.instance.collection('cart').doc(docId);

    await ref.set({
      'storeId': widget.storeId,
      'userId': uid,
      'menuId': widget.menuId,
      'name': widget.name,
      'price': widget.price,
      'imageUrl': widget.imageUrl,
      'qty': FieldValue.increment(qty),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
          )
        ],
      ),
      body: Column(
        children: [
          /// รูปอาหาร
          widget.imageUrl.isNotEmpty
              ? Image.network(
                  widget.imageUrl,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                Text(widget.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),

                const SizedBox(height: 8),

                Text(
                  "${widget.price.toStringAsFixed(0)} บาท",
                  style: const TextStyle(
                      fontSize: 20,
                      color: Colors.red,
                      fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                /// ปุ่มเพิ่มลดจำนวน
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () {
                        if (qty > 1) setState(() => qty--);
                      },
                    ),
                    Text(
                      "$qty",
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
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

          /// ปุ่มเพิ่มตะกร้า
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                await _addToCart();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เพิ่ม ${widget.name} x$qty แล้ว'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "เพิ่มลงตะกร้า • ${total.toStringAsFixed(0)} บาท",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}