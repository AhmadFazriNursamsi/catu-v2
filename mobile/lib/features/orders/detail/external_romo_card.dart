import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/models.dart';

/// Kartu "Romo yang Bertugas" bila pelayanan dialihkan ke Romo Eksternal (di luar CATU).

const _amber = Color(0xFFB45309);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Pengalihan ke Romo Eksternal yang berlaku untuk [item] (atau seluruh order), terbaru lebih dulu; null bila tidak ada.
OrderRomoHandover? externalHandoverOf(Order order, OrderItem? item) {
  final perItem = order.items.isNotEmpty && item != null;
  if (perItem && item.acceptedRomoId != null) return null;
  if (!perItem && order.acceptedRomoId != null) return null;
  for (final h in order.handoverHistory) {
    if (h.handoverType.toUpperCase() != 'EXTERNAL_ROMO' || h.status.toUpperCase() != 'ACCEPTED') continue;
    if (!perItem || h.itemId == null || h.itemId == item.id) return h;
  }
  return null;
}

/// Memisahkan "Nama (08123)" menjadi nama dan nomor ponsel.
(String, String) splitExternalRomo(String raw) {
  final m = RegExp(r'^(.*?)\s*\(([\d+\-\s]{6,})\)\s*$').firstMatch(raw.trim());
  if (m == null) return (raw.trim(), '');
  return (m.group(1)!.trim(), m.group(2)!.replaceAll(RegExp(r'[\s-]'), ''));
}

String _when(String? raw) {
  final d = DateTime.tryParse(raw ?? '')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}.${two(d.minute)} WIB';
}

class ExternalRomoCard extends StatelessWidget {
  final OrderRomoHandover handover;
  /// Nama yang tersimpan di pelayanan; dipakai bila riwayat tidak membawa nama romo eksternal.
  final String fallbackName;
  const ExternalRomoCard({super.key, required this.handover, required this.fallbackName});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka aplikasi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (name, phone) = splitExternalRomo(handover.externalRomoName ?? fallbackName);
    final wa = phone.startsWith('0') ? '62${phone.substring(1)}' : phone.replaceFirst('+', '');
    final when = _when(handover.createdAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _amber.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.person_pin_rounded, color: _amber, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Romo yang Bertugas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
            child: const Text('Romo Eksternal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _amber)),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Romo ${name.isEmpty ? '-' : name}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 2),
        const Text('Romo dari luar aplikasi CATU (belum terdaftar)', style: TextStyle(fontSize: 12.5, color: _muted)),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.phone_rounded, size: 16, color: _muted),
            const SizedBox(width: 6),
            SelectableText(phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _open(context, Uri.parse('tel:$phone')),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Telepon'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E5399), padding: const EdgeInsets.symmetric(vertical: 11)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _open(context, Uri.parse('https://wa.me/$wa')),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF15803D),
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 12),
        _row(Icons.swap_horiz_rounded, 'Dialihkan oleh', 'Romo ${handover.previousRomoName}'),
        if (when.isNotEmpty) _row(Icons.schedule_rounded, 'Waktu pengalihan', when),
        if (handover.reason.trim().isNotEmpty) _row(Icons.notes_rounded, 'Alasan', handover.reason.trim()),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _amber),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Romo eksternal tidak menerima notifikasi maupun pesan grup chat CATU. '
                'Koordinasikan jadwal, lokasi, dan kebutuhan pelayanan langsung lewat telepon atau WhatsApp.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 6),
          SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 12.5, color: _muted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink))),
        ]),
      );
}
