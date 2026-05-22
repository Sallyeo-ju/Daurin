import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'LoginPage.dart';
import 'api_client.dart';

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
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _accountAddressController.text = prefs.getString('account_address') ?? '';
      _accountUsernameController.text =
          prefs.getString('account_username') ?? '';
      _accountEmailController.text = prefs.getString('account_email') ?? '';
      _locationStatus = prefs.getString('location_status') ?? 'Belum dideteksi';
      _detectedLocationText =
          prefs.getString('detected_location_text') ?? _detectedLocationText;
    });
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
    if (index == 3 && !_showedAccountIntro) {
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
                _accountPasswordController.text = passwordController.text
                    .trim();
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
      final locationText =
          'Lat ${position.latitude.toStringAsFixed(6)}, Lng ${position.longitude.toStringAsFixed(6)}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('location_status', 'Aktif');
      await prefs.setString('detected_location_text', locationText);

      if (!mounted) return;
      setState(() {
        _locationStatus = 'Aktif';
        _detectedLocationText = locationText;
        _accountAddressController.text = locationText;
      });
      _showMessage('Lokasi berhasil dideteksi.');
    } catch (error) {
      _showMessage('Gagal detect lokasi: $error');
    }
  }

  void _addToCart(_Item item) {
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
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final discountPercentController = TextEditingController();
    final imagePicker = ImagePicker();
    String? selectedPhotoPath;
    String? selectedPhotoName;
    String selectedCategory = 'Recycle';

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
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Lokasi'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lokasi wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        items: const [
                          DropdownMenuItem(
                            value: 'Recycle',
                            child: Text('Recycle'),
                          ),
                          DropdownMenuItem(
                            value: 'Second hand',
                            child: Text('Second hand'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (v) => selectedCategory = v ?? 'Recycle',
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
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
                                      imageQuality: 85,
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
                          final discountText = discountPercentController.text
                              .trim();
                          final discountPercentValue = discountText.isEmpty
                              ? 0
                              : int.parse(discountText);

                          setState(() {
                            _isSubmitting = true;
                          });
                          setDialogState(() {});

                          try {
                            final navigator = Navigator.of(context);
                            final response =
                                await postMultipartItemWithFallback(
                                  fields: {
                                    'name': nameController.text.trim(),
                                    'price': priceController.text.trim(),
                                    'location': locationController.text.trim(),
                                    'discountPercent': discountPercentValue
                                        .toString(),
                                    'category': selectedCategory,
                                    'description': descriptionController.text
                                        .trim(),
                                  },
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
      // Main home content (existing layout)
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderBar(
                searchController: _searchController,
                onFilterPressed: _showFilterSheet,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredItems.isEmpty
                      ? const Center(
                          child: Text('Belum ada item. Tambahkan item dulu.'),
                        )
                      : GridView.builder(
                          itemCount: _filteredItems.length,
                          padding: const EdgeInsets.only(bottom: 90),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 310,
                              ),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return _ItemCard(
                              item: item,
                              onAddToCart: _addToCart,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Promo page: items on promo or with discount
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPromoPage(),
        ),
      ),

      // Cart page (placeholder for now)
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCartPage(),
        ),
      ),

      // Account / Settings page
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildAccountPage(),
        ),
      ),
    ];

    final titles = ['Daurin', 'Promo', 'Keranjang', 'Akun'];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F3),
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        centerTitle: false,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterSheet,
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
        Expanded(
          child: ListView.separated(
            itemCount: _cart.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, idx) {
              final ci = _cart[idx];
              return ListTile(
                leading: ci.item.imageUrl != null
                    ? Image.network(
                        buildApiUrl(ci.item.imageUrl!),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox(width: 56, height: 56),
                title: Text(ci.item.name),
                subtitle: Text('Rp ${ci.item.price} x ${ci.quantity}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (ci.quantity > 1) {
                          setState(() {
                            _cart[idx] = ci.copyWith(quantity: ci.quantity - 1);
                          });
                        } else {
                          _removeFromCart(ci.item.id);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() {
                          _cart[idx] = ci.copyWith(quantity: ci.quantity + 1);
                        });
                      },
                    ),
                  ],
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
              Text(
                'Total: Rp $_cartTotal',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () {
                  _showMessage('Checkout belum diimplementasikan');
                },
                child: const Text('Checkout'),
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

  void _showFilterSheet() {
    final areaOptions = [
      'Jabodetabek',
      'West Jakarta',
      'East Jakarta',
      'Central Jakarta',
      'South Jakarta',
    ];
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
                    children: ([...areaOptions, 'Other'])
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
    final standard = [
      'Jabodetabek',
      'West Jakarta',
      'East Jakarta',
      'Central Jakarta',
      'South Jakarta',
    ];
    return standard.contains(area);
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
      ),
      child: GridView.builder(
        itemCount: promoItems.length,
        padding: const EdgeInsets.only(bottom: 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 310,
        ),
        itemBuilder: (context, index) =>
            _ItemCard(item: promoItems[index], onAddToCart: _addToCart),
      ),
    );
  }

  Widget _buildAccountPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Akun',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildProfileSummaryCard(),
          const SizedBox(height: 12),
          _buildLocationCard(),
          const SizedBox(height: 12),
          _buildDarkModeCard(),
          const SizedBox(height: 12),
          _buildLogoutCard(),
        ],
      ),
    );
  }

  Widget _buildProfileSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.person, color: Colors.green.shade800),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _accountUsernameController.text.isEmpty
                          ? 'Nama akun belum diisi'
                          : _accountUsernameController.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accountEmailController.text.isEmpty
                          ? 'Email belum diisi'
                          : _accountEmailController.text,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _accountAddressController.text.isEmpty
                ? 'Alamat belum diisi'
                : _accountAddressController.text,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text(
                'Lokasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  _locationStatus,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _detectedLocationText,
            style: TextStyle(color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _detectCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Detect Location'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDarkModeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.dark_mode_outlined),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text('Tampilan gelap langsung aktif setelah diubah.'),
              ],
            ),
          ),
          Switch(
            value: _darkMode,
            onChanged: (v) async {
              setState(() => _darkMode = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dark_mode', v);
              _showMessage('Dark mode ${v ? 'aktif' : 'non-aktif'}.');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keluar akun',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Logout akan membawa kamu kembali ke halaman login.',
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Logout dari akun?'),
                    content: const Text(
                      'Kamu akan keluar dan perlu login lagi untuk masuk.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (!mounted) return;
                  final navigator = Navigator.of(context);
                  navigator.pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
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
              fillColor: Colors.white,
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
  const _ItemCard({required this.item, this.onAddToCart});

  final _Item item;
  final void Function(_Item)? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row at top left - compact
          if (item.isPromoted ||
              (item.discountPercent != null && item.discountPercent! > 0))
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
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
                if (item.discountPercent != null && item.discountPercent! > 0)
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
          if (item.isPromoted ||
              (item.discountPercent != null && item.discountPercent! > 0))
            const SizedBox(height: 8),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                buildApiUrl(item.imageUrl!),
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          if (item.category != null && item.category!.isNotEmpty) ...[
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
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
          if (item.promoNote != null && item.promoNote!.isNotEmpty) ...[
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
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: onAddToCart == null
                    ? null
                    : () => onAddToCart!(item),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  minimumSize: const Size(72, 36),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
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
              if (item.category != null && item.category!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Category: ${item.category!}', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade800)),
              ],
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.description!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
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
    this.imageUrl,
    this.isPromoted = false,
    this.discountPercent,
    this.discountedPrice,
    this.promoNote,
    this.category,
    this.description,
  });

  final String id;
  final String name;
  final int price;
  final String location;
  final String? imageUrl;
  final bool isPromoted;
  final int? discountPercent;
  final int? discountedPrice;
  final String? promoNote;
  final String? category;
  final String? description;

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
      imageUrl: json['imageUrl']?.toString(),
      isPromoted:
          json['isPromoted'] == true ||
          json['isPromoted']?.toString() == 'true',
      discountPercent: _parseOptionalInt(json['discountPercent']),
      discountedPrice: _parseOptionalInt(json['discountedPrice']),
      promoNote: json['promoNote']?.toString(),
      category: json['category']?.toString(),
      description: json['description']?.toString(),
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
