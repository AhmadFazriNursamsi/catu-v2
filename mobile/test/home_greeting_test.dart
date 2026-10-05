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
