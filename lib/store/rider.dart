import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rider_order_detail.dart';
import '../login.dart'; // 🔁 แก้ชื่อไฟล์ตามโปรเจกต์คุณ

class RiderHomePage extends StatelessWidget {
  final String riderId; // ใช้เป็นเบอร์โทร rider

  const RiderHomePage({
    super.key,
    required this.riderId,
  });

  /// 🔍 โหลดชื่อ rider จาก collection riders ด้วย phone
  Future<String> _loadRiderName() async {
    final snap = await FirebaseFirestore.instance
        .collection('riders')
        .where('phone', isEqualTo: riderId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 'Rider';

    return snap.docs.first.data()['name'] ?? 'Rider';
  }

  /// 🚪 ออกจากระบบ
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),

            /// 🔴 ปุ่มออกจากระบบ
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'ออกจากระบบ',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('ออกจากระบบ'),
                      content:
                          const Text('คุณต้องการออกจากระบบหรือไม่?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('ยกเลิก'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
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
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              final orders = snap.data?.docs ?? [];

              if (orders.isEmpty) {
                return const Center(child: Text('ไม่มีงานรอรับ'));
              }

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data();

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: ListTile(
                      title: Text(data['fullname'] ?? ''),
                      subtitle: Text(data['location'] ?? ''),
                      trailing: ElevatedButton(
                        child: const Text('รับงาน'),
                        onPressed: () async {
                          await doc.reference.update({
                            'riderId': riderId,
                            'riderName': riderName,
                            'status': 'pending',
                            'riderStatus': 'success',
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RiderOrderDetailPage(
                                      orderId: doc.id),
                            ),
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
