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

            final cancelRequestStatus =
                (data['cancelRequestStatus'] ?? '').toString().toLowerCase();

            final location = (data['location'] ?? '').toString().trim();

            final isCancelled = status == 'cancelled' ||
                status == 'canceled' ||
                status == 'cancel';

            // ✅ แสดงออเดอร์ที่ถูกยกเลิกแล้วด้วย
            if (isCancelled) {
              return true;
            }

            // ✅ แสดงออเดอร์ที่ลูกค้าขอยกเลิก รอร้านอนุมัติ
            if (cancelRequestStatus == 'pending') {
              return true;
            }

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
              title: 'ยังไม่มีออเดอร์',
              subtitle:
                  'ออเดอร์รอดำเนินการ หรือออเดอร์ที่ถูกยกเลิกจะแสดงที่นี่',
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
                cancelRequestStatus:
                    (data['cancelRequestStatus'] ?? '').toString(),
                cancelReason: (data['cancelReason'] ?? '').toString(),
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
    required this.cancelRequestStatus,
    required this.cancelReason,
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
  final String cancelRequestStatus;
  final String cancelReason;
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
  late String _cancelRequestStatus;

  bool _cancelling = false;
  bool _approvingCancel = false;
  bool _rejectingCancel = false;

  bool get _isPickup => widget.locationText.trim() == 'รับอาหารที่ร้าน';

  bool get _isCancelled =>
      _status == 'cancelled' || _status == 'canceled' || _status == 'cancel';

  bool get _hasCancelRequest => _cancelRequestStatus == 'pending';

  @override
  void initState() {
    super.initState();
    _status = widget.status.toLowerCase();
    _riderStatus = widget.riderStatus.toLowerCase();
    _payment = widget.payment.toLowerCase();
    _cancelRequestStatus = widget.cancelRequestStatus.toLowerCase();
  }

  Future<void> _updateStatus(String value) async {
    if (_isCancelled) {
      _showSnack(
        'ออเดอร์นี้ถูกยกเลิกแล้ว ไม่สามารถแก้ไขสถานะได้',
        Colors.red,
      );
      return;
    }

    try {
      setState(() => _status = value);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showSnack('แก้ไขสถานะออเดอร์ไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _updatePayment(String value) async {
    if (_isCancelled) {
      _showSnack(
        'ออเดอร์นี้ถูกยกเลิกแล้ว ไม่สามารถแก้ไขการชำระเงินได้',
        Colors.red,
      );
      return;
    }

    try {
      setState(() => _payment = value);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'payment': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showSnack('แก้ไขสถานะการชำระเงินไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _approveCancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'อนุมัติการยกเลิก?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'หากอนุมัติ ออเดอร์นี้จะถูกยกเลิก และให้ลูกค้าติดต่อกลับทางร้าน',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ไม่'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text('อนุมัติยกเลิก'),
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _approvingCancel = true);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'cancelled',
        'orderCancelStatus': 'cancelled',
        'cancelRequestStatus': 'approved',
        'cancelApprovedBy': 'store',
        'cancelApprovedAt': FieldValue.serverTimestamp(),
        'refundStatus': 'contact_store',
        'refundPolicy': 'กรุณาติดต่อกลับทางร้าน',
        'cancelNote': 'ร้านค้าอนุมัติคำขอยกเลิกจากลูกค้า',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _status = 'cancelled';
        _cancelRequestStatus = 'approved';
        _approvingCancel = false;
      });

      _showSnack(
        'อนุมัติยกเลิกออเดอร์แล้ว กรุณาติดต่อกลับทางร้าน',
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _approvingCancel = false);
      _showSnack('อนุมัติยกเลิกไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _rejectCancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'ไม่อนุมัติการยกเลิก?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('ลูกค้าจะเห็นสถานะว่า ร้านไม่อนุมัติยกเลิก'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
              label: const Text('ไม่อนุมัติ'),
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _rejectingCancel = true);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'cancelRequestStatus': 'rejected',
        'cancelRejectedBy': 'store',
        'cancelRejectedAt': FieldValue.serverTimestamp(),
        'cancelRejectNote': 'ร้านค้าไม่อนุมัติคำขอยกเลิก',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _cancelRequestStatus = 'rejected';
        _rejectingCancel = false;
      });

      _showSnack('ไม่อนุมัติคำขอยกเลิกแล้ว', Colors.blueGrey);
    } catch (e) {
      if (!mounted) return;

      setState(() => _rejectingCancel = false);
      _showSnack('ไม่อนุมัติไม่สำเร็จ: $e', Colors.red);
    }
  }

  Future<void> _cancelOrderByStore() async {
    if (_isCancelled) {
      _showSnack('ออเดอร์นี้ถูกยกเลิกไปแล้ว', Colors.red);
      return;
    }

    if (!_isPickup && _riderStatus == 'success') {
      _showSnack('ไม่สามารถยกเลิกได้ ไรเดอร์รับงานแล้ว', Colors.red);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'ยืนยันการยกเลิกออเดอร์',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order: ${widget.orderId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'หากยกเลิกออเดอร์แล้ว กรุณาติดต่อกลับทางร้าน',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ไม่ยกเลิก'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.cancel),
            label: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancelling = true);

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'status': 'cancelled',
        'orderCancelStatus': 'cancelled',
        'cancelledBy': 'store',
        'cancelledAt': FieldValue.serverTimestamp(),
        'refundStatus': 'contact_store',
        'refundPolicy': 'กรุณาติดต่อกลับทางร้าน',
        'cancelNote': 'ร้านค้ายกเลิกออเดอร์',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _status = 'cancelled';
        _cancelling = false;
      });

      _showSnack(
        'ยกเลิกออเดอร์แล้ว กรุณาติดต่อกลับทางร้าน',
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _cancelling = false);
      _showSnack('ยกเลิกออเดอร์ไม่สำเร็จ: $e', Colors.red);
    }
  }

  void _showSnack(String text, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
      ),
    );
  }

  String _statusLabel(String value) {
    if (value == 'success') return 'จัดส่งสำเร็จ';
    if (value == 'cancelled' || value == 'canceled' || value == 'cancel') {
      return 'ยกเลิกแล้ว';
    }

    return 'รอดำเนินการ';
  }

  String _paymentLabel(String value) {
    if (value == 'success') return 'ชำระเงินแล้ว';
    return 'รอชำระเงิน';
  }

  String _riderLabel(String value) {
    if (value == 'success') return 'ไรเดอร์รับงานแล้ว';
    return 'กำลังหาไรเดอร์';
  }

  Color _statusColor(String value) {
    if (value == 'success') return Colors.green;

    if (value == 'cancelled' || value == 'canceled' || value == 'cancel') {
      return Colors.red;
    }

    return Colors.orange;
  }

  Color _paymentColor(String value) {
    return value == 'success' ? Colors.green : Colors.orange;
  }

  Color _riderColor(String value) {
    return value == 'success' ? Colors.green : Colors.orange;
  }

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
            child: Icon(
              _isCancelled ? Icons.cancel : Icons.receipt_long,
              color: statusColor,
            ),
          ),
          title: const Text(
            'ออเดอร์',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    if (_hasCancelRequest)
                      const _StatusChip(
                        label: 'ลูกค้าขอยกเลิก',
                        color: Colors.red,
                      ),
                    if (_isCancelled)
                      const _StatusChip(
                        label: 'กรุณาติดต่อกลับทางร้าน',
                        color: Colors.red,
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

            if (_hasCancelRequest)
              _SectionCard(
                title: 'คำขอยกเลิกจากลูกค้า',
                icon: Icons.cancel_schedule_send,
                color: Colors.red,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ลูกค้าขอยกเลิกออเดอร์นี้ หากอนุมัติให้ลูกค้าติดต่อกลับทางร้าน',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.edit_note, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.cancelReason.trim().isEmpty
                                  ? 'ลูกค้าไม่ได้ระบุเหตุผล'
                                  : 'เหตุผล: ${widget.cancelReason}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueGrey,
                              side: const BorderSide(color: Colors.blueGrey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _rejectingCancel
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close),
                            label: const Text('ไม่อนุมัติ'),
                            onPressed: _rejectingCancel || _approvingCancel
                                ? null
                                : _rejectCancelRequest,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _approvingCancel
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: const Text('อนุมัติ'),
                            onPressed: _rejectingCancel || _approvingCancel
                                ? null
                                : _approveCancelRequest,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (_isCancelled)
              _SectionCard(
                title: 'สถานะการยกเลิก',
                icon: Icons.contact_support,
                color: Colors.red,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ออเดอร์นี้ถูกยกเลิกแล้ว กรุณาติดต่อกลับทางร้าน',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isCancelled)
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

            if (!_isCancelled && !_hasCancelRequest)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                      (!_isPickup && _riderStatus == 'success') || _cancelling
                          ? null
                          : _cancelOrderByStore,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Icon(Icons.cancel),
                  label: Text(
                    _cancelling ? 'กำลังยกเลิก...' : 'ยกเลิกออเดอร์',
                  ),
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
                                  const _ProductPlaceholder(),
                            )
                          : const _ProductPlaceholder(),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
  const _ProductPlaceholder();

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