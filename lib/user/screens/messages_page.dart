import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _green = Color(0xff2E7D32);
const Color _background = Color(0xffF0F2F5);
const Color _text = Color(0xff050505);
const Color _subText = Color(0xff65676B);
const Color _otherBubble = Color(0xffE4E6EB);

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String userId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(userId);

    await chatRef.collection('messages').add({
      'senderId': userId,
      'receiverId': 'admin',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isAutoMessage': false,
    });

    await chatRef.set({
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
      'unreadByAdmin': true,
      'unreadByUser': false,
    }, SetOptions(merge: true));

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _background,
        body: const Center(
          child: Text(
            'Please log in to view messages.',
            style: TextStyle(
              color: _subText,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final userInitial = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _text),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xffE4E6EB),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: _green,
                    size: 23,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xff31A24C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Active now',
                  style: TextStyle(
                    color: _subText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(user.uid)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: _subText),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _green,
                    ),
                  );
                }

                final chatDocs = snapshot.data?.docs ?? [];

                if (chatDocs.isEmpty) {
                  return _EmptyConversation(
                    userInitial: userInitial,
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    16,
                    12,
                    12,
                  ),
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        chatDocs[index].data() as Map<String, dynamic>;

                    final senderId = data['senderId'] ?? '';
                    final text = data['text'] ?? data['message'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;

                    final isUser = senderId == user.uid;

                    return _MessageBubble(
                      text: text,
                      imageUrl: data['imageUrl'] as String?,
                      isUser: isUser,
                      timestamp: timestamp,
                      userInitial: userInitial,
                    );
                  },
                );
              },
            ),
          ),
          _MessageInput(
            controller: _messageController,
            onSend: () => _sendMessage(user.uid),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isUser;
  final Timestamp? timestamp;
  final String userInitial;

  const _MessageBubble({
    required this.text,
    required this.imageUrl,
    required this.isUser,
    required this.timestamp,
    required this.userInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xffE4E6EB),
              child: Icon(
                Icons.support_agent_rounded,
                color: Color(0xff2E7D32),
                size: 16,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * .72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: isUser ? _green : _otherBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 5),
                  bottomRight: Radius.circular(isUser ? 5 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 220,
                            height: 120,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Text(
                      text,
                      style: TextStyle(
                        color: isUser ? Colors.white : _text,
                        fontSize: 15,
                        height: 1.25,
                      ),
                    ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _formatTime(timestamp!),
                      style: TextStyle(
                        color: isUser
                            ? Colors.white.withOpacity(.75)
                            : _subText,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: _green.withOpacity(.12),
              child: Text(
                userInitial,
                style: const TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}

class _EmptyConversation extends StatelessWidget {
  final String userInitial;

  const _EmptyConversation({
    required this.userInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xffE4E6EB),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xff2E7D32),
                  size: 38,
                ),
              ),
              Positioned(
                right: 1,
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xff31A24C),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Admin',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start a conversation',
            style: TextStyle(
              color: _subText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(
          8,
          8,
          8,
          8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Aa',
                  hintStyle: const TextStyle(
                    color: _subText,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: _background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(
                Icons.send_rounded,
                color: _green,
                size: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}