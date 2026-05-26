import 'package:flutter/material.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'api_client.dart';
import 'pin_gate.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.adminFee,
    required this.shippingFee,
    this.voucherCode,
    required this.userAddress,
    this.voucherCode,
    required this.userAddress,
    required this.paymentMethod,
    this.qrisImageAssetPath = 'assets/images/qris.png',
    this.showQris = false,
  });

  final List<Map<String, dynamic>> cartItems;
  final int subtotal;
  final int discount;
  final int total;
  final int adminFee;
  final int shippingFee;
  final String? voucherCode;
  final String userAddress;
  final String? voucherCode;
  final String userAddress;
  final String paymentMethod;
  final String qrisImageAssetPath;
  final bool showQris;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String _selectedMethod = 'Kartu Kredit/Debit';
  bool _agreedToTerms = false;
  bool _isProcessing = false;

  // Controllers untuk Kartu Kredit/Debit
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  // Controllers untuk Transfer Bank
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  // Controllers untuk GoPay
  final TextEditingController _goPeyPhoneController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _goPeyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pembayaran'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ringkasan Pesanan
                const Text(
                  'Ringkasan Pesanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...widget.cartItems.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item['name']} x${item['quantity']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rp ${item['subtotal']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Item:'),
                            Text(
                              '${widget.cartItems.length} item(s)',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Alamat Pengiriman
                const Text(
                  'Alamat Pengiriman',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      widget.userAddress.isNotEmpty
                          ? widget.userAddress
                          : 'Alamat belum diatur',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Detail Pembayaran
                const Text(
                  'Detail Pembayaran',
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
                        _buildPaymentRow('Subtotal', widget.subtotal),
                        const SizedBox(height: 10),
                        _buildPaymentRow(
                          'Diskon Voucher',
                          -widget.discount,
                          isDiscount: true,
                        ),
                        _buildPaymentRow('Biaya Admin', widget.adminFee),
                        _buildPaymentRow('Ongkir', widget.shippingFee),
                        if (widget.voucherCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Voucher: ${widget.voucherCode}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildPaymentRow(
                          'Total Bayar',
                          widget.total,
                          isBold: true,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Metode Pembayaran
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        'Kartu Kredit/Debit',
                        'Transfer Bank',
                        'GoPay',
                        'QRIS',
                        'COD (Cash on Delivery)',
                      ]
                          .map((method) {
                            final isSelected = _selectedMethod == method;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: RadioListTile<String>(
                                title: Text(method),
                                value: method,
                                groupValue: _selectedMethod,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMethod = value!;
                                  });
                                },
                                activeColor: Colors.green.shade700,
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Form pembayaran dinamis berdasarkan metode
                _buildPaymentForm(),
                const SizedBox(height: 20),

                // Syarat dan Ketentuan
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                      activeColor: Colors.green.shade700,
                    ),
                    const Expanded(
                      child: Text(
                        'Saya setuju dengan syarat dan ketentuan pembelian',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tombol Konfirmasi dan Kembali
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.green.shade700),
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _agreedToTerms && !_isProcessing
                            ? _confirmCheckout
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Konfirmasi Pembayaran'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Info Keamanan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data pembayaran Anda aman dan terenkripsi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    int amount, {
    bool isBold = false,
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isDiscount ? Colors.green : null,
          ),
        ),
        Text(
          '${amount >= 0 ? '' : '-'}Rp ${amount.abs()}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? Colors.green.shade700 : null,
          ),
        ),
      ],
    );
  }

  void _confirmCheckout() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan setujui syarat dan ketentuan terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi berdasarkan metode pembayaran
    if (!_validatePaymentForm()) {
      return;
    }

    setState(() => _isProcessing = true);

    // Simulasi proses pembayaran
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _isProcessing = false);

    // Navigasi ke halaman sukses atau pembayaran
    Navigator.of(context).pop({
      'confirmed': true,
      'paymentMethod': _selectedMethod,
    });
  }

  bool _validatePaymentForm() {
    switch (_selectedMethod) {
      case 'Kartu Kredit/Debit':
        if (_cardNumberController.text.trim().isEmpty ||
            _cardHolderController.text.trim().isEmpty ||
            _expiryController.text.trim().isEmpty ||
            _cvvController.text.trim().isEmpty) {
          _showError('Lengkapi semua data kartu kredit');
          return false;
        }
        if (_cardNumberController.text.length < 13) {
          _showError('Nomor kartu harus minimal 13 digit');
          return false;
        }
        if (_cvvController.text.length < 3) {
          _showError('CVV harus 3-4 digit');
          return false;
        }
        break;

      case 'Transfer Bank':
        if (_bankNameController.text.trim().isEmpty ||
            _accountNumberController.text.trim().isEmpty ||
            _accountNameController.text.trim().isEmpty) {
          _showError('Lengkapi semua data transfer bank');
          return false;
        }
        if (_accountNumberController.text.length < 8) {
          _showError('Nomor rekening tidak valid');
          return false;
        }
        break;

      case 'GoPay':
        if (_goPeyPhoneController.text.trim().isEmpty) {
          _showError('Masukkan nomor telepon GoPay');
          return false;
        }
        if (_goPeyPhoneController.text.length < 10) {
          _showError('Nomor telepon tidak valid');
          return false;
        }
        break;

      case 'QRIS':
        // QRIS tidak memerlukan validasi form
        break;

      case 'COD (Cash on Delivery)':
        // COD tidak memerlukan validasi form
        break;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildPaymentForm() {
    switch (_selectedMethod) {
      case 'Kartu Kredit/Debit':
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Kartu Kredit/Debit',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Kartu (16 digit)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pemegang Kartu',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _expiryController,
                        decoration: const InputDecoration(
                          labelText: 'Exp (MM/YY)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

      case 'Transfer Bank':
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Transfer Bank',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Bank (contoh: BCA, Mandiri)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.domain),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Rekening',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNameController,
                  decoration: const InputDecoration(
                    labelText: 'Atas Nama Rekening',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transfer akan diverifikasi dalam 5-10 menit',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case 'GoPay':
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail GoPay',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _goPeyPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon GoPay',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anda akan diarahkan ke aplikasi GoPay untuk menyelesaikan pembayaran',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case 'QRIS':
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Pembayaran QRIS',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_2,
                      size: 120,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Rp ${widget.total}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scan QR code di atas menggunakan aplikasi pembayaran Anda',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case 'COD (Cash on Delivery)':
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cash on Delivery (COD)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Bayar Saat Barang Tiba',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Total Pembayaran: Rp ${widget.total}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Pembayaran dilakukan saat barang tiba\n• Kurir akan memverifikasi uang tunai\n• Pastikan Anda memiliki uang cash yang cukup',
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  bool _agreedToTerms = false;
  bool _qrisPaid = false;
  bool _isProcessing = false;

  bool get _isQris => widget.paymentMethod == 'QRIS';

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildRow(String label, int amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            amount < 0 ? '-Rp ${amount.abs()}' : 'Rp $amount',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    if (_isQris && widget.showQris) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Pembayaran QRIS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    widget.qrisImageAssetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.qr_code_2,
                          size: 120,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scan QRIS di atas lalu lanjutkan konfirmasi setelah pembayaran selesai.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_isQris && !widget.showQris) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QRIS dipilih',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'QRIS baru ditampilkan setelah kamu tekan Lanjut ke Konfirmasi.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cash on Delivery (COD)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pembayaran dilakukan saat barang diterima.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCheckout() async {
    if (!_agreedToTerms) {
      _showError('Silakan setujui syarat dan ketentuan terlebih dahulu');
      return;
    }

    if (_isQris && !widget.showQris) {
      _showError('Tekan Lanjut ke Konfirmasi dulu untuk menampilkan QRIS.');
      return;
    }

    if (_isQris && !_qrisPaid) {
      _showError('Centang bahwa kamu sudah melakukan pembayaran QRIS.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final allowed = await PinGate.requirePin(
      context,
      messenger: messenger,
      purpose: 'konfirmasi pembayaran',
    );
    if (!allowed) return;

    final navigator = Navigator.of(context);
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final buyerName = prefs.getString('account_username')?.trim() ?? '';
    final buyerEmail = prefs.getString('account_email')?.trim() ?? '';
    final now = DateTime.now();

    try {
      for (final cartItem in widget.cartItems) {
        final sellerEmail = cartItem['sellerEmail']?.toString().trim() ?? '';
        final itemId = cartItem['itemId']?.toString().trim() ?? '';
        final threadId = cartItem['threadId']?.toString().trim();

        final payload = <String, dynamic>{
          'name': cartItem['name']?.toString() ?? 'Pesanan',
          'status': widget.paymentMethod == 'QRIS'
              ? 'Diterima'
              : 'Dalam Proses',
          'date': '${now.day} ${_monthName(now.month)} ${now.year}',
          'price': 'Rp ${cartItem['subtotal'] ?? widget.total}',
          'detail':
              '${cartItem['quantity']?.toString() ?? '1'} item, metode ${widget.paymentMethod}.',
          'type': 'buy',
          'image': cartItem['image']?.toString() ?? '',
        };

        final sellerName = cartItem['sellerName']?.toString().trim() ?? '';
        if (sellerName.isNotEmpty) {
          payload['sellerName'] = sellerName;
        }
        if (sellerEmail.isNotEmpty) {
          payload['sellerEmail'] = sellerEmail;
        }
        if (buyerName.isNotEmpty) {
          payload['buyerName'] = buyerName;
        }
        if (buyerEmail.isNotEmpty) {
          payload['buyerEmail'] = buyerEmail;
        }

        final resolvedThreadId = threadId?.isNotEmpty == true
            ? threadId!
            : (sellerEmail.isNotEmpty &&
                  buyerEmail.isNotEmpty &&
                  itemId.isNotEmpty)
            ? '${itemId.toLowerCase()}__${sellerEmail.toLowerCase()}__${buyerEmail.toLowerCase()}'
            : '';
        if (resolvedThreadId.isNotEmpty) {
          payload['threadId'] = resolvedThreadId;
        }

        final response = await postJsonWithFallback(
          path: '/transactions',
          body: jsonEncode(payload),
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(_extractResponseMessage(response.body));
        }
      }
    } catch (error) {
      setState(() => _isProcessing = false);
      _showError('Gagal menyimpan riwayat ke database. ${error.toString()}');
      return;
    }

    setState(() => _isProcessing = false);

    navigator.pop(<String, dynamic>{
      'confirmed': true,
      'paymentMethod': widget.paymentMethod,
    });
  }

  String _monthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  String _extractResponseMessage(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return 'Respons server kosong.';
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
      // Fallback to raw body.
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pembayaran'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Pesanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...widget.cartItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['name']} x${item['quantity']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Rp ${item['subtotal']}'),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      _buildRow('Subtotal', widget.subtotal),
                      _buildRow('Diskon Voucher', -widget.discount),
                      if (widget.voucherCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Voucher: ${widget.voucherCode}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildRow('Total Bayar', widget.total, bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Alamat Pengiriman',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.userAddress.isNotEmpty
                        ? widget.userAddress
                        : 'Alamat belum diatur',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: ['COD', 'QRIS'].map((method) {
                      final isSelected = widget.paymentMethod == method;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(method),
                            selected: isSelected,
                            onSelected: null,
                            selectedColor: Colors.green.shade100,
                            labelStyle: TextStyle(
                              color: isSelected
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
              _buildPaymentMethodCard(),
              if (_isQris && widget.showQris) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _qrisPaid,
                  onChanged: (value) {
                    setState(() {
                      _qrisPaid = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Saya sudah membayar QRIS'),
                  subtitle: const Text('Centang setelah pembayaran selesai.'),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                    activeColor: Colors.green.shade700,
                  ),
                  const Expanded(
                    child: Text(
                      'Saya setuju dengan syarat dan ketentuan pembelian',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isProcessing ? null : _confirmCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Konfirmasi Pesanan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
