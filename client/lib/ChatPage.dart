import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal chat page used by HomePage. Stores messages per thread in
/// SharedPreferences under key `chat_thread_<threadId>`.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.threadId,
    this.itemId,
    this.itemName,
    this.sellerName,
    this.sellerEmail,
    this.buyerName,
    this.buyerEmail,
    this.draftMode = false,
  });

  final String? threadId;
  final String? itemId;
  final String? itemName;
  final String? sellerName;
  final String? sellerEmail;
  final String? buyerName;
  final String? buyerEmail;
  final bool draftMode;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late String _threadId;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _threadId =
        widget.threadId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_thread_$_threadId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw) as List<dynamic>;
        _messages.clear();
        _messages.addAll(parsed.whereType<Map<String, dynamic>>());
      } catch (_) {
        _messages.clear();
      }
    }
    setState(() {});
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_thread_$_threadId', jsonEncode(_messages));
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final time = TimeOfDay.now().format(context);
    setState(() {
      _messages.add({'text': text, 'isUser': true, 'time': time});
      _messageController.clear();
    });
    _saveMessages();
  }

  Widget _buildBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] == true;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.green.shade100 : Colors.grey.shade200;
    final textColor = Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(message['text'] ?? '', style: TextStyle(color: textColor)),
            const SizedBox(height: 6),
            Text(
              message['time'] ?? '',
              style: TextStyle(
                color: textColor.withAlpha((0.7 * 255).round()),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.itemName ?? widget.sellerName ?? 'Chat';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
                  ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
