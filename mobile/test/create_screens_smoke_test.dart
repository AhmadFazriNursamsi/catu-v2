import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catu_mobile/core/services/language_service.dart';
import 'package:catu_mobile/features/orders/create_kedukaan_screen.dart';
import 'package:catu_mobile/features/orders/create_perminyakan_screen.dart';
import 'package:catu_mobile/core/models/models.dart' show OrderItem;
import 'package:catu_mobile/features/orders/widgets/form_helpers.dart' show compareMisaSchedule;

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
    expect(find.text('Pilih jenis urgensi'), findsNothing, reason: 'urgensi punya default Standar seperti Perminyakan');
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

  group('Misa Kedukaan: kursor mengikuti kolom yang sedang diisi', () {
    EditableText byLines(WidgetTester tester, int lines) => tester.widgetList<EditableText>(find.byType(EditableText)).firstWhere((e) => e.maxLines == lines);

    testWidgets('Next dari Nama Almarhum memindahkan fokus ke Catatan (melewati dropdown dan kolom tanggal)', (tester) async {
      await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
      final nama = tester.widgetList<EditableText>(find.byType(EditableText)).first;
      nama.focusNode.requestFocus();
      await tester.pump();
      expect(nama.focusNode.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump(const Duration(milliseconds: 400));
      expect(byLines(tester, 3).focusNode.hasFocus, isTrue, reason: 'fokus harus pindah ke Catatan');
      expect(nama.focusNode.hasFocus, isFalse);
    });

    testWidgets('kolom tanggal (dipilih lewat kalender) tidak dapat menerima fokus keyboard', (tester) async {
      await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
      final locked = tester.widgetList<EditableText>(find.byType(EditableText)).where((e) => !e.focusNode.canRequestFocus);
      expect(locked.length, 2, reason: 'tanggal meninggal dan tanggal misa');
    });

    testWidgets('kolom Alamat misa yang jauh di bawah digulirkan ke area di atas keyboard saat fokus', (tester) async {
      await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
      final alamat = byLines(tester, 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900); // keyboard ~300 dp dari layar 800 dp
      await tester.pump();
      alamat.focusNode.requestFocus();
      await tester.pump();
      await tester.pumpAndSettle(); // tunggu keyboard naik dan gulir mengikuti fokus selesai
      final rect = tester.getRect(find.byWidgetPredicate((w) => w is EditableText && w.focusNode == alamat.focusNode));
      const keyboardTop = (2400 - 900) / 3;
      expect(rect.bottom, lessThanOrEqualTo(keyboardTop), reason: 'kolom tidak boleh tertutup keyboard');
      expect(rect.top, greaterThan(56), reason: 'kolom tidak boleh tertutup AppBar');
    });
  });

  group('Misa Kedukaan: teks dan perilaku form sesuai desain terbaru', () {
    testWidgets('judul, petunjuk, dan placeholder memakai teks baru; teks lama tidak ada', (tester) async {
      await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
      expect(find.text('Lengkapi Form Kedukaan berikut ini'), findsOneWidget);
      expect(find.text('Data Kedukaan'), findsOneWidget);
      expect(find.text('Data Paroki'), findsOneWidget);
      expect(find.text('Nama'), findsOneWidget, reason: 'placeholder kolom nama');
      for (final lama in ['Isi form dibawah ini', 'Data Almarhum', 'Alm. Bapak', 'Catatan tambahan', 'Read Only', '/ banner', 'Alamat & Paroki Pelayanan Kedukaan']) {
        expect(find.textContaining(lama), findsNothing, reason: 'teks lama "$lama" harus hilang');
      }
      await tester.scrollUntilVisible(find.textContaining('upload foto duka'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Ketuk di sini untuk upload foto duka (Opsional)'), findsOneWidget);
      expect(find.text('Catatan'), findsWidgets);
    });

    testWidgets('default Jenis Misa = Misa Requiem dan urgensi = Standar (sama dengan Perminyakan)', (tester) async {
      await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
      expect(find.text('Misa Requiem / Misa Arwah'), findsOneWidget);
      expect(find.text('Misa Malam Kembang'), findsNothing);
      expect(find.text('Standar'), findsOneWidget);
    });

    testWidgets('tambah misa: daftar tanpa ikon kalender dan fokus kembali ke "Pilih Misa", hapus juga', (tester) async {
      await pumpScreen(tester, const CreateKedukaanScreen(userId: 1, user: _user));
      // Tanggal misa dipilih lewat kalender; di tes diisi lewat controller (tahun depan agar selalu di masa depan).
      tester.widgetList<EditableText>(find.byType(EditableText)).where((e) => !e.focusNode.canRequestFocus).last.controller.text = '15/06/${DateTime.now().year + 1}';
      final alamat = tester.widgetList<EditableText>(find.byType(EditableText)).firstWhere((e) => e.maxLines == 2);
      await tester.enterText(find.byWidgetPredicate((w) => w is EditableText && w.focusNode == alamat.focusNode), 'Rumah Duka Grand Heaven');
      await tester.ensureVisible(find.text('TAMBAHKAN MISA'));
      await tester.tap(find.text('TAMBAHKAN MISA'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rumah Duka Grand Heaven'), findsWidgets);
      expect(find.textContaining('📅'), findsNothing, reason: 'tanpa ikon kalender (salah persepsi tanggal 17)');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'jenisMisa', reason: 'setelah tambah misa kursor aktif pindah ke Pilih Misa, bukan Alamat');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.byIcon(Icons.delete_outline_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'jenisMisa', reason: 'setelah hapus misa kursor aktif juga ke Pilih Misa');
    });
  });

  test('daftar misa diurutkan berdasarkan tanggal lalu jam mulai', () {
    OrderItem m(String d, String t) => OrderItem(itemName: 'x', scheduledDate: d, scheduledTimeStart: t, scheduledTimeEnd: '23:00', locationName: 'y');
    final list = [m('2026-10-07', '09:00'), m('2026-10-06', '18:00'), m('2026-10-06', '08:00'), m('2026-10-05', '16:00')]..sort(compareMisaSchedule);
    expect(list.map((e) => '${e.scheduledDate} ${e.scheduledTimeStart}').toList(), ['2026-10-05 16:00', '2026-10-06 08:00', '2026-10-06 18:00', '2026-10-07 09:00']);
  });
}
