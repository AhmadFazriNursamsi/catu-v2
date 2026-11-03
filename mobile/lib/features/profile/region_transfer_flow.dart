import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../auth/pending_approval_screen.dart';

/// Konfirmasi sebelum Umat pindah lingkungan: perpindahan harus disetujui pengurus lingkungan tujuan.
Future<bool> confirmRegionTransfer(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Pindah lingkungan?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: const Text(
        'Perpindahan ini perlu disetujui pengurus lingkungan tujuan. Selama menunggu, akun Anda tidak dapat dipakai. '
        'Jika ditolak, Anda kembali ke lingkungan semula.',
        style: TextStyle(fontSize: 13.5, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajukan Pindah')),
      ],
    ),
  );
  return ok ?? false;
}

/// Pesan galat dari respons backend (`message` dapat berupa teks atau daftar).
String backendMessage(String body, String fallback) {
  try {
    final m = (jsonDecode(body) as Map)['message'];
    if (m is List && m.isNotEmpty) return m.join('\n');
    if (m is String && m.isNotEmpty) return m;
  } catch (_) {}
  return fallback;
}

/// Setelah permintaan pindah diajukan, akun berstatus menunggu: tampilkan layar menunggu persetujuan.
Future<void> openPendingAfterTransfer(BuildContext context, Map<String, dynamic> user) async {
  user['accountStatus'] = 'PENDING_APPROVAL';
  await AuthService.saveSession(user);
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(context, FadeSlideRoute(page: PendingApprovalScreen(user: user)), (_) => false);
}
