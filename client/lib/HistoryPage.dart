import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ChatPage.dart';
import 'api_client.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final Future<_HistoryData> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistoryData();
  }

  void _openGeneralChat(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
  }

  Future<_HistoryData> _loadHistoryData() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('account_email')?.trim() ?? '';
    if (userEmail.isEmpty) {
      return const _HistoryData(buy: [], sell: []);
    }

    try {
      final response = await getJsonWithFallback(
        path: '/transactions?userEmail=${Uri.encodeComponent(userEmail)}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final transactions = <Map<String, dynamic>>[];
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              transactions.add(entry);
            }
          }
        }

        return _HistoryData(
          buy: transactions.where((entry) {
            final type = entry['type']?.toString().toLowerCase() ?? '';
            return type == 'buy';
          }).toList(),
          sell: transactions.where((entry) {
            final type = entry['type']?.toString().toLowerCase() ?? '';
            return type == 'sell';
          }).toList(),
        );
      }
    } catch (_) {
      // fall through to empty data
    }

    return const _HistoryData(buy: [], sell: []);
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
              onPressed: () => _openGeneralChat(context),
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
        body: FutureBuilder<_HistoryData>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data ?? const _HistoryData(buy: [], sell: []);
            return TabBarView(
              children: [
                _HistoryList(type: HistoryType.buy, items: data.buy),
                _HistoryList(type: HistoryType.sell, items: data.sell),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryData {
  const _HistoryData({required this.buy, required this.sell});

  final List<Map<String, dynamic>> buy;
  final List<Map<String, dynamic>> sell;
}

enum HistoryType { buy, sell }

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.type, required this.items});

  final HistoryType type;
  final List<Map<String, dynamic>> items;

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
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child:
                      item['image'] is String &&
                          (item['image'] as String).isNotEmpty
                      ? Image.network(
                          item['image'].toString(),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                              _historyPlaceholder(type),
                        )
                      : _historyPlaceholder(type),
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
                              item['name']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _StatusBadge(
                            status: item['status']?.toString() ?? '',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['detail']?.toString() ?? '-',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['price']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            item['date']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (type == HistoryType.buy &&
                          item['sellerName']?.toString().isNotEmpty ==
                              true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Seller: ${item['sellerName']}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _historyPlaceholder(HistoryType type) {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        type == HistoryType.buy
            ? Icons.shopping_bag_outlined
            : Icons.storefront,
        color: Colors.grey.shade500,
      ),
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
        color: color.withAlpha((0.15 * 255).round()),
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
