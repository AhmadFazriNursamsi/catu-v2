import 'package:flutter/material.dart';
import '../../core/models/models.dart';

const _terminalStatuses = {'DONE', 'CLOSE', 'FAIL', 'CANCELLED', 'REJECTED'};

/// Konfirmasi sebelum menghapus satu riwayat kunjungan; true bila pengguna memilih Hapus.
/// Kunjungan yang masih punya pelayanan aktif (belum selesai/gagal/dibatalkan) tidak boleh dihapus.
Future<bool> confirmDeleteKunjungan(BuildContext context, Map<String, dynamic> item, List<Order> orders) async {
  final active = orders.where((o) => !_terminalStatuses.contains(o.status.toUpperCase())).length;
  final place = '${item['alamat'] ?? '-'} (${item['kota'] ?? '-'})';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(active > 0 ? 'Belum Bisa Dihapus' : 'Hapus Riwayat Kunjungan?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Text(active > 0
          ? 'Kunjungan di $place masih punya $active pelayanan yang berjalan. Riwayat bisa dihapus setelah semua pelayanannya selesai, gagal, atau dibatalkan.'
          : 'Kunjungan di $place akan dihapus dari riwayat.${orders.isNotEmpty ? ' ${orders.length} pelayanan terkait yang sudah selesai tetap tersimpan di Riwayat Permintaan.' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(active > 0 ? 'Mengerti' : 'Batal')),
        if (active == 0)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
      ],
    ),
  );
  return ok == true;
}
