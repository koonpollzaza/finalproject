import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:finalproject/chat_page.dart';

class RiderOrderDetailPage extends StatefulWidget {
  final String orderId;

  const RiderOrderDetailPage({super.key, required this.orderId});

  @override
  State<RiderOrderDetailPage> createState() => _RiderOrderDetailPageState();
}

class _RiderOrderDetailPageState extends State<RiderOrderDetailPage> {
  final ImagePicker _picker = ImagePicker();

  XFile? _pickedImage;
  bool _isUploading = false;
  bool _isDeliveryConfirmed = false;

  Future<void> _openMap(double lat, double lng) async {
    if (lat == 0 || lng == 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบพิกัดแผนที่'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openRiderStoreChat({
    required String orderId,
    required String storeId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลไรเดอร์ กรุณาเข้าสู่ระบบใหม่'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลร้านค้า'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          orderId: orderId,
          chatType: 'rider_store',
          senderType: 'rider',
          senderId: user.uid,
          senderName: 'ไรเดอร์',
          storeId: storeId,
          riderId: user.uid,
        ),
      ),
    );
  }

  Future<void> _openRiderCustomerChat({
    required String orderId,
    required String customerPhone,
    required String customerName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลไรเดอร์ กรุณาเข้าสู่ระบบใหม่'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (customerPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบเบอร์ลูกค้า'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          orderId: orderId,
          chatType: 'customer_rider',
          senderType: 'rider',
          senderId: user.uid,
          senderName: 'ไรเดอร์',
          riderId: user.uid,
          customerPhone: customerPhone,
          customerName: customerName,
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _pickedImage = image;
          _isDeliveryConfirmed = true;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยืนยันการจัดส่งแล้ว')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดกล้องไม่สำเร็จ: $e')),
      );
    }
  }

  Future<String?> _uploadDeliveryImage(String orderId) async {
    if (_pickedImage == null) return null;

    try {
      final file = File(_pickedImage!.path);
      final fileName = 'delivery_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('delivery_proofs')
          .child(orderId)
          .child(fileName);

      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload delivery image error: $e');
      return null;
    }
  }

  Future<void> _submitDelivery(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> orderRef,
  ) async {
    if (!_isDeliveryConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณายืนยันการจัดส่งก่อน')),
      );
      return;
    }

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาถ่ายรูปก่อนกดจัดส่ง')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _uploadDeliveryImage(widget.orderId);

      if (imageUrl == null || imageUrl.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ')),
        );
        return;
      }

      await orderRef.update({
        "status": "success",
        "deliveryImageUrl": imageUrl,
        "deliveredAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("จัดส่งสำเร็จ และบันทึกรูปแล้ว 🚴")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildDeliveryImageSection({
    required String deliveryImageUrl,
  }) {
    final hasNetworkImage = deliveryImageUrl.trim().isNotEmpty;
    final hasLocalImage = _pickedImage != null;

    return _SectionCard(
      title: 'หลักฐานการจัดส่ง',
      icon: Icons.image,
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasNetworkImage && !hasLocalImage)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                'ยังไม่มีรูปหลักฐานการจัดส่ง',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else if (hasLocalImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_pickedImage!.path),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                deliveryImageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 220,
                    alignment: Alignment.center,
                    color: Colors.grey.shade200,
                    child: const Text('โหลดรูปไม่สำเร็จ'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(
    DocumentReference<Map<String, dynamic>> orderRef,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: orderRef.collection('items').snapshots(),
      builder: (context, itemSnap) {
        if (!itemSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final items = itemSnap.data!.docs;

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: Text("ไม่มีสินค้า")),
          );
        }

        return _SectionCard(
          title: 'รายการอาหาร',
          icon: Icons.receipt_long,
          color: Colors.orange,
          child: Column(
            children: items.map((doc) {
              final item = doc.data();
              final imageUrl = (item['imageUrl'] ?? '').toString();
              final name = (item['name'] ?? '').toString();
              final qty = item['qty'] ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const _FoodPlaceholder();
                              },
                            )
                          : const _FoodPlaceholder(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'x$qty',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'รายละเอียดงาน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: orderRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snap.data!.data();

            if (data == null) {
              return const Center(child: Text("ไม่พบข้อมูล"));
            }

            final fullname = (data['fullname'] ?? '').toString();
            final customerPhone = (data['phone'] ?? '').toString();

            final location = (data['location'] ?? '').toString();
            final description = (data['description'] ?? '').toString();
            final status = (data['status'] ?? '').toString();
            final payment = (data['payment'] ?? '').toString();
            final storeId = (data['storeId'] ?? '').toString();
            final deliveryImageUrl =
                (data['deliveryImageUrl'] ?? '').toString();

            final lat = (data['lat'] ?? 0).toDouble();
            final lng = (data['lng'] ?? 0).toDouble();

            if (deliveryImageUrl.trim().isNotEmpty &&
                !_isDeliveryConfirmed &&
                _pickedImage == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _isDeliveryConfirmed = true);
                }
              });
            }

            final isSuccess = status == 'success';
            final isPaid = payment == 'success';

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                    child: Column(
                      children: [
                        _SectionCard(
                          title: 'ข้อมูลลูกค้า',
                          icon: Icons.person,
                          color: Colors.orange,
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.account_circle,
                                label: 'ชื่อลูกค้า',
                                value: fullname,
                              ),
                              _InfoRow(
                                icon: Icons.phone,
                                label: 'เบอร์ติดต่อลูกค้า',
                                value: customerPhone,
                              ),
                              _InfoRow(
                                icon: Icons.location_on,
                                label: 'ที่อยู่จัดส่ง',
                                value: location,
                              ),
                              if (description.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.note_alt,
                                  label: 'รายละเอียด',
                                  value: description,
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _StatusChip(
                                    text: isPaid
                                        ? 'ชำระเงินแล้ว'
                                        : 'ยังไม่ชำระเงิน',
                                    color: isPaid ? Colors.green : Colors.red,
                                    icon: isPaid
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusChip(
                                    text: isSuccess
                                        ? 'จัดส่งสำเร็จ'
                                        : 'กำลังจัดส่ง',
                                    color: isSuccess
                                        ? Colors.green
                                        : Colors.orange,
                                    icon: isSuccess
                                        ? Icons.done_all
                                        : Icons.delivery_dining,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.chat),
                                  label: const Text(
                                    'แชทกับลูกค้า',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    _openRiderCustomerChat(
                                      orderId: widget.orderId,
                                      customerPhone: customerPhone,
                                      customerName: fullname,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (storeId.isNotEmpty)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('stores')
                                .doc(storeId)
                                .get(),
                            builder: (context, storeSnap) {
                              if (!storeSnap.hasData) {
                                return const SizedBox.shrink();
                              }

                              final rawData = storeSnap.data?.data();

                              if (rawData == null) {
                                return const SizedBox.shrink();
                              }

                              final storeData = rawData as Map<String, dynamic>;
                              final storeName =
                                  storeData['name'] ?? 'ไม่ทราบชื่อร้าน';
                              final address = storeData['address'] ?? '';
                              final latStore =
                                  (storeData['lat_store'] ?? 0).toDouble();
                              final lngStore =
                                  (storeData['lng_store'] ?? 0).toDouble();

                              return _SectionCard(
                                title: 'ข้อมูลร้านค้า',
                                icon: Icons.store,
                                color: Colors.cyan,
                                child: Column(
                                  children: [
                                    _InfoRow(
                                      icon: Icons.storefront,
                                      label: 'ร้าน',
                                      value: storeName.toString(),
                                    ),
                                    if (address.toString().isNotEmpty)
                                      _InfoRow(
                                        icon: Icons.place,
                                        label: 'ที่อยู่ร้าน',
                                        value: address.toString(),
                                      ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.cyan,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(Icons.store),
                                            label: const Text("ไปร้าน"),
                                            onPressed: () => _openMap(
                                              latStore,
                                              lngStore,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(Icons.navigation),
                                            label: const Text("ไปหาลูกค้า"),
                                            onPressed: () => _openMap(lat, lng),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const Icon(Icons.chat),
                                        label: const Text(
                                          'แชทกับร้าน',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () {
                                          _openRiderStoreChat(
                                            orderId: widget.orderId,
                                            storeId: storeId,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        _buildDeliveryImageSection(
                          deliveryImageUrl: deliveryImageUrl,
                        ),
                        if (status == 'pending')
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isDeliveryConfirmed
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isDeliveryConfirmed
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isDeliveryConfirmed
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  color: _isDeliveryConfirmed
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isDeliveryConfirmed
                                        ? 'สถานะ: ยืนยันการจัดส่งแล้ว'
                                        : 'สถานะ: ยังไม่ได้ยืนยันการจัดส่ง',
                                    style: TextStyle(
                                      color: _isDeliveryConfirmed
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildOrderItems(orderRef),
                      ],
                    ),
                  ),
                ),
                if (status == 'pending')
                  _BottomActionBar(
                    isUploading: _isUploading,
                    isDeliveryConfirmed: _isDeliveryConfirmed,
                    onCamera: _isUploading ? null : _openCamera,
                    onSubmit: (!_isDeliveryConfirmed || _isUploading)
                        ? null
                        : () => _submitDelivery(context, orderRef),
                  ),
              ],
            );
          },
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
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
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isUploading,
    required this.isDeliveryConfirmed,
    required this.onCamera,
    required this.onSubmit,
  });

  final bool isUploading;
  final bool isDeliveryConfirmed;
  final VoidCallback? onCamera;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  isDeliveryConfirmed
                      ? "ถ่ายรูปยืนยันใหม่"
                      : "ยืนยันการจัดส่ง",
                ),
                onPressed: onCamera,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDeliveryConfirmed ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  isUploading ? "กำลังบันทึก..." : "จัดส่งสำเร็จ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodPlaceholder extends StatelessWidget {
  const _FoodPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      color: Colors.grey.shade200,
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }
}