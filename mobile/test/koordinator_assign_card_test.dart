import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/services/koordinator_assignment_api.dart';
import 'package:catu_mobile/features/orders/widgets/koordinator_assign_card.dart';

KoordinatorAssignment _data(String state, {String? reason}) => KoordinatorAssignment(
      eligible: state == 'OPEN',
      state: state,
      reason: reason,
      categoryName: 'Sakramen Perminyakan',
      orderNumber: 'SM-1',
      summary: '',
      pendingItems: const [],
      romos: state == 'OPEN' ? const [AssignableRomo(id: 1, fullName: 'Romo A', roleCode: 'ROMO_PAROKI', affiliation: 'Paroki X', local: true)] : const [],
    );

Future<void> _pump(WidgetTester tester, {required bool koordinator, required KoordinatorAssignment data, VoidCallback? onAssigned, void Function()? onLoad}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: KoordinatorAssignCard(
        orderId: 5,
        isKoordinator: koordinator,
        onAssigned: onAssigned ?? () {},
        loader: (_) async {
          onLoad?.call();
          return data;
        },
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('peran selain Koordinator: tidak memuat dan tidak menampilkan apa pun', (tester) async {
    var loads = 0;
    await _pump(tester, koordinator: false, data: _data('OPEN'), onLoad: () => loads++);
    expect(find.text('Carikan Romo'), findsNothing);
    expect(loads, 0);
  });

  testWidgets('siap dicarikan Romo: tombol Carikan Romo membuka layar pemilihan', (tester) async {
    await _pump(tester, koordinator: true, data: _data('OPEN'));
    expect(find.text('Pelayanan ini belum ada Romo'), findsOneWidget);
    await tester.tap(find.text('Carikan Romo'));
    await tester.pumpAndSettle();
    expect(find.text('Tetapkan Romo'), findsOneWidget); // layar pemilihan Romo
    expect(find.text('Romo A'), findsOneWidget);
  });

  testWidgets('belum waktunya: tombol tetap ada, ditekan hanya menampilkan peringatan (tidak membuka pemilihan Romo)', (tester) async {
    await _pump(tester, koordinator: true, data: _data('WAITING', reason: 'Baru dapat dicarikan Romo mulai pukul 11:15 WIB'));
    expect(find.text('Menunggu Romo Paroki / Ordo'), findsOneWidget);
    expect(find.text('Carikan Romo'), findsOneWidget);

    await tester.tap(find.text('Carikan Romo'));
    await tester.pumpAndSettle();
    expect(find.text('Belum Saatnya'), findsOneWidget);
    expect(find.textContaining('mulai pukul 11:15 WIB'), findsWidgets);
    expect(find.text('Tetapkan Romo'), findsNothing); // layar pemilihan Romo tidak terbuka

    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Belum Saatnya'), findsNothing);
    expect(find.text('Carikan Romo'), findsOneWidget);
  });

  testWidgets('sudah diterima/ditutup: tidak menampilkan kartu', (tester) async {
    await _pump(tester, koordinator: true, data: _data('CLOSED', reason: 'Pelayanan ini sudah diterima Romo'));
    expect(find.byType(Container), findsNothing);
    expect(find.text('Carikan Romo'), findsNothing);
  });

  testWidgets('setelah Romo ditetapkan, onAssigned dipanggil', (tester) async {
    var assigned = 0;
    await _pump(tester, koordinator: true, data: _data('OPEN'), onAssigned: () => assigned++);
    await tester.tap(find.text('Carikan Romo'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop(true);
    await tester.pumpAndSettle();
    expect(assigned, 1);
  });
}
