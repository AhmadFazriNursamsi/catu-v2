import 'package:flutter/material.dart' show TimeOfDay;
import '../../../core/models/models.dart' show OrderRescheduleLog;

const int kRescheduleReasonMin = 10;
const int kRescheduleReasonMax = 300;
const int kRescheduleMaxDaysAhead = 60;

/// Pengajuan ubah jam ditutup setelah ditolak sebanyak ini (harus sama dengan backend).
const int kRescheduleMaxRejections = 2;

/// Jumlah pengajuan yang ditolak Umat untuk misa [itemId] (atau order tanpa misa bila null).
int rescheduleRejections(Iterable<OrderRescheduleLog> history, int? itemId) =>
    history.where((r) => r.itemId == itemId && r.status.toUpperCase() == 'REJECTED').length;

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Hasil validasi per kolom; `null` berarti kolom itu valid.
class RescheduleErrors {
  final String? date, start, end, reason, general;
  const RescheduleErrors({this.date, this.start, this.end, this.reason, this.general});
  bool get hasAny => [date, start, end, reason, general].any((e) => e != null);
}

/// Data pengajuan yang siap dikirim ke backend.
class RescheduleRequest {
  final String newDate, newTimeStart, reason;
  final String? newTimeEnd;
  const RescheduleRequest({required this.newDate, required this.newTimeStart, this.newTimeEnd, required this.reason});
}

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

String formatHm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String formatIsoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Sabtu, 3 Oktober 2026"
String formatLongDate(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// Menerima "18:00", "18:00:00", atau "18.00"; selain itu (mis. "Selesai", "") menghasilkan null.
TimeOfDay? parseTimeOfDay(String? raw) {
  final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(raw ?? '');
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  return (h > 23 || min > 59) ? null : TimeOfDay(hour: h, minute: min);
}

/// Menerima "2026-10-03" atau "2026-10-03T00:00:00Z"; hasilnya tanpa komponen jam.
DateTime? parseDateOnly(String? raw) {
  final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(raw ?? '');
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

RescheduleErrors validateReschedule({
  required DateTime date,
  required TimeOfDay start,
  TimeOfDay? end,
  required String reason,
  required DateTime now,
  DateTime? currentDate,
  TimeOfDay? currentStart,
  TimeOfDay? currentEnd,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);

  String? dateErr, startErr, endErr, reasonErr, general;
  if (day.isBefore(today)) {
    dateErr = 'Tanggal tidak boleh sudah lewat.';
  } else if (day.difference(today).inDays > kRescheduleMaxDaysAhead) {
    dateErr = 'Maksimal $kRescheduleMaxDaysAhead hari ke depan.';
  } else if (day == today && minutesOf(start) <= now.hour * 60 + now.minute) {
    startErr = 'Jam ini sudah lewat. Pilih jam setelah ${formatHm(TimeOfDay.fromDateTime(now))}.';
  }
  if (end != null && minutesOf(end) <= minutesOf(start)) {
    endErr = 'Jam selesai harus setelah jam mulai.';
  }

  final text = reason.trim();
  if (text.isEmpty) {
    reasonErr = 'Alasan wajib diisi.';
  } else if (text.length < kRescheduleReasonMin) {
    reasonErr = 'Alasan terlalu singkat, tambahkan ${kRescheduleReasonMin - text.length} karakter lagi.';
  } else if (text.length > kRescheduleReasonMax) {
    reasonErr = 'Alasan maksimal $kRescheduleReasonMax karakter.';
  }

  final noFieldError = dateErr == null && startErr == null && endErr == null && reasonErr == null;
  if (noFieldError && currentDate != null && currentStart != null) {
    final sameDay = DateTime(currentDate.year, currentDate.month, currentDate.day) == day;
    final sameEnd = (end == null && currentEnd == null) ||
        (end != null && currentEnd != null && minutesOf(end) == minutesOf(currentEnd));
    if (sameDay && minutesOf(currentStart) == minutesOf(start) && sameEnd) {
      general = 'Jadwal baru sama dengan jadwal saat ini. Ubah tanggal atau jam terlebih dahulu.';
    }
  }

  return RescheduleErrors(date: dateErr, start: startErr, end: endErr, reason: reasonErr, general: general);
}
