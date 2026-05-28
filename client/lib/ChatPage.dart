import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.threadId,
    this.sellerId,
    this.sellerUsername,
    this.sellerName,
    this.sellerEmail,
    this.buyerName,
    this.buyerEmail,
    this.draftMode = false,
  });

  final String? threadId;
  final String? sellerId;
  final String? sellerUsername;
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
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _threadId =
        widget.threadId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _hasRemoteContext {
    return !widget.draftMode &&
        (widget.sellerId ?? '').trim().isNotEmpty &&
        (widget.sellerEmail ?? '').trim().isNotEmpty &&
        (widget.buyerEmail ?? '').trim().isNotEmpty;
  }

  Future<void> _loadConversation() async {
    setState(() => _isLoading = true);

    if (_hasRemoteContext) {
      try {
        final response = await getJsonWithFallback(
          path: '/chat/threads/${Uri.encodeComponent(_threadId)}/messages',
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            if (!mounted) return;
            setState(() {
              _messages.clear();
              for (final msg in decoded) {
                if (msg is Map<String, dynamic>) {
                  _messages.add(_normalizeMessage(msg));
                }
              }
              _isLoading = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> msg) {
    final senderEmail = msg['senderEmail']?.toString() ?? '';
    final buyerEmail = widget.buyerEmail?.trim().toLowerCase() ?? '';
    final isUser = senderEmail.trim().toLowerCase() == buyerEmail;

    return {
      'text': msg['text']?.toString() ?? '',
      'isUser': isUser,
      'time': _formatTime(msg['sentAt']),
    };
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    try {
      final parsed = DateTime.parse(value.toString()).toLocal();
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final senderName = prefs.getString('account_username') ?? 'User';
    final senderEmail = prefs.getString('account_email') ?? '';

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': TimeOfDay.now().format(context),
      });
      _messageController.clear();
      _isSending = true;
    });

    try {
      if (_hasRemoteContext && senderEmail.isNotEmpty) {
        await postJsonWithFallback(
          path: '/chat/messages',
          body: jsonEncode({
            'threadId': _threadId,
            'sellerId': widget.sellerId,
            'sellerUsername': widget.sellerUsername,
            'sellerName': widget.sellerName,
            'sellerEmail': widget.sellerEmail,
            'buyerName': widget.buyerName,
            'buyerEmail': widget.buyerEmail,
            'senderName': senderName,
            'senderEmail': senderEmail,
            'text': text,
          }),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.sellerUsername ?? widget.sellerName ?? 'Chat';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isUser = msg['isUser'] == true;
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.green.shade100
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(msg['text'] ?? ''),
                                  const SizedBox(height: 6),
                                  Text(
                                    msg['time'] ?? '',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                      onSubmitted: (_) {
                        if (!_isSending) _sendMessage();
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}