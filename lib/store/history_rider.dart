import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rider_order_detail.dart';

class HistoryRiderPage extends StatelessWidget {
  final String riderId;   // 🔥 ต้องมีตัวนี้

  const HistoryRiderPage({
    super.key,
    required this.riderId,  // 🔥 ต้องมี required riderId
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติคำสั่งซื้อ'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('riderId', isEqualTo: riderId) // 🔥 ใช้ riderId ตรงนี้
            .where('riderStatus', isEqualTo: 'success')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Center(child: Text('เกิดข้อผิดพลาด'));
          }

          final orders = snap.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีประวัติคำสั่งซื้อ'),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(
                    data['fullname'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(data['location'] ?? ''),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RiderOrderDetailPage(orderId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}