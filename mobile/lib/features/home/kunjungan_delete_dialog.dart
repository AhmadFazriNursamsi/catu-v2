import 'package:flutter/material.dart';

/// Konfirmasi sebelum menghapus satu riwayat kunjungan; true bila pengguna memilih Hapus.
Future<bool> confirmDeleteKunjungan(BuildContext context, Map<String, dynamic> item, int orderCount) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Hapus Riwayat Kunjungan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text(
        'Kunjungan di ${item['alamat'] ?? '-'} (${item['kota'] ?? '-'}) akan dihapus dari riwayat.'
        '${orderCount > 0 ? ' $orderCount permintaan pelayanan terkait tidak ikut terhapus.' : ''}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Hapus', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return ok == true;
}
