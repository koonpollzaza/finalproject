import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String orderId;
  final String chatType;

  final String senderType; // customer / store / rider
  final String senderId;
  final String senderName;

  final String? storeId;
  final String? riderId;
  final String? customerPhone;
  final String? customerName;

  const ChatPage({
    super.key,
    required this.orderId,
    required this.chatType,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    this.storeId,
    this.riderId,
    this.customerPhone,
    this.customerName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgC = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _sending = false;
  bool _sendingImage = false;

  String get chatId => '${widget.orderId}_${widget.chatType}';

  DocumentReference<Map<String, dynamic>> get chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(chatId);

  CollectionReference<Map<String, dynamic>> get messagesRef =>
      chatRef.collection('messages');

  @override
  void initState() {
    super.initState();
    _createChatIfNeeded();
  }

  @override
  void dispose() {
    _msgC.dispose();
    super.dispose();
  }

  Future<void> _createChatIfNeeded() async {
    await chatRef.set({
      'orderId': widget.orderId,
      'chatType': widget.chatType,
      'storeId': widget.storeId,
      'riderId': widget.riderId,
      'customerPhone': widget.customerPhone,
      'customerName': widget.customerName,
      'participants': _buildParticipants(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<String> _buildParticipants() {
    final list = <String>[];

    if ((widget.customerPhone ?? '').isNotEmpty) {
      list.add('customer:${widget.customerPhone}');
    }

    if ((widget.storeId ?? '').isNotEmpty) {
      list.add('store:${widget.storeId}');
    }

    if ((widget.riderId ?? '').isNotEmpty) {
      list.add('rider:${widget.riderId}');
    }

    return list;
  }

  Future<void> _sendMessage() async {
    final text = _msgC.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await messagesRef.add({
        'type': 'text',
        'senderType': widget.senderType,
        'senderId': widget.senderId,
        'senderName': widget.senderName,
        'text': text,
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await chatRef.set({
        'lastMessage': text,
        'lastMessageType': 'text',
        'lastSenderType': widget.senderType,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _msgC.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งข้อความไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sendingImage) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked == null) return;

      setState(() => _sendingImage = true);

      final file = File(picked.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child(fileName);

      await ref.putFile(file);

      final imageUrl = await ref.getDownloadURL();

      await messagesRef.add({
        'type': 'image',
        'senderType': widget.senderType,
        'senderId': widget.senderId,
        'senderName': widget.senderName,
        'text': '',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await chatRef.set({
        'lastMessage': 'ส่งรูปภาพ',
        'lastMessageType': 'image',
        'lastSenderType': widget.senderType,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งรูปไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingImage = false);
      }
    }
  }

  String _title() {
    switch (widget.chatType) {
      case 'customer_store':
        return 'ลูกค้า ↔ ร้านค้า';
      case 'customer_rider':
        return 'ลูกค้า ↔ ไรเดอร์';
      case 'rider_store':
        return 'ไรเดอร์ ↔ ร้านค้า';
      default:
        return 'แชท';
    }
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return '';
  }

  Widget _buildOrderHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.cyan.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.cyan.shade100),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Order ID: ${widget.orderId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'โหลดรูปไม่สำเร็จ',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required Map<String, dynamic> data,
    required bool isMe,
  }) {
    final senderType = (data['senderType'] ?? '').toString();
    final senderName = (data['senderName'] ?? '').toString();
    final text = (data['text'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final type = (data['type'] ?? 'text').toString();
    final createdAt = data['createdAt'];

    final hasImage = type == 'image' && imageUrl.isNotEmpty;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.cyan : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                senderName.isEmpty ? senderType : senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),

            if (!isMe) const SizedBox(height: 4),

            if (hasImage)
              GestureDetector(
                onTap: () => _openImage(imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 210,
                    height: 210,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return Container(
                        width: 210,
                        height: 210,
                        alignment: Alignment.center,
                        color: Colors.grey.shade200,
                        child: const CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (_, __, ___) {
                      return Container(
                        width: 210,
                        height: 140,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('โหลดรูปไม่สำเร็จ'),
                      );
                    },
                  ),
                ),
              )
            else
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),

            const SizedBox(height: 4),

            Text(
              _formatTime(createdAt),
              style: TextStyle(
                color: isMe ? Colors.white.withOpacity(0.85) : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: Colors.white,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: IconButton(
                icon: _sendingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image, color: Colors.cyan),
                onPressed: _sendingImage ? null : _pickAndSendImage,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: TextField(
                controller: _msgC,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            CircleAvatar(
              backgroundColor: Colors.cyan,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Order: ${widget.orderId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildOrderHeader(),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snap.error}'),
                  );
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีข้อความ'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data();

                    final senderType = (data['senderType'] ?? '').toString();
                    final senderId = (data['senderId'] ?? '').toString();

                    final isMe = senderType == widget.senderType &&
                        senderId == widget.senderId;

                    return _buildMessageBubble(
                      data: data,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),

          _buildInputBar(),
        ],
      ),
    );
  }
}