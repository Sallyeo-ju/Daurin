import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'HomePage.dart';
import 'RegisterPage.dart';
import 'pin_gate.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await postJsonWithFallback(
        path: '/auth/login',
        body: jsonEncode({
          'identifier': _identifierController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic>? data =
            jsonDecode(response.body) as Map<String, dynamic>?;
        final user = data?['user'];
        if (user is Map<String, dynamic>) {
          final email = user['email']?.toString() ?? '';
          final username = user['username']?.toString() ?? '';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('account_username', username);
          await prefs.setString('account_email', email);
          if (email.isNotEmpty) {
            await PinGate.setActiveAccountIdentifier(email);
          } else if (username.isNotEmpty) {
            await PinGate.setActiveAccountIdentifier(username);
          }
        }

        await _showStatusDialog(
          title: 'Login Berhasil',
          message: 'Selamat datang di Daurin.',
          isSuccess: true,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const HomePage()),
        );
        return;
      }

      final Map<String, dynamic>? data =
          jsonDecode(response.body) as Map<String, dynamic>?;
      final message = data?['message'];
      await _showStatusDialog(
        title: 'Login Gagal',
        message: message is String ? message : 'Login gagal.',
        isSuccess: false,
      );
    } on TimeoutException {
      await _showStatusDialog(
        title: 'Timeout',
        message: 'Request timeout. ${apiConnectionHint()}',
        isSuccess: false,
      );
    } catch (e) {
      await _showStatusDialog(
        title: 'Koneksi Gagal',
        message: 'Tidak bisa terhubung ke server. ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _quickLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('account_username')?.trim();
    final savedEmail = prefs.getString('account_email')?.trim();
    final savedPassword = prefs.getString('account_password') ?? '';

    if ((savedUsername == null || savedUsername.isEmpty) &&
        (savedEmail == null || savedEmail.isEmpty)) {
      await _showStatusDialog(
        title: 'Quick Login tidak tersedia',
        message: 'Tidak ada kredensial tersimpan.',
        isSuccess: false,
      );
      return;
    }

    if (savedPassword.isEmpty) {
      await _showStatusDialog(
        title: 'Quick Login tidak tersedia',
        message: 'Password tidak tersimpan.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final identifier = (savedUsername != null && savedUsername.isNotEmpty)
          ? savedUsername
          : savedEmail!;
      final response = await postJsonWithFallback(
        path: '/auth/login',
        body: jsonEncode({'identifier': identifier, 'password': savedPassword}),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _showStatusDialog(
          title: 'Quick Login Berhasil',
          message: 'Login otomatis berhasil.',
          isSuccess: true,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (c) => const HomePage()),
        );
        return;
      }
      final Map<String, dynamic>? data =
          jsonDecode(response.body) as Map<String, dynamic>?;
      final message = data?['message'];
      await _showStatusDialog(
        title: 'Quick Login Gagal',
        message: message is String ? message : 'Login gagal.',
        isSuccess: false,
      );
    } catch (e) {
      await _showStatusDialog(
        title: 'Quick Login Error',
        message: 'Terjadi kesalahan: ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 80,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      labelText: 'Email / Username',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Email atau username wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Password wajib diisi' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _isLoading ? null : _quickLogin,
                    child: const Text('Quick Login'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterPage(
                          initialEmail: _identifierController.text.contains('@')
                              ? _identifierController.text
                              : '',
                        ),
                      ),
                    ),
                    child: const Text('Belum punya akun? Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
