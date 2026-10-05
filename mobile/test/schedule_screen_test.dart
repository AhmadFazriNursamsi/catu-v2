import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/models/models.dart';
import 'package:catu_mobile/core/services/language_service.dart';
import 'package:catu_mobile/features/orders/schedule_screen.dart';
import 'package:catu_mobile/features/orders/widgets/schedule_parts.dart';

String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Order order(int id, DateTime date, {String category = 'Sakramen Perminyakan'}) => Order(
      id: id,
      orderNumber: 'ORD-$id',
      categoryName: category,
      urgencyName: 'Penting',
      status: 'CONFIRMED',
      acceptedRomoId: 5,
      acceptedRomoName: 'Romo Agus',
      scheduledDate: iso(date),
      scheduledTime: '18:00:00',
      locationName: 'RS Carolus',
      pemohonName: 'Budi',
    );

Future<void> pump(WidgetTester tester, List<Order> orders) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: ScheduleScreen(orders: orders, userName: 'Budi', userId: 8, onRefresh: () {})));
  await tester.pumpAndSettle(const Duration(milliseconds: 600));
}

ScrollPosition dayStrip(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .firstWhere((s) => s.axisDirection == AxisDirection.right)
    .position;

void main() {
  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  group('logika deretan tanggal', () {
    test('dayStripOffset menaruh hari di tengah dan membatasi di ujung', () {
      expect(dayStripOffset(day: 1, viewport: 360, maxExtent: 1000), 0, reason: 'hari pertama tidak digulir negatif');
      final d15 = dayStripOffset(day: 15, viewport: 360, maxExtent: 2000);
      expect(d15, kDayStripPadding + 14 * kDayItemExtent + kDayItemExtent / 2 - 180);
      expect(dayStripOffset(day: 31, viewport: 360, maxExtent: 1500), 1500, reason: 'dibatasi maxExtent');
      expect(dayStripOffset(day: 10, viewport: 360, maxExtent: -5), 0);
    });

    test('nearestDateFrom memilih tanggal terdekat yang tidak sebelum batas', () {
      final dates = [DateTime(2026, 10, 2, 9), DateTime(2026, 10, 9, 18), DateTime(2026, 10, 7), null, DateTime(2026, 10, 7, 20)];
      expect(nearestDateFrom(dates, DateTime(2026, 10, 5, 23)), DateTime(2026, 10, 7));
      expect(nearestDateFrom(dates, DateTime(2026, 10, 8)), DateTime(2026, 10, 9));
      expect(nearestDateFrom(dates, DateTime(2026, 10, 10)), isNull);
      expect(nearestDateFrom(const [], DateTime(2026, 10, 1)), isNull);
    });
  });

  testWidgets('hari ini kosong: tampil saran jadwal terdekat dan tombol lihat semua', (tester) async {
    final event = today.add(const Duration(days: 12));
    await pump(tester, [order(1, event)]);
    expect(tester.takeException(), isNull);
    expect(find.text('Tidak Ada Pelayanan Aktif'), findsOneWidget);
    expect(find.text('Jadwal terdekat'), findsOneWidget);
    expect(find.textContaining('1 pelayanan'), findsWidgets);
    expect(find.text('Lihat Semua Jadwal'), findsOneWidget);
  });

  testWidgets('mengetuk jadwal terdekat membuka tanggalnya dan menggulir deretan tanggal ke sana', (tester) async {
    final event = today.add(const Duration(days: 12));
    await pump(tester, [order(1, event)]);
    await tester.tap(find.text('Jadwal terdekat'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Tidak Ada Pelayanan Aktif'), findsNothing);
    expect(find.text('Sakramen Perminyakan'), findsWidgets);
    expect(find.text('1 pelayanan'), findsOneWidget, reason: 'penghitung di samping judul daftar');

    final pos = dayStrip(tester);
    final expected = dayStripOffset(day: event.day, viewport: pos.viewportDimension, maxExtent: pos.maxScrollExtent);
    expect(pos.pixels, closeTo(expected, 1.0), reason: 'tanggal ${event.day} harus terlihat di tengah deretan');
  });

  testWidgets('Lihat Semua Jadwal menghapus filter tanggal dan menampilkan daftar mendatang', (tester) async {
    await pump(tester, [order(1, today.add(const Duration(days: 12)))]);
    await tester.tap(find.text('Lihat Semua Jadwal'));
    await tester.pumpAndSettle();
    expect(find.text('Jadwal Mendatang'), findsOneWidget);
    expect(find.text('Sakramen Perminyakan'), findsWidgets);
    expect(find.text('Tidak Ada Pelayanan Aktif'), findsNothing);
  });

  testWidgets('kartu ringkas: nomor order di subjudul, panah, tanpa footer lama', (tester) async {
    await pump(tester, [order(7, today)]); // hari ini = tanggal terpilih bawaan
    expect(find.textContaining('#ORD-7'), findsOneWidget);
    expect(find.text(LanguageService.tr('view_detail')), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    expect(find.text('Urutkan: Terdekat'), findsOneWidget);
    expect(find.text('Sort: Terdekat'), findsNothing);
  });

  testWidgets('garis timeline mengikuti tinggi sebenarnya kelompok tanggal', (tester) async {
    await pump(tester, [order(1, today), order(2, today, category: 'Misa Kedukaan')]);
    expect(tester.takeException(), isNull);
    final group = tester.getRect(find.byType(IntrinsicHeight).first);
    final line = find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == const Color(0xFFCBD5E1));
    expect(line, findsOneWidget);
    final lineRect = tester.getRect(line);
    expect(lineRect.height, greaterThan(300), reason: 'dua kartu lebih tinggi daripada satu kartu');
    expect(lineRect.bottom, closeTo(group.bottom, 1.0), reason: 'garis berakhir tepat di dasar kelompok, bukan tinggi tetap');
  });

  testWidgets('tanpa data sama sekali: keadaan kosong tanpa saran dan tanpa error', (tester) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.text('Jadwal terdekat'), findsNothing);
    expect(find.text('Tidak Ada Pelayanan Aktif'), findsOneWidget);
  });
}
