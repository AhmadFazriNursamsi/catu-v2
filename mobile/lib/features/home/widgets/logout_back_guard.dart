import 'package:flutter/material.dart';

/// Konfirmasi keluar akun. Mengembalikan true bila pengguna memilih keluar.
Future<bool> confirmLogout(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.logout_rounded, size: 30, color: Color(0xFFDC2626)),
      title: const Text('Keluar dari akun?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: const Text(
        'Menekan tombol kembali di beranda berarti Anda akan keluar (logout) dari akun ini.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w700))),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Ya, Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result == true;
}

/// Menahan tombol kembali pada layar utama: kembali berarti logout, jadi minta konfirmasi dulu.
class LogoutBackGuard extends StatelessWidget {
  final Widget child;
  final VoidCallback onLogout;
  const LogoutBackGuard({super.key, required this.child, required this.onLogout});

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await confirmLogout(context)) onLogout();
        },
        child: child,
      );
}
