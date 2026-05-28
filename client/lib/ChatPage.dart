import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Chat page that uses seller-based threading instead of product-based.
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
  bool _useBackend = false;

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
    setState(() {
      _isLoading = true;
    });

    if (_hasRemoteContext) {
      try {
        final response = await getJsonWithFallback(
          path: '/chat/threads/${Uri.encodeComponent(_threadId)}/messages',
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          final messages = _parseMessages(decoded);
          if (!mounted) return;
          setState(() {
            _messages
              ..clear()
              ..addAll(messages);
            _useBackend = true;
            _isLoading = false;
          });
          if (_messages.isNotEmpty) return;
        }
      } catch (_) {
        // Fall back to local storage below.
      }
    }

    await _loadLocalMessages();
    if (!mounted) return;
    setState(() {
      _useBackend = false;
      _isLoading = false;
    });
  }

  Future<void> _loadLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_thread_$_threadId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw) as List<dynamic>;
        _messages
          ..clear()
          ..addAll(parsed.whereType<Map<String, dynamic>>());
      } catch (_) {
        _messages.clear();
      }
    } else {
      _messages.clear();
    }
  }

  Future<void> _saveLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_thread_$_threadId', jsonEncode(_messages));
  }

  List<Map<String, dynamic>> _parseMessages(dynamic decoded) {
    final items = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          items.add(_normalizeBackendMessage(entry));
        }
      }
    }
    return items;
  }

  Map<String, dynamic> _normalizeBackendMessage(Map<String, dynamic> message) {
    final senderEmail = message['senderEmail']?.toString() ?? '';
    final buyerEmail = widget.buyerEmail?.trim().toLowerCase() ?? '';
    final sellerEmail = widget.sellerEmail?.trim().toLowerCase() ?? '';
    final isUser = buyerEmail.isNotEmpty
        ? senderEmail.trim().toLowerCase() == buyerEmail
        : senderEmail.trim().toLowerCase() != sellerEmail;

    return {
      'text': message['text']?.toString() ?? '',
      'isUser': isUser,
      'time': _formatTime(message['sentAt'] ?? message['createdAt']),
    };
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.isEmpty) return '';
    try {
      final parsed = DateTime.parse(text).toLocal();
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return text;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final time = TimeOfDay.now().format(context);

    final prefs = await SharedPreferences.getInstance();
    final senderName =
        prefs.getString('account_username')?.trim().isNotEmpty == true
            ? prefs.getString('account_username')!.trim()
            : (widget.buyerName?.trim().isNotEmpty == true
                ? widget.buyerName!.trim()
                : (widget.sellerName?.trim().isNotEmpty == true
                    ? widget.sellerName!.trim()
                    : 'User'));
    final senderEmail =
        prefs.getString('account_email')?.trim().isNotEmpty == true
            ? prefs.getString('account_email')!.trim().toLowerCase()
            : (widget.buyerEmail?.trim().isNotEmpty == true
                ? widget.buyerEmail!.trim().toLowerCase()
                : (widget.sellerEmail?.trim().isNotEmpty == true
                    ? widget.sellerEmail!.trim().toLowerCase()
                    : ''));

    setState(() {
      _messages.add({'text': text, 'isUser': true, 'time': time});
      _messageController.clear();
      _isSending = true;
    });

    try {
      if (_useBackend && _hasRemoteContext && senderEmail.isNotEmpty) {
        final response = await postJsonWithFallback(
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

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Gagal mengirim pesan ke server.');
        }

        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['message'] is Map<String, dynamic>) {
          final message = _normalizeBackendMessage(
            decoded['message'] as Map<String, dynamic>,
          );
          if (mounted) {
            setState(() {
              _messages.removeLast();
              _messages.add(message);
            });
          }
        }
      } else {
        await _saveLocalMessages();
      }
    } catch (_) {
      // If backend send fails, keep the local message so the chat still works offline.
      await _saveLocalMessages();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
    final title = widget.sellerUsername ?? widget.sellerName ?? 'Chat';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (_hasRemoteContext)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Text(
                  'Chat dengan penjual ${widget.sellerUsername ?? widget.sellerName ?? ''}'
                      .trim(),
                  style: TextStyle(color: Colors.green.shade800),
                ),
              ),
            ),
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
                      onSubmitted: (_) {
                        if (!_isSending) {
                          _sendMessage();
                        }
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