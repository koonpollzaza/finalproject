import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finalproject/select_location_page.dart';
import 'package:finalproject/store/payment.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();
  final _descriptionC = TextEditingController();
  final _otpC = TextEditingController();

  double? _lat;
  double? _lng;

  double _distanceKm = 0;
  double _deliveryFee = 0;

  final double _feePerKm = 10;

  String _paymentMethod = 'payment';

  bool _loadingUser = true;
  bool _calculatingFee = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _submittingOrder = false;
  bool _otpCompleted = false;

  String? loginPhone;
  String? loginDisplayName;
  String? loginUserDocId;

  String? _verificationId;

  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _pendingDocs;
  double _pendingSubTotal = 0;
  String? _pendingStoreId;

  CollectionReference<Map<String, dynamic>> get cartRef =>
      FirebaseFirestore.instance.collection('cart');

  CollectionReference<Map<String, dynamic>> get storeRef =>
      FirebaseFirestore.instance.collection('stores');

  @override
  void initState() {
    super.initState();
    _loadLoginData();
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

  String _formatPhoneForFirebase(String phone) {
    phone = _formatPhoneNumber(phone);

    if (phone.startsWith('0')) {
      return '+66${phone.substring(1)}';
    }

    return phone;
  }

  List<String> _phoneSearchKeys(String phone) {
    final local = _formatPhoneNumber(phone);

    if (local.startsWith('0')) {
      final noZero = local.substring(1);

      return [
        local,
        '+66$noZero',
        '66$noZero',
      ];
    }

    return [local];
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _loadLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final phone = prefs.getString('loginPhone');
      final displayName = prefs.getString('loginDisplayName');
      final userDocId = prefs.getString('loginUserDocId');

      if (phone == null || phone.isEmpty) {
        if (!mounted) return;

        setState(() {
          _loadingUser = false;
        });

        return;
      }

      loginPhone = _formatPhoneNumber(phone);
      loginDisplayName = displayName ?? '';
      loginUserDocId = userDocId;

      _phoneC.text = loginPhone!;
      _fullNameC.text = loginDisplayName ?? '';

      await _loadUserInfoByPhone(loginPhone!);
    } catch (e) {
      debugPrint('Load login data error: $e');
    }

    if (!mounted) return;

    setState(() {
      _loadingUser = false;
    });
  }

  Future<void> _loadUserInfoByPhone(String phone) async {
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', whereIn: _phoneSearchKeys(phone))
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final data = userQuery.docs.first.data();

        final fullname = (data['displayName'] ??
                data['fullname'] ??
                data['fullName'] ??
                data['name'] ??
                loginDisplayName ??
                '')
            .toString();

        final userPhone = (data['phone'] ??
                data['phoneNumber'] ??
                data['PhoneNumber'] ??
                phone)
            .toString();

        _fullNameC.text = fullname;
        _phoneC.text = _formatPhoneNumber(userPhone);
      }
    } catch (e) {
      debugPrint('Load user by phone error: $e');
    }
  }

  @override
  void dispose() {
    _fullNameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _descriptionC.dispose();
    _otpC.dispose();
    super.dispose();
  }

  Future<String?> _getStoreName(String storeId) async {
    final doc = await storeRef.doc(storeId).get();

    if (doc.exists) {
      return doc.data()?['name']?.toString();
    }

    return null;
  }

  Future<void> _calculateDeliveryFee(String storeId) async {
    if (_paymentMethod != 'payment') {
      setState(() {
        _distanceKm = 0;
        _deliveryFee = 0;
      });
      return;
    }

    if (_lat == null || _lng == null) return;

    setState(() => _calculatingFee = true);

    try {
      final storeDoc = await storeRef.doc(storeId).get();

      if (!storeDoc.exists) {
        throw Exception('ไม่พบตำแหน่งร้านค้า');
      }

      final data = storeDoc.data();

      final storeLat = _toDouble(data?['lat_store']);
      final storeLng = _toDouble(data?['lng_store']);

      if (storeLat == 0 || storeLng == 0) {
        throw Exception('ร้านค้ายังไม่ได้บันทึกตำแหน่ง');
      }

      final meters = Geolocator.distanceBetween(
        storeLat,
        storeLng,
        _lat!,
        _lng!,
      );

      final distanceKm = meters / 1000;
      final deliveryFee = distanceKm * _feePerKm;

      if (!mounted) return;

      setState(() {
        _distanceKm = distanceKm;
        _deliveryFee = deliveryFee;
      });
    } catch (e) {
      debugPrint('Calculate delivery fee error: $e');

      if (!mounted) return;

      setState(() {
        _distanceKm = 0;
        _deliveryFee = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _calculatingFee = false);
      }
    }
  }

  Future<void> _updateQty(
    DocumentReference docRef,
    int currentQty,
    int change,
  ) async {
    final newQty = currentQty + change;

    if (newQty <= 0) {
      await docRef.delete();
    } else {
      await docRef.update({
        'qty': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _deleteItem(DocumentReference docRef) async {
    await docRef.delete();
  }

  Future<void> _startOtpBeforeSubmit(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  double subTotal,
  String storeId,
) async {
  if (_sendingOtp || _verifyingOtp || _submittingOrder) return;

  _pendingDocs = docs;
  _pendingSubTotal = subTotal;
  _pendingStoreId = storeId;
  _verificationId = null;
  _otpCompleted = false;
  _otpC.clear();

  await _sendOtpBeforeSubmit();

  if (!mounted || _otpCompleted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      size: 46,
                      color: Colors.cyan,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'ยืนยันตัวตนก่อนสั่งซื้อ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'ระบบได้ส่งรหัส OTP ไปที่',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Text(
                      _phoneC.text.trim(),
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _otpC,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '------',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade300,
                        letterSpacing: 8,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: 'กรอกรหัส OTP',
                      labelStyle: const TextStyle(color: Colors.cyan),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.cyan,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'กรุณากรอกรหัส 6 หลักที่ได้รับทาง SMS',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _verifyingOtp || _submittingOrder
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
                        _verifyingOtp || _submittingOrder
                            ? 'กำลังยืนยัน...'
                            : 'ยืนยัน OTP',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _verifyingOtp || _submittingOrder
                          ? null
                          : () async {
                              setDialogState(() {
                                _verifyingOtp = true;
                              });

                              await _verifyOtpBeforeSubmit(dialogContext);

                              if (mounted) {
                                setDialogState(() {
                                  _verifyingOtp = false;
                                });
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _verifyingOtp || _submittingOrder
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                },
                          icon: const Icon(Icons.close),
                          label: const Text('ยกเลิก'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _sendingOtp ||
                                  _verifyingOtp ||
                                  _submittingOrder
                              ? null
                              : () async {
                                  _otpC.clear();

                                  setDialogState(() {
                                    _sendingOtp = true;
                                  });

                                  await _sendOtpBeforeSubmit();

                                  if (mounted) {
                                    setDialogState(() {
                                      _sendingOtp = false;
                                    });
                                  }
                                },
                          icon: _sendingOtp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sms_outlined),
                          label: Text(
                            _sendingOtp ? 'กำลังส่ง...' : 'ส่ง OTP อีกครั้ง',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  Future<void> _sendOtpBeforeSubmit() async {
    final phone = _formatPhoneForFirebase(_phoneC.text.trim());

    setState(() => _sendingOtp = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _confirmCredentialAndSubmit(credential, null);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ส่ง OTP ไม่สำเร็จ: ${e.message ?? e.code}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ส่ง OTP แล้ว กรุณากรอกรหัส'),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่ง OTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingOtp = false);
      }
    }
  }

  Future<void> _verifyOtpBeforeSubmit(BuildContext dialogContext) async {
    final otp = _otpC.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอก OTP 6 หลัก')),
      );
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาส่ง OTP อีกครั้ง')),
      );
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _confirmCredentialAndSubmit(credential, dialogContext);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP ไม่ถูกต้อง: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmCredentialAndSubmit(
    PhoneAuthCredential credential,
    BuildContext? dialogContext,
  ) async {
    if (_otpCompleted || _submittingOrder) return;

    _otpCompleted = true;

    setState(() => _submittingOrder = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final verifiedUid = userCredential.user?.uid;

      if (_pendingDocs == null || _pendingStoreId == null) {
        throw Exception('ไม่พบข้อมูลตะกร้า');
      }

      if (!mounted) return;

      if (dialogContext != null && Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }

      await _submitOrder(
        _pendingDocs!,
        _pendingSubTotal,
        _pendingStoreId!,
        verifiedUid,
      );
    } catch (e) {
      _otpCompleted = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ยืนยัน OTP ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loginPhone == null || loginPhone!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบ")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ตะกร้าสินค้า',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartRef.where('userPhone', isEqualTo: loginPhone).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ยังไม่มีสินค้าในตะกร้า',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final docs = snap.data!.docs;

          final storeIds = docs
              .map((d) => d.data()['storeId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();

          final multipleStores = storeIds.length > 1;
          final storeId = storeIds.isNotEmpty ? storeIds.first : null;

          final subTotal = docs.fold<double>(0, (sum, d) {
            final data = d.data();
            final price = _toDouble(data['price']);
            final qty = (data['qty'] ?? 1).toInt();
            return sum + price * qty;
          });

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildForm(storeId),
                      const SizedBox(height: 14),

                      if (storeId != null)
                        FutureBuilder<String?>(
                          future: _getStoreName(storeId),
                          builder: (context, snapshot) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.orange.shade100,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Colors.orange,
                                    child: Icon(
                                      Icons.store,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      snapshot.hasData
                                          ? 'ร้าน: ${snapshot.data}'
                                          : 'กำลังโหลดชื่อร้าน...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      if (multipleStores) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'คุณสามารถสั่งได้ครั้งละ 1 ร้านเท่านั้น',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      const Text(
                        'รายการสินค้า',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      ...docs.map((doc) {
                        final data = doc.data();

                        final qty = (data['qty'] ?? 1).toInt();
                        final price = _toDouble(data['price']);
                        final name = data['name'] ?? '';
                        final imageUrl = (data['imageUrl'] ?? '').toString();
                        final itemTotal = price * qty;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl.isEmpty
                                      ? Container(
                                          width: 64,
                                          height: 64,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.fastfood),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              width: 64,
                                              height: 64,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.fastfood),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${price.toStringAsFixed(2)} บาท',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'รวม ${itemTotal.toStringAsFixed(2)} บาท',
                                        style: const TextStyle(
                                          color: Colors.cyan,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deleteItem(doc.reference),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            iconSize: 18,
                                            icon: const Icon(Icons.remove),
                                            onPressed: () => _updateQty(
                                              doc.reference,
                                              qty,
                                              -1,
                                            ),
                                          ),
                                          Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            iconSize: 18,
                                            icon: const Icon(Icons.add),
                                            onPressed: () => _updateQty(
                                              doc.reference,
                                              qty,
                                              1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              _buildSummary(subTotal, docs, multipleStores, storeId),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(String? storeId) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.cyan,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'ข้อมูลผู้สั่ง',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _fullNameC,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้สั่ง',
                  prefixIcon: const Icon(Icons.account_circle),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneC,
                decoration: InputDecoration(
                  labelText: 'เบอร์ติดต่อ',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'กรุณากรอกเบอร์ติดต่อ';
                  }

                  final phone = _formatPhoneNumber(v);

                  if (phone.length != 10 || !phone.startsWith('0')) {
                    return 'เบอร์ไม่ถูกต้อง';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              if (_paymentMethod == 'payment') ...[
                TextFormField(
                  controller: _addressC,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'ที่อยู่จัดส่ง',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: const Icon(Icons.map),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onTap: storeId == null
                      ? null
                      : () async {
                          await _selectLocation(storeId);
                        },
                  validator: (_) {
                    if (_lat == null || _lng == null) {
                      return 'กรุณาเลือกตำแหน่งจัดส่ง';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _descriptionC,
                decoration: InputDecoration(
                  labelText: 'รายละเอียดเพิ่มเติม',
                  prefixIcon: const Icon(Icons.note_alt),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'รูปแบบการรับสินค้า',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              _DeliveryOption(
                title: 'จัดส่งถึงบ้าน',
                subtitle: 'เลือกตำแหน่งจัดส่ง',
                icon: Icons.delivery_dining,
                value: 'payment',
                groupValue: _paymentMethod,
                onChanged: (v) async {
                  setState(() {
                    _paymentMethod = v!;
                  });

                  if (storeId != null && _lat != null && _lng != null) {
                    await _calculateDeliveryFee(storeId);
                  }
                },
              ),

              const SizedBox(height: 8),

              _DeliveryOption(
                title: 'รับอาหารที่ร้าน',
                subtitle: 'ไปรับสินค้าด้วยตัวเองที่ร้าน',
                icon: Icons.storefront,
                value: 'pickup',
                groupValue: _paymentMethod,
                onChanged: (v) {
                  setState(() {
                    _paymentMethod = v!;
                    _lat = null;
                    _lng = null;
                    _addressC.clear();
                    _distanceKm = 0;
                    _deliveryFee = 0;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    double subTotal,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool multipleStores,
    String? storeId,
  ) {
    final bool isDelivery = _paymentMethod == 'payment';
    final double grandTotal = isDelivery ? subTotal + _deliveryFee : subTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ค่าสินค้า',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Text(
                  '${subTotal.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (isDelivery) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ระยะทาง',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  _calculatingFee
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '${_distanceKm.toStringAsFixed(2)} กม.',
                          style: const TextStyle(fontSize: 15),
                        ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ค่าส่ง (กม.ละ 10 บาท)',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  Text(
                    '${_deliveryFee.toStringAsFixed(2)} บาท',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 22),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'รวมทั้งหมด',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
                Text(
                  '${grandTotal.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle),
                label: _sendingOtp || _submittingOrder
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ยืนยันการสั่งสินค้า',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                onPressed: docs.isEmpty ||
                        multipleStores ||
                        storeId == null ||
                        _calculatingFee ||
                        _sendingOtp ||
                        _submittingOrder
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _startOtpBeforeSubmit(docs, subTotal, storeId);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectLocation(String storeId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectLocationPage()),
    );

    if (result != null) {
      setState(() {
        _lat = _toDouble(result['lat']);
        _lng = _toDouble(result['lng']);
        _addressC.text = result['address'] ?? '';
      });

      await _calculateDeliveryFee(storeId);
    }
  }

  Future<void> _submitOrder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    double subTotal,
    String storeId,
    String? verifiedUid,
  ) async {
    final db = FirebaseFirestore.instance;

    final phoneFormatted = _formatPhoneNumber(_phoneC.text.trim());

    final isDelivery = _paymentMethod == 'payment';

    final distanceKm = isDelivery ? _distanceKm : 0.0;
    final deliveryFee = isDelivery ? _deliveryFee : 0.0;
    final grandTotal = subTotal + deliveryFee;

    final Map<String, dynamic> orderData = {
      'userId': verifiedUid,
      'userPhone': loginPhone,
      'fullname': _fullNameC.text.trim(),
      'phone': phoneFormatted,
      'description': _descriptionC.text.trim(),
      'storeId': storeId,
      'status': 'pending',
      'payment': 'pending',

      'otpVerified': true,
      'phoneVerified': phoneFormatted,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),

      'subTotal': subTotal,

      'distanceKm': distanceKm,
      'deliveryFee': deliveryFee,
      'feePerKm': _feePerKm,

      'total': grandTotal,
      'grandTotal': grandTotal,

      'createdAt': FieldValue.serverTimestamp(),
    };

    if (isDelivery) {
      orderData['location'] = _addressC.text.trim();
      orderData['lat'] = _lat;
      orderData['lng'] = _lng;
      orderData['riderStatus'] = 'pending';
      orderData['PickUp'] = false;
    } else {
      orderData['location'] = 'รับอาหารที่ร้าน';
      orderData['PickUp'] = true;
      orderData['riderStatus'] = '';
      orderData['lat'] = null;
      orderData['lng'] = null;
    }

    final orderRef = await db.collection('orders').add(orderData);

    final batch = db.batch();

    for (final d in docs) {
      batch.set(orderRef.collection('items').doc(), d.data());
      batch.delete(d.reference);
    }

    await batch.commit();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          orderId: orderRef.id,
          total: grandTotal,
        ),
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.cyan.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.cyan : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? Colors.cyan : Colors.grey.shade300,
              child: Icon(
                icon,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.cyan : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: Colors.cyan,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}