import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:finalproject/home.dart';

class PaymentPage extends StatefulWidget {
  final String orderId;
  final double total;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.total,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  int secondsLeft = 20;
  Timer? timer;

  File? slipImage;

  bool uploading = false;
  bool loadingOrder = true;
  bool timeoutHandled = false;

  final String promptPayId = "0968355416";

  bool isPickUp = false;

  double foodTotal = 0.0;
  double deliveryFee = 0.0;
  double distanceKm = 0.0;
  double finalTotal = 0.0;

  String qrData = "";

  @override
  void initState() {
    super.initState();

    foodTotal = widget.total;
    finalTotal = widget.total;
    qrData = generatePromptPayQR(promptPayId, finalTotal);

    loadOrderData();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<void> loadOrderData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      final data = doc.data();

      if (data == null) {
        throw Exception('ไม่พบข้อมูลออเดอร์');
      }

      isPickUp = data['PickUp'] == true;

      foodTotal = _toDouble(data['subTotal']);

      if (foodTotal == 0) {
        foodTotal = _toDouble(data['foodTotal']);
      }

      if (foodTotal == 0) {
        foodTotal = widget.total;
      }

      deliveryFee = isPickUp ? 0.0 : _toDouble(data['deliveryFee']);
      distanceKm = isPickUp ? 0.0 : _toDouble(data['distanceKm']);

      finalTotal = _toDouble(data['grandTotal']);

      if (finalTotal == 0) {
        finalTotal = _toDouble(data['total']);
      }

      if (finalTotal == 0) {
        finalTotal = foodTotal + deliveryFee;
      }

      qrData = generatePromptPayQR(promptPayId, finalTotal);

      if (!mounted) return;

      setState(() {
        loadingOrder = false;
      });

      startTimer();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingOrder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("โหลดข้อมูลออเดอร์ไม่สำเร็จ: $e")),
      );
    }
  }

  String generatePromptPayQR(String mobile, double amount) {
    String format(String id, String value) =>
        id + value.length.toString().padLeft(2, '0') + value;

    if (mobile.startsWith("0")) {
      mobile = "0066${mobile.substring(1)}";
    }

    String qr = format("00", "01") +
        format("01", "11") +
        format(
          "29",
          format("00", "A000000677010111") + format("01", mobile),
        ) +
        format("52", "0000") +
        format("53", "764") +
        format("54", amount.toStringAsFixed(2)) +
        format("58", "TH");

    String crc = calculateCRC("${qr}6304");
    qr += format("63", crc);

    return qr;
  }

  String calculateCRC(String input) {
    int crc = 0xFFFF;

    for (int i = 0; i < input.length; i++) {
      crc ^= input.codeUnitAt(i) << 8;

      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }

        crc &= 0xFFFF;
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        slipImage = File(picked.path);
      });
    }
  }

  Future<void> uploadSlip() async {
    if (slipImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาแนบสลิปก่อน")),
      );
      return;
    }

    setState(() => uploading = true);

    try {
      final ref = FirebaseStorage.instance.ref('slips/${widget.orderId}.jpg');

      await ref.putFile(slipImage!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'payment': 'pending',
        'slipUrl': url,
        'PickUp': isPickUp,
        'subTotal': foodTotal,
        'foodTotal': foodTotal,
        'distanceKm': distanceKm,
        'deliveryFee': deliveryFee,
        'total': finalTotal,
        'grandTotal': finalTotal,
        'paidAmount': finalTotal,
        'slipUploadedAt': FieldValue.serverTimestamp(),
      });

      timer?.cancel();

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }

    if (mounted) {
      setState(() => uploading = false);
    }
  }

  void startTimer() {
    timer?.cancel();
    secondsLeft = 20;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 0) {
        handleTimeout();
      } else {
        if (mounted) {
          setState(() {
            secondsLeft--;
          });
        }
      }
    });
  }

  Future<void> handleTimeout() async {
    if (timeoutHandled) return;

    timeoutHandled = true;
    timer?.cancel();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("หมดเวลา"),
        content: const Text("ชำระเงินไม่สำเร็จ กรุณาสั่งซื้อใหม่อีกครั้ง"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.orderId)
                    .delete();
              } catch (e) {
                debugPrint('Delete order timeout error: $e');
              }

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
            child: const Text("ตกลง"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget buildPaymentContent() {
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            "สแกนเพื่อชำระเงิน",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          QrImageView(
            data: qrData,
            size: 240,
          ),

          const SizedBox(height: 20),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ค่าสินค้า"),
                      Text("${foodTotal.toStringAsFixed(2)} บาท"),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (!isPickUp) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("ระยะทาง"),
                        Text("${distanceKm.toStringAsFixed(2)} กม."),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPickUp
                            ? "รับเองที่ร้าน"
                            : "ค่าจัดส่ง (กม.ละ 10 บาท)",
                      ),
                      Text("${deliveryFee.toStringAsFixed(2)} บาท"),
                    ],
                  ),

                  const Divider(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ยอดรวมทั้งหมด",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${finalTotal.toStringAsFixed(2)} บาท",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            "เวลาที่เหลือ $minutes:$seconds",
            style: const TextStyle(
              color: Colors.red,
              fontSize: 18,
            ),
          ),

          const Divider(height: 40),

          if (slipImage != null) ...[
            Image.file(
              slipImage!,
              height: 180,
            ),
            const SizedBox(height: 12),
          ],

          ElevatedButton(
            onPressed: pickImage,
            child: const Text("แนบสลิป"),
          ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: uploading ? null : uploadSlip,
              child: uploading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Text("ส่งสลิปเพื่อยืนยัน"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("PromptPay Payment"),
          backgroundColor: Colors.orange,
        ),
        body: loadingOrder
            ? const Center(child: CircularProgressIndicator())
            : buildPaymentContent(),
      ),
    );
  }
}