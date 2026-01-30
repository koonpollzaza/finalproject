// lib/menu_food.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      appBar: AppBar(title: Text(name)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: menusRef.orderBy('name').snapshots(), // เรียงชื่อเมนู (มีฟิลด์ name )
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("ยังไม่มีเมนูในร้านนี้"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data();
              final menuId = docs[i].id;
              final menuName = (data['name'] ?? '').toString();
              final price = (data['price'] is num)
                  ? (data['price'] as num).toDouble()
                  : double.tryParse('${data['price']}') ?? 0.0;
              final menuImage = (data['imageUrl'] ?? '').toString();

              return ListTile(
                leading: menuImage.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          menuImage,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.fastfood, size: 40),
                title: Text(menuName),
                subtitle: Text('ราคา ${price.toStringAsFixed(2)} บาท'),
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
              );
            },
          );
        },
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
    // ----- เปลี่ยน path ได้ถ้าต้องการ cart ต่อผู้ใช้ -----
    // final uid = FirebaseAuth.instance.currentUser!.uid;
    // final ref = FirebaseFirestore.instance.collection('carts').doc(uid).collection('items').doc('${widget.storeId}_${widget.menuId}');
    final ref = FirebaseFirestore.instance
        .collection('cart') // ใช้ collection เดียว (global cart)
        .doc('${widget.storeId}_${widget.menuId}');

    await ref.set({
      'storeId': widget.storeId,
      'menuId': widget.menuId,
      'name': widget.name,
      'price': widget.price,           // เก็บเป็น number
      'imageUrl': widget.imageUrl,
      'qty': FieldValue.increment(qty), // เพิ่มตามจำนวนที่เลือก
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final priceStr = widget.price.toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // กลับไปหน้าเมนูร้าน
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fastfood, size: 60),
              ),
            const SizedBox(height: 16),
            Text(widget.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('ราคา: $priceStr บาท'),
            const SizedBox(height: 16),

            // จำนวน (– / +)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'ลดจำนวน',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (qty > 1) setState(() => qty--);
                  },
                ),
                Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  tooltip: 'เพิ่มจำนวน',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => qty++),
                ),
              ],
            ),
            const Spacer(),

            // ปุ่ม Add to cart (โชว์ราคารวม)
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: Text('Add to cart  (${(widget.price * qty).toStringAsFixed(2)} บาท)'),
              onPressed: () async {
                try {
                  await _addToCart();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เพิ่ม "${widget.name}" x$qty ลงตะกร้าแล้ว')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เพิ่มตะกร้าไม่สำเร็จ: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text('ดูตะกร้า'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
