import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ChatPage.dart';
import 'CheckoutPage.dart';

class PaymentPage extends StatefulWidget {
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

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedPaymentMethod = 'COD';

  Future<void> _openChatPage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final buyerName = prefs.getString('account_username')?.trim() ?? '';
    final buyerEmail = prefs.getString('account_email')?.trim() ?? '';
    final firstItem = widget.cartItems.isNotEmpty
        ? widget.cartItems.first
        : null;
    final sellerName = firstItem?['sellerName']?.toString().trim() ?? '';
    final sellerEmail = firstItem?['sellerEmail']?.toString().trim() ?? '';
    final itemId = firstItem?['itemId']?.toString().trim() ?? '';
    final itemName = firstItem?['name']?.toString().trim() ?? '';

    final hasSellerContext =
        buyerEmail.isNotEmpty && sellerEmail.isNotEmpty && itemId.isNotEmpty;
    final threadId = hasSellerContext
        ? '${itemId.toLowerCase()}__${sellerEmail.toLowerCase()}__${buyerEmail.toLowerCase()}'
        : null;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: threadId,
          itemId: itemId.isNotEmpty ? itemId : null,
          itemName: itemName.isNotEmpty ? itemName : null,
          sellerName: sellerName.isNotEmpty ? sellerName : null,
          sellerEmail: sellerEmail.isNotEmpty ? sellerEmail : null,
          buyerName: buyerName.isNotEmpty ? buyerName : null,
          buyerEmail: buyerEmail.isNotEmpty ? buyerEmail : null,
          draftMode: !hasSellerContext,
        ),
      ),
    );
  }

  Future<void> _goToCheckout(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          cartItems: widget.cartItems,
          subtotal: widget.subtotal,
          adminFee: widget.adminFee,
          shippingFee: widget.shippingFee,
          discount: widget.discount,
          total: widget.total,
          voucherCode: widget.voucherCode,
          userAddress: widget.userAddress,
          paymentMethod: _selectedPaymentMethod,
          qrisImageAssetPath: widget.qrisImageAssetPath,
          showQris: _selectedPaymentMethod == 'QRIS',
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
    final int totalWithFees =
        widget.total + widget.shippingFee + widget.adminFee;
    final isQris = _selectedPaymentMethod == 'QRIS';

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
                      _buildSummaryRow('Subtotal', widget.subtotal),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Biaya Admin', widget.adminFee),
                      _buildSummaryRow('Ongkos Kirim', widget.shippingFee),
                      if (widget.discount != 0) ...[
                        const SizedBox(height: 8),
                        _buildSummaryRow('Diskon', -widget.discount),
                      ],
                      const Divider(height: 24),
                      _buildSummaryRow('Total', totalWithFees, bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('COD'),
                          selected: _selectedPaymentMethod == 'COD',
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() {
                              _selectedPaymentMethod = 'COD';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('QRIS'),
                          selected: isQris,
                          onSelected: (selected) {
                            if (!selected) return;
                            setState(() {
                              _selectedPaymentMethod = 'QRIS';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isQris
                    ? Card(
                        key: const ValueKey('qris_info'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'QRIS akan ditampilkan di halaman konfirmasi. Tekan Lanjut ke Konfirmasi untuk melihat kode QR dan menyelesaikan pembayaran.',
                          ),
                        ),
                      )
                    : Card(
                        key: const ValueKey('cod_info'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'COD dipilih. Kamu akan konfirmasi pembayaran di halaman berikutnya.',
                          ),
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
