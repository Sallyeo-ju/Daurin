import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'pin_gate.dart';

const String _brandLogoAsset = 'assets/images/Logo.jpeg';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isSuccess
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Icon(
                  isSuccess ? Icons.check : Icons.close,
                  color: isSuccess
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(child: Text(message)),
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

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await postJsonWithFallback(
        path: '/auth/register',
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'account_username',
          _usernameController.text.trim(),
        );
        await prefs.setString('account_email', _emailController.text.trim());
        final registerData =
            jsonDecode(response.body) as Map<String, dynamic>?;
        final registerToken = registerData?['accessToken']?.toString() ?? '';
        await prefs.setString('auth_token', registerToken);

        // Auto-login after successful registration
        final loginResp = await postJsonWithFallback(
          path: '/auth/login',
          body: jsonEncode({
            'identifier': _emailController.text.trim(),
            'password': _passwordController.text,
          }),
        );

        if (loginResp.statusCode >= 200 && loginResp.statusCode < 300) {
          final loginData =
              jsonDecode(loginResp.body) as Map<String, dynamic>?;
          final loginToken = loginData?['accessToken']?.toString() ?? '';
          await prefs.setString('auth_token', loginToken);
          await PinGate.setActiveAccountIdentifier(
            _emailController.text.trim(),
          );

          // Ask user to create PIN now that they're logged in
          if (!mounted) return;
          await _promptCreatePin();
          if (!mounted) return;

          await _showStatusDialog(
            title: 'Register & Login Berhasil',
            message:
                'Akun dibuat dan Anda sudah login. Silakan buat PIN untuk keamanan.',
            isSuccess: true,
          );

          // Pop this page only once (the dialogs are already closed by the user)
          if (!mounted) return;
          Navigator.pop(context);
        } else {
          await _showStatusDialog(
            title: 'Register Berhasil',
            message: 'Akun berhasil dibuat. Silakan login.',
            isSuccess: true,
          );

          // Pop this page only once
          if (!mounted) return;
          Navigator.pop(context);
        }
      } else {
        final Map<String, dynamic>? data =
            jsonDecode(response.body) as Map<String, dynamic>?;
        final message = data?['message'];
        await _showStatusDialog(
          title: 'Register Gagal',
          message: message is String
              ? message
              : 'Register gagal. Silakan cek data kamu.',
          isSuccess: false,
        );
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      await _showStatusDialog(
        title: 'Timeout',
        message:
            'Request timeout. ${apiConnectionHint()} Pastikan backend hidup di port 3000.',
        isSuccess: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showStatusDialog(
        title: 'Koneksi Gagal',
        message:
            'Tidak bisa terhubung ke server. ${error.toString()}. ${apiConnectionHint()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _promptCreatePin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buat PIN'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'PIN 6 digit'),
                ),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi PIN',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            // ignore: use_build_context_synchronously
            FilledButton(
              // ignore: use_build_context_synchronously
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(ctx);
                final p = pinController.text.trim();
                final c = confirmController.text.trim();
                if (p.length != 6 || !RegExp(r'^\d{6}$').hasMatch(p)) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('PIN harus 6 digit angka.')),
                  );
                  return;
                }
                if (p != c) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Konfirmasi PIN tidak cocok.'),
                    ),
                  );
                  return;
                }
                // Call backend to set PIN
                try {
                  final resp = await postJsonWithFallback(
                    path: '/auth/set-pin',
                    body: jsonEncode({
                      'identifier': _emailController.text.trim(),
                      'pin': p,
                    }),
                  );
                  if (resp.statusCode >= 200 && resp.statusCode < 300) {
                    await PinGate.savePinForAliases(
                      email: _emailController.text.trim(),
                      username: _usernameController.text.trim(),
                      pin: p,
                    );
                    // ignore: use_build_context_synchronously
                    Navigator.pop(ctx, true);
                    return;
                  }
                } catch (_) {}

                // fallback: save locally only
                await PinGate.savePinForAliases(
                  email: _emailController.text.trim(),
                  username: _usernameController.text.trim(),
                  pin: p,
                );
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx, true);
              },
              child: const Text('Simpan PIN'),
            ),
          ],
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Akun')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8F5EF), Color(0xFFFDFCF8)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    // Prevent bottom overflow on smaller screens/keyboard.
                    physics: const BouncingScrollPhysics(),
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 120),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.brown.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Image.asset(
                                    _brandLogoAsset,
                                    width: 78,
                                    height: 78,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Buat akun Daurin',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Setelah daftar, kamu langsung login lalu diminta membuat PIN untuk keamanan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Username',
                                        prefixIcon: Icon(Icons.person),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Username wajib diisi';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(Icons.email),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Email wajib diisi';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Format email tidak valid';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'No Telp',
                                        prefixIcon: Icon(Icons.phone),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'No telp wajib diisi';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(Icons.lock),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty) {
                                          return 'Password wajib diisi';
                                        }
                                        if (value.length < 6) {
                                          return 'Password minimal 6 karakter';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      decoration: InputDecoration(
                                        labelText: 'Re-enter Password',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty) {
                                          return 'Konfirmasi password wajib diisi';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Password tidak sama';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _register,
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Register'),
                                      ),
                                    ),
                                  ],
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
            );
          },
        ),
      ),
    );
  }
}
