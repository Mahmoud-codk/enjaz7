import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class WhatsAppChatScreen extends StatefulWidget {
  const WhatsAppChatScreen({super.key});

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  Future<void> _sendMessage({String? imageUrl}) async {
    if (_messageController.text.trim().isEmpty && imageUrl == null) return;

    final user = _auth.currentUser;
    final senderId = user?.uid ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
    final senderName = user?.displayName ?? 'مستخدم مجهول';

    try {
      await _firestore.collection('group_chat_messages').add({
        'text': _messageController.text.trim(),
        'imageUrl': imageUrl,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في إرسال الرسالة: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري تحميل الصورة...')),
        );

        final File imageFile = File(image.path);
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final Reference ref = FirebaseStorage.instance.ref('chat_images/$fileName');
        
        await ref.putFile(imageFile);
        final String downloadUrl = await ref.getDownloadURL();
        
        _sendMessage(imageUrl: downloadUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحميل الصورة بنجاح')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الصورة: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدردشة'),
        content: const Text('هل أنت متأكد من حذف جميع رسائل الدردشة؟ هذه العملية لا يمكن التراجع عنها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري حذف الرسائل...')),
      );
      await _deleteAllMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف جميع رسائل الدردشة')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف الدردشة: $e')),
      );
    }
  }

  Future<void> _deleteAllMessages() async {
    final CollectionReference coll = _firestore.collection('group_chat_messages');
    const int batchSize = 500;

    while (true) {
      final snapshot = await coll.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final WriteBatch batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دردشة جماعية'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'حذف الدردشة',
            onPressed: _confirmAndDeleteChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('group_chat_messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'حدث خطأ في تحميل الرسائل',
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الخطأ: ${snapshot.error}',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد رسائل بعد',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        Text(
                          'ابدأ المحادثة الآن!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final currentUserId = user?.uid ?? '';
                    final isMe = data['senderId'] == currentUserId;

                    return _GroupMessageBubble(
                      text: data['text'] ?? '',
                      imageUrl: data['imageUrl'],
                      senderName: data['senderName'] ?? 'مجهول',
                      isMe: isMe,
                      timestamp: data['timestamp'] as Timestamp?,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo, color: Colors.blue),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'اكتب رسالة...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25.0)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final String senderName;
  final bool isMe;
  final Timestamp? timestamp;

  const _GroupMessageBubble({
    required this.text,
    this.imageUrl,
    required this.senderName,
    required this.isMe,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final timeString = timestamp != null
        ? '${timestamp!.toDate().hour}:${timestamp!.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                senderName,
                style: const TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16.0),
                topRight: const Radius.circular(16.0),
                bottomLeft: isMe ? const Radius.circular(16.0) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => _FullScreenImage(imageUrl: imageUrl!),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Text('فشل في تحميل الصورة'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                if (timeString.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 10.0,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator(color: Colors.white);
              },
            ),
          ),
        ),
      ),
    );
  }
}
