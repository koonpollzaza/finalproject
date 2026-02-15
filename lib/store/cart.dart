import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home.dart';
import 'food.dart';
import 'drink.dart';
import 'package:finalproject/history.dart';
import 'package:finalproject/select_location_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int _currentIndex = 2;

  final _formKey = GlobalKey<FormState>();
  final _fullNameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();
  final _descriptionC = TextEditingController(); // ✅ เพิ่ม

  double? _lat;
  double? _lng;

  CollectionReference<Map<String, dynamic>> get cartRef =>
      FirebaseFirestore.instance.collection('cart');

  CollectionReference<Map<String, dynamic>> get storeRef =>
      FirebaseFirestore.instance.collection('stores');

  @override
  void dispose() {
    _fullNameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _descriptionC.dispose(); // ✅ dispose
    super.dispose();
  }

  Future<String?> _getStoreName(String storeId) async {
    final doc = await storeRef.doc(storeId).get();
    if (doc.exists) {
      return doc.data()?['name'];
    }
    return null;
  }

  Future<void> _updateQty(
      DocumentReference docRef, int currentQty, int change) async {
    final newQty = currentQty + change;

    if (newQty <= 0) {
      await docRef.delete();
    } else {
      await docRef.update({'qty': newQty});
    }
  }

  Future<void> _deleteItem(DocumentReference docRef) async {
    await docRef.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตะกร้า'),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีสินค้าในตะกร้า'));
          }

          final storeIds =
              docs.map((d) => d.data()['storeId']?.toString() ?? '').toSet();

          final bool multipleStores = storeIds.length > 1;
          final String? storeId =
              storeIds.isNotEmpty ? storeIds.first : null;

          final total = docs.fold<double>(0, (sum, d) {
            final data = d.data();
            return sum +
                (data['price'] ?? 0).toDouble() *
                    (data['qty'] ?? 1).toInt();
          });

          return FutureBuilder<String?>(
            future: storeId != null ? _getStoreName(storeId) : null,
            builder: (context, storeSnap) {
              final storeName = storeSnap.data;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _buildForm(),
                          const SizedBox(height: 10),

                          if (storeName != null)
                            Card(
                              color: Colors.orange.shade50,
                              child: ListTile(
                                leading: const Icon(Icons.store),
                                title: Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),

                          if (multipleStores)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'คุณสามารถสั่งได้ครั้งละ 1 ร้านเท่านั้น',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),

                          const SizedBox(height: 10),

                          ...docs.map((doc) {
                            final data = doc.data();
                            final qty = data['qty'] ?? 1;

                            return Card(
                              child: ListTile(
                                title: Text(data['name'] ?? ''),
                                subtitle:
                                    Text('ราคา ${data['price']} บาท'),
                                leading: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteItem(doc.reference),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () =>
                                          _updateQty(doc.reference, qty, -1),
                                    ),
                                    Text('$qty'),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () =>
                                          _updateQty(doc.reference, qty, 1),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  _buildSummary(total, docs, multipleStores, storeId),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const FoodPage()));
          } else if (i == 1) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const DrinkPage()));
          } else if (i == 3) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const HistoryPage()));
          } else if (i == 4) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (_) => false,
            );
          }
          setState(() => _currentIndex = i);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.restaurant), label: 'อาหาร'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_drink), label: 'เครื่องดื่ม'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'ตะกร้า'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'ประวัติ'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout), label: 'ออกจากระบบ'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fullNameC,
                decoration:
                    const InputDecoration(labelText: 'ชื่อผู้สั่ง'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              TextFormField(
                controller: _phoneC,
                decoration:
                    const InputDecoration(labelText: 'เบอร์ติดต่อ'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.length < 10 ? 'เบอร์ไม่ถูกต้อง' : null,
              ),
              TextFormField(
                controller: _addressC,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่จัดส่ง',
                  suffixIcon: Icon(Icons.map),
                ),
                onTap: _selectLocation,
                validator: (_) =>
                    _lat == null ? 'กรุณาเลือกตำแหน่งจัดส่ง' : null,
              ),

              // ✅ เพิ่ม description
              TextFormField(
                controller: _descriptionC,
                decoration: const InputDecoration(
                    labelText: 'รายละเอียดเพิ่มเติม'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
      double total,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      bool multipleStores,
      String? storeId) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('รวมทั้งหมด',
                      style: TextStyle(fontSize: 18))),
              Text('${total.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              child: const Text('ยืนยันการสั่งสินค้า'),
              onPressed: docs.isEmpty || multipleStores
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _submitOrder(docs, total, storeId);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationPage()),
    );

    if (result != null) {
      setState(() {
        _lat = result['lat'];
        _lng = result['lng'];
        _addressC.text = result['address'] ?? '';
      });
    }
  }

  Future<void> _submitOrder(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      double total,
      String? storeId) async {
    final db = FirebaseFirestore.instance;

    final orderRef = await db.collection('orders').add({
      'fullname': _fullNameC.text.trim(),
      'phone': _phoneC.text.trim(),
      'location': _addressC.text.trim(),
      'lat': _lat,
      'lng': _lng,
      'description': _descriptionC.text.trim(), // ✅ ส่งเข้า Firebase
      'storeId': storeId,
      'status': 'pending',
      'riderStatus': 'waiting',
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final batch = db.batch();

    for (final d in docs) {
      batch.set(orderRef.collection('items').doc(), d.data());
      batch.delete(d.reference);
    }

    await batch.commit();

    _descriptionC.clear(); // ✅ ล้างค่า

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สั่งสินค้าเรียบร้อย ✅')),
    );
  }
}
