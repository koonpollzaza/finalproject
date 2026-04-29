import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalproject/chat_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? loginPhone;
  bool loadingLogin = true;

  @override
  void initState() {
    super.initState();
    _loadLoginPhone();
  }

  String _formatPhoneNumber(String phone) {
    phone = phone.trim().replaceAll(' ', '').replaceAll('-', '');

    if (phone.startsWith('+66')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('66')) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  Future<void> _loadLoginPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('loginPhone');

    if (!mounted) return;

    setState(() {
      loginPhone = phone == null ? null : _formatPhoneNumber(phone);
      loadingLogin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loadingLogin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loginPhone == null || loginPhone!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบ")),
      );
    }

    final ordersRef = FirebaseFirestore.instance.collection('orders');
    final storesRef = FirebaseFirestore.instance.collection('stores');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ประวัติคำสั่งซื้อ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersRef.where('userPhone', isEqualTo: loginPhone).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          docs.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีประวัติคำสั่งซื้อ',
                style: TextStyle(fontSize: 16),
              ),
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
                storeId: (data['storeId'] ?? '').toString(),
                riderId: (data['riderId'] ?? '').toString(),
                status: (data['status'] ?? 'pending').toString(),
                payment: (data['payment'] ?? 'pending').toString(),
                cancelRequestStatus:
                    (data['cancelRequestStatus'] ?? '').toString(),
                cancelReason: (data['cancelReason'] ?? '').toString(),
                createdText: _formatTime(data['createdAt']),
                fullName: (data['fullname'] ?? '').toString(),
                phone: (data['phone'] ?? '').toString(),
                address: (data['location'] ?? '').toString(),
                description: (data['description'] ?? '').toString(),
                deliveryImageUrl:
                    (data['deliveryImageUrl'] ?? '').toString(),
                slipUrl: (data['slipUrl'] ?? '').toString(),
                riderName: (data['riderName'] ?? '').toString(),
                riderPhone: (data['riderPhone'] ?? '').toString(),
                storesRef: storesRef,
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.orderId,
    required this.storeId,
    required this.riderId,
    required this.status,
    required this.payment,
    required this.cancelRequestStatus,
    required this.cancelReason,
    required this.createdText,
    required this.fullName,
    required this.phone,
    required this.address,
    required this.description,
    required this.deliveryImageUrl,
    required this.slipUrl,
    required this.riderName,
    required this.riderPhone,
    required this.storesRef,
  });

  final String orderId;
  final String storeId;
  final String riderId;
  final String status;
  final String payment;
  final String cancelRequestStatus;
  final String cancelReason;
  final String createdText;
  final String fullName;
  final String phone;
  final String address;
  final String description;
  final String deliveryImageUrl;
  final String slipUrl;
  final String riderName;
  final String riderPhone;
  final CollectionReference<Map<String, dynamic>> storesRef;

  Future<void> _requestCancelOrder(BuildContext context) async {
    final reason = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CancelOrderReasonPage(orderId: orderId),
      ),
    );

    if (reason == null || reason.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'cancelRequestStatus': 'pending',
        'cancelRequestedBy': 'customer',
        'cancelRequestedAt': FieldValue.serverTimestamp(),
        'cancelReason': reason.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งคำขอยกเลิกไปยังร้านค้าแล้ว'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำขอยกเลิกไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    final cancelReq = cancelRequestStatus.toLowerCase();

    final isSuccess = statusLower == 'success';
    final isPending = statusLower == 'pending';
    final isCancelled = statusLower == 'cancelled' ||
        statusLower == 'canceled' ||
        statusLower == 'cancel';

    final isCancelPending = cancelReq == 'pending';
    final isCancelRejected = cancelReq == 'rejected';
    final isCancelApproved = cancelReq == 'approved';

    final canRequestCancel =
        !isSuccess && !isCancelled && !isCancelPending && !isCancelApproved;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (isSuccess) {
      statusColor = Colors.green;
      statusText = 'สำเร็จ';
      statusIcon = Icons.check_circle;
    } else if (isCancelled) {
      statusColor = Colors.red;
      statusText = 'ยกเลิกแล้ว';
      statusIcon = Icons.cancel;
    } else if (isPending) {
      statusColor = Colors.orange;
      statusText = 'กำลังดำเนินการ';
      statusIcon = Icons.access_time;
    } else {
      statusColor = Colors.blueGrey;
      statusText = status;
      statusIcon = Icons.info;
    }

    final paymentText = payment == 'success'
        ? 'ชำระเงินสำเร็จ'
        : payment == 'pending'
            ? 'รอตรวจสอบการชำระเงิน'
            : payment;

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
            radius: 24,
            backgroundColor: statusColor.withOpacity(0.15),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: const Text(
            'คำสั่งซื้อ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order: $orderId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        createdText,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallChip(
                      text: statusText,
                      color: statusColor,
                    ),
                    _SmallChip(
                      text: paymentText,
                      color: Colors.cyan,
                    ),
                    if (isCancelPending)
                      const _SmallChip(
                        text: 'รอร้านอนุมัติยกเลิก',
                        color: Colors.orange,
                      ),
                    if (isCancelRejected)
                      const _SmallChip(
                        text: 'ร้านไม่อนุมัติยกเลิก',
                        color: Colors.blueGrey,
                      ),
                    if (isCancelled)
                      const _SmallChip(
                        text: 'กรุณาติดต่อกลับทางร้าน',
                        color: Colors.red,
                      ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(),

            _InfoSection(
              title: 'ข้อมูลผู้รับ',
              icon: Icons.person,
              color: Colors.cyan,
              children: [
                if (fullName.isNotEmpty)
                  _InfoRow(icon: Icons.account_circle, text: fullName),
                if (phone.isNotEmpty)
                  _InfoRow(icon: Icons.phone, text: phone),
                if (address.isNotEmpty)
                  _InfoRow(icon: Icons.location_on, text: address),
                if (description.isNotEmpty)
                  _InfoRow(icon: Icons.description, text: description),
              ],
            ),

            const SizedBox(height: 12),

            if (isCancelPending)
              _NoticeBox(
                color: Colors.orange,
                icon: Icons.hourglass_top,
                text: 'ส่งคำขอยกเลิกแล้ว กำลังรอร้านค้าอนุมัติ',
                subText: cancelReason.isNotEmpty ? 'เหตุผล: $cancelReason' : '',
              ),

            if (isCancelRejected)
              _NoticeBox(
                color: Colors.blueGrey,
                icon: Icons.block,
                text: 'ร้านค้าไม่อนุมัติคำขอยกเลิก',
                subText:
                    cancelReason.isNotEmpty ? 'เหตุผลที่ส่ง: $cancelReason' : '',
              ),

            if (isCancelled)
              _NoticeBox(
                color: Colors.red,
                icon: Icons.contact_support,
                text: 'ออเดอร์นี้ถูกยกเลิกแล้ว: กรุณาติดต่อกลับทางร้าน',
                subText: cancelReason.isNotEmpty ? 'เหตุผล: $cancelReason' : '',
              ),

            if (isCancelPending || isCancelRejected || isCancelled)
              const SizedBox(height: 12),

            if (riderName.isNotEmpty || riderPhone.isNotEmpty)
              _InfoSection(
                title: 'ข้อมูลคนขับ',
                icon: Icons.delivery_dining,
                color: Colors.orange,
                children: [
                  if (riderName.isNotEmpty)
                    _InfoRow(icon: Icons.person_pin, text: riderName),
                  if (riderPhone.isNotEmpty)
                    _InfoRow(icon: Icons.phone_android, text: riderPhone),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delivery_dining, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'ยังไม่มีไรเดอร์รับงาน',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.store),
                    label: const Text('แชทกับร้าน'),
                    onPressed: storeId.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  orderId: orderId,
                                  chatType: 'customer_store',
                                  senderType: 'customer',
                                  senderId: phone,
                                  senderName: fullName,
                                  storeId: storeId,
                                  customerPhone: phone,
                                  customerName: fullName,
                                ),
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('แชทกับไรเดอร์'),
                    onPressed: riderId.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  orderId: orderId,
                                  chatType: 'customer_rider',
                                  senderType: 'customer',
                                  senderId: phone,
                                  senderName: fullName,
                                  riderId: riderId,
                                  customerPhone: phone,
                                  customerName: fullName,
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (canRequestCancel)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text(
                    'ขอยกเลิกออเดอร์',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _requestCancelOrder(context),
                ),
              ),

            const SizedBox(height: 12),

            if (slipUrl.isNotEmpty)
              _ImageSection(
                title: 'หลักฐานการโอนเงิน',
                imageUrl: slipUrl,
              ),

            if (slipUrl.isNotEmpty) const SizedBox(height: 12),

            if (deliveryImageUrl.isNotEmpty)
              _ImageSection(
                title: 'หลักฐานการจัดส่ง',
                imageUrl: deliveryImageUrl,
              ),

            const SizedBox(height: 8),

            _OrderItemsList(
              orderId: orderId,
              storesRef: storesRef,
            ),
          ],
        ),
      ),
    );
  }
}

