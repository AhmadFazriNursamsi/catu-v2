// CATU — Hapus akun sendiri (syarat App Store 5.1.1(v) dan Google Play).
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_http.dart' as http;

const _danger = Color(0xFFDC2626);

/// Konfirmasi dengan kata sandi lalu hapus akun di server. Setelah berhasil, [onDeleted] dipanggil (keluar dari aplikasi).
Future<void> confirmDeleteAccount(BuildContext context, {required VoidCallback onDeleted}) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (deleted != true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Akun Dihapus', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text('Akun CATU Anda telah dihapus. Terima kasih telah menggunakan CATU.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
  onDeleted();
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Masukkan kata sandi Anda.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiService.baseUrl}/auth/account'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': _password.text}),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _error = _messageOf(response.body) ?? 'Gagal menghapus akun (kode ${response.statusCode}).');
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal terhubung ke server. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _messageOf(String body) {
    try {
      final message = (jsonDecode(body) as Map)['message'];
      if (message is List) return message.join(', ');
      return message?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.delete_forever_rounded, color: _danger),
          SizedBox(width: 10),
          Expanded(child: Text('Hapus Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akun akan dihapus permanen dan tidak dapat dipulihkan:\n'
              '• Nama, email, alamat, tanggal lahir dan foto Anda dihapus.\n'
              '• Anda keluar dari semua grup chat dan tidak menerima notifikasi lagi.\n'
              '• Riwayat pelayanan tetap tercatat di paroki atas nama "Pengguna terhapus".\n'
              '• Nomor HP dapat dipakai untuk mendaftar ulang sebagai akun baru.\n\n'
              'Pelayanan yang masih berjalan harus selesai atau dibatalkan terlebih dahulu.',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: _error,
                errorMaxLines: 4,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _danger,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Hapus Permanen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
