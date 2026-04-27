import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingStorePage extends StatelessWidget {
  const PendingStorePage({super.key, this.storeId});

  final String? storeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ออเดอร์รอดำเนินการ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: (storeId != null && storeId!.isNotEmpty)
            ? FirebaseFirestore.instance
                .collection('orders')
                .where('storeId', isEqualTo: storeId)
                .snapshots()
            : FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _EmptyState(
              icon: Icons.error_outline,
              title: 'เกิดข้อผิดพลาด',
              subtitle: '${snap.error}',
              color: Colors.red,
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.where((doc) {
            final data = doc.data();

            final status =
                (data['status'] ?? 'pending').toString().toLowerCase();
            final payment =
                (data['payment'] ?? 'pending').toString().toLowerCase();
            final riderStatus =
                (data['riderStatus'] ?? 'pending').toString().toLowerCase();
            final location = (data['location'] ?? '').toString().trim();

            final isPickup = location == 'รับอาหารที่ร้าน';

            if (isPickup) {
              return status == 'pending' || payment == 'pending';
            }

            return status == 'pending' ||
                payment == 'pending' ||
                riderStatus == 'pending';
          }).toList();

          docs.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

          if (docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.receipt_long,
              title: 'ยังไม่มีออเดอร์รอดำเนินการ',
              subtitle: 'เมื่อมีออเดอร์ใหม่ รายการจะแสดงที่นี่',
              color: Colors.orange,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();

              return _OrderCard(
                orderId: d.id,
                status: (data['status'] ?? 'pending').toString(),
                riderStatus: (data['riderStatus'] ?? 'pending').toString(),
                payment: (data['payment'] ?? 'pending').toString(),
                createdText: _formatTime(data['createdAt']),
                fullName: (data['fullname'] ?? 'ไม่ระบุ').toString(),
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

  bool get _isPickup => widget.locationText.trim() == 'รับอาหารที่ร้าน';

  @override
  void initState() {
    super.initState();
    _status = widget.status.toLowerCase();
    _riderStatus = widget.riderStatus.toLowerCase();
    _payment = widget.payment.toLowerCase();
  }

  Future<void> _updateStatus(String value) async {
    try {
      setState(() => _status = value);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': value});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('แก้ไขสถานะออเดอร์ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updatePayment(String value) async {
    try {
      setState(() => _payment = value);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'payment': value});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('แก้ไขสถานะการชำระเงินไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteOrder() async {
    if (!_isPickup && _riderStatus == 'success') {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('ยืนยันการยกเลิก'),
        content: const Text('ต้องการลบออเดอร์นี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ไม่'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    try {
      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

      final items = await orderRef.collection('items').get();

      for (final doc in items.docs) {
        await doc.reference.delete();
      }

      await orderRef.delete();
    } catch (e) {
      if (!mounted) return;

      setState(() => _deleting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบออเดอร์ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _statusLabel(String value) =>
      value == 'success' ? 'จัดส่งสำเร็จ' : 'รอดำเนินการ';

  String _paymentLabel(String value) =>
      value == 'success' ? 'ชำระเงินแล้ว' : 'รอชำระเงิน';

  String _riderLabel(String value) =>
      value == 'success' ? 'ไรเดอร์รับงานแล้ว' : 'กำลังหาไรเดอร์';

  Color _statusColor(String value) =>
      value == 'success' ? Colors.green : Colors.orange;

  Color _paymentColor(String value) =>
      value == 'success' ? Colors.green : Colors.orange;

  Color _riderColor(String value) =>
      value == 'success' ? Colors.green : Colors.orange;

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('โหลดรูปภาพไม่สำเร็จ'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_status);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.12),
            child: Icon(Icons.receipt_long, color: statusColor),
          ),
          title: const Text(
            'ออเดอร์',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order: ${widget.orderId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.createdText,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusChip(
                      label: _statusLabel(_status),
                      color: _statusColor(_status),
                    ),
                    _StatusChip(
                      label: _paymentLabel(_payment),
                      color: _paymentColor(_payment),
                    ),
                    if (!_isPickup)
                      _StatusChip(
                        label: _riderLabel(_riderStatus),
                        color: _riderColor(_riderStatus),
                      ),
                    if (_isPickup)
                      const _StatusChip(
                        label: 'รับเองที่ร้าน',
                        color: Colors.blue,
                      ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            _SectionCard(
              title: 'ข้อมูลลูกค้า',
              icon: Icons.person,
              color: Colors.cyan,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.account_circle,
                    label: 'ลูกค้า',
                    value: widget.fullName,
                  ),
                  _InfoRow(
                    icon: Icons.phone,
                    label: 'เบอร์',
                    value: widget.phone,
                  ),
                  if (widget.address != '-')
                    _InfoRow(
                      icon: Icons.home,
                      label: 'ที่อยู่',
                      value: widget.address,
                    ),
                  if (widget.locationText.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on,
                      label: _isPickup ? 'การรับสินค้า' : 'ตำแหน่งจัดส่ง',
                      value: widget.locationText,
                    ),
                ],
              ),
            ),

            _SectionCard(
              title: 'แก้ไขสถานะ',
              icon: Icons.tune,
              color: Colors.orange,
              child: Column(
                children: [
                  _DropdownBox(
                    title: 'สถานะออเดอร์',
                    icon: Icons.assignment_turned_in,
                    value: _status,
                    color: _statusColor(_status),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('รอดำเนินการ'),
                      ),
                      DropdownMenuItem(
                        value: 'success',
                        child: Text('จัดส่งสำเร็จ'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) _updateStatus(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _DropdownBox(
                    title: 'สถานะการชำระเงิน',
                    icon: Icons.payments,
                    value: _payment,
                    color: _paymentColor(_payment),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('รอชำระเงิน'),
                      ),
                      DropdownMenuItem(
                        value: 'success',
                        child: Text('ชำระเงินแล้ว'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) _updatePayment(value);
                    },
                  ),
                  if (!_isPickup) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _riderColor(_riderStatus).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _riderColor(_riderStatus).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            color: _riderColor(_riderStatus),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'สถานะไรเดอร์: ${_riderLabel(_riderStatus)}',
                              style: TextStyle(
                                color: _riderColor(_riderStatus),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (widget.slipUrl.isNotEmpty)
              _SectionCard(
                title: 'หลักฐานการโอนเงิน',
                icon: Icons.image,
                color: Colors.green,
                child: GestureDetector(
                  onTap: () => _showImage(widget.slipUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      widget.slipUrl,
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 210,
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: Colors.grey.shade200,
                        child: const Text('โหลดรูปสลิปไม่สำเร็จ'),
                      ),
                    ),
                  ),
                ),
              ),

            _OrderItemsList(
              orderId: widget.orderId,
              storeIdFilter: widget.storeIdFilter,
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (!_isPickup && _riderStatus == 'success') || _deleting
                    ? null
                    : _deleteOrder,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(Icons.delete),
                label: Text(_deleting ? 'กำลังยกเลิก...' : 'ยกเลิกออเดอร์'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(0.13),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  const _DropdownBox({
    required this.title,
    required this.icon,
    required this.value,
    required this.color,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final String value;
  final Color color;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.28)),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

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
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }

        final itemDocs = snap.data!.docs;

        if (itemDocs.isEmpty) {
          return const _SectionCard(
            title: 'รายการสินค้า',
            icon: Icons.shopping_bag,
            color: Colors.orange,
            child: Text('ไม่มีรายการสินค้า'),
          );
        }

        return _SectionCard(
          title: 'รายการสินค้า',
          icon: Icons.shopping_bag,
          color: Colors.orange,
          child: Column(
            children: itemDocs.map((doc) {
              final x = doc.data() as Map<String, dynamic>;

              final name = (x['name'] ?? '').toString();
              final price = (x['price'] as num?)?.toDouble() ?? 0;
              final qty = (x['qty'] as num?)?.toInt() ?? 1;
              final total = price * qty;
              final imageUrl = (x['imageUrl'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _ProductPlaceholder(),
                            )
                          : _ProductPlaceholder(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '฿${price.toStringAsFixed(2)} x $qty',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '฿${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: Colors.grey.shade200,
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 62, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}