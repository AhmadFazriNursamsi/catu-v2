import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/models/models.dart';
import 'package:catu_mobile/core/services/language_service.dart';
import 'package:catu_mobile/features/orders/histori_screen.dart';
import 'package:catu_mobile/features/profile/main_menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order order(int id, String status, {String category = 'Misa Kedukaan', String urgency = 'Biasa', List<OrderItem> items = const [], String name = 'Yohanes', String date = '2026-09-28'}) => Order(
      id: id,
      orderNumber: 'ORD-$id',
      categoryName: category,
      urgencyName: urgency,
      status: status,
      scheduledDate: date,
      scheduledTime: '18:00:00',
      locationName: 'RS Carolus',
      pemohonName: 'Budi',
      notes: (category.contains('Kedukaan') ? 'Nama Almarhum: ' : 'Nama Penerima: ') + name,
      items: items,
    );

OrderItem item(int id, String name, String status) => OrderItem(
      id: id,
      itemName: name,
      scheduledDate: '2026-09-27',
      scheduledTimeStart: '19:00:00',
      scheduledTimeEnd: '20:00:00',
      locationName: 'Rumah Duka',
      status: status,
      acceptedRomoId: 5,
      acceptedRomoName: 'Romo Budi',
    );

final orders = [
  order(1, 'DONE', category: 'Sakramen Perminyakan', urgency: 'Sangat Penting / Butuh Segera', name: 'Antonius'),
  order(2, 'DONE', items: [item(21, 'Misa Malam Kembang', 'DONE'), item(22, 'Misa Requiem', 'CLOSE')]),
  order(3, 'FAIL', category: 'Sakramen Perminyakan', name: 'Maria'),
];

Future<int> pump(WidgetTester tester, {List<Order>? data, VoidCallback? onRefresh}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  var refreshes = 0;
  await tester.pumpWidget(MaterialApp(
    home: HistoriScreen(orders: data ?? orders, userName: 'Budi', userId: 8, onRefresh: onRefresh ?? () => refreshes++),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 600));
  return refreshes;
}

void main() {
  testWidgets('chip filter menampilkan jumlah dan menyembunyikan status yang kosong', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // total entri: 1 + 2 misa + 1
    expect(find.text('Ditutup'), findsOneWidget);
    expect(find.text('Gagal'), findsOneWidget);
    expect(find.text(LanguageService.tr('status_in_progress')), findsNothing, reason: 'tidak ada entri berlangsung, chip disembunyikan');
  });

  testWidgets('baris statistik lama sudah tidak ada', (tester) async {
    await pump(tester);
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('mengetuk chip menyaring daftar', (tester) async {
    await pump(tester);
    expect(find.text('4 Permintaan'), findsOneWidget);
    await tester.ensureVisible(find.text('Gagal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gagal'));
    await tester.pumpAndSettle();
    expect(find.text('1 Permintaan'), findsOneWidget);
    expect(find.text('Sakramen Perminyakan'), findsOneWidget);
    expect(find.text('Misa Requiem'), findsNothing);
  });

  testWidgets('kartu ringkas: nomor order di subjudul, jam tanpa detik, tanpa footer lama', (tester) async {
    await pump(tester);
    expect(find.textContaining('#ORD-2'), findsWidgets);
    expect(find.textContaining('19:00–20:00 WIB'), findsWidgets);
    expect(find.textContaining('19:00:00'), findsNothing);
    expect(find.text(LanguageService.tr('view_detail')), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
  });

  testWidgets('subjudul memakai nama penerima, bukan mengulang kategori', (tester) async {
    await pump(tester);
    expect(find.textContaining('Antonius · #ORD-1'), findsOneWidget);
    expect(find.textContaining('Alm. Yohanes · #ORD-2'), findsWidgets);
  });

  testWidgets('urgensi tampil sebagai ikon bendera berwarna, bukan teks', (tester) async {
    await pump(tester);
    expect(find.text('Sangat Penting / Butuh Segera'), findsNothing);
    expect(find.text('Biasa'), findsNothing);
    final colors = tester.widgetList<Icon>(find.byIcon(Icons.flag_rounded)).map((i) => i.color).toSet();
    expect(colors, {const Color(0xFFDC2626), const Color(0xFF1D4ED8)}, reason: 'sangat penting merah, biasa/standar biru');
  });

  testWidgets('pencarian tanpa hasil menampilkan keadaan kosong dan bisa direset', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tidak-ada-yang-cocok');
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak ditemukan hasil'), findsOneWidget);
    await tester.tap(find.text('Reset Pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('4 Permintaan'), findsOneWidget);
  });

  testWidgets('tarik ke bawah memanggil onRefresh', (tester) async {
    var refreshes = 0;
    await pump(tester, onRefresh: () => refreshes++);
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 500), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets('tanpa data: keadaan kosong tampil tanpa error', (tester) async {
    await pump(tester, data: const []);
    expect(tester.takeException(), isNull);
    expect(find.text('0 Permintaan'), findsOneWidget);
    expect(find.textContaining('Belum ada histori'), findsOneWidget);
  });

  Iterable<Color?> textColors(WidgetTester tester, String label) =>
      tester.widgetList<Text>(find.text(label)).map((t) => t.style?.color);

  testWidgets('warna status: selesai hijau, ditutup abu-abu, gagal merah', (tester) async {
    await pump(tester);
    const green = Color(0xFF059669), grey = Color(0xFF64748B), red = Color(0xFFDC2626);
    expect(textColors(tester, 'Telah Selesai'), contains(green), reason: 'chip status "Telah Selesai" harus hijau');
    expect(textColors(tester, 'Ditutup Otomatis'), contains(grey), reason: 'chip status "Ditutup Otomatis" harus abu-abu');
    expect(textColors(tester, 'Gagal / Kadaluarsa'), contains(red));
    expect(textColors(tester, 'Telah Selesai'), isNot(contains(const Color(0xFF2563EB))), reason: 'biru lama sudah diganti');
  });

  testWidgets('foto kartu memakai Katedral Jakarta tanpa ikon atau overlay gelap', (tester) async {
    await pump(tester);
    final assets = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName).toSet();
    expect(assets, {'assets/images/katedral_jakarta.jpg'});
    for (final emoji in ['⛪', '🕯️', '✝️', '📿']) {
      expect(find.text(emoji), findsNothing, reason: 'ikon emoji pada foto kartu harus hilang');
    }
  });

  testWidgets('Riwayat: tidak ada ikon segarkan, pencarian tetap ada', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('Akun Saya: tidak ada ikon segarkan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MainMenuScreen(user: const {'id': 8, 'fullName': 'Budi', 'roleCode': 'UMAT'}, onRefresh: () {}, onLogout: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.text(LanguageService.tr('menu_title')), findsOneWidget);
  });
}
