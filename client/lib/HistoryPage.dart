import 'package:flutter/material.dart';

import 'ChatPage.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  static final List<Map<String, String>> _buyHistory = [
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Kemeja Bekas Premium',
      'status': 'Selesai',
      'date': '20 Mei 2026',
      'price': 'Rp 120.000',
      'detail': '1 pcs, kondisi bagus, dikirim dari Jakarta Selatan.',
    },
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Botol Kaca Bekas',
      'status': 'Dalam Proses',
      'date': '22 Mei 2026',
      'price': 'Rp 45.000',
      'detail': '2 pcs, untuk pengumpulan recycle.',
    },
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Tas Jeans Second',
      'status': 'Diterima',
      'date': '18 Mei 2026',
      'price': 'Rp 85.000',
      'detail': '1 pcs, pick up oleh seller.',
    },
  ];

  static final List<Map<String, String>> _sellHistory = [
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Kaleng Minuman',
      'status': 'Dijual',
      'date': '23 Mei 2026',
      'price': 'Rp 5.000 / pcs',
      'detail': 'Stok 15 pcs, kondisi bersih.',
    },
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Alas Plastik Bekas',
      'status': 'Terkirim',
      'date': '19 Mei 2026',
      'price': 'Rp 30.000',
      'detail': '1 set, sudah dikemas aman.',
    },
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Pakaian Vintage',
      'status': 'Selesai',
      'date': '15 Mei 2026',
      'price': 'Rp 150.000',
      'detail': '3 pcs, kualitas bagus.',
    },
  ];

  Widget _buildStatusBadge(String status) {
    final color = status == 'Selesai' || status == 'Diterima'
        ? Colors.green
        : status == 'Dalam Proses' || status == 'Dijual'
            ? Colors.blue
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, String> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                item['image']!,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _buildStatusBadge(item['status']!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['detail']!,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        item['price']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item['date']!,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<Map<String, String>> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildHistoryCard(context, items[index]);
      },
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'ChatPage.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<_HistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<_HistoryItem>> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final accountEmail = prefs.getString('account_email')?.trim() ?? '';
    if (accountEmail.isEmpty) {
      return <_HistoryItem>[];
    }

    final response = await getJsonWithFallback(
      path: '/transactions?userEmail=${Uri.encodeComponent(accountEmail)}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractMessage(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return <_HistoryItem>[];
    }

    return decoded
        .whereType<Map>()
        .map((entry) => _HistoryItem.fromJson(entry.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
    await _historyFuture;
  }

  String _extractMessage(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return apiConnectionHint();
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Use the raw response body below.
    }

    return trimmed;
  }

  void _openGeneralChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
  }

  void _openSellerChat(_HistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(threadId: item.threadId, sellerName: item.sellerName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Transaksi'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _openGeneralChat,
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat',
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Buy History'),
              Tab(text: 'Sell History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HistoryTab(type: HistoryType.buy),
            _HistoryTab(type: HistoryType.sell),
          ],
        ),
      ),
    );
  }
}

enum HistoryType { buy, sell }

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.type});

  final HistoryType type;

  List<Map<String, String>> get items => type == HistoryType.buy
      ? HistoryPage._buyHistory
      : HistoryPage._sellHistory;

  @override
  Widget build(BuildContext context) {
    return items.isEmpty
        ? const Center(child: Text('Belum ada riwayat.'))
        : ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item['image']!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (item['status'] == 'Selesai' ||
                                            item['status'] == 'Diterima')
                                        ? Colors.green.withOpacity(0.15)
                                        : item['status'] == 'Dalam Proses' ||
                                                item['status'] == 'Dijual'
                                            ? Colors.blue.withOpacity(0.15)
                                            : Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    item['status']!,
                                    style: TextStyle(
                                      color: (item['status'] == 'Selesai' ||
                                              item['status'] == 'Diterima')
                                          ? Colors.green.shade700
                                          : item['status'] == 'Dalam Proses' ||
                                                  item['status'] == 'Dijual'
                                              ? Colors.blue.shade700
                                              : Colors.orange.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['detail']!,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['price']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item['date']!,
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        body: FutureBuilder<List<_HistoryItem>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? <_HistoryItem>[];
            final buyItems = items.where((item) => item.type == 'buy').toList();
            final sellItems = items
                .where((item) => item.type == 'sell')
                .toList();

            return RefreshIndicator(
              onRefresh: _refresh,
              child: TabBarView(
                children: [
                  _HistoryList(items: buyItems, onChatSeller: _openSellerChat),
                  _HistoryList(items: sellItems, onChatSeller: _openSellerChat),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items, required this.onChatSeller});

  final List<_HistoryItem> items;
  final ValueChanged<_HistoryItem> onChatSeller;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Belum ada riwayat.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    item.image,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 88,
                        height: 88,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _StatusBadge(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.detail,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => onChatSeller(item),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Chat Seller'),
                              ),
                            ),
                          ),
                          Text(
                            item.date,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.price,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Seller: ${item.sellerName}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Selesai' || status == 'Diterima'
        ? Colors.green
        : status == 'Dalam Proses' || status == 'Dijual'
        ? Colors.blue
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HistoryItem {
  _HistoryItem({
    required this.image,
    required this.name,
    required this.status,
    required this.date,
    required this.price,
    required this.detail,
    required this.type,
    required this.sellerName,
    required this.threadId,
  });

  final String image;
  final String name;
  final String status;
  final String date;
  final String price;
  final String detail;
  final String type;
  final String sellerName;
  final String threadId;

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    return _HistoryItem(
      image: json['image']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pesanan',
      status: json['status']?.toString() ?? 'Dalam Proses',
      date: json['date']?.toString() ?? '-',
      price: json['price']?.toString() ?? 'Rp 0',
      detail: json['detail']?.toString() ?? '-',
      type: json['type']?.toString() ?? 'buy',
      sellerName: json['sellerName']?.toString() ?? '',
      threadId: json['threadId']?.toString() ?? '',
    );
  }
}
