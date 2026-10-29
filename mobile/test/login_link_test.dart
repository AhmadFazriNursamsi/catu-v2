import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/services/login_link_service.dart';
import 'package:catu_mobile/features/profile/change_password_screen.dart';

const _token = 'abcdefghijklmnopqrstuvwxyz0123456789_-ABCDE';

void main() {
  group('LoginLinkService.tokenFrom', () {
    test('menerima tautan https dan skema catu', () {
      expect(LoginLinkService.tokenFrom(Uri.parse('https://catu.devoutsys.com/api/public/m/login?t=$_token')), _token);
      expect(LoginLinkService.tokenFrom(Uri.parse('catu://m/login?t=$_token')), _token);
    });

    test('menolak jalur lain, token pendek, atau tanpa token', () {
      expect(LoginLinkService.tokenFrom(Uri.parse('https://catu.devoutsys.com/api/public/apk?t=$_token')), isNull);
      expect(LoginLinkService.tokenFrom(Uri.parse('catu://m/login?t=abc')), isNull);
      expect(LoginLinkService.tokenFrom(Uri.parse('catu://m/login')), isNull);
      expect(LoginLinkService.tokenFrom(Uri.parse('http://evil.test/x?t=$_token')), isNull);
    });
  });

  group('ChangePasswordScreen wajib ganti', () {
    Future<void> pump(WidgetTester tester, Map<String, dynamic> user) =>
        tester.pumpWidget(MaterialApp(home: ChangePasswordScreen(user: user, forced: true)));

    testWidgets('sesi tautan WhatsApp tidak meminta kata sandi saat ini', (tester) async {
      await pump(tester, {'id': 1, 'loginViaLink': true});
      expect(find.text('Kata Sandi Saat Ini'), findsNothing);
      expect(find.text('Kata Sandi Baru'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('login manual dengan kata sandi sementara tetap meminta kata sandi saat ini', (tester) async {
      await pump(tester, {'id': 1});
      expect(find.text('Kata Sandi Saat Ini'), findsOneWidget);
    });
  });
}
