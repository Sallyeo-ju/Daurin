import 'package:flutter/material.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'api_client.dart';
import 'pin_gate.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.adminFee,
    required this.shippingFee,
    required this.discount,
    required this.total,
    this.voucherCode,
    required this.userAddress,
    required this.paymentMethod,
    this.qrisImageAssetPath = 'assets/images/qris.png',
    this.showQris = false,
  });

  final List<Map<String, dynamic>> cartItems;
  final int subtotal;
  final int adminFee;
  final int shippingFee;
  final int discount;
  final int total;
  final String? voucherCode;
  final String userAddress;
  final String paymentMethod;
  final String qrisImageAssetPath;
  final bool showQris;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // Removed unused payment method field.
  bool _agreedToTerms = false;
  bool _isProcessing = false;
  bool _qrisPaid = false;

  // Controllers untuk Kartu Kredit/Debit
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  // Controllers untuk Transfer Bank
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
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

  // Legacy per-method validators removed; validation is handled inline in confirmCheckout.

  // Legacy helper removed; use `showError` below.

  // Unused legacy helpers removed to avoid analyzer warnings.

  bool get isQris => widget.paymentMethod == 'QRIS';

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget buildRow(String label, int amount, {bool bold = false}) {
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

  Widget buildPaymentMethodCard() {
    if (isQris && widget.showQris) {
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

    if (isQris && !widget.showQris) {
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

  Future<void> confirmCheckout() async {
    if (!_agreedToTerms) {
      showError('Silakan setujui syarat dan ketentuan terlebih dahulu');
      return;
    }

    if (isQris && !widget.showQris) {
      showError('Tekan Lanjut ke Konfirmasi dulu untuk menampilkan QRIS.');
      return;
    }

    if (isQris && !_qrisPaid) {
      showError('Centang bahwa kamu sudah melakukan pembayaran QRIS.');
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
          'date': '${now.day} ${monthName(now.month)} ${now.year}',
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
          throw Exception(extractResponseMessage(response.body));
        }
      }
    } catch (error) {
      setState(() => _isProcessing = false);
      showError('Gagal menyimpan riwayat ke database. ${error.toString()}');
      return;
    }

    setState(() => _isProcessing = false);

    navigator.pop(<String, dynamic>{
      'confirmed': true,
      'paymentMethod': widget.paymentMethod,
    });
  }

  String monthName(int month) {
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

  String extractResponseMessage(String rawBody) {
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
                      buildRow('Subtotal', widget.subtotal),
                      buildRow('Biaya Admin', widget.adminFee),
                      buildRow('Biaya Ongkir', widget.shippingFee),
                      buildRow('Diskon Voucher', -widget.discount),
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
                      buildRow('Total Bayar', widget.total, bold: true),
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
              buildPaymentMethodCard(),
              if (isQris && widget.showQris) ...[
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
                  onPressed: _isProcessing ? null : confirmCheckout,
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
