import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catu_mobile/core/models/models.dart';
import 'package:catu_mobile/core/widgets/urgency_label.dart';
import 'package:catu_mobile/features/home/umat_dashboard_view.dart';
import 'package:catu_mobile/features/orders/create_kedukaan_screen.dart';

const blue = Color(0xFF1D4ED8), orange = Color(0xFFD97706), red = Color(0xFFDC2626);

void main() {
  group('pemetaan urgensi', () {
    test('standar biru, penting oranye, sangat penting merah', () {
      for (final n in ['Standar', 'Biasa', '', 'apa saja']) {
        expect(urgencyLevelOf(n), UrgencyLevel.standar, reason: n);
        expect(urgencyColorOf(n), blue, reason: n);
        expect(urgencyLabelOf(n), 'Standar', reason: n);
      }
      expect(urgencyColorOf('Penting'), orange);
      expect(urgencyLabelOf('Penting'), 'Penting');
      for (final n in ['Sangat Penting / Butuh Segera', 'Darurat / Kritis', 'darurat', 'SANGAT PENTING']) {
        expect(urgencyLevelOf(n), UrgencyLevel.sangatPenting, reason: n);
        expect(urgencyColorOf(n), red, reason: n);
        expect(urgencyLabelOf(n), 'Sangat Penting', reason: n);
      }
      expect(urgencyLevelOf(null), UrgencyLevel.standar);
    });
  });

  group('UrgencyLabel', () {
    testWidgets('menampilkan label teks berwarna, bukan ikon bendera', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Column(children: [
          UrgencyLabel(urgencyName: 'Biasa'),
          UrgencyLabel(urgencyName: 'Penting'),
          UrgencyLabel(urgencyName: 'Sangat Penting / Butuh Segera'),
        ])),
      ));
      Color? colorOf(String text) => tester.widget<Text>(find.text(text)).style?.color;
      expect(colorOf('Standar'), blue);
      expect(colorOf('Penting'), orange);
      expect(colorOf('Sangat Penting'), red);
      expect(find.byIcon(Icons.flag_rounded), findsNothing);
      expect(find.text('Sangat Penting / Butuh Segera'), findsNothing, reason: 'nama panjang diringkas');
    });
  });

  group('kartu beranda', () {
    Future<void> pumpHome(WidgetTester tester, List<String> urgencies) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final future = DateTime.now().add(const Duration(days: 5));
      final date = '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';
      Order o(int id, String urgency) => Order(id: id, orderNumber: 'ORD-$id', categoryName: 'Sakramen Perminyakan', urgencyName: urgency, status: 'PENDING', scheduledDate: date, locationName: 'RS', pemohonName: 'Budi');
      await tester.pumpWidget(MaterialApp(
        home: UmatDashboardView(
          user: const {'id': 8, 'fullName': 'Budi', 'roleCode': 'UMAT', 'accountStatus': 'APPROVED'},
          orders: [for (var i = 0; i < urgencies.length; i++) o(i + 1, urgencies[i])],
          onRefresh: () {},
          onLogout: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    }

    testWidgets('standar biru dan penting oranye sebagai label', (tester) async {
      await pumpHome(tester, ['Standar', 'Penting']);
      expect(tester.widget<Text>(find.text('Standar')).style?.color, blue);
      expect(tester.widget<Text>(find.text('Penting')).style?.color, orange);
      expect(find.byIcon(Icons.flag_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox()); // hentikan timer polling
    });

    testWidgets('sangat penting merah sebagai label', (tester) async {
      await pumpHome(tester, ['Sangat Penting / Butuh Segera']);
      expect(tester.widget<Text>(find.text('Sangat Penting')).style?.color, red);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('Misa Kedukaan: pilihan urgensi sama dengan Sakramen Perminyakan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CreateKedukaanScreen(userId: 1, user: {'id': 1, 'roleCode': 'UMAT'})));
    await tester.pump(const Duration(milliseconds: 300));
    final dropdown = find.byType(DropdownButtonFormField<String>).at(1);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    for (final opt in ['Standar', 'Penting', 'Sangat Penting / Butuh Segera']) {
      expect(find.text(opt), findsWidgets, reason: opt);
    }
    expect(find.text('Biasa'), findsNothing);
    expect(find.text('Darurat / Kritis'), findsNothing);
  });
}
