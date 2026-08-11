import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int groupId;
  final String orderNumber;
  final String userName;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.orderNumber,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final msgs = await ApiService.getGroupMessages(widget.groupId);
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await ApiService.sendChatMessage(widget.groupId, 'TEXT', text);
    _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grup Pelayanan ${widget.orderNumber}', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Text('Umat, Romo, Pengurus Lingkungan, Koordinator', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMessages,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isSystem = msg.messageType == 'SYSTEM_EVENT';
                      final bool isMe = msg.senderName == widget.userName;

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5C4),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                            ),
                            child: Text(
                              msg.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe && msg.senderName != null)
                                Text(
                                  msg.senderName!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF075E54)),
                                ),
                              const SizedBox(height: 2),
                              Text(msg.message, style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    msg.createdAt.length >= 16 ? msg.createdAt.substring(11, 16) : '',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.done_all_rounded, size: 14, color: Colors.blue),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan chat...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  backgroundColor: const Color(0xFF075E54),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
