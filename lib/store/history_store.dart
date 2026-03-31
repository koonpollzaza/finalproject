import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryStorePage extends StatelessWidget {
  const HistoryStorePage({super.key, this.storeId});

  final String? storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติคำสั่งซื้อ'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: (storeId != null && storeId!.isNotEmpty)
            ? FirebaseFirestore.instance
                .collection('orders')
                .where('storeId', isEqualTo: storeId)
                .orderBy('createdAt', descending: true)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .snapshots(),
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

              return _OrderCard(
                orderId: d.id,
                status: (data['status'] ?? 'pending').toString(),
                riderStatus: (data['riderStatus'] ?? 'pending').toString(),
                payment: (data['payment'] ?? 'pending').toString(),
                createdText: _formatTime(data['createdAt']),
                fullName:
                    (data['fullname'] ?? 'ไม่ระบุ').toString(),
                phone: (data['phone'] ?? '-').toString(),
                address: (data['address'] ?? '-').toString(),
                locationText: (data['location'] ?? '').toString(),
                slipUrl: (data['slipUrl'] ?? '').toString(),
                storeIdFilter: storeId,
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day}/${d.month}/${d.year} '
          '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }
}

/* ================= ORDER CARD ================= */

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.riderStatus,
    required this.payment,
    required this.createdText,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.locationText,
    required this.slipUrl,
    required this.storeIdFilter,
  });

  final String orderId;
  final String status;
  final String riderStatus;
  final String payment;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final String locationText;
  final String slipUrl;
  final String? storeIdFilter;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late String _status;
  late String _riderStatus;
  late String _payment;

  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status.toLowerCase();
    _riderStatus = widget.riderStatus.toLowerCase();
    _payment = widget.payment.toLowerCase();
  }

  Future<void> _updateStatus(String value) async {
    setState(() => _status = value);

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'status': value});
  }

  Future<void> _updatePayment(String value) async {
    setState(() => _payment = value);

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'payment': value});
  }

  Future<void> _deleteOrder() async {
    if (_riderStatus == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถยกเลิกได้ ไรเดอร์รับงานแล้ว'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: const Text('ต้องการลบออเดอร์นี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ไม่')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ยืนยัน')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    final items = await orderRef.collection('items').get();
    for (final doc in items.docs) {
      await doc.reference.delete();
    }

    await orderRef.delete();
  }

  String _statusLabel(String value) =>
      value == 'success' ? 'จัดส่งสำเร็จ' : 'รอดำเนินการ';

  String _riderLabel(String value) =>
      value == 'success' ? 'ไรเดอร์รับงานแล้ว' : 'กำลังหาไรเดอร์';

  Color _statusColor(String value) =>
      value == 'success' ? Colors.green : Colors.orange;

  Color _riderColor(String value) =>
      value == 'success' ? Colors.green : Colors.orange;

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Order: ${widget.orderId}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Chip(
              label: Text(
                _statusLabel(_status),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _statusColor(_status),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เวลา: ${widget.createdText}'),

            const SizedBox(height: 10),

            /// 👤 ลูกค้า
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 6),
                      Text('ลูกค้า: ${widget.fullName}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 18),
                      const SizedBox(width: 6),
                      Text('เบอร์: ${widget.phone}'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// 📍 location (จาก Firestore)
            if (widget.locationText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.locationText)),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            const Text("สถานะออเดอร์"),
            DropdownButton<String>(
              value: _status,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
                DropdownMenuItem(value: 'success', child: Text('จัดส่งสำเร็จ')),
              ],
              onChanged: (value) {
                if (value != null) _updateStatus(value);
              },
            ),

            const SizedBox(height: 10),

            const Text("สถานะการชำระเงิน"),
            DropdownButton<String>(
              value: _payment,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: 'pending', child: Text('ชำระเงินไม่สำเร็จ')),
                DropdownMenuItem(value: 'success', child: Text('ชำระเงินแล้ว')),
              ],
              onChanged: (value) {
                if (value != null) _updatePayment(value);
              },
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Text('สถานะไรเดอร์ : '),
                const SizedBox(width: 6),
                Chip(
                  label: Text(
                    _riderLabel(_riderStatus),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _riderColor(_riderStatus),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_riderStatus == 'success' || _deleting)
                    ? null
                    : _deleteOrder,
                icon: const Icon(Icons.delete),
                label: const Text('ยกเลิกออเดอร์'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
        children: [
          if (widget.slipUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _showImage(widget.slipUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.slipUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          _OrderItemsList(
            orderId: widget.orderId,
            storeIdFilter: widget.storeIdFilter,
          ),
        ],
      ),
    );
  }
}

/* ================= ITEMS ================= */

class _OrderItemsList extends StatelessWidget {
  const _OrderItemsList({
    required this.orderId,
    required this.storeIdFilter,
  });

  final String orderId;
  final String? storeIdFilter;

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('items');

    if (storeIdFilter != null && storeIdFilter!.isNotEmpty) {
      q = q.where('storeId', isEqualTo: storeIdFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        return Column(
          children: snap.data!.docs.map((doc) {
            final x = doc.data() as Map<String, dynamic>;

            final name = x['name'] ?? '';
            final price = (x['price'] as num?)?.toDouble() ?? 0;
            final qty = (x['qty'] as num?)?.toInt() ?? 1;
            final total = price * qty;

            return ListTile(
              title: Text(name),
              subtitle: Text('฿${price.toStringAsFixed(2)} x $qty'),
              trailing: Text('฿${total.toStringAsFixed(2)}'),
            );
          }).toList(),
        );
      },
    );
  }
}