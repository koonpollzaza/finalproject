import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryStorePage extends StatelessWidget {
  const HistoryStorePage({super.key, this.storeId});

  final String? storeId;

  CollectionReference<Map<String, dynamic>> get ordersRef =>
      FirebaseFirestore.instance.collection('orders');

  CollectionReference<Map<String, dynamic>> get storesRef =>
      FirebaseFirestore.instance.collection('stores');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติคำสั่งซื้อ'),
        backgroundColor: Colors.cyan[300],
      ),
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

              final recipient = _toMap(data['recipient']);
              final fullName = recipient['fullName'] ?? '';
              final phone = recipient['phone'] ?? '';
              final address = recipient['address'] ?? '';

              return _OrderCard(
                orderId: d.id,
                status: status,
                createdText: createdText,
                fullName: fullName,
                phone: phone,
                address: address,
                storesRef: storesRef,
                storeIdFilter: storeId,
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute}';
    }
    return '-';
  }

  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }
}

/* ---------------- ORDER CARD ---------------- */

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.createdText,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.storesRef,
    required this.storeIdFilter,
  });

  final String orderId;
  final String status;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final CollectionReference<Map<String, dynamic>> storesRef;
  final String? storeIdFilter;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status.toLowerCase() == 'success'
        ? 'success'
        : 'pending';
  }

  Future<void> _updateStatus(String value) async {
    if (_status == value) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _status = value);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        _status == 'success' ? Colors.green : Colors.orange;

    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Chip(
              label: Text(_status.toUpperCase()),
              backgroundColor: color.withOpacity(.15),
              labelStyle: TextStyle(color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Order: ${widget.orderId}',
                  overflow: TextOverflow.ellipsis),
            )
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เวลา: ${widget.createdText}'),
            if (widget.fullName.isNotEmpty)
              Text('ผู้รับ: ${widget.fullName}'),
            if (widget.phone.isNotEmpty)
              Text('เบอร์: ${widget.phone}'),
            if (widget.address.isNotEmpty)
              Text('ที่อยู่: ${widget.address}'),
            Row(
              children: [
                const Text('สถานะ: '),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(
                        value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'success', child: Text('Success')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => _updateStatus(v!),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
              ],
            )
          ],
        ),
        children: [
          _OrderItemsList(
            orderId: widget.orderId,
            storesRef: widget.storesRef,
            storeIdFilter: widget.storeIdFilter,
          )
        ],
      ),
    );
  }
}

/* ---------------- ITEMS ---------------- */

class _OrderItemsList extends StatelessWidget {
  const _OrderItemsList({
    required this.orderId,
    required this.storesRef,
    required this.storeIdFilter,
  });

  final String orderId;
  final CollectionReference<Map<String, dynamic>> storesRef;
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
            final price =
                (x['price'] as num?)?.toDouble() ?? 0;
            final qty = (x['qty'] as num?)?.toInt() ?? 1;

            final total = price * qty;

            return ListTile(
              title: Text(name,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '฿${price.toStringAsFixed(2)} x $qty'),
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
