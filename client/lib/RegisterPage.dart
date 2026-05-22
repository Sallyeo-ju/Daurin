import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'api_client.dart';

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
        await _showStatusDialog(
          title: 'Register Berhasil',
          message: 'Akun berhasil dibuat, silakan login.',
          isSuccess: true,
        );
        if (!mounted) {
          return;
        }
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'No telp wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration:
                      const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
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
                  decoration:
                      const InputDecoration(
                        labelText: 'Re-enter Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ).copyWith(
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
                    if (value == null || value.isEmpty) {
                      return 'Konfirmasi password wajib diisi';
                    }
                    if (value != _passwordController.text) {
                      return 'Password tidak sama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
