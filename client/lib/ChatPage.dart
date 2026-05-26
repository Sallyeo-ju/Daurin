import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String? initialRoomId;
  final String? initialRoomName;

  const ChatPage({super.key, this.initialRoomId, this.initialRoomName});
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentRoomId;
  String? _currentRoomName;
  List<Map<String, String>> _rooms = []; // {id, name}

  @override
  void dispose() {
  io.Socket? _socket;
  List<_ChatThreadSummary> _threads = <_ChatThreadSummary>[];
  List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _loadingInbox = true;
  bool _loadingThread = true;
  bool _sending = false;
  String? _accountName;
  String? _accountEmail;
  String? _activeThreadId;
  String? _activeItemId;
  String? _activeItemName;
  String? _activeSellerName;
  String? _activeSellerEmail;
  String? _activeBuyerName;
  String? _activeBuyerEmail;
  String _statusText = 'Menghubungkan...';

  bool get _isInbox => widget.threadId == null;

  bool get _isDraftRoom => widget.draftMode;

  String? get _displayName => _activeSellerName ?? widget.sellerName ?? 'Chat';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }
    final now = TimeOfDay.now();
    final timeStr = now.format(context);

    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'time': timeStr,
      });
      _messageController.clear();
    });
    _saveMessages();
  }

  Future<void> _saveMessages() async {
    if (_currentRoomId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_room_$_currentRoomId', jsonEncode(_messages));
  }

  Future<void> _loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_rooms');
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw) as List<dynamic>;
        _rooms = parsed
            .whereType<Map<String, dynamic>>()
            .map((m) => {
                  'id': (m['id'] ?? '').toString(),
                  'name': (m['name'] ?? '').toString()
                })
            .toList();
      } catch (_) {
        _rooms = [];
      }
    }
  }

  Future<void> _loadMessagesForCurrentRoom() async {
    if (_currentRoomId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_room_$_currentRoomId');
    if (raw != null && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw) as List<dynamic>;
        setState(() {
          _messages.clear();
          _messages.addAll(parsed
              .whereType<Map<String, dynamic>>()
              .map((m) => {
                    'text': m['text']?.toString() ?? '',
                    'isUser': m['isUser'] == true,
                    'time': m['time']?.toString() ?? ''
                  }));
        });
      } catch (_) {
        setState(() => _messages.clear());
      }
    } else {
      setState(() => _messages.clear());
    }
  }

  Future<void> _addRoom() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Room Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Room ID'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Room'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final id = idController.text.trim();
              final name = nameController.text.trim().isEmpty
                  ? id
                  : nameController.text.trim();
              if (id.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              _rooms.add({'id': id, 'name': name});
              await prefs.setString('chat_rooms', jsonEncode(_rooms));
              setState(() {
                _currentRoomId = id;
                _currentRoomName = name;
              });
              await _saveMessages();
              navigator.pop();
              await _loadMessagesForCurrentRoom();
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.green.shade100 : Colors.blue.shade50;
    final textColor = isUser ? Colors.green.shade900 : Colors.blue.shade900;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['text'] as String,
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              message['time'] as String,
              style: TextStyle(
                color: textColor.withOpacity(0.7),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRoomName ?? 'Chat'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addRoom,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final room = _rooms.firstWhere((r) => r['id'] == value);
              setState(() {
                _currentRoomId = room['id'];
                _currentRoomName = room['name'];
              });
              await _loadMessagesForCurrentRoom();
            },
            itemBuilder: (ctx) => _rooms
                .map((r) => PopupMenuItem(value: r['id'], child: Text(r['name'] ?? r['id']!)))
                .toList(),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentRoomId == null
                ? Center(
                    child: Text(
                      'Pilih atau buat room untuk mulai chat',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final accountName = prefs.getString('account_username')?.trim();
    final accountEmail = prefs.getString('account_email')?.trim();

    if (!mounted) {
      return;
    }

    setState(() {
      _accountName = accountName?.isNotEmpty == true ? accountName : null;
      _accountEmail = accountEmail?.isNotEmpty == true ? accountEmail : null;
    });

    if (_isInbox) {
      await _loadInbox();
      _connectSocket();
      return;
    }

    if (_isDraftRoom) {
      _setupDraftRoom();
      return;
    }

    await _loadThreadFromContext();
    _connectSocket();
  }

  void _setupDraftRoom() {
    final buyerName = _resolveBuyerName();
    final buyerEmail = _resolveBuyerEmail();
    final itemId = widget.itemId?.trim();

    if (buyerName == null || buyerEmail == null || itemId == null || itemId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingThread = false;
        _statusText = 'Data akun atau item belum lengkap.';
      });
      return;
    }

    final draftThreadId = widget.threadId?.trim().isNotEmpty == true
        ? widget.threadId!.trim()
        : 'draft__${itemId.toLowerCase()}__${buyerEmail.toLowerCase()}';

    _applyThreadIdentity(
      threadId: draftThreadId,
      itemId: itemId,
      itemName: widget.itemName?.trim(),
      sellerName: widget.sellerName?.trim().isNotEmpty == true
          ? widget.sellerName!.trim()
          : widget.itemName?.trim().isNotEmpty == true
              ? widget.itemName!.trim()
              : 'Chat baru',
      sellerEmail: buyerEmail,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _messages = <_ChatMessage>[];
      _loadingThread = false;
      _statusText = 'Room chat baru';
    });
  }

  void _connectSocket() {
    if (_socket != null) {
      return;
    }

    final socket = io.io(
      primaryApiHost(),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    socket.onConnect((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Terkoneksi';
      });

      if (!_isInbox && _activeThreadId != null && _threadPayload != null) {
        socket.emit('join_thread', _threadPayload);
      }
    });

    socket.onConnectError((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Socket gagal tersambung';
      });
    });

    socket.onDisconnect((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Terputus, mencoba sambung ulang';
      });
    });

    socket.on('thread_snapshot', (data) {
      final snapshot = _parseThreadSnapshot(data);
      if (!mounted) {
        return;
      }

      setState(() {
        if (snapshot.thread != null) {
          _applyThreadSummary(snapshot.thread!);
        }
        _messages = snapshot.messages;
        _loadingThread = false;
        _statusText = 'Pesan terbaru';
      });
    });

    socket.on('message_received', (data) {
      final received = _parseIncomingMessage(data);
      if (received == null || !mounted) {
        return;
      }

      setState(() {
        final duplicateIndex = _messages.indexWhere(
          (message) => message.isSameAs(received),
        );
        if (duplicateIndex >= 0) {
          _messages[duplicateIndex] = received;
        } else {
          _messages.add(received);
        }
        _loadingThread = false;
      });
    });

    socket.connect();
    _socket = socket;
  }

  Future<void> _loadInbox() async {
    if (_accountEmail == null || _accountEmail!.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _threads = <_ChatThreadSummary>[];
        _loadingInbox = false;
        _statusText = 'Login dulu untuk membuka inbox.';
      });
      return;
    }

    try {
      final response = await getJsonWithFallback(
        path: '/chat/threads?userEmail=${Uri.encodeComponent(_accountEmail!)}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractMessage(response.body));
      }

      final decoded = jsonDecode(response.body);
      final threads = decoded is List
          ? decoded
                .whereType<Map>()
                .map(
                  (item) =>
                      _ChatThreadSummary.fromJson(item.cast<String, dynamic>()),
                )
                .toList()
          : <_ChatThreadSummary>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _threads = threads;
        _loadingInbox = false;
        _statusText = threads.isEmpty ? 'Belum ada chat' : 'Inbox siap';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _threads = <_ChatThreadSummary>[];
        _loadingInbox = false;
        _statusText = 'Gagal memuat chat. ${error.toString()}';
      });
    }
  }

  Future<void> _loadThreadFromContext() async {
    final buyerName = _resolveBuyerName();
    final buyerEmail = _resolveBuyerEmail();
    final sellerName = widget.sellerName?.trim();
    final sellerEmail = widget.sellerEmail?.trim();
    final itemId = widget.itemId?.trim();

    if (buyerName == null || buyerEmail == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingThread = false;
        _statusText = 'Data akun belum lengkap.';
      });
      return;
    }

    if (sellerName == null ||
        sellerName.isEmpty ||
        sellerEmail == null ||
        sellerEmail.isEmpty ||
        itemId == null ||
        itemId.isEmpty) {
      if (!mounted) {
        return;
      }

      _setupDraftRoom();
      return;
    }

    final resolvedThreadId = widget.threadId?.trim().isNotEmpty == true
        ? widget.threadId!.trim()
        : _buildThreadId(itemId, sellerEmail, buyerEmail);

    _applyThreadIdentity(
      threadId: resolvedThreadId,
      itemId: itemId,
      itemName: widget.itemName?.trim(),
      sellerName: sellerName,
      sellerEmail: sellerEmail,
      buyerName: buyerName,
      buyerEmail: buyerEmail,
    );

    await _loadMessagesFromServer(resolvedThreadId);

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingThread = false;
      _statusText = 'Siap chat';
    });
  }

  Future<void> _loadMessagesFromServer(String threadId) async {
    try {
      final response = await getJsonWithFallback(
        path: '/chat/threads/$threadId/messages',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractMessage(response.body));
      }

      final decoded = jsonDecode(response.body);
      final messages = decoded is List
          ? decoded
                .whereType<Map>()
                .map(
                  (item) => _ChatMessage.fromJson(item.cast<String, dynamic>()),
                )
                .toList()
          : <_ChatMessage>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages = <_ChatMessage>[];
        _statusText = 'Gagal memuat pesan. ${error.toString()}';
      });
    }
  }

  void _applyThreadIdentity({
    required String threadId,
    required String itemId,
    required String? itemName,
    required String sellerName,
    required String sellerEmail,
    required String buyerName,
    required String buyerEmail,
  }) {
    _activeThreadId = threadId;
    _activeItemId = itemId;
    _activeItemName = itemName;
    _activeSellerName = sellerName;
    _activeSellerEmail = sellerEmail;
    _activeBuyerName = buyerName;
    _activeBuyerEmail = buyerEmail;
  }

  void _openThreadFromInbox(_ChatThreadSummary thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: thread.threadId,
          itemId: thread.itemId,
          itemName: thread.itemName,
          sellerName: thread.sellerName,
          sellerEmail: thread.sellerEmail,
          buyerName: thread.buyerName,
          buyerEmail: thread.buyerEmail,
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeThreadId == null) {
      return;
    }

    final senderName = _resolveBuyerName();
    final senderEmail = _resolveBuyerEmail();
    if (senderName == null || senderEmail == null) {
      _showMessage('Data akun belum lengkap untuk mengirim chat.');
      return;
    }

    final payload = <String, dynamic>{
      'threadId': _activeThreadId,
      'itemId': _activeItemId,
      'itemName': _activeItemName,
      'sellerName': _activeSellerName,
      'sellerEmail': _activeSellerEmail,
      'buyerName': _activeBuyerName ?? senderName,
      'buyerEmail': _activeBuyerEmail ?? senderEmail,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'text': text,
    };

    setState(() {
      _sending = true;
      _statusText = 'Mengirim pesan...';
    });

    _messageController.clear();

    try {
      if (_isDraftRoom) {
        final localMessage = _ChatMessage(
          threadId: _activeThreadId!,
          itemId: _activeItemId ?? '',
          senderEmail: senderEmail,
          senderName: senderName,
          receiverEmail: _activeSellerEmail ?? '',
          receiverName: _activeSellerName ?? 'Seller',
          text: text,
          sentAt: DateTime.now(),
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _messages = [..._messages, localMessage];
          _sending = false;
          _statusText = 'Room chat baru';
        });
        return;
      }

      if (_socket?.connected == true) {
        _socket!.emit('send_message', payload);
      } else {
        final response = await postJsonWithFallback(
          path: '/chat/messages',
          body: jsonEncode(payload),
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(_extractMessage(response.body));
        }

        await _loadMessagesFromServer(_activeThreadId!);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _statusText = 'Pesan terkirim';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _statusText = 'Gagal mengirim chat';
      });
      _showMessage('Tidak bisa mengirim chat. ${error.toString()}');
    }
  }

  Future<void> _refreshCurrentView() async {
    if (_isInbox) {
      await _loadInbox();
      return;
    }

    if (_activeThreadId != null) {
      await _loadMessagesFromServer(_activeThreadId!);
    }
  }

  String? _resolveBuyerName() {
    final fromWidget = widget.buyerName?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget;
    }

    final fromAccount = _accountName?.trim();
    if (fromAccount != null && fromAccount.isNotEmpty) {
      return fromAccount;
    }

    return null;
  }

  String? _resolveBuyerEmail() {
    final fromWidget = widget.buyerEmail?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget.toLowerCase();
    }

    final fromAccount = _accountEmail?.trim();
    if (fromAccount != null && fromAccount.isNotEmpty) {
      return fromAccount.toLowerCase();
    }

    return null;
  }

  String _buildThreadId(String itemId, String sellerEmail, String buyerEmail) {
    return '${itemId.trim().toLowerCase()}__${sellerEmail.trim().toLowerCase()}__${buyerEmail.trim().toLowerCase()}';
  }

  Map<String, dynamic>? get _threadPayload {
    if (_activeThreadId == null ||
        _activeItemId == null ||
        _activeSellerName == null ||
        _activeSellerEmail == null ||
        _activeBuyerName == null ||
        _activeBuyerEmail == null) {
      return null;
    }

    return <String, dynamic>{
      'threadId': _activeThreadId,
      'itemId': _activeItemId,
      'itemName': _activeItemName,
      'sellerName': _activeSellerName,
      'sellerEmail': _activeSellerEmail,
      'buyerName': _activeBuyerName,
      'buyerEmail': _activeBuyerEmail,
    };
  }

  _ThreadSnapshot _parseThreadSnapshot(dynamic data) {
    if (data is! Map) {
      return const _ThreadSnapshot(messages: <_ChatMessage>[]);
    }

    final map = data.cast<String, dynamic>();
    final threadData = map['thread'];
    final messagesData = map['messages'];

    final thread = threadData is Map<String, dynamic>
        ? _ChatThreadSummary.fromJson(threadData)
        : null;

    final messages = messagesData is List
        ? messagesData
              .whereType<Map>()
              .map(
                (item) => _ChatMessage.fromJson(item.cast<String, dynamic>()),
              )
              .toList()
        : <_ChatMessage>[];

    return _ThreadSnapshot(thread: thread, messages: messages);
  }

  _ChatMessage? _parseIncomingMessage(dynamic data) {
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final message = map['message'];
      if (message is Map<String, dynamic>) {
        return _ChatMessage.fromJson(message);
      }
      return _ChatMessage.fromJson(map);
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyThreadSummary(_ChatThreadSummary thread) {
    _activeThreadId = thread.threadId;
    _activeItemId = thread.itemId;
    _activeItemName = thread.itemName;
    _activeSellerName = thread.sellerName;
    _activeSellerEmail = thread.sellerEmail;
    _activeBuyerName = thread.buyerName;
    _activeBuyerEmail = thread.buyerEmail;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isInbox ? 'Chat' : 'Chat dengan ${_displayName ?? 'Seller'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Inbox',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: _isInbox
                ? null
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ChatPage()),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCurrentView,
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _isInbox ? _buildInbox() : _buildThreadView(),
        ),
      ),
    );
  }

  Widget _buildInbox() {
    if (_loadingInbox) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshCurrentView,
      child: _threads.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 56,
                        color: Colors.blueGrey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada chat. Buka item dari homepage lalu tekan Chat Seller.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final thread = _threads[index];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.black12),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.store, color: Colors.blue),
                    ),
                    title: Text(thread.sellerName),
                    subtitle: Text(
                      thread.itemName.isNotEmpty
                          ? '${thread.itemName}\n${thread.lastMessage}'
                          : thread.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: thread.itemName.isNotEmpty,
                    trailing: Text(
                      _formatTime(thread.lastMessageAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    onTap: () => _openThreadFromInbox(thread),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildThreadView() {
    if (_loadingThread) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeSellerName ?? widget.sellerName ?? 'Seller',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _activeItemName ?? widget.itemName ?? 'Item',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _statusText,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
              if (_isDraftRoom) ...[
                const SizedBox(height: 6),
                Text(
                  'Room baru akan dipakai sampai data seller terhubung.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCurrentView,
            child: _messages.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Icon(
                        Icons.forum_outlined,
                        size: 58,
                        color: Colors.blueGrey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada pesan. Kirim pesan pertama dari sini.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildBubble(_messages[index]);
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan untuk seller...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue.shade700,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _currentRoomId == null ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentRoomId = widget.initialRoomId;
    _currentRoomName = widget.initialRoomName;
    _loadRooms().then((_) async {
      if (_currentRoomId != null) {
        await _loadMessagesForCurrentRoom();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan...',
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  backgroundColor: Colors.blue.shade700,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(_ChatMessage message) {
    final buyerEmail = _resolveBuyerEmail() ?? '';
    final isMine =
        message.senderEmail.toLowerCase() == buyerEmail.toLowerCase();
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = isMine
        ? Colors.green.shade100
        : Colors.blue.shade50;
    final textColor = isMine ? Colors.green.shade900 : Colors.blue.shade900;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: textColor)),
            const SizedBox(height: 8),
            Text(
              _formatTime(message.sentAt),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _extractMessage(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return apiConnectionHint();
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to the raw body.
    }

    return trimmed;
  }
}

class _ThreadSnapshot {
  const _ThreadSnapshot({this.thread, required this.messages});

  final _ChatThreadSummary? thread;
  final List<_ChatMessage> messages;
}

class _ChatThreadSummary {
  _ChatThreadSummary({
    required this.threadId,
    required this.itemId,
    required this.itemName,
    required this.sellerName,
    required this.sellerEmail,
    required this.buyerName,
    required this.buyerEmail,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  final String threadId;
  final String itemId;
  final String itemName;
  final String sellerName;
  final String sellerEmail;
  final String buyerName;
  final String buyerEmail;
  final String lastMessage;
  final DateTime lastMessageAt;

  factory _ChatThreadSummary.fromJson(Map<String, dynamic> json) {
    return _ChatThreadSummary(
      threadId: json['threadId']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? 'Seller',
      sellerEmail: json['sellerEmail']?.toString() ?? '',
      buyerName: json['buyerName']?.toString() ?? 'Buyer',
      buyerEmail: json['buyerEmail']?.toString() ?? '',
      lastMessage: json['lastMessage']?.toString() ?? 'Mulai chat',
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.threadId,
    required this.itemId,
    required this.senderEmail,
    required this.senderName,
    required this.receiverEmail,
    required this.receiverName,
    required this.text,
    required this.sentAt,
  });

  final String threadId;
  final String itemId;
  final String senderEmail;
  final String senderName;
  final String receiverEmail;
  final String receiverName;
  final String text;
  final DateTime sentAt;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      threadId: json['threadId']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      senderEmail: json['senderEmail']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      receiverEmail: json['receiverEmail']?.toString() ?? '',
      receiverName: json['receiverName']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      sentAt:
          DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool isSameAs(_ChatMessage other) {
    return threadId == other.threadId &&
        senderEmail == other.senderEmail &&
        text == other.text &&
        sentAt.toIso8601String() == other.sentAt.toIso8601String();
  }
}
