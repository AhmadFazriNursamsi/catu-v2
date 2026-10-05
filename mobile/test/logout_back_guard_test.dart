import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catu_mobile/core/services/notification_service.dart';
import 'package:catu_mobile/features/home/home_screen.dart';
import 'package:catu_mobile/features/home/widgets/logout_back_guard.dart';

Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('LogoutBackGuard', () {
    Future<int Function()> pumpGuard(WidgetTester tester) async {
      var logouts = 0;
      await tester.pumpWidget(MaterialApp(home: LogoutBackGuard(onLogout: () => logouts++, child: const Scaffold(body: Text('beranda')))));
      return () => logouts;
    }

    testWidgets('tombol kembali menampilkan konfirmasi dan tidak langsung keluar', (tester) async {
      final logouts = await pumpGuard(tester);
      await pressBack(tester);
      expect(find.text('Keluar dari akun?'), findsOneWidget);
      expect(find.textContaining('berarti Anda akan keluar (logout)'), findsOneWidget);
      expect(find.text('beranda'), findsOneWidget, reason: 'layar beranda tetap ada di belakang dialog');
      expect(logouts(), 0);
    });

    testWidgets('Batal menutup dialog tanpa logout', (tester) async {
      final logouts = await pumpGuard(tester);
      await pressBack(tester);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari akun?'), findsNothing);
      expect(logouts(), 0);
      await pressBack(tester); // masih bisa dipicu lagi
      expect(find.text('Keluar dari akun?'), findsOneWidget);
    });

    testWidgets('Ya, Keluar menjalankan logout tepat satu kali', (tester) async {
      final logouts = await pumpGuard(tester);
      await pressBack(tester);
      await tester.tap(find.text('Ya, Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari akun?'), findsNothing);
      expect(logouts(), 1);
    });

    testWidgets('mengetuk di luar dialog sama dengan Batal', (tester) async {
      final logouts = await pumpGuard(tester);
      await pressBack(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari akun?'), findsNothing);
      expect(logouts(), 0);
    });
  });

  testWidgets('HomeScreen (layar utama setelah login) memakai konfirmasi logout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen(user: {'id': 8, 'fullName': 'Budi', 'roleCode': 'UMAT', 'accountStatus': 'APPROVED'})));
    await tester.pump(const Duration(milliseconds: 600));
    await pressBack(tester);
    expect(find.text('Keluar dari akun?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox()); // lepas layar
    NotificationService.stopPolling(); // polling notifikasi bersifat statis dan baru berhenti saat logout
  });
}
