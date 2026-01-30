import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  CollectionReference<Map<String, dynamic>> get ordersRef =>
      FirebaseFirestore.instance.collection('orders');

  CollectionReference<Map<String, dynamic>> get storesRef =>
      FirebaseFirestore.instance.collection('stores');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติคำสั่งซื้อ')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีประวัติคำสั่งซื้อ'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              final status = (data['status'] ?? 'pending').toString();
              final createdText = _formatTime(data['createdAt']);

              final fullName = (data['fullname'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();
              final address = (data['location'] ?? '').toString();

              return _OrderCard(
                orderId: d.id,
                status: status,
                createdText: createdText,
                fullName: fullName,
                phone: phone,
                address: address,
                storesRef: storesRef,
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
    required this.storesRef,
  });

  final String orderId;
  final String status;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final CollectionReference<Map<String, dynamic>> storesRef;

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'success'
        ? Colors.green
        : Colors.orange;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          _OrderItemsList(orderId: orderId, storesRef: storesRef),
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
                      ),
                    ),
              title: Text(name),
              subtitle: Text(
                '${price.toStringAsFixed(2)} x $qty = ${total.toStringAsFixed(2)} บาท',
              ),
              trailing: storeId.isNotEmpty
                  ? _StoreChip(storesRef: storesRef, storeId: storeId)
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
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data();
        if (data == null) return const SizedBox.shrink();

        return Chip(
          label: Text(data['name'] ?? 'ร้านค้า'),
        );
      },
    );
  }
}
