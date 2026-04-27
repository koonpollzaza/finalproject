import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("กรุณาเข้าสู่ระบบ"),
        ),
      );
    }

    final uid = user.uid;

    final ordersRef = FirebaseFirestore.instance.collection('orders');
    final storesRef = FirebaseFirestore.instance.collection('stores');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ประวัติคำสั่งซื้อ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersRef
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีประวัติคำสั่งซื้อ',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              return _OrderCard(
                orderId: d.id,
                status: (data['status'] ?? 'pending').toString(),
                createdText: _formatTime(data['createdAt']),
                fullName: (data['fullname'] ?? '').toString(),
                phone: (data['phone'] ?? '').toString(),
                address: (data['location'] ?? '').toString(),
                deliveryImageUrl:
                    (data['deliveryImageUrl'] ?? '').toString(),
                riderName: (data['riderName'] ?? '').toString(),
                riderPhone: (data['riderPhone'] ?? '').toString(),
                storesRef: storesRef,
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.createdText,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.deliveryImageUrl,
    required this.riderName,
    required this.riderPhone,
    required this.storesRef,
  });

  final String orderId;
  final String status;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final String deliveryImageUrl;
  final String riderName;
  final String riderPhone;
  final CollectionReference<Map<String, dynamic>> storesRef;

  @override
  Widget build(BuildContext context) {
    final isSuccess = status.toLowerCase() == 'success';
    final statusColor = isSuccess ? Colors.green : Colors.orange;
    final statusText = isSuccess ? 'สำเร็จ' : 'กำลังดำเนินการ';

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: statusColor.withOpacity(0.15),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.access_time,
              color: statusColor,
            ),
          ),
          title: const Text(
            'คำสั่งซื้อ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order: $orderId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        createdText,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(),

            _InfoSection(
              title: 'ข้อมูลผู้รับ',
              icon: Icons.person,
              color: Colors.cyan,
              children: [
                if (fullName.isNotEmpty)
                  _InfoRow(icon: Icons.account_circle, text: fullName),
                if (phone.isNotEmpty)
                  _InfoRow(icon: Icons.phone, text: phone),
                if (address.isNotEmpty)
                  _InfoRow(icon: Icons.location_on, text: address),
              ],
            ),

            const SizedBox(height: 12),

            if (riderName.isNotEmpty || riderPhone.isNotEmpty)
              _InfoSection(
                title: 'ข้อมูลคนขับ',
                icon: Icons.delivery_dining,
                color: Colors.orange,
                children: [
                  if (riderName.isNotEmpty)
                    _InfoRow(icon: Icons.person_pin, text: riderName),
                  if (riderPhone.isNotEmpty)
                    _InfoRow(icon: Icons.phone_android, text: riderPhone),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delivery_dining, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'ยังไม่มีไรเดอร์รับงาน',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            if (deliveryImageUrl.isNotEmpty)
              _DeliveryImage(deliveryImageUrl: deliveryImageUrl),

            const SizedBox(height: 8),

            _OrderItemsList(
              orderId: orderId,
              storesRef: storesRef,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryImage extends StatelessWidget {
  const _DeliveryImage({
    required this.deliveryImageUrl,
  });

  final String deliveryImageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'หลักฐานการจัดส่ง',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            deliveryImageUrl,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('โหลดรูปหลักฐานไม่สำเร็จ'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderItemsList extends StatelessWidget {
  const _OrderItemsList({
    required this.orderId,
    required this.storesRef,
  });

  final String orderId;
  final CollectionReference<Map<String, dynamic>> storesRef;

  @override
  Widget build(BuildContext context) {
    final itemsRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('items');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: itemsRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snap.data!.docs;

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('ไม่มีรายการสินค้า'),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'รายการสินค้า',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              ...items.map((doc) {
                final data = doc.data();

                final name = (data['name'] ?? '').toString();
                final price = (data['price'] as num?)?.toDouble() ?? 0;
                final qty = (data['qty'] as num?)?.toInt() ?? 1;
                final total = price * qty;
                final imageUrl = (data['imageUrl'] ?? '').toString();
                final storeId = (data['storeId'] ?? '').toString();

                return ListTile(
                  leading: imageUrl.isEmpty
                      ? CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: const Icon(Icons.fastfood),
                              );
                            },
                          ),
                        ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${price.toStringAsFixed(2)} x $qty = '
                    '${total.toStringAsFixed(2)} บาท',
                  ),
                  trailing: storeId.isNotEmpty
                      ? _StoreChip(
                          storesRef: storesRef,
                          storeId: storeId,
                        )
                      : null,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({
    required this.storesRef,
    required this.storeId,
  });

  final CollectionReference<Map<String, dynamic>> storesRef;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: storesRef.doc(storeId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final data = snap.data!.data();
        if (data == null) return const SizedBox.shrink();

        return Chip(
          backgroundColor: Colors.cyan.shade50,
          label: Text(
            data['name'] ?? 'ร้านค้า',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}