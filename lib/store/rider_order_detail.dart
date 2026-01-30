import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderOrderDetailPage extends StatelessWidget {
  final String orderId;
  const RiderOrderDetailPage({super.key, required this.orderId});

  /// ✅ เปิด Google Maps (ไม่ใช้ canLaunch)
  Future<void> _openGoogleMap(String location) async {
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

          final data = snap.data!.data()!;
          final status = data['status'];
          final location = data['location'];

          return Column(
            children: [
              ListTile(
                title: Text(data['fullname']),
                subtitle: Text(location),
                trailing: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    color:
                        status == 'success' ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              /// 🔵 ปุ่มเปิดแผนที่
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text('เปิดเส้นทาง Google Maps'),
                    onPressed: () => _openGoogleMap(location),
                  ),
                ),
              ),

              const Divider(),

              /// 🍱 รายการอาหาร
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: orderRef.collection('items').snapshots(),
                  builder: (context, itemSnap) {
                    if (!itemSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final items = itemSnap.data!.docs;

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index].data();
                        return ListTile(
                          leading: item['imageUrl'] != null &&
                                  item['imageUrl'] != ''
                              ? Image.network(
                                  item['imageUrl'],
                                  width: 50,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          title: Text(item['name']),
                          subtitle: Text(
                              'จำนวน ${item['qty']} ชิ้น'),
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
                          backgroundColor: Colors.green),
                      child: const Text('จัดส่งสำเร็จ'),
                      onPressed: () async {
                        await orderRef.update({
                          'status': 'success',
                          'deliveredAt':
                              FieldValue.serverTimestamp(),
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('จัดส่งสำเร็จ 🚴‍♂️')),
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
