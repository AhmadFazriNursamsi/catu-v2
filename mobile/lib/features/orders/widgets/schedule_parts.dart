import 'package:flutter/material.dart';

const _ink = Color(0xFF334155);
const _muted = Color(0xFF94A3B8);
const _blue = Color(0xFF1D4ED8);

/// Lebar satu hari pada deretan tanggal (kotak 50 + jarak 4 di kiri dan kanan) dan padding daftar.
const double kDayItemExtent = 58;
const double kDayStripPadding = 12;

/// Posisi gulir agar [day] (1-31) berada di tengah deretan tanggal, dibatasi 0..[maxExtent].
double dayStripOffset({required int day, required double viewport, required double maxExtent}) {
  final itemCenter = kDayStripPadding + (day - 1) * kDayItemExtent + kDayItemExtent / 2;
  return (itemCenter - viewport / 2).clamp(0.0, maxExtent < 0 ? 0.0 : maxExtent);
}

/// Tanggal terdekat yang bukan sebelum [from] (hanya tanggal, tanpa jam); null bila tidak ada.
DateTime? nearestDateFrom(Iterable<DateTime?> dates, DateTime from) {
  final start = DateTime(from.year, from.month, from.day);
  DateTime? best;
  for (final d in dates) {
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(start)) continue;
    if (best == null || day.isBefore(best)) best = day;
  }
  return best;
}

/// Keadaan kosong layar Jadwal: menjelaskan kenapa kosong dan memberi jalan keluar.
class ScheduleEmptyState extends StatelessWidget {
  final DateTime? selectedDate;
  final bool hasOtherFilters;
  final DateTime? nearestDate;
  final int nearestCount;
  final String Function(DateTime) formatDate;
  final VoidCallback onShowAll, onResetFilters, onJumpToNearest;

  const ScheduleEmptyState({
    super.key,
    required this.selectedDate,
    required this.hasOtherFilters,
    required this.nearestDate,
    required this.nearestCount,
    required this.formatDate,
    required this.onShowAll,
    required this.onResetFilters,
    required this.onJumpToNearest,
  });

  @override
  Widget build(BuildContext context) {
    final message = selectedDate != null
        ? 'Tidak ada pelayanan aktif pada tanggal\n${formatDate(selectedDate!)}.'
        : (hasOtherFilters ? 'Tidak ditemukan pelayanan dengan filter terpilih.' : 'Belum ada jadwal pelayanan aktif mendatang.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.event_busy_rounded, size: 38, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 18),
            const Text('Tidak Ada Pelayanan Aktif', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: _muted, height: 1.5)),
            if (nearestDate != null) ...[
              const SizedBox(height: 18),
              InkWell(
                onTap: onJumpToNearest,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: _blue.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: _blue.withValues(alpha: 0.2))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_rounded, size: 20, color: _blue),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jadwal terdekat', style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
                            Text('${formatDate(nearestDate!)} · $nearestCount pelayanan', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _blue)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: _blue),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (selectedDate != null) _action('Lihat Semua Jadwal', onShowAll),
            if (hasOtherFilters) _action('Reset Semua Filter', onResetFilters),
          ],
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextButton(onPressed: onTap, child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _blue))),
      );
}

/// Penghitung kecil "N pelayanan" di samping judul daftar.
class ScheduleCountChip extends StatelessWidget {
  final int count;
  const ScheduleCountChip({super.key, required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
        child: Text('$count pelayanan', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
      );
}
