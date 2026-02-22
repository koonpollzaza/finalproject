import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderOrderDetailPage extends StatelessWidget {
  final String orderId;
  const RiderOrderDetailPage({super.key, required this.orderId});

  /// ✅ เปิด Google Maps
  Future<void> _openGoogleMap(String location) async {
    if (location.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$location',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 รายละเอียดงาน'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: orderRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!.data();
          if (data == null) {
            return const Center(child: Text('ไม่พบข้อมูลออเดอร์'));
          }

          final status = data['status'] ?? '';
          final payment = data['payment'] ?? '';
          final location = data['location'] ?? '';
          final fullname = data['fullname'] ?? '';
          final description = data['description'] ?? '';

          /// 🔎 แปลงสถานะการชำระเงิน
          String paymentText = '';
          Color paymentColor = Colors.grey;

          if (payment == 'success') {
            paymentText = 'ชำระเงินแล้ว';
            paymentColor = Colors.green;
          } else if (payment == 'pending') {
            paymentText = 'ชำระเงินไม่สำเร็จ';
            paymentColor = Colors.red;
          }

          return Column(
            children: [
              /// 🔶 ข้อมูลลูกค้า
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 18, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(child: Text(location)),
                        ],
                      ),

                      /// ✅ แสดงหมายเหตุ
                      if (description.toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note,
                                  color: Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  description,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      /// 🔵 แสดงสถานะการชำระเงิน
                      if (paymentText.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            paymentText,
                            style: TextStyle(
                              color: paymentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),

                      const SizedBox(height: 4),

                      /// 🔶 แสดงสถานะออเดอร์
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          status.toString().toUpperCase(),
                          style: TextStyle(
                            color: status == 'success'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// 🔵 ปุ่มเปิดแผนที่
              if (location.toString().isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label:
                          const Text('เปิดเส้นทาง Google Maps'),
                      onPressed: () =>
                          _openGoogleMap(location),
                    ),
                  ),
                ),

              const Divider(),

              /// 🍱 รายการสินค้า
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      orderRef.collection('items').snapshots(),
                  builder: (context, itemSnap) {
                    if (!itemSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final items = itemSnap.data!.docs;

                    if (items.isEmpty) {
                      return const Center(
                          child: Text('ไม่มีรายการสินค้า'));
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item =
                            items[index].data();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: item['imageUrl'] != null &&
                                    item['imageUrl'] != ''
                                ? Image.network(
                                    item['imageUrl'],
                                    width: 50,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.fastfood,
                                    size: 40,
                                  ),
                            title: Text(item['name'] ?? ''),
                            subtitle: Text(
                                'จำนวน ${item['qty'] ?? 1} ชิ้น'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              /// ✅ ปุ่มจัดส่งสำเร็จ
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child:
                          const Text('จัดส่งสำเร็จ'),
                      onPressed: () async {
                        await orderRef.update({
                          'status': 'success',
                          'deliveredAt':
                              FieldValue.serverTimestamp(),
                        });

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                                'จัดส่งสำเร็จ 🚴‍♂️'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}