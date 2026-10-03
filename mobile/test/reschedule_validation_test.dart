import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/models/models.dart' show OrderRescheduleLog;
import 'package:catu_mobile/features/orders/widgets/reschedule_validation.dart';

void main() {
  final now = DateTime(2026, 10, 3, 10, 0);
  final tomorrow = DateTime(2026, 10, 4);
  const start = TimeOfDay(hour: 18, minute: 0);
  const end = TimeOfDay(hour: 19, minute: 30);
  const reason = 'Ada misa konselebrasi mendadak';

  RescheduleErrors run({
    DateTime? date,
    TimeOfDay s = start,
    TimeOfDay? e = end,
    String r = reason,
    DateTime? curDate,
    TimeOfDay? curStart,
    TimeOfDay? curEnd,
  }) =>
      validateReschedule(
        date: date ?? tomorrow,
        start: s,
        end: e,
        reason: r,
        now: now,
        currentDate: curDate,
        currentStart: curStart,
        currentEnd: curEnd,
      );

  test('pengajuan lengkap dan masuk akal dinyatakan valid', () {
    expect(run().hasAny, isFalse);
    expect(run(e: null).hasAny, isFalse);
  });

  test('tanggal lampau dan terlalu jauh ditolak', () {
    expect(run(date: DateTime(2026, 10, 2)).date, contains('lewat'));
    expect(run(date: DateTime(2026, 12, 31)).date, contains('Maksimal'));
    expect(run(date: DateTime(2026, 12, 2)).date, isNull); // tepat 60 hari
  });

  test('hari ini: jam mulai harus setelah jam sekarang', () {
    final today = DateTime(2026, 10, 3);
    expect(run(date: today, s: const TimeOfDay(hour: 9, minute: 59)).start, isNotNull);
    expect(run(date: today, s: const TimeOfDay(hour: 10, minute: 0)).start, isNotNull);
    expect(run(date: today, s: const TimeOfDay(hour: 10, minute: 1)).start, isNull);
  });

  test('jam selesai harus setelah jam mulai', () {
    expect(run(e: const TimeOfDay(hour: 18, minute: 0)).end, isNotNull);
    expect(run(e: const TimeOfDay(hour: 17, minute: 0)).end, isNotNull);
    expect(run(e: const TimeOfDay(hour: 18, minute: 1)).end, isNull);
  });

  test('alasan: wajib, minimal 10 karakter, maksimal 300', () {
    expect(run(r: '').reason, contains('wajib'));
    expect(run(r: '   ').reason, contains('wajib'));
    expect(run(r: 'sakit').reason, contains('singkat'));
    expect(run(r: 'x' * 10).reason, isNull);
    expect(run(r: 'x' * 301).reason, contains('maksimal'));
  });

  test('jadwal yang sama dengan jadwal saat ini ditolak, perubahan sekecil apa pun lolos', () {
    final same = run(curDate: tomorrow, curStart: start, curEnd: end);
    expect(same.general, isNotNull);
    expect(run(curDate: tomorrow, curStart: start, curEnd: null).general, isNull);
    expect(run(curDate: tomorrow, curStart: const TimeOfDay(hour: 17, minute: 59), curEnd: end).general, isNull);
    expect(run(curDate: DateTime(2026, 10, 5), curStart: start, curEnd: end).general, isNull);
  });

  test('parseTimeOfDay dan parseDateOnly menerima format dari backend dan menolak sisanya', () {
    expect(parseTimeOfDay('18:00:00'), const TimeOfDay(hour: 18, minute: 0));
    expect(parseTimeOfDay('7.05'), const TimeOfDay(hour: 7, minute: 5));
    expect(parseTimeOfDay('Selesai'), isNull);
    expect(parseTimeOfDay(''), isNull);
    expect(parseTimeOfDay('25:00'), isNull);
    expect(parseDateOnly('2026-10-03T00:00:00.000Z'), DateTime(2026, 10, 3));
    expect(parseDateOnly('-'), isNull);
  });

  test('format tanggal Indonesia', () {
    expect(formatLongDate(DateTime(2026, 10, 3)), 'Sabtu, 3 Oktober 2026');
    expect(formatIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
    expect(formatHm(const TimeOfDay(hour: 7, minute: 5)), '07:05');
  });

  test('rescheduleRejections hanya menghitung penolakan pada misa yang sama', () {
    OrderRescheduleLog log(int? itemId, String status) => OrderRescheduleLog(
          id: 1,
          orderId: 9,
          itemId: itemId,
          proposedBy: 5,
          proposerName: 'Romo',
          proposedDate: '2026-10-04',
          proposedTimeStart: '18:00',
          reason: 'x',
          status: status,
        );
    final history = [log(10, 'REJECTED'), log(10, 'REJECTED'), log(10, 'ACCEPTED'), log(9, 'REJECTED'), log(10, 'PENDING_UMAT'), log(null, 'REJECTED')];
    expect(rescheduleRejections(history, 10), 2);
    expect(rescheduleRejections(history, 9), 1);
    expect(rescheduleRejections(history, null), 1);
    expect(rescheduleRejections(history, 77), 0);
    expect(rescheduleRejections(const [], 10), 0);
    expect(rescheduleRejections(history, 10) >= kRescheduleMaxRejections, isTrue);
  });
}
