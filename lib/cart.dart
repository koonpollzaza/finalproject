import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';
import 'food.dart';
import 'drink.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int _currentIndex = 2;
  bool _placing = false;

  // 👉 ถ้าต้องการแยกตะกร้าต่อผู้ใช้ ให้เปลี่ยน path เป็น carts/{uid}/items
  CollectionReference<Map<String, dynamic>> get cartRef =>
      FirebaseFirestore.instance.collection('cart');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ตะกร้า"),
        backgroundColor: Colors.cyan[300],
        actions: [
          IconButton(
            tooltip: 'ล้างตะกร้า',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _placing ? null : () async {
              final snap = await cartRef.get();
              if (snap.docs.isEmpty) return;
              final batch = FirebaseFirestore.instance.batch();
              for (final d in snap.docs) {
                batch.delete(d.reference);
              }
              await batch.commit();
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('ล้างตะกร้าเรียบร้อย')));
            },
          ),
        ],
      ),

      // 🔥 อ่าน cart แบบเรียลไทม์
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartRef.orderBy('createdAt', descending: false).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("ยังไม่มีสินค้าในตะกร้า"));
          }

          // รวมยอด
          final total = docs.fold<double>(0.0, (sum, d) {
            final x = d.data();
            final price = (x['price'] is num)
                ? (x['price'] as num).toDouble()
                : double.tryParse('${x['price']}') ?? 0.0;
            final qty = (x['qty'] is num) ? (x['qty'] as num).toInt() : 0;
            return sum + price * qty;
          });

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final name = (data['name'] ?? '').toString();
                    final imageUrl = (data['imageUrl'] ?? '').toString();
                    final price = (data['price'] is num)
                        ? (data['price'] as num).toDouble()
                        : double.tryParse('${data['price']}') ?? 0.0;
                    final qty = (data['qty'] is num)
                        ? (data['qty'] as num).toInt()
                        : 0;

                    return Dismissible(
                      key: ValueKey(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red[300],
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await doc.reference.delete();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ลบ "$name" จากตะกร้า')),
                        );
                      },
                      child: ListTile(
                        leading: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const CircleAvatar(child: Icon(Icons.fastfood)),
                        title: Text(name),
                        subtitle: Text('ราคา: ${price.toStringAsFixed(2)} บาท'),
                        trailing: SizedBox(
                          width: 140,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'ลดจำนวน',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _placing ? null : () async {
                                  final xqty = qty - 1;
                                  if (xqty <= 0) {
                                    await doc.reference.delete();
                                  } else {
                                    await doc.reference.update({
                                      'qty': xqty,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });
                                  }
                                },
                              ),
                              Text('$qty'),
                              IconButton(
                                tooltip: 'เพิ่มจำนวน',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: _placing ? null : () async {
                                  await doc.reference.update({
                                    'qty': FieldValue.increment(1),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // แถบสรุปราคา + ปุ่มสั่งสินค้า
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: const Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text("รวมทั้งหมด",
                              style: TextStyle(fontSize: 18)),
                        ),
                        Text(
                          "${total.toStringAsFixed(2)} บาท",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _placing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.receipt_long),
                        label: Text(_placing ? 'กำลังสั่งสินค้า...' : 'สั่งสินค้า'),
                        onPressed: _placing
                            ? null
                            : () => _placeOrder(docs, total),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FoodPage()));
          } else if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DrinkPage()));
          } else if (index == 2) {
            // already here
          } else if (index == 3) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          }
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "อาหาร"),
          BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: "เครื่องดื่ม"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "ตะกร้า"),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: "ออกจากระบบ"),
        ],
      ),
    );
  }

  /// สร้างคำสั่งซื้อใน collection `orders` + ย้าย items เป็น subcollection `orders/{orderId}/items`
  Future<void> _placeOrder(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, double total) async {
    if (docs.isEmpty) return;
    setState(() => _placing = true);
    final db = FirebaseFirestore.instance;
    try {
      final orderRef = db.collection('orders').doc(); // 👉 เปลี่ยนเป็น orders/{uid}/orders ได้ถ้าต้องการแยกผู้ใช้
      final now = FieldValue.serverTimestamp();

      // Header ของออเดอร์
      final header = {
        'total': total,
        'itemCount': docs.fold<int>(0, (sum, d) => sum + ((d.data()['qty'] ?? 0) as num).toInt()),
        'status': 'pending',           // pending | paid | cancelled ...
        'createdAt': now,
        'updatedAt': now,
        // 'userId': uid,               // ← ถ้าใช้ auth ให้ใส่
      };

      final batch = db.batch();
      batch.set(orderRef, header);

      for (final d in docs) {
        final x = d.data();
        final itemRef = orderRef.collection('items').doc(d.id);
        batch.set(itemRef, {
          'storeId': x['storeId'],
          'menuId': x['menuId'],
          'name': x['name'],
          'price': x['price'],
          'imageUrl': x['imageUrl'],
          'qty': x['qty'],
        });
        // ลบออกจาก cart
        batch.delete(d.reference);
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สั่งสินค้าเรียบร้อย')),
      );
      // จะไปหน้าอื่นต่อก็ได้ เช่น หน้า orders:
      // Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สั่งสินค้าไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}
