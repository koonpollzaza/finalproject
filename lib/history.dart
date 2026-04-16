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
      appBar: AppBar(
        title: const Text('ประวัติคำสั่งซื้อ'),
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
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    required this.storesRef,
  });

  final String orderId;
  final String status;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final String deliveryImageUrl;
  final CollectionReference<Map<String, dynamic>> storesRef;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        status.toLowerCase() == 'success' ? Colors.green : Colors.orange;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Order: $orderId',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เวลา: $createdText'),
            if (fullName.isNotEmpty) Text('ผู้รับ: $fullName'),
            if (phone.isNotEmpty) Text('โทร: $phone'),
            if (address.isNotEmpty) Text('ที่อยู่: $address'),
          ],
        ),
        children: [
          if (deliveryImageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
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
                    borderRadius: BorderRadius.circular(12),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('โหลดรูปหลักฐานไม่สำเร็จ'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

          _OrderItemsList(
            orderId: orderId,
            storesRef: storesRef,
          ),
        ],
      ),
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
            child: CircularProgressIndicator(),
          );
        }

        final items = snap.data!.docs;

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('ไม่มีรายการสินค้า'),
          );
        }

        return Column(
          children: items.map((doc) {
            final data = doc.data();

            final name = (data['name'] ?? '').toString();
            final price = (data['price'] as num?)?.toDouble() ?? 0;
            final qty = (data['qty'] as num?)?.toInt() ?? 1;
            final total = price * qty;
            final imageUrl = (data['imageUrl'] ?? '').toString();
            final storeId = (data['storeId'] ?? '').toString();

            return ListTile(
              leading: imageUrl.isEmpty
                  ? const Icon(Icons.fastfood)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.fastfood);
                        },
                      ),
                    ),
              title: Text(name),
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
          }).toList(),
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
          label: Text(data['name'] ?? 'ร้านค้า'),
        );
      },
    );
  }
}