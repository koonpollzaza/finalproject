import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finalproject/select_location_page.dart';
import 'package:finalproject/store/payment.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();
  final _descriptionC = TextEditingController();

  double? _lat;
  double? _lng;

  String _paymentMethod = 'payment';

  CollectionReference<Map<String, dynamic>> get cartRef =>
      FirebaseFirestore.instance.collection('cart');

  CollectionReference<Map<String, dynamic>> get storeRef =>
      FirebaseFirestore.instance.collection('stores');

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _fullNameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _descriptionC.dispose();
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
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบ")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตะกร้า'),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartRef.where('userId', isEqualTo: uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีสินค้าในตะกร้า'));
          }

          final docs = snap.data!.docs;

          final storeIds =
              docs.map((d) => d.data()['storeId']?.toString() ?? '').toSet();

          final multipleStores = storeIds.length > 1;
          final storeId = storeIds.isNotEmpty ? storeIds.first : null;

          final total = docs.fold<double>(0, (sum, d) {
            final data = d.data();
            return sum +
                (data['price'] ?? 0).toDouble() * (data['qty'] ?? 1).toInt();
          });

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildForm(),
                      const SizedBox(height: 10),
                      if (storeId != null)
                        FutureBuilder<String?>(
                          future: _getStoreName(storeId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Text("กำลังโหลดชื่อร้าน...");
                            }

                            return Text(
                              "ร้าน: ${snapshot.data}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 10),
                      if (multipleStores)
                        const Text(
                          'คุณสามารถสั่งได้ครั้งละ 1 ร้านเท่านั้น',
                          style: TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 10),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final qty = data['qty'] ?? 1;

                        return Card(
                          child: ListTile(
                            title: Text(data['name'] ?? ''),
                            subtitle: Text('ราคา ${data['price']} บาท'),
                            leading: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(doc.reference),
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
                decoration: const InputDecoration(labelText: 'ชื่อผู้สั่ง'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              TextFormField(
                controller: _phoneC,
                decoration: const InputDecoration(labelText: 'เบอร์ติดต่อ'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.length < 10 ? 'เบอร์ไม่ถูกต้อง' : null,
              ),
              if (_paymentMethod == 'payment')
                TextFormField(
                  controller: _addressC,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'ที่อยู่จัดส่ง',
                    suffixIcon: Icon(Icons.map),
                  ),
                  onTap: _selectLocation,
                  validator: (_) {
                    if (_lat == null) {
                      return 'กรุณาเลือกตำแหน่งจัดส่ง';
                    }
                    return null;
                  },
                ),
              TextFormField(
                controller: _descriptionC,
                decoration:
                    const InputDecoration(labelText: 'รายละเอียดเพิ่มเติม'),
              ),
              RadioListTile<String>(
                title: const Text('จัดส่งถึงบ้าน'),
                value: 'payment',
                groupValue: _paymentMethod,
                onChanged: (v) {
                  setState(() {
                    _paymentMethod = v!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('รับอาหารที่ร้าน'),
                value: 'pickup',
                groupValue: _paymentMethod,
                onChanged: (v) {
                  setState(() {
                    _paymentMethod = v!;
                    _lat = null;
                    _lng = null;
                    _addressC.clear();
                  });
                },
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
    String? storeId,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('รวมทั้งหมด', style: TextStyle(fontSize: 18)),
              ),
              Text(
                '${total.toStringAsFixed(2)} บาท',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: docs.isEmpty || multipleStores
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _submitOrder(docs, total, storeId);
                      }
                    },
              child: const Text('ยืนยันการสั่งสินค้า'),
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
    String? storeId,
  ) async {
    final db = FirebaseFirestore.instance;

    final Map<String, dynamic> orderData = {
      'userId': uid,
      'fullname': _fullNameC.text.trim(),
      'phone': _phoneC.text.trim(),
      'description': _descriptionC.text.trim(),
      'storeId': storeId,
      'status': 'pending',
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
      'payment': 'pending',
    };

    if (_paymentMethod == 'payment') {
      orderData['location'] = _addressC.text.trim();
      orderData['lat'] = _lat;
      orderData['lng'] = _lng;
      orderData['riderStatus'] = 'pending';
      orderData['PickUp'] = false;
    } else {
      orderData['location'] = 'รับอาหารที่ร้าน';
      orderData['PickUp'] = true;
      orderData['riderStatus'] = 'pending';
      orderData['lat'] = null;
      orderData['lng'] = null;
    }

    final orderRef = await db.collection('orders').add(orderData);

    final batch = db.batch();

    for (final d in docs) {
      batch.set(orderRef.collection('items').doc(), d.data());
      batch.delete(d.reference);
    }

    await batch.commit();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          orderId: orderRef.id,
          total: total,
        ),
      ),
    );
  }
}