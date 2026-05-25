import 'package:flutter/material.dart';
import 'CheckoutPage.dart';

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

  bool get _isQris => _selectedMethod == 'QRIS';

  void _submitPayment() {
    Navigator.of(context).pop(true);
  }

  void _goToCheckout() async {
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Total bayar',
                          widget.total,
                          isBold: true,
                        ),
                        if (widget.voucherCode != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Voucher: ${widget.voucherCode}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pilih Metode Pembayaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const ['COD', 'QRIS'].map((method) {
                    final isSelected = _selectedMethod == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedMethod = method;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                if (_isQris) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Scan QRIS di bawah ini',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: widget.qrisImageAssetPath.isNotEmpty
                              ? Image.asset(
                                  widget.qrisImageAssetPath,
                                  fit: BoxFit.contain,
                                  height: 260,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 260,
                                      width: double.infinity,
                                      color: Colors.white,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Isi gambar QRIS di:\n${widget.qrisImageAssetPath}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  height: 260,
                                  width: double.infinity,
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Isi gambar QRIS di qrisImageAssetPath',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text(
                    'COD dipilih. Kurir akan menerima pembayaran saat barang diterima.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _goToCheckout,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    child: const Text('Lanjut ke Konfirmasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          'Rp $amount',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
