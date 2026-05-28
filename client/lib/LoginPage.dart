import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import 'HomePage.dart';
import 'RegisterPage.dart';
import 'pin_gate.dart';

const String _brandLogoAsset = 'assets/images/Logo.jpeg';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.clipPath(Path()..addOval(rect));

    canvas.drawArc(
      rect,
      -2.618,
      1.571,
      true,
      Paint()..color = const Color(0xFFEA4335),
    );
    canvas.drawArc(
      rect,
      -1.047,
      2.094,
      true,
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawArc(
      rect,
      1.047,
      1.571,
      true,
      Paint()..color = const Color(0xFFFBBC05),
    );
    canvas.drawArc(
      rect,
      2.618,
      0.524,
      true,
      Paint()..color = const Color(0xFF34A853),
    );

    canvas.drawCircle(center, radius * 0.65, Paint()..color = Colors.white);

    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - radius * 0.18,
        radius * 0.95,
        radius * 0.36,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '842210818086-c05k5hpkj46m8mge2km51ss2irql4c57.apps.googleusercontent.com',
  );
  late final Future<void> _googleSignInInit = _googleSignIn.initialize();
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

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _googleSignInInit;
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      if (!mounted) return;
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final response = await postJsonWithFallback(
        path: '/auth/google',
        body: jsonEncode({
          'idToken': googleAuth.idToken,
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
        }),
      );

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await PinGate.setActiveAccountIdentifier(googleUser.email);
        await _showStatusDialog(
          title: 'Login Berhasil',
          message:
              'Selamat datang, ${googleUser.displayName ?? googleUser.email}!',
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
      await _showStatusDialog(
        title: 'Login Google Gagal',
        message: data?['message'] is String
            ? data!['message']
            : 'Gagal masuk dengan Google. Coba lagi.',
        isSuccess: false,
      );
    } catch (e) {
      if (!mounted) return;
      await _showStatusDialog(
        title: 'Koneksi Gagal',
        message: 'Tidak bisa login dengan Google: ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Masuk')),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F5EF), Color(0xFFFDFCF8)],
            ),
          ),
          child: SingleChildScrollView(
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
                            'Masuk ke Daurin',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kelola akun, chat seller, dan cek ongkir dengan lebih nyaman.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
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
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Password wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading || _isGoogleLoading
                                    ? null
                                    : _loginWithGoogle,
                                icon: _isGoogleLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CustomPaint(
                                          painter: _GoogleLogoPainter(),
                                        ),
                                      ),
                                label: const Text('Login dengan Google'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterPage(
                                    initialEmail:
                                        _identifierController.text.contains('@')
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
