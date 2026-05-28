import 'package:flutter/material.dart';

class Voucher {
  Voucher({
    required this.id,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.expiresOn,
    this.minCartValue,
    this.requiredCategory,
    this.isUsed = false,
  });

  final String id;
  final String title;
  final String description;
  final int discountPercent;
  final String expiresOn;
  final int? minCartValue;
  final String? requiredCategory;
  final bool isUsed;

  Voucher copyWith({
    String? id,
    String? title,
    String? description,
    int? discountPercent,
    String? expiresOn,
    int? minCartValue,
    String? requiredCategory,
    bool? isUsed,
  }) {
    return Voucher(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      discountPercent: discountPercent ?? this.discountPercent,
      expiresOn: expiresOn ?? this.expiresOn,
      minCartValue: minCartValue ?? this.minCartValue,
      requiredCategory: requiredCategory ?? this.requiredCategory,
      isUsed: isUsed ?? this.isUsed,
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.username,
    required this.email,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.onDetectLocation,
    required this.onLogout,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onManageAddresses,
    required this.onAboutUs,
    required this.onFaq,
    required this.vouchers,
    required this.recommendedVoucher,
    required this.onUseVoucher,
    this.selectedVoucherCode,
    this.locationStatus = '',
    this.locationText = '',
    this.profilePictureUrl,
  });

  final String username;
  final String email;
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final VoidCallback onDetectLocation;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onManageAddresses;
  final VoidCallback onAboutUs;
  final VoidCallback onFaq;
  final List<Voucher> vouchers;
  final Voucher? recommendedVoucher;
  final ValueChanged<String> onUseVoucher;
  final String? selectedVoucherCode;
  final String locationStatus;
  final String locationText;
  final String? profilePictureUrl;

  void _showVoucherSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Voucher Diskon',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (recommendedVoucher != null) ...{
                  ListTile(
                    title: Text('Rekomendasi: ${recommendedVoucher!.title}'),
                    subtitle: Text(recommendedVoucher!.description),
                    trailing: FilledButton(
                      onPressed: recommendedVoucher!.isUsed
                          ? null
                          : () => onUseVoucher(recommendedVoucher!.id),
                      child: const Text('Gunakan'),
                    ),
                  ),
                  const Divider(),
                },
                if (vouchers.isNotEmpty)
                  ...vouchers.map(
                    (v) => ListTile(
                      title: Text(v.title),
                      subtitle: Text(v.description),
                      trailing: FilledButton(
                        onPressed: v.isUsed ? null : () => onUseVoucher(v.id),
                        child: Text(v.isUsed ? 'Sudah digunakan' : 'Gunakan'),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Tidak ada voucher tersedia saat ini.'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: profilePictureUrl != null &&
                            profilePictureUrl!.isNotEmpty
                        ? NetworkImage(profilePictureUrl!)
                        : null,
                    child: profilePictureUrl == null ||
                            profilePictureUrl!.isEmpty
                        ? Text(
                            username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(email, style: theme.textTheme.bodySmall),
                        if (locationStatus.isNotEmpty ||
                            locationText.isNotEmpty) ...{
                          const SizedBox(height: 6),
                          Text(
                            locationStatus.isNotEmpty
                                ? '$locationStatus • $locationText'
                                : locationText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        },
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dark Mode Toggle
              SwitchListTile.adaptive(
                value: isDarkMode,
                onChanged: onToggleDarkMode,
                title: const Text('Dark Mode'),
              ),
              const Divider(),

              // Voucher
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: const Text('Voucher Diskon'),
                subtitle: const Text('Lihat dan pakai voucher aktif'),
                onTap: () => _showVoucherSheet(context),
              ),

              // Detect Location
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Detect Location'),
                onTap: onDetectLocation,
              ),

              // Edit Profile
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                subtitle: const Text('Ubah foto profil dan informasi'),
                onTap: onEditProfile,
              ),

              // Change Password
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Change Password'),
                subtitle: const Text('Ubah password akun Anda'),
                onTap: onChangePassword,
              ),

              // Manage Addresses
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Manage Addresses'),
                subtitle: const Text('Kelola alamat pengiriman'),
                onTap: onManageAddresses,
              ),

              // About Us
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About Us'),
                onTap: onAboutUs,
              ),

              // FAQ
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('FAQ'),
                onTap: onFaq,
              ),

              const SizedBox(height: 16),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}