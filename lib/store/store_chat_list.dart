import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:finalproject/chat_page.dart';

class StoreChatListPage extends StatelessWidget {
  final String storeId;
  final String storeName;

  const StoreChatListPage({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  String _chatTitle(String chatType) {
    switch (chatType) {
      case 'customer_store':
        return 'ลูกค้า ↔ ร้านค้า';
      case 'rider_store':
        return 'ไรเดอร์ ↔ ร้านค้า';
      case 'customer_rider':
        return 'ลูกค้า ↔ ไรเดอร์';
      default:
        return 'แชท';
    }
  }

  String _formatTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final chatsRef = FirebaseFirestore.instance.collection('chats');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'แชทของร้าน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.cyan,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: chatsRef
            .where('participants', arrayContains: 'store:$storeId')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('เกิดข้อผิดพลาด: ${snap.error}'),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          docs.sort((a, b) {
            final aTime = a.data()['updatedAt'];
            final bTime = b.data()['updatedAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีข้อความ',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data();

              final orderId = (data['orderId'] ?? '').toString();
              final chatType = (data['chatType'] ?? '').toString();
              final lastMessage = (data['lastMessage'] ?? '').toString();
              final customerPhone =
                  (data['customerPhone'] ?? '').toString();
              final customerName =
                  (data['customerName'] ?? '').toString();
              final riderId = (data['riderId'] ?? '').toString();
              final updatedAt = data['updatedAt'];

              final title = _chatTitle(chatType);

              String subtitle = '';

              if (chatType == 'customer_store') {
                subtitle = customerName.isNotEmpty
                    ? 'ลูกค้า: $customerName'
                    : 'ลูกค้า: $customerPhone';
              } else if (chatType == 'rider_store') {
                subtitle = riderId.isNotEmpty
                    ? 'ไรเดอร์: $riderId'
                    : 'ไรเดอร์';
              } else {
                subtitle = 'แชท';
              }

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: chatType == 'customer_store'
                        ? Colors.cyan
                        : Colors.deepPurple,
                    child: Icon(
                      chatType == 'customer_store'
                          ? Icons.person
                          : Icons.delivery_dining,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Text(
                          'Order ID: $orderId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        lastMessage.isEmpty
                            ? 'ยังไม่มีข้อความล่าสุด'
                            : lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _formatTime(updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (orderId.isEmpty || chatType.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ข้อมูลแชทไม่ครบ'),
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
                          chatType: chatType,
                          senderType: 'store',
                          senderId: storeId,
                          senderName: storeName,
                          storeId: storeId,
                          riderId: riderId,
                          customerPhone: customerPhone,
                          customerName: customerName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}