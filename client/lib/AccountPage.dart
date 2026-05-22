import 'package:flutter/material.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({
    Key? key,
    required this.username,
    required this.email,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.locationStatus,
    required this.locationText,
    required this.onDetectLocation,
    required this.onLogout,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onAboutUs,
    required this.onFaq,
  }) : super(key: key);

  final String username;
  final String email;
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final String locationStatus;
  final String locationText;
  final VoidCallback onDetectLocation;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onAboutUs;
  final VoidCallback onFaq;

  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var darkModeValue = isDarkMode;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile.adaptive(
                      value: darkModeValue,
                      onChanged: (value) {
                        setSheetState(() {
                          darkModeValue = value;
                        });
                        onToggleDarkMode(value);
                      },
                      title: const Text('Dark Mode'),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                    ListTile(
                      leading: const Icon(Icons.my_location),
                      title: const Text('Detect Location'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onDetectLocation();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit Profile'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onEditProfile();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Change Password'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onChangePassword();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About Us'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onAboutUs();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('FAQ'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onFaq();
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          onLogout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
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
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(email, style: const TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Location',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        locationStatus,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    locationText,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showAccountMenu(context),
                icon: const Icon(Icons.tune),
                label: const Text('Menu Akun'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
