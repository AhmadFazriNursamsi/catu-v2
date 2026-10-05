import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/services/koordinator_assignment_api.dart';
import 'package:catu_mobile/features/orders/koordinator_assign_screen.dart';
import 'package:catu_mobile/features/orders/widgets/register_romo_sheet.dart';

const _existing = [AssignableRomo(id: 12, fullName: 'Romo Agus', roleCode: 'ROMO_PAROKI', affiliation: 'Paroki X', local: true)];
const _options = RomoRegisterOptions(parokis: [NamedOption(256, 'Paroki Santo Yosef'), NamedOption(257, 'Paroki Bunda Maria')], ordos: [NamedOption(2, 'SJ - Serikat Yesus')], defaultParokiId: 256);

Future<void> _pump(WidgetTester tester, {RomoRegistrar? registrar, RegisterOptionsLoader? optionsLoader, void Function(Object?)? onPop}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final screen = KoordinatorAssignScreen(
    orderId: 5,
    loader: (_) async => const KoordinatorAssignment(eligible: true, reason: null, categoryName: 'Sakramen Perminyakan', orderNumber: 'SM-1', summary: '', pendingItems: [], romos: _existing),
    optionsLoader: optionsLoader ?? (_) async => _options,
    registrar: registrar,
  );
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
          onPop?.call(result);
        }, child: const Text('buka')))),
    ),
  ));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Romo belum terdaftar? Daftarkan'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('formulir kosong: validasi tampil dan pendaftaran tidak dikirim', (tester) async {
    var calls = 0;
    await _pump(tester, registrar: (id, {required fullName, required phoneNumber, required roleCode, parokiId, ordoId, itemId}) async {
      calls++;
      throw Exception('tidak boleh dipanggil');
    });
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftarkan Romo'));
    await tester.pump();
    expect(find.text('Nama minimal 3 karakter'), findsOneWidget);
    expect(find.text('Nomor HP tidak valid'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('daftar Romo Paroki: kirim data, kata sandi tampil, lalu pelayanan otomatis diterima dan layar menutup', (tester) async {
    Map<String, Object?>? sent;
    var popped = false;
    await _pump(tester, onPop: (v) => popped = v == true, registrar: (id, {required fullName, required phoneNumber, required roleCode, parokiId, ordoId, itemId}) async {
      sent = {'order': id, 'name': fullName, 'phone': phoneNumber, 'role': roleCode, 'paroki': parokiId, 'ordo': ordoId, 'item': itemId};
      return const RegisteredRomo(
        romo: AssignableRomo(id: 99, fullName: 'Romo Baru Uji', roleCode: 'ROMO_PAROKI', affiliation: 'Paroki Santo Yosef', local: true),
        phoneNumber: '6281300000771',
        temporaryPassword: 'Ab3dEf7hJk',
        assigned: true,
      );
    });
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap Romo'), 'Romo Baru Uji');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomor HP / WhatsApp'), '0813-0000-0771');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftarkan Romo'));
    await tester.pumpAndSettle();

    expect(sent, {'order': 5, 'name': 'Romo Baru Uji', 'phone': '0813-0000-0771', 'role': 'ROMO_PAROKI', 'paroki': 256, 'ordo': null, 'item': null});
    expect(find.text('Akun Romo Aktif'), findsOneWidget);
    expect(find.textContaining('otomatis menerima pelayanan ini'), findsOneWidget);
    expect(find.text('Ab3dEf7hJk'), findsOneWidget);
    expect(find.text('6281300000771'), findsOneWidget);

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(popped, isTrue); // layar Carikan Romo menutup dengan hasil "ditetapkan"
    expect(find.text('Carikan Romo'), findsNothing);
  });

  testWidgets('penetapan otomatis gagal: akun tetap dibuat, Romo baru terpilih untuk ditetapkan manual', (tester) async {
    await _pump(tester, registrar: (id, {required fullName, required phoneNumber, required roleCode, parokiId, ordoId, itemId}) async => const RegisteredRomo(
          romo: AssignableRomo(id: 99, fullName: 'Romo Baru Uji', roleCode: 'ROMO_PAROKI', affiliation: 'Paroki Santo Yosef', local: true),
          phoneNumber: '6281300000771',
          temporaryPassword: 'Ab3dEf7hJk',
          assigned: false,
          assignError: 'Pelayanan ini sudah diterima Romo lain.',
        ));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap Romo'), 'Romo Baru Uji');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomor HP / WhatsApp'), '0813-0000-0771');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftarkan Romo'));
    await tester.pumpAndSettle();
    expect(find.text('Akun Romo Aktif'), findsOneWidget);
    expect(find.textContaining('otomatis menerima'), findsNothing);
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('Carikan Romo'), findsOneWidget);
    expect(find.text('2 Romo terdaftar'), findsOneWidget);
    expect(find.textContaining('penetapan gagal: Pelayanan ini sudah diterima Romo lain.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tetapkan Romo')).onPressed, isNotNull);
  });

  testWidgets('Romo Ordo: wajib pilih ordo; galat server ditampilkan dan formulir tetap terbuka', (tester) async {
    await _pump(tester, registrar: (id, {required fullName, required phoneNumber, required roleCode, parokiId, ordoId, itemId}) async => throw Exception('Nomor 6281300000771 sudah terdaftar atas nama Romo Lama.'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap Romo'), 'Romo Ordo Uji');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomor HP / WhatsApp'), '081300000771');
    await tester.tap(find.text('Romo Ordo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftarkan Romo'));
    await tester.pump();
    expect(find.text('Pilih ordo'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SJ - Serikat Yesus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Daftarkan Romo'));
    await tester.pumpAndSettle();
    expect(find.text('Nomor 6281300000771 sudah terdaftar atas nama Romo Lama.'), findsOneWidget);
    expect(find.text('Daftarkan Romo'), findsWidgets);
  });
}
