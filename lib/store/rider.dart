import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rider_order_detail.dart';
import 'history_rider.dart';
import '../login.dart';

class RiderHomePage extends StatelessWidget {
  final String riderId;

  const RiderHomePage({
    super.key,
    required this.riderId,
  });

  Future<String> _loadRiderName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return 'Rider';

    final snap = await FirebaseFirestore.instance
        .collection('riders')
        .where('userUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 'Rider';

    final data = snap.docs.first.data();
    return data['name']?.toString() ?? 'Rider';
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  Future<void> _acceptOrder({
    required BuildContext context,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) async {
    final orderRef = doc.reference;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('User not login');
      }

      final riderSnap = await FirebaseFirestore.instance
          .collection('riders')
          .where('userUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (riderSnap.docs.isEmpty) {
        throw Exception('Rider not found');
      }

      final riderData = riderSnap.docs.first.data();

      final riderName = riderData['name']?.toString() ?? 'Rider';
      final riderPhone = riderData['phone']?.toString() ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshSnap = await transaction.get(orderRef);
        final orderData = freshSnap.data();

        if (orderData == null) {
          throw Exception('Order not found');
        }

        final currentStatus = orderData['riderStatus'];

        if (currentStatus != 'pending') {
          throw Exception('Order already accepted');
        }

        transaction.update(orderRef, {
          'riderId': uid,
          'riderName': riderName,
          'riderPhone': riderPhone,
          'riderStatus': 'success',
        });
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderOrderDetailPage(orderId: doc.id),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('งานนี้มีไรเดอร์รับไปแล้ว หรือไม่พบข้อมูลไรเดอร์'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadRiderName(),
      builder: (context, riderSnap) {
        final riderName = riderSnap.data ?? 'Rider';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.orange,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚴‍♂️ งานที่รอรับ'),
                Text(
                  riderName,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'ประวัติคำสั่งซื้อ',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryRiderPage(
                        riderId:
                            FirebaseAuth.instance.currentUser?.uid ?? riderId,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('ออกจากระบบ'),
                      content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('ยกเลิก'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('ออกจากระบบ'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _logout(context);
                  }
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: 'pending')
                .where('payment', isEqualTo: 'success')
                .where('riderStatus', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return const Center(
                  child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'),
                );
              }

              final allOrders = snap.data?.docs ?? [];

              final orders = allOrders.where((doc) {
                final data = doc.data();
                final location = (data['location'] ?? '').toString().trim();

                return location != 'รับอาหารที่ร้าน';
              }).toList();

              if (orders.isEmpty) {
                return const Center(
                  child: Text(
                    'ไม่มีงานรอรับ',
                    style: TextStyle(fontSize: 16),
                  ),
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
                        data['fullname']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        data['location']?.toString() ?? '',
                      ),
                      trailing: ElevatedButton(
                        child: const Text('รับงาน'),
                        onPressed: () {
                          _acceptOrder(
                            context: context,
                            doc: doc,
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}