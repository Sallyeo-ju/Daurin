import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class PinGate {
  static const String _activeAccountIdentifierKey = 'active_account_identifier';
  static const String _pinPrefix = 'account_pin_';
  static const String _failCountPrefix = 'pin_fail_count_';
  static const String _lockUntilPrefix = 'pin_lock_until_';

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _pinKey(String accountIdentifier) =>
      '$_pinPrefix${_normalize(accountIdentifier)}';

  static String _failCountKey(String accountIdentifier) =>
      '$_failCountPrefix${_normalize(accountIdentifier)}';

  static String _lockUntilKey(String accountIdentifier) =>
      '$_lockUntilPrefix${_normalize(accountIdentifier)}';

  static Future<void> setActiveAccountIdentifier(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeAccountIdentifierKey, _normalize(identifier));
  }

  static Future<String?> getActiveAccountIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final identifier = prefs.getString(_activeAccountIdentifierKey);
    if (identifier == null || identifier.trim().isEmpty) {
      return null;
    }
    return identifier;
  }

  static Future<void> savePinForAccount({
    required String identifier,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accountKey = _normalize(identifier);
    await prefs.setString(_pinKey(accountKey), pin);
    await prefs.setInt(_failCountKey(accountKey), 0);
    await prefs.remove(_lockUntilKey(accountKey));
  }

  static Future<void> savePinForAliases({
    required String email,
    required String username,
    required String pin,
  }) async {
    await savePinForAccount(identifier: email, pin: pin);
    await savePinForAccount(identifier: username, pin: pin);
    await setActiveAccountIdentifier(email);
  }

  static Future<bool> requirePin(
    BuildContext context, {
    required String purpose,
    required ScaffoldMessengerState messenger,
    String? identifier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accountIdentifier = _normalize(
      identifier ?? prefs.getString(_activeAccountIdentifierKey) ?? '',
    );

    if (accountIdentifier.isEmpty) {
      _showSnackBar(messenger, 'Akun belum dipilih, silakan login ulang.');
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final lockedUntil = prefs.getInt(_lockUntilKey(accountIdentifier)) ?? 0;
    if (lockedUntil > now) {
      final remainingSeconds = ((lockedUntil - now) / 1000).ceil();
      _showSnackBar(
        messenger,
        'Akun dibekukan $remainingSeconds detik karena PIN salah.',
      );
      return false;
    }

    final enteredPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final controller = TextEditingController();
        bool obscurePin = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Masukkan PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Untuk $purpose, masukkan PIN 6 digit.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: obscurePin,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'PIN 6 digit',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePin ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePin = !obscurePin;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(controller.text.trim());
                  },
                  child: const Text('Lanjut'),
                ),
              ],
            );
          },
        );
      },
    );

    if (enteredPin == null || enteredPin.length != 6) {
      if (enteredPin != null) {
        _showSnackBar(messenger, 'PIN harus 6 digit angka.');
      }
      return false;
    }

    final isPinValid = await _verifyPinWithBackend(
      identifier: accountIdentifier,
      pin: enteredPin,
      prefs: prefs,
    );

    if (!isPinValid) {
      final failCount =
          (prefs.getInt(_failCountKey(accountIdentifier)) ?? 0) + 1;
      if (failCount >= 3) {
        await prefs.setInt(_failCountKey(accountIdentifier), 0);
        await prefs.setInt(
          _lockUntilKey(accountIdentifier),
          DateTime.now()
              .add(const Duration(seconds: 30))
              .millisecondsSinceEpoch,
        );
        _showSnackBar(messenger, 'PIN salah 3 kali. Akun dibekukan 30 detik.');
      } else {
        await prefs.setInt(_failCountKey(accountIdentifier), failCount);
        _showSnackBar(messenger, 'PIN salah. Sisa percobaan ${3 - failCount}.');
      }
      return false;
    }

    await prefs.setInt(_failCountKey(accountIdentifier), 0);
    await prefs.remove(_lockUntilKey(accountIdentifier));
    return true;
  }

  static Future<bool> _verifyPinWithBackend({
    required String identifier,
    required String pin,
    required SharedPreferences prefs,
  }) async {
    try {
      final response = await postJsonWithFallback(
        path: '/auth/verify-pin',
        body: jsonEncode({'identifier': identifier, 'pin': pin}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(_pinKey(identifier), pin);
        return true;
      }

      return false;
    } catch (_) {
      final cachedPin = prefs.getString(_pinKey(identifier));
      return cachedPin != null && cachedPin == pin;
    }
  }

  static void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
