import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/services/koordinator_assignment_api.dart';
import 'package:catu_mobile/features/orders/koordinator_assign_screen.dart';

const _romos = [
  AssignableRomo(id: 12, fullName: 'Romo Agus Setiawan', roleCode: 'ROMO_PAROKI', affiliation: 'Paroki Santo Yosef', local: true),
  AssignableRomo(id: 60, fullName: 'Romo Fransiscus SJ', roleCode: 'ROMO_ORDO', affiliation: 'Serikat Yesus', local: true),
  AssignableRomo(id: 77, fullName: 'Romo Petrus MSC', roleCode: 'ROMO_ORDO', affiliation: 'MSC', local: false),
];

KoordinatorAssignment _data({bool eligible = true, String? reason, List<AssignableItem> items = const []}) => KoordinatorAssignment(
      eligible: eligible,
      reason: reason,
      categoryName: 'Sakramen Perminyakan',
      orderNumber: 'SM-20261005-1234',
      summary: '2026-10-05 • 18:00 • RS Carolus',
      pendingItems: items,
      romos: eligible ? _romos : const [],
    );

Future<void> _pump(WidgetTester tester, KoordinatorAssignment data, {RomoAssigner? assigner}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: KoordinatorAssignScreen(orderId: 5, loader: (_) async => data, assigner: assigner)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('belum waktunya: menampilkan alasan, tanpa daftar Romo dan tombol', (tester) async {
    await _pump(tester, _data(eligible: false, reason: 'Baru dapat dicarikan Romo mulai pukul 11:15 WIB'));
    expect(find.text('Baru dapat dicarikan Romo mulai pukul 11:15 WIB'), findsOneWidget);
    expect(find.text('Tetapkan Romo'), findsNothing);
    expect(find.textContaining('Romo Agus'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menampilkan seluruh Romo terdaftar dan mencari berdasarkan nama atau asal', (tester) async {
    await _pump(tester, _data());
    expect(find.text('3 Romo terdaftar'), findsOneWidget);
    expect(find.textContaining('Setempat'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'serikat');
    await tester.pump();
    expect(find.text('1 Romo terdaftar'), findsOneWidget);
    expect(find.text('Romo Fransiscus SJ'), findsOneWidget);
    expect(find.text('Romo Agus Setiawan'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Tidak ada Romo yang cocok dengan pencarian.'), findsOneWidget);
  });

  testWidgets('tombol nonaktif sampai Romo dipilih; konfirmasi memanggil penetapan dengan Romo terpilih', (tester) async {
    int? gotRomo;
    int? gotItem = -1;
    await _pump(tester, _data(), assigner: (orderId, {required romoId, itemId}) async {
      gotRomo = romoId;
      gotItem = itemId;
      return 'Pelayanan ditetapkan kepada Romo Fransiscus SJ.';
    });
    final button = find.widgetWithText(ElevatedButton, 'Tetapkan Romo');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.text('Romo Fransiscus SJ'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Tetapkan Romo?'), findsOneWidget);
    await tester.tap(find.text('Tetapkan'));
    await tester.pumpAndSettle();

    expect(gotRomo, 60);
    expect(gotItem, isNull); // tanpa item: semua yang belum diterima
  });

  testWidgets('beberapa misa: dapat memilih satu misa saja', (tester) async {
    int? gotItem;
    await _pump(
      tester,
      _data(items: const [AssignableItem(id: 9, name: 'Misa Pemberkatan', schedule: ''), AssignableItem(id: 10, name: 'Misa Pemakaman', schedule: '')]),
      assigner: (orderId, {required romoId, itemId}) async {
        gotItem = itemId;
        return 'ok';
      },
    );
    await tester.tap(find.text('Misa Pemakaman'));
    await tester.pump();
    await tester.tap(find.text('Romo Agus Setiawan'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tetapkan Romo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tetapkan'));
    await tester.pumpAndSettle();
    expect(gotItem, 10);
  });

  testWidgets('galat server ditampilkan dan layar tetap terbuka', (tester) async {
    await _pump(tester, _data(), assigner: (orderId, {required romoId, itemId}) async => throw Exception('Pelayanan ini sudah diterima Romo atau sudah ditutup.'));
    await tester.tap(find.text('Romo Agus Setiawan'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tetapkan Romo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tetapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Pelayanan ini sudah diterima Romo atau sudah ditutup.'), findsOneWidget);
    expect(find.text('Carikan Romo'), findsOneWidget);
  });

  test('parsing respons server: hanya misa yang belum diterima yang menjadi pilihan', () {
    final a = KoordinatorAssignment.fromJson({
      'eligible': true,
      'reason': null,
      'order': {
        'orderNumber': 'MD-1',
        'categoryName': 'Misa Kedukaan',
        'scheduledDate': '2026-12-23T00:00:00.000Z',
        'scheduledTime': '09:00:00',
        'locationName': 'Duka',
        'items': [
          {'id': 9, 'itemName': 'Pemberkatan', 'scheduledDate': '2026-12-23', 'scheduledTime': '09:00:00'},
          {'id': 10, 'itemName': 'Pemakaman', 'scheduledDate': '2026-12-24', 'scheduledTime': '09:00:00'},
        ],
      },
      'pendingItemIds': [10],
      'romos': [
        {'id': 12, 'fullName': 'Romo A', 'roleCode': 'ROMO_PAROKI', 'affiliation': 'Paroki X', 'local': true}
      ],
    });
    expect(a.pendingItems.map((i) => i.id), [10]);
    expect(a.summary, '2026-12-23 • 09:00 • Duka');
    expect(a.romos.single.roleLabel, 'Romo Paroki');
  });
}
