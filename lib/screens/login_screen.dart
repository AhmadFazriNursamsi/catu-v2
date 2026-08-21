import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  bool _obscurePass = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    String phone = _phoneController.text.trim();
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    } else if (phone.startsWith('+62')) {
      phone = phone.substring(1);
    } else if (!phone.startsWith('62')) {
      phone = '62$phone';
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'password': _passController.text,
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final user = body['user'];
        final token = body['accessToken'] ?? '';
        final status = user['accountStatus'] ?? 'APPROVED';

        if (status == 'PENDING_APPROVAL') {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: const [
                  Icon(Icons.hourglass_top, color: Colors.amber, size: 28),
                  SizedBox(width: 10),
                  Text('Menunggu Persetujuan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Akun ${user['fullName']} (${user['roleCode']}) telah terdaftar dan saat ini berstatus MENUNGGU APPROVAL dari Pengurus Lingkungan / Administrator.',
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK, Mengerti'),
                ),
              ],
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(user: user, token: token),
            ),
          );
        }
      } else {
        final errorMsg = body['message'] is List
            ? (body['message'] as List).join('\n')
            : (body['message'] ?? 'Nomor HP atau kata sandi tidak valid.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(errorMsg, style: const TextStyle(color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Koneksi ke backend gagal: $e', style: const TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Selamat Datang',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.extrabold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aplikasi Pelayanan & Manajemen Umat Katolik CATU',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 35),

                // Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.indigo.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Image.asset('assets/images/catuv2_1.png', height: 95),
                  ),
                ),
                const SizedBox(height: 35),

                const Text(
                  'Masuk ke Akun Anda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),

                // Nomor WhatsApp / HP Input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Nomor WhatsApp / HP',
                    hintText: '081234567890',
                    prefixIcon: const Icon(Icons.phone_android, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.indigo, width: 2)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan nomor WhatsApp' : null,
                ),
                const SizedBox(height: 14),

                // Password Input
                TextFormField(
                  controller: _passController,
                  obscureText: _obscurePass,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.indigo),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.indigo, width: 2)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Masukkan kata sandi' : null,
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          activeColor: Colors.indigo.shade800,
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        ),
                        const Text('Ingat Saya', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Silakan hubungi Pengurus Lingkungan atau Admin untuk reset sandi.')),
                        );
                      },
                      child: Text('Lupa Password?', style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tombol Masuk
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade800,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),

                const SizedBox(height: 25),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Belum Punya Akun? ',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Daftar Disini',
                          style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 14),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.build_circle_outlined, size: 13, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          'v2.5.0-build.20260821.170800',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.3,
                          ),
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
    );
  }
}
