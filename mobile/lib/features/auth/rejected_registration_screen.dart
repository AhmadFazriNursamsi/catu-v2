import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../news/public_news_screen.dart';
import '../profile/edit_profile_screen.dart';

/// Pendaftaran ditolak: tampilkan alasan dan beri jalan keluar, yaitu memperbaiki data lalu mengajukan ulang.
class RejectedRegistrationScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const RejectedRegistrationScreen({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PublicNewsScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = (user['rejectionReason'] ?? '').toString().trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cancel_rounded, size: 72, color: Color(0xFFDC2626)),
              const SizedBox(height: 16),
              const Text('Pendaftaran Ditolak', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Pendaftaran Anda belum disetujui. Perbaiki data sesuai alasan di bawah, lalu ajukan kembali.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFECACA))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Alasan penolakan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                  const SizedBox(height: 4),
                  Text(reason.isEmpty ? 'Penyetuju tidak menuliskan alasan. Hubungi pengurus lingkungan Anda bila perlu.' : reason, style: const TextStyle(fontSize: 14, height: 1.4, color: AppConstants.textDark)),
                ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Perbaiki Data & Ajukan Ulang'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: user, onSaved: () {}, resubmit: true))),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => _logout(context), child: const Text('Keluar')),
            ]),
          ),
        ),
      ),
    );
  }
}
