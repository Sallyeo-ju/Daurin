import 'package:flutter/material.dart';
import 'CheckoutPage.dart';
import 'ChatPage.dart';
import 'HistoryPage.dart';

import 'ChatPage.dart';
import 'CheckoutPage.dart';
import 'HistoryPage.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.voucherCode,
    this.cartItems = const [],
    this.userAddress = '',
    this.qrisImageAssetPath = 'assets/images/qris.png',
  });

  final int subtotal;
  final int discount;
  final int total;
  final String? voucherCode;
  final List<Map<String, dynamic>> cartItems;
  final String userAddress;
  final String qrisImageAssetPath;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'COD';

  void _openHistoryPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
  }

  void _openChatPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
  }

  Future<void> _goToCheckout() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          cartItems: widget.cartItems,
          subtotal: widget.subtotal,
          discount: widget.discount,
          total: widget.total,
          voucherCode: widget.voucherCode,
          userAddress: widget.userAddress,
          paymentMethod: _selectedMethod,
          qrisImageAssetPath: widget.qrisImageAssetPath,
          showQris: true,
        ),
      ),
    );

  int get _estimatedDistanceKm {
    if (widget.userAddress.isEmpty) return 10;
    final normalizedAddress = widget.userAddress.toLowerCase();
    final itemLocations = widget.cartItems
        .map((item) => (item['location']?.toString() ?? '').toLowerCase())
        .where((loc) => loc.isNotEmpty)
        .toList();

    if (itemLocations.any((loc) => normalizedAddress.contains(loc))) {
      return 3;
    }

    if (itemLocations.any((loc) {
      final firstPart = loc.split(',').first.trim();
      return firstPart.isNotEmpty && normalizedAddress.contains(firstPart);
    })) {
      return 5;
    }

    if (normalizedAddress.contains('jakarta') ||
        itemLocations.any((loc) => loc.contains('jakarta'))) {
      return 12;
    }

    return 20;
  }

  int get _shippingFee {
    final distanceKm = _estimatedDistanceKm;
    if (distanceKm <= 5) return 10000;
    if (distanceKm <= 12) return 15000;
    if (distanceKm <= 20) return 22000;
    return 30000;
  }

  int get _adminFee {
    final computed = (widget.subtotal * 0.02).round();
    return computed < 5000 ? 5000 : computed;
  }

  int get _totalWithFees => widget.total + _shippingFee + _adminFee;

  void _submitPayment() {
    if (_needsCardInfo) {
      if (_cardNumberController.text.trim().isEmpty ||
          _cardHolderController.text.trim().isEmpty ||
          _expiryController.text.trim().isEmpty ||
          _cvvController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lengkapi data kartu sebelum melanjutkan.')),
        );
        return;
      }
    if (result != null && result['confirmed'] == true) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildSummaryRow(String label, int amount, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          amount < 0 ? '-Rp ${amount.abs()}' : 'Rp $amount',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _openHistoryPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
  }

  void _openChatPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatPage()),
    );
  }

  void _goToCheckout() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          cartItems: widget.cartItems,
          subtotal: widget.subtotal,
          discount: widget.discount,
          total: _totalWithFees,
          adminFee: _adminFee,
          shippingFee: _shippingFee,
          voucherCode: widget.voucherCode,
          userAddress: widget.userAddress,
        ),
      ),
    );

    if (result != null && result['confirmed'] == true) {
      if (!mounted) return;
      _submitPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openChatPage,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade700,
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Builder(builder: (ctx) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + bottom),
                child: Column(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Pembayaran',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow('Subtotal', widget.subtotal),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Diskon voucher', -widget.discount),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Biaya admin', _adminFee),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Ongkir', _shippingFee),
                        const SizedBox(height: 8),
                        Text(
                          'Estimasi jarak: ${_estimatedDistanceKm} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total bayar', _totalWithFees, isBold: true),
                        if (widget.voucherCode != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Voucher: ${widget.voucherCode}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                        const Divider(height: 24),
                        _buildSummaryRow(
                          'Total bayar',
                          widget.total,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _openHistoryPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                    ),
                    child: const Text('Lihat Riwayat Transaksi'),
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 20),
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: ['COD', 'QRIS'].map((method) {
                        final selected = _selectedMethod == method;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(method),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedMethod = method;
                                });
                              },
                              selectedColor: Colors.green.shade100,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.green.shade800
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedMethod == 'QRIS')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: const Text(
                      'QRIS belum ditampilkan di sini. Tekan Lanjut ke Konfirmasi untuk melihat QRIS.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  const Text(
                    'COD dipilih. Kurir akan menerima pembayaran saat barang diterima.',
                    style: TextStyle(color: Colors.black54),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _goToCheckout,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Lanjut ke Checkout'),
                    child: const Text('Lanjut ke Konfirmasi'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _openHistoryPage,
                    child: const Text('Lihat Riwayat Transaksi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
