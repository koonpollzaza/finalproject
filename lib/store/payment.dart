import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  int secondsLeft = 120;
  Timer? timer;
  late String qrData;

  File? slipImage;
  bool uploading = false;

  final String promptPayId = "0968355416";

  @override
  void initState() {
    super.initState();
    qrData = generatePromptPayQR(promptPayId, widget.total);
    startTimer();
  }

  // ===============================
  // 🔥 สร้าง PromptPay QR
  // ===============================
  String generatePromptPayQR(String mobile, double amount) {
    String format(String id, String value) =>
        id + value.length.toString().padLeft(2, '0') + value;

    if (mobile.startsWith("0")) {
      mobile = "66" + mobile.substring(1);
    }

    String qr = format("00", "01") +
        format("01", "11") +
        format("29", format("00", "A000000677010111") + format("01", mobile)) +
        format("52", "0000") +
        format("53", "764") +
        format("54", amount.toStringAsFixed(2)) +
        format("58", "TH");

    String crc = calculateCRC(qr + "6304");
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

  // ===============================
  // 📷 เลือกรูป
  // ===============================
  Future<void> pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (picked != null) {
      setState(() {
        slipImage = File(picked.path);
      });
    }
  }

  // ===============================
  // 🔥 อัปโหลดสลิป
  // ===============================
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
      });

      timer?.cancel();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }

    setState(() => uploading = false);
  }

  // ===============================
  // ⏳ Timer เมื่อหมดเวลา
  // ===============================
  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft == 0) {
        handleTimeout();
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  Future<void> handleTimeout() async {
    timer?.cancel();

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("หมดเวลา"),
        content: const Text("ชำระเงินไม่สำเร็จ"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ตกลง"),
          ),
        ],
      ),
    );

    // 🔥 ลบ document order ทั้งก้อน
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .delete();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("PromptPay Payment"),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("สแกนเพื่อชำระเงิน",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              QrImageView(data: qrData, size: 240),
              const SizedBox(height: 20),
              Text(
                "ยอด ${widget.total.toStringAsFixed(2)} บาท",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(
                "เวลาที่เหลือ $minutes:$seconds",
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
              const Divider(height: 40),
              if (slipImage != null) Image.file(slipImage!, height: 180),
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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ส่งสลิปเพื่อยืนยัน"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
