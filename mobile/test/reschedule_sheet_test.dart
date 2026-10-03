import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/features/orders/widgets/reschedule_sheet.dart';
import 'package:catu_mobile/features/orders/widgets/reschedule_validation.dart';

void main() {
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final currentDate = today.add(const Duration(days: 5));
  final tomorrow = today.add(const Duration(days: 1));

  Future<List<RescheduleRequest>> openSheet(
    WidgetTester tester, {
    Future<String?> Function(RescheduleRequest r)? answer,
    int rejectedCount = 0,
  }) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final sent = <RescheduleRequest>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showRescheduleSheet(
                context: context,
                itemName: 'Misa Pelepasan',
                currentDate: currentDate,
                currentStart: const TimeOfDay(hour: 18, minute: 0),
                currentEnd: const TimeOfDay(hour: 19, minute: 30),
                rejectedCount: rejectedCount,
                onSubmit: (r) async {
                  sent.add(r);
                  return answer == null ? null : answer(r);
                },
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return sent;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan jadwal saat ini dengan format yang mudah dibaca', (tester) async {
    await openSheet(tester);
    expect(find.text('Ajukan Perubahan Jadwal'), findsOneWidget);
    expect(find.text('Misa Pelepasan'), findsOneWidget);
    expect(find.text('Jadwal saat ini'), findsOneWidget);
    expect(find.textContaining('18:00 – 19:30 WIB'), findsOneWidget);
    expect(find.textContaining(formatLongDate(currentDate)), findsWidgets);
  });

  testWidgets('kirim tanpa alasan: tampil error merah dan tidak dikirim', (tester) async {
    final sent = await openSheet(tester);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tapText(tester, 'Kirim Pengajuan ke Umat');
    expect(find.text('Alasan wajib diisi.'), findsOneWidget);
    expect(find.text('Periksa kembali isian yang ditandai merah.'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testWidgets('jadwal sama dengan yang berlaku ditolak dengan pesan umum', (tester) async {
    final sent = await openSheet(tester);
    await tapText(tester, 'Kendala perjalanan / transportasi');
    await tapText(tester, 'Kirim Pengajuan ke Umat');
    expect(find.textContaining('sama dengan jadwal saat ini'), findsOneWidget);
    expect(sent, isEmpty);
  });

  testWidgets('pengajuan valid dikirim lalu form tertutup', (tester) async {
    final sent = await openSheet(tester);
    await tapText(tester, 'Besok');
    await tapText(tester, 'Ada keperluan pastoral mendadak');
    expect(find.text('Yang akan diajukan ke Umat'), findsOneWidget);
    await tapText(tester, 'Kirim Pengajuan ke Umat');

    expect(sent, hasLength(1));
    expect(sent.single.newDate, formatIsoDate(tomorrow));
    expect(sent.single.newTimeStart, '18:00');
    expect(sent.single.newTimeEnd, '19:30');
    expect(sent.single.reason, 'Ada keperluan pastoral mendadak');
    expect(find.text('Ajukan Perubahan Jadwal'), findsNothing);
  });

  testWidgets('jam selesai bisa dikosongkan lewat tombol hapus', (tester) async {
    final sent = await openSheet(tester);
    await tapText(tester, 'Besok');
    await tapText(tester, 'Ada keperluan pastoral mendadak');
    final clear = find.byIcon(Icons.close_rounded);
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('Belum diatur'), findsOneWidget);
    await tapText(tester, 'Kirim Pengajuan ke Umat');
    expect(sent.single.newTimeEnd, isNull);
  });

  testWidgets('penolakan server: pesan tampil dan isian tidak hilang', (tester) async {
    final sent = await openSheet(tester, answer: (_) async => 'Hanya Romo yang bertugas yang dapat mengajukan.');
    await tapText(tester, 'Besok');
    await tapText(tester, 'Kondisi kesehatan kurang baik');
    await tapText(tester, 'Kirim Pengajuan ke Umat');

    expect(sent, hasLength(1));
    expect(find.text('Hanya Romo yang bertugas yang dapat mengajukan.'), findsOneWidget);
    expect(find.text('Ajukan Perubahan Jadwal'), findsOneWidget);
    expect(find.text('Kondisi kesehatan kurang baik'), findsWidgets); // alasan tetap terisi
  });

  testWidgets('ditolak 1x: form tetap ada dengan peringatan sisa kesempatan', (tester) async {
    await openSheet(tester, rejectedCount: 1);
    expect(find.textContaining('ditolak 1x'), findsOneWidget);
    expect(find.textContaining('Sisa kesempatan: 1'), findsOneWidget);
    expect(find.text('Kirim Pengajuan ke Umat'), findsOneWidget);
  });

  testWidgets('ditolak 2x: ubah jam ditutup, tidak ada form dan tidak ada yang dikirim', (tester) async {
    final sent = await openSheet(tester, rejectedCount: 2);
    expect(find.text('Ubah Jam Sudah Ditutup'), findsOneWidget);
    expect(find.textContaining('ditolak 2 kali'), findsOneWidget);
    expect(find.text('Kirim Pengajuan ke Umat'), findsNothing);
    expect(find.text('Besok'), findsNothing);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah Jam Sudah Ditutup'), findsNothing);
    expect(sent, isEmpty);
  });
}
