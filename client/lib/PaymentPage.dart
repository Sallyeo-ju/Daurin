import 'package:flutter/material.dart';

import 'CheckoutPage.dart';
import 'ChatPage.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({
    super.key,
    required this.subtotal,
    required this.adminFee,
    required this.shippingFee,
    required this.discount,
    required this.total,
    this.voucherCode,
    this.cartItems = const [],
    this.userAddress = '',
    this.qrisImageAssetPath = 'assets/images/qris.png',
  });

  final int subtotal;
  final int adminFee;
  final int shippingFee;
  final int discount;
  final int total;
  final String? voucherCode;
  final List<Map<String, dynamic>> cartItems;
  final String userAddress;
  final String qrisImageAssetPath;

  // History page navigation removed (unused) to avoid analyzer warnings.

  void _openChatPage(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
  }

  Future<void> _goToCheckout(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          cartItems: cartItems,
          subtotal: subtotal,
          adminFee: adminFee,
          shippingFee: shippingFee,
          discount: discount,
          total: total,
          voucherCode: voucherCode,
          userAddress: userAddress,
          paymentMethod: 'COD',
          qrisImageAssetPath: qrisImageAssetPath,
          showQris: false,
        ),
      ),
    );

    if (result != null && result['confirmed'] == true) {
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalWithFees = total + shippingFee + adminFee;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _openChatPage(context),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow('Subtotal', subtotal),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Biaya Admin', adminFee),
                      _buildSummaryRow('Ongkos Kirim', shippingFee),
                      if (discount != 0) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Diskon', -discount),
                      ],
                      const Divider(height: 24),
                      _buildSummaryRow('Total', totalWithFees, bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _goToCheckout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: Text('Lanjut ke Konfirmasi')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            amount < 0 ? '-Rp ${amount.abs()}' : 'Rp $amount',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
