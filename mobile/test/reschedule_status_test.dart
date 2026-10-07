import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/models/models.dart';
import 'package:catu_mobile/features/orders/schedule_screen.dart';
import 'package:catu_mobile/features/orders/widgets/reschedule_widgets.dart';

String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  test('label status ubah jam: diajukan, ditolak, diterima; tanpa pengajuan tidak ada status', () {
    expect(rescheduleStatusLabel('PENDING_UMAT', 'CONFIRMED'), 'Ubah Jam Diajukan');
    expect(rescheduleStatusLabel('REJECTED', 'CONFIRMED'), 'Ubah Jam Ditolak');
    expect(rescheduleStatusLabel('ACCEPTED', 'IN_PROGRESS'), 'Ubah Jam Diterima');
    expect(rescheduleStatusLabel('accepted', 'confirmed'), 'Ubah Jam Diterima', reason: 'tidak peka huruf besar/kecil');
    expect(rescheduleStatusLabel('NONE', 'CONFIRMED'), isNull);
    expect(rescheduleStatusLabel('', 'CONFIRMED'), isNull);
  });

  test('status ubah jam tidak berlaku bila pelayanan sudah selesai, ditutup, atau gagal', () {
    for (final done in ['DONE', 'CLOSE', 'FAIL', 'COMPLETED', 'CLOSED', 'done']) {
      for (final r in ['PENDING_UMAT', 'REJECTED', 'ACCEPTED']) {
        expect(rescheduleStatusLabel(r, done), isNull, reason: '$r pada pelayanan $done');
      }
    }
  });

  test('order bermisa memakai status ubah jam milik misa itu, order tanpa misa memakai status order', () {
    final misa1 = OrderItem(id: 1, itemName: 'A', scheduledDate: '2026-10-10', scheduledTimeStart: '09:00', scheduledTimeEnd: '10:00', locationName: 'x', rescheduleStatus: 'PENDING_UMAT');
    final misa2 = OrderItem(id: 2, itemName: 'B', scheduledDate: '2026-10-11', scheduledTimeStart: '09:00', scheduledTimeEnd: '10:00', locationName: 'x');
    Order mk(List<OrderItem> items) => Order(id: 1, orderNumber: 'MD-1', categoryName: 'Misa Kedukaan', urgencyName: 'Standar', status: 'CONFIRMED', scheduledDate: '2026-10-10', scheduledTime: '09:00', locationName: 'x', pemohonName: 'Budi', items: items, rescheduleStatus: 'REJECTED');
    expect(rescheduleStatusOf(mk([misa1, misa2]), misa1), 'PENDING_UMAT');
    expect(rescheduleStatusOf(mk([misa1, misa2]), misa2), 'NONE', reason: 'misa 2 belum pernah mengajukan walau status order terakhir REJECTED');
    expect(rescheduleStatusOf(mk([]), null), 'REJECTED');
  });

  testWidgets('chip hanya tampil bila berlaku; teks dan warna sesuai status', (tester) async {
    Widget host(String r, String s) => MaterialApp(home: Scaffold(body: RescheduleStatusChip(rescheduleStatus: r, serviceStatus: s)));
    await tester.pumpWidget(host('PENDING_UMAT', 'CONFIRMED'));
    expect(find.text('Ubah Jam Diajukan'), findsOneWidget);
    await tester.pumpWidget(host('REJECTED', 'CONFIRMED'));
    expect(find.text('Ubah Jam Ditolak'), findsOneWidget);
    await tester.pumpWidget(host('ACCEPTED', 'IN_PROGRESS'));
    expect(find.text('Ubah Jam Diterima'), findsOneWidget);
    await tester.pumpWidget(host('ACCEPTED', 'DONE'));
    expect(find.textContaining('Ubah Jam'), findsNothing);
    await tester.pumpWidget(host('REJECTED', 'CLOSE'));
    expect(find.textContaining('Ubah Jam'), findsNothing);
  });

  testWidgets('kartu jadwal menampilkan status pelayanan dan status ubah jam secara terpisah', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final event = DateTime.now().add(const Duration(days: 3));
    Order order(int id, String reschedule) => Order(
          id: id, orderNumber: 'ORD-$id', categoryName: 'Sakramen Perminyakan', urgencyName: 'Penting', status: 'CONFIRMED',
          acceptedRomoId: 5, acceptedRomoName: 'Romo Agus', scheduledDate: iso(event), scheduledTime: '18:00:00',
          locationName: 'RS Carolus', pemohonName: 'Budi', rescheduleStatus: reschedule,
        );
    await tester.pumpWidget(MaterialApp(home: ScheduleScreen(orders: [order(1, 'PENDING_UMAT'), order(2, 'ACCEPTED'), order(3, 'NONE')], userName: 'Budi', userId: 8, onRefresh: () {})));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    // Jadwal tiga hari lagi: ketuk tanggalnya bila daftar hari ini kosong.
    if (find.textContaining('Ubah Jam').evaluate().isEmpty) {
      final jump = find.textContaining('Jadwal terdekat');
      if (jump.evaluate().isNotEmpty) {
        await tester.tap(jump);
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
      }
    }
    expect(find.text('Ubah Jam Diajukan'), findsOneWidget);
    expect(find.text('Ubah Jam Diterima'), findsOneWidget);
    expect(find.text('Ubah Jam Ditolak'), findsNothing);
  });
}
