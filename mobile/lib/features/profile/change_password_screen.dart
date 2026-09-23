import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      _showSnackbar('Kata sandi baru dan konfirmasi tidak cocok', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnackbar('Kata sandi minimal 6 karakter', isError: true);
      return;
    }
    if (newPass == currentPass) {
      _showSnackbar('Kata sandi baru tidak boleh sama dengan kata sandi lama', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = widget.user['id'] ?? widget.user['user_id'] ?? widget.user['userId'];
      final phone = widget.user['phoneNumber'] ?? widget.user['phone_number'] ?? '';

      final url = Uri.parse('${ApiService.baseUrl}/auth/change-password');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'phoneNumber': phone,
              'currentPassword': currentPass,
              'newPassword': newPass,
            }),
          )
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          _showSuccessDialog();
        }
      } else {
        String msg = 'Gagal mengubah kata sandi.';
        if (data['message'] != null) {
          if (data['message'] is List) {
            msg = (data['message'] as List).join(', ');
          } else {
            msg = data['message'].toString();
          }
        }
        _showSnackbar(msg, isError: true);
      }
    } catch (_) {
      _showSnackbar('Gagal terhubung ke server backend. Periksa koneksi internet.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 34),
            ),
            const SizedBox(height: 14),
            const Text('Kata Sandi Diperbarui', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text('Kata sandi akun Anda berhasil diganti.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity, height: 42,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('OK, Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMinLength = _newPasswordController.text.length >= 6;
    final isMatching = _newPasswordController.text.isNotEmpty && _newPasswordController.text == _confirmPasswordController.text;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)), onPressed: () => Navigator.pop(context)),
          title: const Text('Ubah Kata Sandi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: _currentPasswordController, label: 'Kata Sandi Saat Ini', hint: 'Masukkan kata sandi lama',
                  obscure: _obscureCurrent, onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icons.lock_outline_rounded, validator: (v) => (v == null || v.isEmpty) ? 'Kata sandi saat ini wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _newPasswordController, label: 'Kata Sandi Baru', hint: 'Minimal 6 karakter',
                  obscure: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  icon: Icons.vpn_key_rounded, onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 16),
                _buildPasswordField(
                  controller: _confirmPasswordController, label: 'Konfirmasi Kata Sandi Baru', hint: 'Ulangi kata sandi baru',
                  obscure: _obscureConfirm, onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icons.check_circle_outline_rounded, onChanged: (_) => setState(() {}),
                  validator: (v) => (v != _newPasswordController.text) ? 'Konfirmasi kata sandi tidak cocok' : null,
                ),
                const SizedBox(height: 16),
                _buildIndicator('Minimal 6 karakter', hasMinLength),
                const SizedBox(height: 6),
                _buildIndicator('Kata sandi konfirmasi cocok', isMatching),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : const Text('Simpan Kata Sandi Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2), boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0066FF), size: 24)),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keamanan Akun', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                SizedBox(height: 2),
                Text('Gunakan kata sandi baru yang aman dan mudah Anda ingat.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String label, required String hint, required bool obscure, required VoidCallback onToggle, required IconData icon, ValueChanged<String>? onChanged, FormFieldValidator<String>? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller, obscureText: obscure, onChanged: onChanged, validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20), onPressed: onToggle),
            filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.6)),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(String text, bool met) => Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 15, color: met ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: met ? const Color(0xFF16A34A) : const Color(0xFF64748B))),
        ],
      );
}
