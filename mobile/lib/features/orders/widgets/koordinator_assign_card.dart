import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/koordinator_assignment_api.dart';
import '../koordinator_assign_screen.dart';

const _amber = Color(0xFFD97706);

/// Kartu di detail pelayanan untuk Koordinator: pelayanan belum ada Romo -> tombol "Carikan Romo".
/// Tidak menampilkan apa pun untuk peran lain, pelayanan yang sudah diterima, atau bila gagal memuat.
class KoordinatorAssignCard extends StatefulWidget {
  final int orderId;
  final VoidCallback onAssigned;
  final AssignmentLoader? loader;
  /// Untuk uji: menggantikan pemeriksaan peran dari sesi.
  final bool? isKoordinator;
  const KoordinatorAssignCard({super.key, required this.orderId, required this.onAssigned, this.loader, this.isKoordinator});

  @override
  State<KoordinatorAssignCard> createState() => _KoordinatorAssignCardState();
}

class _KoordinatorAssignCardState extends State<KoordinatorAssignCard> {
  KoordinatorAssignment? _data;

  bool get _isKoordinator {
    if (widget.isKoordinator != null) return widget.isKoordinator!;
    final user = AuthService.currentUser;
    return (user?['roleCode'] ?? user?['role_code'] ?? '').toString().toUpperCase().contains('KOORDINATOR');
  }

  @override
  void initState() {
    super.initState();
    if (_isKoordinator) _load();
  }

  Future<void> _load() async {
    try {
      final data = await (widget.loader ?? KoordinatorAssignmentApi.load)(widget.orderId);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      // Di luar wilayah / gagal memuat: kartu tidak ditampilkan.
    }
  }

  /// Belum lewat batas menit: tombol tetap ada, tetapi hanya menampilkan peringatan sampai waktu yang tepat.
  Future<void> _alertNotYet() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.schedule_rounded, color: _amber, size: 32),
          title: const Text('Belum Saatnya', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(_data?.reason ?? 'Pelayanan ini belum dapat dicarikan Romo.', style: const TextStyle(height: 1.4)),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mengerti'))],
        ),
      );

  Future<void> _open() async {
    final assigned = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => KoordinatorAssignScreen(orderId: widget.orderId, loader: widget.loader)));
    if (assigned == true) widget.onAssigned();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null || data.state == 'CLOSED') return const SizedBox.shrink();
    final open = data.state == 'OPEN';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFED7AA))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_search_rounded, color: _amber),
              const SizedBox(width: 10),
              Expanded(child: Text(open ? 'Pelayanan ini belum ada Romo' : 'Menunggu Romo Paroki / Ordo', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF7C2D12)))),
            ]),
            const SizedBox(height: 6),
            Text(open ? 'Belum diterima Romo Paroki maupun Romo Ordo. Pilih Romo terdaftar untuk melayani.' : (data.reason ?? ''), style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A3412), height: 1.4)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: open ? _open : _alertNotYet,
                icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                label: const Text('Carikan Romo', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(backgroundColor: _amber, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
