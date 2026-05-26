import 'package:flutter/material.dart';

import 'ChatPage.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(length: 2, child: _HistoryScaffold());
  }
}

class _HistoryScaffold extends StatelessWidget {
  const _HistoryScaffold();

  void _openGeneralChat(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: const TabBarView(
        children: [
          _HistoryList(type: HistoryType.buy),
          _HistoryList(type: HistoryType.sell),
        ],
      ),
    );
  }
}

enum HistoryType { buy, sell }

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.type});

  final HistoryType type;

  static final List<Map<String, String>> _buyHistory = [
    {
      'image': 'https://via.placeholder.com/120',
      'name': 'Kemeja Bekas Premium',
      'status': 'Selesai',
      'date': '20 Mei 2026',
      'price': 'Rp 120.000',
      'detail': '1 pcs, kondisi bagus, dikirim dari Jakarta Selatan.',
      'seller': 'Penjual A',
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
      'seller': 'Anda',
    },
  ];

  List<Map<String, String>> get items =>
      type == HistoryType.buy ? _buyHistory : _sellHistory;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Belum ada riwayat.'));

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
                          _StatusBadge(status: item['status'] ?? ''),
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