class CancelOrderReasonPage extends StatefulWidget {
  const CancelOrderReasonPage({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<CancelOrderReasonPage> createState() => _CancelOrderReasonPageState();
}

class _CancelOrderReasonPageState extends State<CancelOrderReasonPage> {
  final TextEditingController _reasonC = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonC.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonC.text.trim();

    if (reason.isEmpty) {
      setState(() {
        _errorText = 'กรุณากรอกเหตุผลก่อนส่งคำขอ';
      });
      return;
    }

    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'ขอยกเลิกออเดอร์',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(
                              Icons.cancel_schedule_send,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Order: ${widget.orderId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ระบบจะส่งคำขอยกเลิกไปให้ร้านค้าอนุมัติก่อน หากร้านค้าอนุมัติ กรุณาติดต่อกลับทางร้าน',
                                style: TextStyle(
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextField(
                        controller: _reasonC,
                        maxLines: 5,
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'เหตุผลที่ต้องการยกเลิก',
                          hintText:
                              'เช่น สั่งผิดร้าน, ไม่สะดวกรับอาหาร, ต้องการเปลี่ยนรายการ',
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.edit_note),
                          errorText: _errorText,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Colors.orange,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'ตกลงขอยกเลิก',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _submit,
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('ไม่ส่งคำขอ'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.color,
    required this.icon,
    required this.text,
    required this.subText,
  });

  final Color color;
  final IconData icon;
  final String text;
  final String subText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color, size: 20),
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
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.title,
    required this.imageUrl,
  });

  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('โหลดรูป$titleไม่สำเร็จ'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderItemsList extends StatelessWidget {
  const _OrderItemsList({
    required this.orderId,
    required this.storesRef,
  });

  final String orderId;
  final CollectionReference<Map<String, dynamic>> storesRef;

  @override
  Widget build(BuildContext context) {
    final itemsRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('items');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: itemsRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snap.data!.docs;

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('ไม่มีรายการสินค้า'),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'รายการสินค้า',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              ...items.map((doc) {
                final data = doc.data();

                final name = (data['name'] ?? '').toString();

                final price = (data['price'] is num)
                    ? (data['price'] as num).toDouble()
                    : double.tryParse('${data['price']}') ?? 0.0;

                final qty = (data['qty'] is num)
                    ? (data['qty'] as num).toInt()
                    : int.tryParse('${data['qty']}') ?? 1;

                final total = price * qty;
                final imageUrl = (data['imageUrl'] ?? '').toString();
                final storeId = (data['storeId'] ?? '').toString();

                return ListTile(
                  leading: imageUrl.isEmpty
                      ? CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: const Icon(Icons.fastfood),
                              );
                            },
                          ),
                        ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${price.toStringAsFixed(2)} x $qty = '
                    '${total.toStringAsFixed(2)} บาท',
                  ),
                  trailing: storeId.isNotEmpty
                      ? _StoreChip(
                          storesRef: storesRef,
                          storeId: storeId,
                        )
                      : null,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({
    required this.storesRef,
    required this.storeId,
  });

  final CollectionReference<Map<String, dynamic>> storesRef;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: storesRef.doc(storeId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final data = snap.data!.data();
        if (data == null) return const SizedBox.shrink();

        return Chip(
          backgroundColor: Colors.cyan.shade50,
          label: Text(
            data['name'] ?? 'ร้านค้า',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}