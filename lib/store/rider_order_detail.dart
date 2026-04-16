import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final uri =
        Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        const SnackBar(content: Text('กรุณาถ่ายรูปก่อนกดจัดส่งสำเร็จ')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

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
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildDeliveryImageSection({
    required String deliveryImageUrl,
  }) {
    final hasNetworkImage = deliveryImageUrl.trim().isNotEmpty;
    final hasLocalImage = _pickedImage != null;

    if (!hasNetworkImage && !hasLocalImage) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'ยังไม่มีรูปหลักฐานการจัดส่ง',
          style: TextStyle(fontSize: 14),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'หลักฐานการจัดส่ง',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (hasLocalImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_pickedImage!.path),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            )
          else if (hasNetworkImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
          return const Center(child: CircularProgressIndicator());
        }

        final items = itemSnap.data!.docs;

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: Text("ไม่มีสินค้า")),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = items[index].data();

            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: ListTile(
                leading: item['imageUrl'] != null && item['imageUrl'] != ''
                    ? Image.network(
                        item['imageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.fastfood, size: 40);
                        },
                      )
                    : const Icon(Icons.fastfood, size: 40),
                title: Text(item['name'] ?? ''),
                subtitle: Text("จำนวน ${item['qty'] ?? 1} ชิ้น"),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 รายละเอียดงาน'),
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

            final fullname = data['fullname'] ?? '';
            final location = data['location'] ?? '';
            final description = data['description'] ?? '';
            final status = data['status'] ?? '';
            final payment = data['payment'] ?? '';
            final storeId = data['storeId'] ?? '';
            final deliveryImageUrl = data['deliveryImageUrl'] ?? '';

            final lat = (data['lat'] ?? 0).toDouble();
            final lng = (data['lng'] ?? 0).toDouble();

            if (deliveryImageUrl.toString().trim().isNotEmpty &&
                !_isDeliveryConfirmed &&
                _pickedImage == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _isDeliveryConfirmed = true;
                  });
                }
              });
            }

            String paymentText = '';
            Color paymentColor = Colors.grey;

            if (payment == 'success') {
              paymentText = 'ชำระเงินแล้ว';
              paymentColor = Colors.green;
            } else if (payment == 'pending') {
              paymentText = 'ชำระเงินไม่สำเร็จ';
              paymentColor = Colors.red;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location,
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          if (description.toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.note, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(description)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (paymentText.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                paymentText,
                                style: TextStyle(
                                  color: paymentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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

                  if (storeId != '')
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('stores')
                          .doc(storeId)
                          .get(),
                      builder: (context, storeSnap) {
                        if (!storeSnap.hasData) {
                          return const SizedBox();
                        }

                        final rawData = storeSnap.data?.data();

                        if (rawData == null) {
                          return const SizedBox();
                        }

                        final storeData = rawData as Map<String, dynamic>;
                        final storeName =
                            storeData['name'] ?? 'ไม่ทราบชื่อร้าน';
                        final address = storeData['address'] ?? '';
                        final latStore =
                            (storeData['lat_store'] ?? 0).toDouble();
                        final lngStore =
                            (storeData['lng_store'] ?? 0).toDouble();

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.store,
                                    color: Colors.orange,
                                  ),
                                  title: Text(
                                    storeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(address),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.store),
                                  label: const Text("นำทางไปที่ร้านค้า"),
                                  onPressed: () => _openMap(latStore, lngStore),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.navigation),
                                  label: const Text("นำทางไปหาลูกค้า"),
                                  onPressed: () => _openMap(lat, lng),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 8),

                  _buildDeliveryImageSection(
                    deliveryImageUrl: deliveryImageUrl.toString(),
                  ),

                  const SizedBox(height: 8),

                  if (status == 'pending')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
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
                    ),

                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'รายการอาหาร',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  _buildOrderItems(orderRef),

                  if (status == 'pending')
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(
                                _isDeliveryConfirmed
                                    ? "ถ่ายรูปยืนยันใหม่"
                                    : "ยืนยันการจัดส่ง",
                              ),
                              onPressed: _isUploading ? null : _openCamera,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isDeliveryConfirmed
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              onPressed: (!_isDeliveryConfirmed || _isUploading)
                                  ? null
                                  : () => _submitDelivery(context, orderRef),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text("จัดส่งสำเร็จ"),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}