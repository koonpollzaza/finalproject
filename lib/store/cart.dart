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
    if (doc.exists) return doc.data()?['name'];
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ตะกร้าสินค้า',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartRef.where('userId', isEqualTo: uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ยังไม่มีสินค้าในตะกร้า',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
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
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildForm(),
                      const SizedBox(height: 14),

                      if (storeId != null)
                        FutureBuilder<String?>(
                          future: _getStoreName(storeId),
                          builder: (context, snapshot) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: Colors.orange.shade100),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Icon(
                                      Icons.store,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      snapshot.hasData
                                          ? 'ร้าน: ${snapshot.data}'
                                          : 'กำลังโหลดชื่อร้าน...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      if (multipleStores) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'คุณสามารถสั่งได้ครั้งละ 1 ร้านเท่านั้น',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Text(
                        'รายการสินค้า',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ...docs.map((doc) {
                        final data = doc.data();
                        final qty = data['qty'] ?? 1;
                        final price = (data['price'] ?? 0).toDouble();
                        final name = data['name'] ?? '';
                        final imageUrl = (data['imageUrl'] ?? '').toString();
                        final itemTotal = price * qty;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl.isEmpty
                                      ? Container(
                                          width: 64,
                                          height: 64,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.fastfood),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              width: 64,
                                              height: 64,
                                              color: Colors.grey.shade200,
                                              child:
                                                  const Icon(Icons.fastfood),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${price.toStringAsFixed(2)} บาท',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'รวม ${itemTotal.toStringAsFixed(2)} บาท',
                                        style: const TextStyle(
                                          color: Colors.cyan,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deleteItem(doc.reference),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            iconSize: 18,
                                            icon: const Icon(Icons.remove),
                                            onPressed: () => _updateQty(
                                                doc.reference, qty, -1),
                                          ),
                                          Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            iconSize: 18,
                                            icon: const Icon(Icons.add),
                                            onPressed: () => _updateQty(
                                                doc.reference, qty, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.cyan,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'ข้อมูลผู้สั่ง',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _fullNameC,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้สั่ง',
                  prefixIcon: const Icon(Icons.account_circle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneC,
                decoration: InputDecoration(
                  labelText: 'เบอร์ติดต่อ',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.length < 10 ? 'เบอร์ไม่ถูกต้อง' : null,
              ),
              const SizedBox(height: 12),

              if (_paymentMethod == 'payment') ...[
                TextFormField(
                  controller: _addressC,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'ที่อยู่จัดส่ง',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: const Icon(Icons.map),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onTap: _selectLocation,
                  validator: (_) {
                    if (_lat == null) {
                      return 'กรุณาเลือกตำแหน่งจัดส่ง';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _descriptionC,
                decoration: InputDecoration(
                  labelText: 'รายละเอียดเพิ่มเติม',
                  prefixIcon: const Icon(Icons.note_alt),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                'รูปแบบการรับสินค้า',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _DeliveryOption(
                title: 'จัดส่งถึงบ้าน',
                subtitle: 'เลือกตำแหน่งจัดส่ง',
                icon: Icons.delivery_dining,
                value: 'payment',
                groupValue: _paymentMethod,
                onChanged: (v) {
                  setState(() {
                    _paymentMethod = v!;
                  });
                },
              ),

              const SizedBox(height: 8),

              _DeliveryOption(
                title: 'รับอาหารที่ร้าน',
                subtitle: 'ไปรับสินค้าด้วยตัวเองที่ร้าน',
                icon: Icons.storefront,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'รวมทั้งหมด',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'ยืนยันการสั่งสินค้า',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.cyan.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.cyan : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  selected ? Colors.cyan : Colors.grey.shade300,
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.cyan : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: Colors.cyan,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}