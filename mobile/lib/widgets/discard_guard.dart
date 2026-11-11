import 'package:flutter/material.dart';

/// Menahan tombol kembali (AppBar maupun tombol/gestur kembali Android) saat [active]: tampilkan
/// konfirmasi "Apakah yakin mau Batal Kirim?" dan baru keluar bila pengguna memilih Ya.
/// Navigator.pop langsung (mis. setelah berhasil kirim) tidak ditahan.
class DiscardGuard extends StatelessWidget {
  final bool active;
  final Widget child;
  const DiscardGuard({super.key, required this.active, required this.child});

  static Future<bool> confirm(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batal Kirim?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Apakah yakin mau Batal Kirim? Misa yang sudah ditambahkan tidak akan disimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    return yes == true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !active,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await confirm(context) && context.mounted) Navigator.of(context).pop();
        },
        child: child,
      );
}
