import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class Address {
  Address({
    required this.street,
    required this.city,
    required this.province,
    required this.postalCode,
    this.rt,
    this.rw,
    this.isDefault = false,
  });

  String street;
  String city;
  String province;
  String postalCode;
  String? rt;
  String? rw;
  bool isDefault;

  Map<String, dynamic> toJson() => {
        'street': street,
        'city': city,
        'province': province,
        'postalCode': postalCode,
        'rt': rt,
        'rw': rw,
        'isDefault': isDefault,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] ?? '',
        city: json['city'] ?? '',
        province: json['province'] ?? '',
        postalCode: json['postalCode'] ?? '',
        rt: json['rt'],
        rw: json['rw'],
        isDefault: json['isDefault'] ?? false,
      );
}

class ManageAddressesPage extends StatefulWidget {
  const ManageAddressesPage({super.key});

  @override
  State<ManageAddressesPage> createState() => _ManageAddressesPageState();
}

class _ManageAddressesPageState extends State<ManageAddressesPage> {
  List<Address> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    try {
      final response = await getJsonWithFallback(path: '/auth/addresses');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final addresses = (decoded as List)
            .map((a) => Address.fromJson(a as Map<String, dynamic>))
            .toList();

        setState(() => _addresses = addresses);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading addresses: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(int index) async {
    try {
      final response = await http.delete(
        Uri.parse('${buildApiUrl('/auth/addresses/$index')}'),
        headers: const {'Content-Type': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _addresses.removeAt(index));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat berhasil dihapus')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddressForm({int? editIndex}) {
    final isEditing = editIndex != null;
    final address = isEditing ? _addresses[editIndex] : Address(
      street: '',
      city: '',
      province: '',
      postalCode: '',
    );

    final streetController = TextEditingController(text: address.street);
    final cityController = TextEditingController(text: address.city);
    final provinceController = TextEditingController(text: address.province);
    final postalCodeController = TextEditingController(text: address.postalCode);
    final rtController = TextEditingController(text: address.rt ?? '');
    final rwController = TextEditingController(text: address.rw ?? '');
    bool isDefault = address.isDefault;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEditing ? 'Edit Address' : 'Add Address',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: streetController,
                      decoration: const InputDecoration(
                        labelText: 'Street Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: provinceController,
                      decoration: const InputDecoration(
                        labelText: 'Province',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rtController,
                            decoration: const InputDecoration(
                              labelText: 'RT',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: rwController,
                            decoration: const InputDecoration(
                              labelText: 'RW',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Postal Code',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: isDefault,
                      onChanged: (v) {
                        setState(() => isDefault = v ?? false);
                      },
                      title: const Text('Set as default address'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final newAddress = Address(
                            street: streetController.text,
                            city: cityController.text,
                            province: provinceController.text,
                            postalCode: postalCodeController.text,
                            rt: rtController.text.isEmpty
                                ? null
                                : rtController.text,
                            rw: rwController.text.isEmpty
                                ? null
                                : rwController.text,
                            isDefault: isDefault,
                          );

                          try {
                            if (isEditing) {
                              final response = await postJsonWithFallback(
                                path: '/auth/addresses/$editIndex',
                                body: jsonEncode(newAddress.toJson()),
                              );

                              if (response.statusCode >= 200 &&
                                  response.statusCode < 300) {
                                setState(() {
                                  _addresses[editIndex] = newAddress;
                                });
                              }
                            } else {
                              final response = await postJsonWithFallback(
                                path: '/auth/addresses',
                                body: jsonEncode(newAddress.toJson()),
                              );

                              if (response.statusCode >= 200 &&
                                  response.statusCode < 300) {
                                setState(() {
                                  _addresses.add(newAddress);
                                });
                              }
                            }

                            if (!mounted) return;
                            Navigator.of(sheetContext).pop();
                            _loadAddresses();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: Text(isEditing ? 'Update Address' : 'Add Address'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Addresses')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64),
                      const SizedBox(height: 16),
                      const Text('No addresses yet'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => _showAddressForm(),
                        child: const Text('Add Address'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (ctx, i) {
                    final addr = _addresses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(addr.street),
                        subtitle: Text(
                          '${addr.city}, ${addr.province} ${addr.postalCode}${addr.rt != null ? ' RT ${addr.rt}' : ''}${addr.rw != null ? ' RW ${addr.rw}' : ''}',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              child: const Text('Edit'),
                              onTap: () => _showAddressForm(editIndex: i),
                            ),
                            PopupMenuItem(
                              child: const Text('Delete'),
                              onTap: () => _deleteAddress(i),
                            ),
                          ],
                        ),
                        leading: addr.isDefault
                            ? const Icon(Icons.check_circle)
                            : null,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddressForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}