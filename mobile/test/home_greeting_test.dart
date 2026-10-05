import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/features/auth/widgets/gender_form_field.dart';
import 'package:catu_mobile/features/home/widgets/home_greeting.dart';

void main() {
  group('homeGreeting', () {
    test('Romo: "Hi, Romo Nama", tanpa menggandakan gelar', () {
      expect(homeGreeting({'roleCode': 'ROMO_PAROKI'}, 'Agus Setiawan'), 'Hi, Romo Agus Setiawan');
      expect(homeGreeting({'roleCode': 'ROMO_ORDO', 'gender': 'P'}, 'Romo Samuel'), 'Hi, Romo Samuel');
    });

    test('umat mengikuti gender; tanpa gender hanya nama', () {
      expect(homeGreeting({'roleCode': 'UMAT', 'gender': 'L'}, 'Budi'), 'Hi, Bapak Budi');
      expect(homeGreeting({'roleCode': 'UMAT', 'gender': 'P'}, 'Maria'), 'Hi, Ibu Maria');
      expect(homeGreeting({'roleCode': 'UMAT'}, 'Budi'), 'Hi, Budi');
      expect(homeGreeting({'roleCode': 'UMAT', 'gender': null}, 'Budi'), 'Hi, Budi');
    });
  });

  group('homeRoleTitle', () {
    test('Romo: jabatan Romo Paroki / Ordo, bukan sebutan umat', () {
      expect(homeRoleTitle({'roleCode': 'ROMO_PAROKI', 'romoPosition': 'ROMO_BIASA'}), 'Romo Paroki');
      expect(homeRoleTitle({'roleCode': 'ROMO_PAROKI', 'romoPosition': 'Kepala Romo Paroki'}), 'Kepala Romo Paroki');
      expect(homeRoleTitle({'roleCode': 'ROMO_PAROKI', 'romoPosition': 'KETUA_ROMO'}), 'Kepala Romo Paroki');
      expect(homeRoleTitle({'roleCode': 'ROMO_ORDO', 'romoPosition': 'ROMO_BIASA'}), 'Romo Ordo');
      expect(homeRoleTitle({'roleCode': 'ROMO_ORDO', 'romo_position': 'Ketua Romo Ordo'}), 'Ketua Romo Ordo');
    });

    test('pengurus: menampilkan jabatan, bukan "Umat"', () {
      expect(homeRoleTitle({'roleCode': 'PENGURUS_LINGKUNGAN', 'pengurusPosition': 'Ketua Lingkungan'}), 'Ketua Lingkungan');
      expect(homeRoleTitle({'roleCode': 'PENGURUS_LINGKUNGAN', 'pengurusPosition': 'Sekretaris'}), 'Sekretaris Lingkungan');
      expect(homeRoleTitle({'roleCode': 'PENGURUS_LINGKUNGAN', 'pengurus_position': 'bendahara'}), 'Bendahara Lingkungan');
      expect(homeRoleTitle({'roleCode': 'PENGURUS_LINGKUNGAN', 'pengurusPosition': 'WAKIL'}), 'Wakil Ketua Lingkungan');
      expect(homeRoleTitle({'roleCode': 'PENGURUS_LINGKUNGAN', 'pengurusPosition': 'KETUA'}), 'Ketua Lingkungan');
      expect(homeRoleTitle({'roleCode': 'PENGURUS_LINGKUNGAN'}), 'Pengurus Lingkungan');
    });

    test('koordinator dan umat', () {
      expect(homeRoleTitle({'roleCode': 'KOORDINATOR_KEUSKUPAN', 'pengurusPosition': 'Koordinator'}), 'Koordinator Keuskupan');
      expect(homeRoleTitle({'roleCode': 'UMAT'}), 'Umat');
      expect(homeRoleTitle({'roleCode': 'UMAT_PENDATANG'}), 'Umat Pendatang');
    });
  });

  group('GenderFormField', () {
    testWidgets('wajib dipilih: pesan merah, lalu valid setelah memilih', (tester) async {
      final key = GlobalKey<FormState>();
      String? gender;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(key: key, child: GenderFormField(value: gender, onChanged: (g) => setState(() => gender = g))),
          ),
        ),
      ));
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Pilih jenis kelamin'), findsOneWidget);

      await tester.tap(find.text('Perempuan'));
      await tester.pump();
      expect(gender, 'P');
      expect(key.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Pilih jenis kelamin'), findsNothing);
    });
  });
}
