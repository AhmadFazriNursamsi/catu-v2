import 'package:flutter/material.dart';
import '../../../core/models/models.dart' show Order, OrderItem;
import 'reschedule_validation.dart';

const kRescheduleAmber = Color(0xFFD97706);
const kRescheduleInk = Color(0xFF1E293B);
const kRescheduleMuted = Color(0xFF64748B);

/// "Sabtu, 3 Oktober 2026  •  18:00 – 19:30 WIB"
String rescheduleScheduleText(DateTime? d, TimeOfDay? start, TimeOfDay? end) {
  if (d == null) return 'Belum ada jadwal';
  final time = start == null ? '' : '  •  ${formatHm(start)}${end != null ? ' – ${formatHm(end)}' : ''} WIB';
  return '${formatLongDate(d)}$time';
}

Widget rescheduleLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
    );

Widget rescheduleChip(String text, {required bool selected, required VoidCallback onTap}) => ChoiceChip(
      label: Text(text, style: TextStyle(fontSize: 12, color: selected ? Colors.white : kRescheduleInk)),
      selected: selected,
      selectedColor: kRescheduleAmber,
      backgroundColor: Colors.white,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );

Widget rescheduleErrorText(String text) => Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.red, height: 1.3)),
    );

Widget rescheduleBanner(String? message) => message == null
    ? const SizedBox.shrink()
    : Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: Color(0xFF991B1B), height: 1.3))),
          ],
        ),
      );

/// Kartu informasi jadwal: netral untuk "jadwal saat ini", kuning untuk "yang akan diajukan".
class RescheduleInfoCard extends StatelessWidget {
  final String title, text;
  final bool highlight;
  const RescheduleInfoCard({super.key, required this.title, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: highlight ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: highlight ? const Color(0xFF92400E) : kRescheduleMuted)),
            const SizedBox(height: 3),
            Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: highlight ? const Color(0xFF78350F) : kRescheduleInk)),
          ],
        ),
      );
}

/// Kolom pilihan (tanggal/jam) dengan border merah + pesan bila [error] terisi.
class ReschedulePickerField extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? error;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const ReschedulePickerField({super.key, required this.icon, required this.text, this.error, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: hasError ? Colors.red : Colors.grey.shade300, width: hasError ? 1.6 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (onClear != null)
                  InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.close_rounded, size: 18, color: kRescheduleMuted))),
                Icon(icon, size: 18, color: hasError ? Colors.red : kRescheduleMuted),
              ],
            ),
          ),
        ),
        if (hasError) rescheduleErrorText(error!),
      ],
    );
  }
}

/// Jam saja ("19:00 – 20:00 WIB"): ubah jam tidak mengubah tanggal.
String rescheduleTimeText(TimeOfDay start, TimeOfDay? end) => '${formatHm(start)}${end != null ? ' – ${formatHm(end)}' : ''} WIB';

/// Status ubah jam sebuah misa (atau order tanpa misa). Pada order bermisa, hanya status misa itu yang berlaku.
String rescheduleStatusOf(Order order, OrderItem? item) => (order.items.isNotEmpty && item != null) ? item.rescheduleStatus : order.rescheduleStatus;

const _finishedStatuses = {'DONE', 'COMPLETED', 'CLOSE', 'CLOSED', 'FAIL'};

/// Label status ubah jam; null bila tidak ada pengajuan atau pelayanan sudah selesai/ditutup/gagal
/// (status ubah jam tidak berlaku lagi setelah itu).
String? rescheduleStatusLabel(String rescheduleStatus, String serviceStatus) {
  if (_finishedStatuses.contains(serviceStatus.toUpperCase())) return null;
  switch (rescheduleStatus.toUpperCase()) {
    case 'PENDING_UMAT':
      return 'Ubah Jam Diajukan';
    case 'REJECTED':
      return 'Ubah Jam Ditolak';
    case 'ACCEPTED':
      return 'Ubah Jam Diterima';
  }
  return null;
}

/// Chip status ubah jam (kosong bila tidak berlaku, lihat [rescheduleStatusLabel]).
class RescheduleStatusChip extends StatelessWidget {
  final String rescheduleStatus, serviceStatus;
  final double topGap; // jarak di atas chip; hanya terpakai bila chip tampil (rata kiri)
  const RescheduleStatusChip({super.key, required this.rescheduleStatus, required this.serviceStatus, this.topGap = 0});

  @override
  Widget build(BuildContext context) {
    final label = rescheduleStatusLabel(rescheduleStatus, serviceStatus);
    if (label == null) return const SizedBox.shrink();
    final (color, icon) = switch (rescheduleStatus.toUpperCase()) {
      'REJECTED' => (const Color(0xFFDC2626), Icons.cancel_rounded),
      'ACCEPTED' => (const Color(0xFF0D9488), Icons.check_circle_rounded),
      _ => (kRescheduleAmber, Icons.schedule_send_rounded),
    };
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 10),
              const SizedBox(width: 4),
              Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pil status pelayanan pada kartu; status ubah jam (bila berlaku) tampil sebagai chip tersendiri di bawahnya.
class ServiceStatusPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label, rescheduleStatus, serviceStatus;
  const ServiceStatusPill({super.key, required this.color, required this.icon, required this.label, required this.rescheduleStatus, required this.serviceStatus});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 10),
                const SizedBox(width: 4),
                Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          if (rescheduleStatusLabel(rescheduleStatus, serviceStatus) != null) ...[
            const SizedBox(height: 4),
            RescheduleStatusChip(rescheduleStatus: rescheduleStatus, serviceStatus: serviceStatus),
          ],
        ],
      );
}
