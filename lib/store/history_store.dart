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
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
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
                createdText: _formatTime(data['createdAt']),
                fullName: (data['recipient']?['fullName'] ?? '').toString(),
                phone: (data['recipient']?['phone'] ?? '').toString(),
                address: (data['recipient']?['address'] ?? '').toString(),
                payment: (data['payment'] ?? '').toString(),
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
    required this.createdText,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.payment,
    required this.slipUrl,
    required this.storeIdFilter,
  });

  final String orderId;
  final String status;
  final String riderStatus;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final String payment;
  final String slipUrl;
  final String? storeIdFilter;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late String _status;
  late String _riderStatus;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status.toLowerCase();
    _riderStatus = widget.riderStatus.toLowerCase();
  }

  /* ================= UPDATE STATUS ================= */

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _status = newStatus);

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'status': newStatus});
  }

  /* ================= DELETE ORDER ================= */

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
      builder: (context) => AlertDialog(
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

  /* ================= STATUS STYLE ================= */

  Color _statusColor(String value) {
    return value == 'success' ? Colors.green : Colors.orange;
  }

  String _statusLabel(String value) {
    return value == 'success' ? 'จัดส่งสำเร็จ' : 'รอดำเนินการ';
  }

  Color _riderColor(String value) {
    return value == 'success' ? Colors.green : Colors.orange;
  }

  String _riderLabel(String value) {
    return value == 'success' ? 'ไรเดอร์รับงานแล้ว' : 'กำลังหาไรเดอร์';
  }

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

        /* ================= TITLE ================= */

        title: Row(
          children: [
            Expanded(
              child: Text(
                'Order: ${widget.orderId}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Chip(
              label: Text(
                _statusLabel(_status),
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _statusColor(_status),
            ),
          ],
        ),

        /* ================= BODY ================= */

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เวลา: ${widget.createdText}'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _status,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
                DropdownMenuItem(value: 'success', child: Text('จัดส่งสำเร็จ')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateStatus(value);
                }
              },
            ),
            const SizedBox(height: 8),
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
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('฿${price.toStringAsFixed(2)} x $qty'),
              trailing: Text(
                '฿${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
