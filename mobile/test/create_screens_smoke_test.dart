import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catu_mobile/core/services/language_service.dart';
import 'package:catu_mobile/features/orders/create_kedukaan_screen.dart';
import 'package:catu_mobile/features/orders/create_perminyakan_screen.dart';

const _user = {'id': 1, 'fullName': 'Budi', 'roleCode': 'UMAT'};

/// Membuka layar sungguhan, lalu menekan tombol kirim dengan formulir kosong.
Future<void> openAndSubmitEmpty(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull, reason: 'layar gagal dibangun (mis. assertion pada kolom multibaris)');

  final send = find.byType(ElevatedButton).last;
  await tester.ensureVisible(send);
  await tester.tap(send);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull, reason: 'layar error setelah validasi dijalankan');
}

void main() {
  testWidgets('Sakramen Perminyakan: terbuka tanpa error, kolom Catatan ada, error inline muncul saat kirim kosong', (tester) async {
    await openAndSubmitEmpty(tester, const CreatePerminyakanScreen(userId: 1, user: _user));
    expect(find.textContaining('Catatan'), findsWidgets);
    expect(find.text('Nama wajib diisi'), findsOneWidget);
    expect(find.text('Tanggal wajib dipilih'), findsOneWidget);
    expect(find.text('Alamat detail wajib diisi'), findsOneWidget);
    // jam awal terisi otomatis dan harus valid pada jam berapa pun (tidak melewati tengah malam)
    expect(find.text('Pilih jam mulai'), findsNothing);
    expect(find.text('Harus setelah jam mulai'), findsNothing);
  });

  testWidgets('Misa Kedukaan: terbuka tanpa error, kolom Catatan ada, error inline muncul saat kirim kosong', (tester) async {
    await openAndSubmitEmpty(tester, const CreateKedukaanScreen(userId: 1, user: _user));
    expect(find.textContaining('Catatan'), findsWidgets);
    expect(find.text('Nama wajib diisi'), findsOneWidget);
    expect(find.text('Pilih jenis urgensi'), findsOneWidget);
    expect(find.text('Alamat lokasi misa wajib diisi'), findsOneWidget);
    expect(find.textContaining('Belum ada misa'), findsOneWidget);
    expect(find.text('Harus setelah jam mulai'), findsNothing);
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final c in {
    'Sakramen Perminyakan': (const CreatePerminyakanScreen(userId: 1, user: _user), 'submit_service'),
    'Misa Kedukaan': (const CreateKedukaanScreen(userId: 1, user: _user), 'send_service'),
  }.entries) {
    testWidgets('${c.key}: tombol kirim tidak ikut naik saat keyboard terbuka, kembali setelah keyboard tertutup', (tester) async {
      await pumpScreen(tester, c.value.$1);
      final label = LanguageService.tr(c.value.$2);
      expect(find.text(label), findsOneWidget, reason: 'tombol kirim tampil saat keyboard tertutup');

      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // keyboard terbuka (~300 dp)
      await tester.pump();
      expect(find.text(label), findsNothing, reason: 'tombol kirim harus disembunyikan, bukan terdorong ke atas keyboard');

      tester.view.resetViewInsets();
      await tester.pump();
      expect(find.text(label), findsOneWidget);
    });
  }

  testWidgets('Misa Kedukaan: tidak ada tombol Batalkan', (tester) async {
    await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text(LanguageService.tr('cancel_action')), findsNothing);
    expect(find.byType(BackButton).evaluate().isNotEmpty || find.byIcon(Icons.arrow_back_ios_new_rounded).evaluate().isNotEmpty, isTrue, reason: 'pengguna tetap bisa kembali lewat tombol panah di AppBar');
  });
}
