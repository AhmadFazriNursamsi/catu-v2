import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catu_mobile/core/services/language_service.dart';
import 'package:catu_mobile/features/home/umat_dashboard_view.dart';
import 'package:catu_mobile/features/orders/widgets/service_type_sheet.dart';

final categories = <Map<String, dynamic>>[
  {'id': 1, 'name': 'Sakramen Perminyakan', 'description': 'Pengurapan orang sakit oleh Romo', 'is_active': true},
  {'id': 2, 'name': 'Misa Kedukaan', 'description': 'Misa arwah dan pemakaman', 'is_active': true},
  {'id': 3, 'name': 'Pemberkatan Rumah', 'description': 'Berkat untuk rumah baru', 'is_active': true},
  {'id': 4, 'name': 'Layanan Nonaktif', 'description': 'tidak boleh tampil', 'is_active': false},
];

Future<List<ServiceType>> openSheet(WidgetTester tester, {List<Map<String, dynamic>>? data, List<ServiceType>? picked}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final chosen = picked ?? <ServiceType>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showServiceTypeSheet(context, loadCategories: () async => data ?? categories, onSelected: (t) async => chosen.add(t)),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  testWidgets('hanya judul pelayanan yang tampil, tanpa deskripsi dan tanpa layanan nonaktif', (tester) async {
    await openSheet(tester);
    expect(find.text('Pilih Jenis Pelayanan'), findsOneWidget);
    for (final title in ['Sakramen Perminyakan', 'Misa Kedukaan', 'Pemberkatan Rumah']) {
      expect(find.text(title), findsOneWidget);
    }
    for (final desc in ['Pengurapan orang sakit oleh Romo', 'Misa arwah dan pemakaman', 'Berkat untuk rumah baru']) {
      expect(find.text(desc), findsNothing, reason: 'deskripsi pelayanan harus hilang');
    }
    expect(find.text('Layanan Nonaktif'), findsNothing);
  });

  testWidgets('memilih pelayanan menutup sheet dan meneruskan jenisnya', (tester) async {
    final picked = await openSheet(tester);
    await tester.tap(find.text('Misa Kedukaan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Jenis Pelayanan'), findsNothing);
    expect(picked, hasLength(1));
    expect(picked.single.id, 2);
    expect(picked.single.isKedukaan, isTrue);
    expect(picked.single.isPerminyakan, isFalse);
  });

  testWidgets('jenis dikenali dari id maupun dari nama', (tester) async {
    expect(const ServiceType(id: 1, name: 'apa saja').isPerminyakan, isTrue);
    expect(const ServiceType(id: 99, name: 'Sakramen Perminyakan').isPerminyakan, isTrue);
    expect(const ServiceType(id: 2, name: 'x').isKedukaan, isTrue);
    expect(const ServiceType(id: 99, name: 'Misa Kedukaan Khusus').isKedukaan, isTrue);
    const other = ServiceType(id: 3, name: 'Pemberkatan Rumah');
    expect(other.isPerminyakan || other.isKedukaan, isFalse);
  });

  testWidgets('daftar kosong menampilkan pesan ramah', (tester) async {
    await openSheet(tester, data: const []);
    expect(find.text('Belum ada jenis pelayanan yang tersedia'), findsOneWidget);
  });

  group('label tombol di beranda', () {
    test('label tombol adalah "Permintaan Pelayanan"', () {
      expect(LanguageService.tr('quick_services'), 'Permintaan Pelayanan');
    });

    testWidgets('beranda Umat menampilkan label baru tanpa overflow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: UmatDashboardView(user: const {'id': 8, 'fullName': 'Budi', 'roleCode': 'UMAT', 'accountStatus': 'APPROVED'}, orders: const [], onRefresh: () {}, onLogout: () {}),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Permintaan Pelayanan'), findsOneWidget);
      expect(find.text('Buat Permintaan Pelayanan'), findsNothing);
      expect(find.text('Layanan Cepat'), findsNothing);
      // tombol memakai ikon "+"
      final button = find.ancestor(of: find.text('Permintaan Pelayanan'), matching: find.byType(ElevatedButton));
      expect(button, findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.add_rounded)), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // hentikan timer polling
    });
  });
}
