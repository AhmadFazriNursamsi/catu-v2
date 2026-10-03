import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/features/orders/widgets/form_helpers.dart';

void main() {
  group('plusMinutes', () {
    test('menambah menit dan membatasi sampai 23:59', () {
      expect(plusMinutes('18:00', 60), '19:00');
      expect(plusMinutes('09:30', 90), '11:00');
      expect(plusMinutes('23:30', 60), '23:59');
      expect(plusMinutes('00:00', 0), '00:00');
    });
  });

  group('TimeFormField', () {
    final formKey = GlobalKey<FormState>();

    Future<void> pump(WidgetTester tester, {String? value, String? Function(String?)? validator, VoidCallback? onTap}) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: TimeFormField(label: 'Jam Mulai', value: value, icon: Icons.access_time_rounded, onTap: onTap ?? () {}, validator: validator),
          ),
        ),
      ));
    }

    testWidgets('menampilkan placeholder bila belum dipilih dan nilai bila sudah', (tester) async {
      await pump(tester);
      expect(find.text('Pilih Jam'), findsOneWidget);
      await pump(tester, value: '18:30');
      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('Pilih Jam'), findsNothing);
    });

    testWidgets('validasi gagal: pesan merah tampil, valid: pesan hilang', (tester) async {
      await pump(tester, validator: (_) => 'Pilih jam mulai');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Pilih jam mulai'), findsOneWidget);

      await pump(tester, value: '18:30', validator: (_) => null);
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Pilih jam mulai'), findsNothing);
    });

    testWidgets('ketuk memanggil onTap', (tester) async {
      var taps = 0;
      await pump(tester, onTap: () => taps++);
      await tester.tap(find.text('Pilih Jam'));
      expect(taps, 1);
    });
  });

  group('scrollToFirstFormError', () {
    testWidgets('menggulir ke kolom pertama yang salah yang berada di luar layar', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = ScrollController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  TextFormField(initialValue: 'terisi', validator: (v) => v!.isEmpty ? 'kosong' : null),
                  const SizedBox(height: 1600),
                  TextFormField(initialValue: '', validator: (v) => v!.isEmpty ? 'Wajib diisi' : null),
                  const SizedBox(height: 600),
                  TextFormField(initialValue: '', validator: (v) => v!.isEmpty ? 'kedua' : null),
                ],
              ),
            ),
          ),
        ),
      ));

      expect(controller.offset, 0);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      scrollToFirstFormError(formKey.currentContext);
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(1000)); // turun ke kolom kosong pertama, bukan ke kolom terakhir
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));
      expect(find.text('Wajib diisi'), findsOneWidget);
    });

    testWidgets('tidak melakukan apa pun bila semua kolom valid atau konteks null', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = ScrollController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Form(key: formKey, child: SingleChildScrollView(controller: controller, child: Column(children: [TextFormField(initialValue: 'ok'), const SizedBox(height: 2000)])))),
      ));
      expect(formKey.currentState!.validate(), isTrue);
      scrollToFirstFormError(formKey.currentContext);
      scrollToFirstFormError(null);
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
    });
  });

  group('dateHint', () {
    testWidgets('menampilkan nama hari dan tanggal lengkap dari dd/mm/yyyy', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: dateHint('03/10/2026'))));
      expect(find.text('Sabtu, 3 Oktober 2026'), findsOneWidget);
    });

    testWidgets('kosong atau tidak valid: tidak menampilkan apa pun', (tester) async {
      for (final raw in ['', 'abc', '32/13/2026', '1/2']) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: dateHint(raw))));
        expect(find.byType(Text), findsNothing, reason: raw);
      }
    });
  });
}
