import 'dart:ui' show ImageFilter;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'LoginPage.dart';
import 'api_client.dart';
import 'AccountPage.dart';
import 'ChatPage.dart';
import 'PaymentPage.dart';
import 'HistoryPage.dart';
import 'pin_gate.dart';
import 'app_theme_controller.dart';

const List<String> _standardLocations = [
  'Jabodetabek',
  'West Jakarta',
  'East Jakarta',
  'Central Jakarta',
  'South Jakarta',
];

const List<String> _itemCategories = ['Recycle', 'Second hand', 'Other'];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _CartItem {
  _CartItem({required this.item, required this.quantity});

  final _Item item;
  final int quantity;

  _CartItem copyWith({int? quantity}) =>
      _CartItem(item: item, quantity: quantity ?? this.quantity);
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<_Item> _items = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _searchQuery = '';
  int _selectedIndex = 0;
  // Cart
  final List<_CartItem> _cart = [];

  // Voucher and payment
  final List<Voucher> _vouchers = [
    Voucher(
      id: 'VCHR30',
      title: 'Diskon 30%',
      description: 'Potongan harga tanpa minimum pembelian.',
      discountPercent: 30,
      expiresOn: '30 Juni 2026',
    ),
    Voucher(
      id: 'VCHR20K',
      title: 'Diskon 20%',
      description: 'Potongan harga dengan minimum pembelian.',
      discountPercent: 20,
      expiresOn: '15 Juli 2026',
      minCartValue: 30000,
    ),
    Voucher(
      id: 'VCHRONGKIR3',
      title: 'Gratis Ongkir 3',
      description: 'Voucher gratis ongkir untuk pembelian kamu.',
      discountPercent: 0,
      expiresOn: '31 Juli 2026',
    ),
  ];
  String? _appliedVoucherCode;
  int? _appliedVoucherDiscountPercent;

  // Account page controllers
  final TextEditingController _accountAddressController =
      TextEditingController();
  final TextEditingController _accountUsernameController =
      TextEditingController();
  final TextEditingController _accountEmailController = TextEditingController();
  final TextEditingController _accountPasswordController =
      TextEditingController();
  bool _darkMode = false;
  bool _showedAccountIntro = false;
  String _locationStatus = 'Belum dideteksi';
  String _detectedLocationText =
      'Tap "Detect Location" untuk ambil lokasi sekarang.';

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadPreferences();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode =
          prefs.getBool('dark_mode') ??
          AppThemeController.instance.darkMode.value;
      _accountAddressController.text = prefs.getString('account_address') ?? '';
      _accountUsernameController.text =
          prefs.getString('account_username') ?? '';
      _accountEmailController.text = prefs.getString('account_email') ?? '';
      _locationStatus = prefs.getString('location_status') ?? 'Belum dideteksi';
      _detectedLocationText =
          prefs.getString('detected_location_text') ?? _detectedLocationText;
    });
  }

  String? get _currentAccountName {
    final value = _accountUsernameController.text.trim();
    return value.isEmpty ? null : value;
  }

  String? get _currentAccountEmail {
    final value = _accountEmailController.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _setDarkMode(bool value) async {
    await AppThemeController.instance.setDarkMode(value);
    if (!mounted) return;
    setState(() {
      _darkMode = value;
    });
    _showMessage(value ? 'Dark mode aktif.' : 'Light mode aktif.');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _accountAddressController.dispose();
    _accountUsernameController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
    _filterAreaOtherController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);
    if (index == 4 && !_showedAccountIntro) {
      _showedAccountIntro = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAccountIntroDialog();
      });
    }
  }

  Future<void> _showAccountIntroDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Aktifkan lokasi?'),
        content: const Text(
          'Biar akun lebih lengkap, kamu bisa langsung detect lokasi supaya alamat bisa terisi otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti saja'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _detectCurrentLocation();
            },
            child: const Text('Detect Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final passwordController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _accountUsernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accountEmailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _accountAddressController,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password baru (opsional)',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'account_username',
                _accountUsernameController.text.trim(),
              );
              await prefs.setString(
                'account_email',
                _accountEmailController.text.trim(),
              );
              await prefs.setString(
                'account_address',
                _accountAddressController.text.trim(),
              );
              if (passwordController.text.trim().isNotEmpty) {
                final pwd = passwordController.text.trim();
                _accountPasswordController.text = pwd;
                await prefs.setString('account_password', pwd);
              }
              if (!mounted) return;
              navigator.pop();
              _showMessage('Profile tersimpan.');
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutUsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About Us'),
        content: const Text(
          'Daurin adalah aplikasi untuk jual beli dan pengelolaan barang ramah lingkungan, barang bekas, dan item promo dalam satu tempat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _runProtectedAction(Future<void> Function() action) async {
    final allowed = await PinGate.requirePin(
      context,
      messenger: ScaffoldMessenger.of(context),
      purpose: 'aksi sensitif akun',
    );
    if (!allowed) {
      return;
    }
    await action();
  }

  Voucher? get _recommendedVoucher {
    if (_cart.isEmpty) return null;
    final eligible = _vouchers.where((voucher) {
      return _isVoucherEligible(voucher);
    }).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    return eligible.first;
  }

  bool _isVoucherEligible(Voucher voucher) {
    if (voucher.isUsed) return false;
    if (_cart.isEmpty) return false;
    if (voucher.minCartValue != null && _cartTotal < voucher.minCartValue!) {
      return false;
    }
    if (voucher.requiredCategory != null) {
      return _cart.any((ci) => ci.item.category == voucher.requiredCategory);
    }
    return true;
  }

  void _clearVoucher() {
    setState(() {
      _appliedVoucherCode = null;
      _appliedVoucherDiscountPercent = null;
    });
  }

  // Total harga setelah menerapkan diskon penjual (per-item discountedPrice jika ada)
  int get _priceAfterSellerTotal {
    return _cart.fold(
        0,
        (sum, c) =>
            sum + ((c.item.discountedPrice ?? c.item.price) * c.quantity));
  }

  int get _discountAmount {
    if (_appliedVoucherDiscountPercent == null || _cart.isEmpty) {
      return 0;
    }

    // Voucher applies on top of seller-discounted prices (stacking).
    final afterSeller = _priceAfterSellerTotal;
    return ((afterSeller * _appliedVoucherDiscountPercent!) / 100).round();
  }

  int get _finalCartTotal {
    // Subtotal (original prices) minus seller discounts minus voucher discount
    final sellerDiscount = _cartTotal - _priceAfterSellerTotal;
    return _cartTotal - sellerDiscount - _discountAmount;
  }

  void _applyVoucher(String voucherId) {
    final voucherIndex = _vouchers.indexWhere((v) => v.id == voucherId);
    if (voucherIndex < 0) {
      _showMessage('Voucher tidak ditemukan.');
      return;
    }

    final voucher = _vouchers[voucherIndex];
    if (_cart.isEmpty) {
      _showMessage('Tambahkan item ke keranjang dulu untuk pakai voucher.');
      return;
    }
    if (voucher.isUsed) {
      _showMessage('Voucher sudah digunakan.');
      return;
    }
    if (!_isVoucherEligible(voucher)) {
      final conditions = <String>[];
      if (voucher.minCartValue != null) {
        conditions.add('belanja minimal Rp ${voucher.minCartValue}');
      }
      if (voucher.requiredCategory != null) {
        conditions.add('kategori ${voucher.requiredCategory}');
      }
      _showMessage(
        'Voucher tidak memenuhi syarat: ${conditions.join(' dan ')}.',
      );
      return;
    }

    setState(() {
      _vouchers[voucherIndex] = voucher.copyWith(isUsed: true);
      _appliedVoucherCode = voucher.id;
      _appliedVoucherDiscountPercent = voucher.discountPercent;
    });
    _showMessage('Voucher ${voucher.id} berhasil diterapkan.');
  }

  Future<void> _navigateToPaymentPage() async {
    if (_cart.isEmpty) {
      _showMessage('Keranjang kosong, tambahkan item terlebih dahulu.');
      return;
    }

    // Buat list item untuk checkout
    final List<Map<String, dynamic>> cartItems = _cart
        .map((cartItem) => {
              'name': cartItem.item.name,
              'quantity': cartItem.quantity,
              'price': cartItem.item.price,
              'location': cartItem.item.location,
              'subtotal': cartItem.item.price * cartItem.quantity,
            })
        .map(
          (cartItem) => {
            'itemId': cartItem.item.id,
            'name': cartItem.item.name,
            'quantity': cartItem.quantity,
            'price': cartItem.item.price,
            'subtotal': cartItem.item.price * cartItem.quantity,
            'image': cartItem.item.imageUrl,
            'sellerName': cartItem.item.sellerName,
            'sellerEmail': cartItem.item.sellerEmail,
            'threadId':
                cartItem.item.sellerEmail == null ||
                    cartItem.item.sellerEmail!.isEmpty ||
                    _currentAccountEmail == null
                ? null
                : '${cartItem.item.id.trim().toLowerCase()}__${cartItem.item.sellerEmail!.trim().toLowerCase()}__${_currentAccountEmail!.toLowerCase()}',
          },
        )
        .toList();

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          subtotal: _cartTotal,
          discount: _discountAmount,
          total: _finalCartTotal,
          voucherCode: _appliedVoucherCode,
          cartItems: cartItems,
          userAddress: _accountAddressController.text,
        ),
      ),
    );

    if (paid == true) {
      setState(() {
        _cart.clear();
        _clearVoucher();
      });
      _showMessage('Pembayaran berhasil. Terima kasih!');
    }
  }

  String _formatLocationLabel(Placemark placemark) {
    final parts = <String>[
      placemark.subLocality ?? '',
      placemark.subAdministrativeArea ?? '',
      placemark.locality ?? '',
      placemark.administrativeArea ?? '',
    ].where((part) => part.trim().isNotEmpty).toList();

    final uniqueParts = <String>[];
    for (final part in parts) {
      final normalized = part.trim();
      if (uniqueParts.isEmpty || uniqueParts.last != normalized) {
        if (!uniqueParts.contains(normalized)) {
          uniqueParts.add(normalized);
        }
      }
    }

    if (uniqueParts.isEmpty) {
      final country = placemark.country?.trim();
      return country != null && country.isNotEmpty
          ? country
          : 'Lokasi terdeteksi';
    }

    return uniqueParts.take(3).join(', ');
  }

  Future<void> _showFaqDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q: Cara upload barang?'),
              SizedBox(height: 6),
              Text('A: Tekan tombol + di halaman Home, isi data lalu simpan.'),
              SizedBox(height: 12),
              Text('Q: Cara aktifkan lokasi?'),
              SizedBox(height: 6),
              Text('A: Buka menu akun, lalu pilih Detect Location.'),
              SizedBox(height: 12),
              Text('Q: Apa fungsi dark mode?'),
              SizedBox(height: 6),
              Text('A: Mengubah tampilan aplikasi ke mode gelap atau terang.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _detectCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Nyalakan lokasi di device dulu.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showMessage('Izin lokasi ditolak.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessage('Izin lokasi ditolak permanen. Buka settings aplikasi.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      String locationText = 'Lokasi terdeteksi';

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          locationText = _formatLocationLabel(placemarks.first);
        }
      } catch (_) {
        locationText = 'Lokasi terdeteksi';
      }

      final previousLocationText = _detectedLocationText;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('location_status', 'Aktif');
      await prefs.setString('detected_location_text', locationText);

      if (!mounted) return;
      setState(() {
        _locationStatus = 'Aktif';
        _detectedLocationText = locationText;
        _accountAddressController.text = locationText;
      });

      if (previousLocationText != locationText) {
        _showMessage('Lokasi berhasil dideteksi: $locationText');
      }
    } catch (error) {
      _showMessage('Gagal detect lokasi: $error');
    }
  }

  void _addToCart(_Item item) {
    if (item.quantity <= 0) {
      _showMessage('${item.name} sedang sold out.');
      return;
    }
    final existing = _cart.indexWhere((c) => c.item.id == item.id);
    setState(() {
      if (existing >= 0) {
        _cart[existing] = _cart[existing].copyWith(
          quantity: _cart[existing].quantity + 1,
        );
      } else {
        _cart.add(_CartItem(item: item, quantity: 1));
      }
    });
    _showMessage('${item.name} ditambahkan ke keranjang');
  }

  Future<void> _openSellerChat(_Item item) async {
    final sellerName = item.sellerName?.trim();
    final sellerEmail = item.sellerEmail?.trim();
    final buyerName = _currentAccountName;
    final buyerEmail = _currentAccountEmail;

    if (buyerName == null || buyerEmail == null) {
      _showMessage('Data akun belum lengkap. Login dulu untuk chat seller.');
      return;
    }

    if (!mounted) {
      return;
    }

    final hasSellerData =
        sellerName != null && sellerName.isNotEmpty && sellerEmail != null && sellerEmail.isNotEmpty;
    final threadId = hasSellerData
      ? '${item.id.trim().toLowerCase()}__${sellerEmail.toLowerCase()}__${buyerEmail.toLowerCase()}'
        : 'draft__${item.id.trim().toLowerCase()}__${buyerEmail.toLowerCase()}';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          threadId: threadId,
          itemId: item.id,
          itemName: item.name,
          sellerName: sellerName ?? 'Chat baru',
          sellerEmail: sellerEmail,
          buyerName: buyerName,
          buyerEmail: buyerEmail,
          draftMode: !hasSellerData,
        ),
      ),
    );
  }

  void _removeFromCart(String itemId) {
    setState(() {
      _cart.removeWhere((c) => c.item.id == itemId);
    });
  }

  int get _cartTotal {
    return _cart.fold(0, (sum, c) => sum + (c.item.price * c.quantity));
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await getJsonWithFallback(path: '/items');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> rawList =
            jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _items = rawList
              .whereType<Map<String, dynamic>>()
              .map(_Item.fromJson)
              .toList();
        });
      } else {
        _showMessage('Gagal memuat item dari server. ${apiConnectionHint()}');
      }
    } catch (error) {
      _showMessage(
        'Tidak bisa terhubung ke server. ${error.toString()}. ${apiConnectionHint()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddItemDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final customLocationController = TextEditingController();
    final descriptionController = TextEditingController();
    final discountPercentController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final customCategoryController = TextEditingController();
    final imagePicker = ImagePicker();
    String? selectedPhotoPath;
    String? selectedPhotoName;
    String selectedCategory = 'Recycle';
    String selectedLocation = _standardLocations.first;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Item Baru'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama item',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama item wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Harga'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Harga wajib diisi';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Harga harus angka positif';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity/Stok',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Quantity wajib diisi';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Quantity harus angka 0 atau lebih';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLocation,
                        items: [..._standardLocations, 'Other']
                            .map(
                              (location) => DropdownMenuItem(
                                value: location,
                                child: Text(location),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedLocation =
                                value ?? _standardLocations.first;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Lokasi'),
                      ),
                      if (selectedLocation == 'Other') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: customLocationController,
                          decoration: const InputDecoration(
                            labelText: 'Isi lokasi sendiri',
                            hintText: 'Contoh: Bandung, Surabaya, Bekasi',
                          ),
                          validator: (value) {
                            if (selectedLocation != 'Other') {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return 'Lokasi custom wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              selectedLocation = 'Other';
                              customLocationController.text =
                                  _detectedLocationText;
                            });
                          },
                          icon: const Icon(Icons.location_on_outlined),
                          label: const Text('Pakai lokasi terdeteksi'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        items: _itemCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            selectedCategory = v ?? 'Recycle';
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
                      if (selectedCategory == 'Other') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: customCategoryController,
                          decoration: const InputDecoration(
                            labelText: 'Tulis category sendiri',
                            hintText: 'Contoh: Elektronik, Fashion, Furniture',
                          ),
                          validator: (value) {
                            if (selectedCategory != 'Other') {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return 'Category custom wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (opsional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: discountPercentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Diskon (%) - opsional',
                          hintText: 'Contoh: 10',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Diskon harus berupa angka';
                          }
                          if (parsed < 0 || parsed > 100) {
                            return 'Diskon harus di antara 0 sampai 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedPhotoPath == null
                                  ? Icons.cloud_upload_outlined
                                  : Icons.check_circle,
                              color: selectedPhotoPath == null
                                  ? Colors.grey
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isSubmitting
                                    ? 'Sedang upload foto...'
                                    : selectedPhotoPath == null
                                    ? 'Status foto: belum dipilih'
                                    : 'Status foto: siap diupload${selectedPhotoName != null ? ' - $selectedPhotoName' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedPhotoPath == null
                                  ? 'Belum ada foto dipilih'
                                  : 'Foto dipilih',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final picked = await imagePicker.pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 70,
                                      maxWidth: 1600,
                                      maxHeight: 1600,
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        selectedPhotoPath = picked.path;
                                        selectedPhotoName = picked.name;
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Pilih Foto'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          final locationValue = selectedLocation == 'Other'
                              ? customLocationController.text.trim()
                              : selectedLocation;
                          final categoryValue = selectedCategory == 'Other'
                              ? customCategoryController.text.trim()
                              : selectedCategory;
                          final discountText = discountPercentController.text
                              .trim();
                          final quantityText = quantityController.text.trim();
                          final discountPercentValue = discountText.isEmpty
                              ? 0
                              : int.parse(discountText);
                          final quantityValue = int.parse(quantityText);

                          final navigator = Navigator.of(context);
                          final allowed = await PinGate.requirePin(
                            context,
                            messenger: ScaffoldMessenger.of(context),
                            purpose: 'upload barang',
                          );
                          if (!allowed) {
                            return;
                          }

                          setState(() {
                            _isSubmitting = true;
                          });
                          setDialogState(() {});

                          try {
                            final itemFields = <String, String>{
                              'name': nameController.text.trim(),
                              'price': priceController.text.trim(),
                              'quantity': quantityValue.toString(),
                              'location': locationValue,
                              'discountPercent': discountPercentValue
                                  .toString(),
                              'category': categoryValue,
                              'description': descriptionController.text.trim(),
                            };

                            if (_currentAccountName != null) {
                              itemFields['sellerName'] = _currentAccountName!;
                            }
                            if (_currentAccountEmail != null) {
                              itemFields['sellerEmail'] = _currentAccountEmail!;
                            }

                            final response =
                                await postMultipartItemWithFallback(
                                  fields: itemFields,
                                  photoPath: selectedPhotoPath,
                                );
                            if (!mounted) {
                              return;
                            }

                            if (response.statusCode >= 200 &&
                                response.statusCode < 300) {
                              navigator.pop();
                              _showMessage('Item berhasil ditambahkan.');
                              await _loadItems();
                            } else {
                              final backendMessage = _extractBackendMessage(
                                response.body,
                              );
                              _showMessage(
                                'Gagal menambahkan item. $backendMessage',
                              );
                            }
                          } catch (error) {
                            _showMessage(
                              'Tidak bisa terhubung ke server. ${error.toString()}. ${apiConnectionHint()}',
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isSubmitting = false;
                              });
                            }
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // pages for bottom navigation
    final pages = <Widget>[
      // 1. Home
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildHomePage(),
        ),
      ),

      // 2. Promo page
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPromoPage(),
        ),
      ),

      // 3. Cart page
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: const HistoryPage(),
        ),
      ),

      // 4. Cart page
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCartPage(),
        ),
      ),

      // 5. Account page
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AccountPage(
            username: _accountUsernameController.text.isNotEmpty
                ? _accountUsernameController.text
                : 'User Baru',
            email: _accountEmailController.text.isNotEmpty
                ? _accountEmailController.text
                : 'Email belum diisi',
            isDarkMode: _darkMode,
            onToggleDarkMode: _setDarkMode,
            locationStatus: _locationStatus,
            locationText: _detectedLocationText,
            onDetectLocation: () {
              _runProtectedAction(_detectCurrentLocation);
            },
            onLogout: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            onEditProfile: () {
              _runProtectedAction(_showEditProfileDialog);
            },
            onChangePassword: () {
              _runProtectedAction(() async {
                _showMessage('Fitur ganti password akan datang.');
              });
            },
            onAboutUs: _showAboutUsDialog,
            onFaq: _showFaqDialog,
            vouchers: _vouchers,
            recommendedVoucher: _recommendedVoucher,
            selectedVoucherCode: _appliedVoucherCode,
            onUseVoucher: _applyVoucher,
          ),
        ),
      ),
    ];
    final pageTheme = _darkMode
        ? ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade700),
              ),
            ),
            textTheme: ThemeData.dark(useMaterial3: true)
                .textTheme
                .apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
          )
        : ThemeData.light(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFFF6F8F3),
            cardColor: Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade700),
              ),
            ),
          );

    final titles = ['Daurin', 'Promo', 'Keranjang', 'Akun'];

    return Theme(
      data: pageTheme,
      child: Scaffold(
        backgroundColor: pageTheme.scaffoldBackgroundColor,
        appBar: AppBar(
    final titles = ['Daurin', 'Promo', 'History', 'Keranjang', 'Akun'];

    return Scaffold(
      backgroundColor: _pageBackgroundColor,
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        centerTitle: false,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: _selectedIndex == 0
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _detectCurrentLocation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _locationStatus == 'Aktif'
                                  ? _detectedLocationText
                                  : 'Detect lokasi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddItemDialog,
              backgroundColor: Colors.green.shade700,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabChanged,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer),
            label: 'Promo',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Akun'),
        ],
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  Widget _buildCartPage() {
    if (_cart.isEmpty) {
      return Center(
        child: Text(
          'Keranjang kosong',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Keranjang',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('Subtotal'), Text('Rp $_cartTotal')],
                ),
                if (_discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Diskon voucher'),
                      Text('- Rp $_discountAmount'),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Bayar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rp $_finalCartTotal',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_recommendedVoucher != null && _appliedVoucherCode == null) ...[
          Card(
            color: Colors.green.shade50,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voucher terbaik untuk keranjang Anda',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_recommendedVoucher!.title),
                  const SizedBox(height: 4),
                  Text(_recommendedVoucher!.description),
                  if (_recommendedVoucher!.minCartValue != null)
                    Text(
                      'Syarat: minimal belanja Rp ${_recommendedVoucher!.minCartValue}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  if (_recommendedVoucher!.requiredCategory != null)
                    Text(
                      'Kategori: ${_recommendedVoucher!.requiredCategory}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _applyVoucher(_recommendedVoucher!.id),
                      child: const Text('Gunakan voucher ini'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: _cart.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, idx) {
              final ci = _cart[idx];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      if (ci.item.imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            buildApiUrl(ci.item.imageUrl!),
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.image_not_supported),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image_not_supported),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ci.item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Rp ${ci.item.price} x ${ci.quantity}'),
                            if (ci.item.discountPercent != null &&
                                ci.item.discountPercent! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${ci.item.discountPercent}% OFF',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (ci.quantity > 1) {
                                setState(() {
                                  _cart[idx] = ci.copyWith(
                                    quantity: ci.quantity - 1,
                                  );
                                });
                              } else {
                                _removeFromCart(ci.item.id);
                              }
                            },
                          ),
                          Text('${ci.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                _cart[idx] = ci.copyWith(
                                  quantity: ci.quantity + 1,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _navigateToPaymentPage,
                icon: const Icon(Icons.payment),
                label: const Text('Bayar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _cart.clear();
                    _appliedVoucherCode = null;
                    _appliedVoucherDiscountPercent = null;
                  });
                  _showMessage('Keranjang dikosongkan.');
                },
                child: const Text('Kosongkan'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Filters
  String? _filterArea;
  final TextEditingController _filterAreaOtherController =
      TextEditingController();
  String? _filterCategory;
  int? _priceMin;
  int? _priceMax;
  String? _priceSort; // 'asc' or 'desc'

  Color get _pageBackgroundColor =>
      _darkMode ? const Color(0xFF0E1116) : const Color(0xFFF6F8F3);

  Color get _surfaceColor => _darkMode ? const Color(0xFF191F26) : Colors.white;

  Color get _borderColor => _darkMode ? Colors.white12 : Colors.black12;

  void _showFilterSheet() {
    // Fixed category choices per spec
    final categories = ['All', 'Recycle', 'Second hand'];

    final minController = TextEditingController(
      text: _priceMin?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: _priceMax?.toString() ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Area'),
                  Wrap(
                    spacing: 8,
                    children: ([..._standardLocations, 'Other'])
                        .map(
                          (a) => ChoiceChip(
                            label: Text(a),
                            selected:
                                _filterArea == a ||
                                (_filterArea != null &&
                                    a == 'Other' &&
                                    _filterArea != null &&
                                    !_isStandardArea(_filterArea!)),
                            onSelected: (s) {
                              setState(() {
                                if (!s) {
                                  _filterArea = null;
                                } else {
                                  if (a == 'Other') {
                                    _filterArea = '__other__';
                                  } else {
                                    _filterArea = a;
                                    _filterAreaOtherController.text = '';
                                  }
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  if (_filterArea == '__other__') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _filterAreaOtherController,
                      decoration: const InputDecoration(
                        labelText: 'Masukkan kota lain',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Category'),
                  Wrap(
                    spacing: 8,
                    children: categories
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c),
                            selected:
                                _filterCategory == c ||
                                (c == 'All' && _filterCategory == null),
                            onSelected: (s) {
                              setState(() {
                                if (!s) {
                                  _filterCategory = null;
                                } else {
                                  _filterCategory = c == 'All' ? null : c;
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Price'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Sort by price'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('No sort'),
                        selected: _priceSort == null,
                        onSelected: (s) {
                          if (s) setState(() => _priceSort = null);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Lowest first'),
                        selected: _priceSort == 'asc',
                        onSelected: (s) {
                          if (s) setState(() => _priceSort = 'asc');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Highest first'),
                        selected: _priceSort == 'desc',
                        onSelected: (s) {
                          if (s) setState(() => _priceSort = 'desc');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterArea = null;
                            _filterCategory = null;
                            _priceMin = null;
                            _priceMax = null;
                            _priceSort = null;
                            _filterAreaOtherController.text = '';
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _priceMin = int.tryParse(minController.text);
                            _priceMax = int.tryParse(maxController.text);
                            if (_filterArea == '__other__') {
                              final other = _filterAreaOtherController.text
                                  .trim();
                              _filterArea = other.isEmpty ? null : other;
                            }
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isStandardArea(String area) {
    return _standardLocations.contains(area);
  }

  List<_Item> get _filteredItems {
    var list = _items;
    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        return item.name.toLowerCase().contains(_searchQuery) ||
            item.location.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    if (_filterArea != null && _filterArea!.isNotEmpty) {
      list = list
          .where(
            (i) =>
                i.location.toLowerCase().contains(_filterArea!.toLowerCase()),
          )
          .toList();
    }
    if (_filterCategory != null && _filterCategory!.isNotEmpty) {
      list = list.where((i) => i.category == _filterCategory).toList();
    }
    if (_priceMin != null) {
      list = list.where((i) => i.price >= _priceMin!).toList();
    }
    if (_priceMax != null) {
      list = list.where((i) => i.price <= _priceMax!).toList();
    }
    if (_priceSort == 'asc') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_priceSort == 'desc') {
      list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  Widget _buildPromoPage() {
    final promoItems = _items
        .where(
          (item) =>
              item.isPromoted ||
              (item.discountPercent != null && item.discountPercent! > 0),
        )
        .toList();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (promoItems.isEmpty) {
      return Center(
        child: Text(
          'Belum ada promo saat ini.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Diskon & Promo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Lihat penawaran khusus dan item diskon yang dapat kamu tambahkan ke keranjang.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              itemCount: promoItems.length,
              padding: const EdgeInsets.only(bottom: 90),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 338,
              ),
              itemBuilder: (context, index) => _ItemCard(
                item: promoItems[index],
                onAddToCart: _addToCart,
                onChatSeller: _openSellerChat,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    final visibleItems = _filteredItems;

    return RefreshIndicator(
      onRefresh: _loadItems,
      color: Colors.green.shade700,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _HeaderBar(
            searchController: _searchController,
            onFilterPressed: _showFilterSheet,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Item Terbaru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${visibleItems.length} hasil',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibleItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor),
              ),
              child: const Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.black38),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada item yang cocok.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Coba ubah kata kunci atau filter untuk menemukan item lain.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              itemCount: visibleItems.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 338,
              ),
              itemBuilder: (context, index) => _ItemCard(
                item: visibleItems[index],
                onAddToCart: _addToCart,
                onChatSeller: _openSellerChat,
              ),
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.searchController,
    required this.onFilterPressed,
  });

  final TextEditingController searchController;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daurin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cari semua kebutuhan daur ulang kamu di Daurin....',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Cari barang yang kamu butuhkan disini',
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A313A)
                  : Colors.white,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: onFilterPressed,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, this.onAddToCart, this.onChatSeller});

  final _Item item;
  final void Function(_Item)? onAddToCart;
  final Future<void> Function(_Item)? onChatSeller;

  @override
  Widget build(BuildContext context) {
    final isSoldOut = item.quantity <= 0;

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C2229)
              : const Color(0xFFF6F8F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.black12,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: isSoldOut
                      ? ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Opacity(
                    opacity: isSoldOut ? 0.55 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.sellerName?.isNotEmpty == true
                                    ? item.sellerName!
                                    : 'Seller belum diisi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (onChatSeller != null)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => onChatSeller!(item),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (item.isPromoted ||
                            (item.discountPercent != null &&
                                item.discountPercent! > 0))
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isSoldOut
                                      ? Colors.grey.shade200
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  isSoldOut
                                      ? 'SOLD OUT'
                                      : 'STOK ${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isSoldOut
                                        ? Colors.grey.shade700
                                        : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              if (item.isPromoted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'PROMO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ),
                              if (item.discountPercent != null &&
                                  item.discountPercent! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${item.discountPercent}% OFF',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (!item.isPromoted &&
                            (item.discountPercent == null ||
                                item.discountPercent! <= 0))
                          Text(
                            isSoldOut
                                ? 'SOLD OUT'
                                : 'Sisa stok: ${item.quantity}',
                            style: TextStyle(
                              color: isSoldOut
                                  ? Colors.grey.shade700
                                  : Colors.black54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          const SizedBox(height: 1),
                        const SizedBox(height: 6),
                        if (item.imageUrl != null &&
                            item.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              buildApiUrl(item.imageUrl!),
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Gambar tidak bisa dimuat',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return Container(
                                      width: double.infinity,
                                      height: 120,
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (item.discountedPrice != null &&
                            item.discountedPrice! < item.price) ...[
                          Text(
                            'Rp ${item.price}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rp ${item.discountedPrice}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Rp ${item.price}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          item.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        if (item.category != null &&
                            item.category!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.category!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (item.promoNote != null &&
                            item.promoNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.promoNote!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (!isSoldOut && onChatSeller != null)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: onAddToCart == null
                                      ? null
                                      : () => onAddToCart!(item),
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    size: 16,
                                  ),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    minimumSize: const Size(72, 36),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => onChatSeller!(item),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                  ),
                                  label: const Text('Chat'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(72, 36),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (!isSoldOut)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: onAddToCart == null
                                    ? null
                                    : () => onAddToCart!(item),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 16,
                                ),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  minimumSize: const Size(72, 36),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Sold out',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isSoldOut)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'SOLD OUT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    buildApiUrl(item.imageUrl!),
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 160,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Rp ${item.price}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text('Lokasi: ${item.location}'),
              if (item.sellerName != null && item.sellerName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Seller: ${item.sellerName}'),
              ],
              if (item.category != null && item.category!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Category: ${item.category!}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: onAddToCart == null
                ? null
                : () {
                    onAddToCart!(item);
                    Navigator.of(ctx).pop();
                  },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to cart'),
          ),
          if (item.sellerEmail != null &&
              item.sellerEmail!.isNotEmpty &&
              onChatSeller != null)
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await onChatSeller!(item);
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat Seller'),
            ),
        ],
      ),
    );
  }
}

class _Item {
  _Item({
    required this.id,
    required this.name,
    required this.price,
    required this.location,
    this.quantity = 1,
    this.imageUrl,
    this.isPromoted = false,
    this.discountPercent,
    this.discountedPrice,
    this.promoNote,
    this.category,
    this.description,
    this.sellerName,
    this.sellerEmail,
  });

  final String id;
  final String name;
  final int price;
  final String location;
  final int quantity;
  final String? imageUrl;
  final bool isPromoted;
  final int? discountPercent;
  final int? discountedPrice;
  final String? promoNote;
  final String? category;
  final String? description;
  final String? sellerName;
  final String? sellerEmail;

  factory _Item.fromJson(Map<String, dynamic> json) {
    final dynamic priceValue = json['price'];
    int parsedPrice = 0;
    if (priceValue is int) {
      parsedPrice = priceValue;
    } else if (priceValue is double) {
      parsedPrice = priceValue.toInt();
    } else if (priceValue is String) {
      parsedPrice = int.tryParse(priceValue) ?? 0;
    }

    return _Item(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: parsedPrice,
      location: (json['location'] ?? '').toString(),
      quantity: _parseOptionalInt(json['quantity']) ?? 1,
      imageUrl: json['imageUrl']?.toString(),
      isPromoted:
          json['isPromoted'] == true ||
          json['isPromoted']?.toString() == 'true',
      discountPercent: _parseOptionalInt(json['discountPercent']),
      discountedPrice: _parseOptionalInt(json['discountedPrice']),
      promoNote: json['promoNote']?.toString(),
      category: json['category']?.toString(),
      description: json['description']?.toString(),
      sellerName: json['sellerName']?.toString(),
      sellerEmail: json['sellerEmail']?.toString(),
    );
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}

String _extractBackendMessage(String rawBody) {
  if (rawBody.trim().isEmpty) {
    return apiConnectionHint();
  }

  try {
    final parsed = jsonDecode(rawBody);
    if (parsed is Map<String, dynamic>) {
      final message = parsed['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join(', ');
      }
    }
  } catch (_) {
    // Keep fallback below when body is not a JSON payload.
  }

  return rawBody;
}
