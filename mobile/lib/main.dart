import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'core/services/language_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/pending_approval_screen.dart';
import 'features/home/home_screen.dart';
import 'features/news/public_news_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.init();
  await NotificationService.init();
  final savedUser = await AuthService.initSession();
  runApp(CatuApp(initialUser: savedUser));
}

class CatuApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;
  const CatuApp({Key? key, this.initialUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguage,
      builder: (context, langCode, child) {
        return MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          title: LanguageService.tr('app_name'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConstants.primaryBlue,
              primary: AppConstants.primaryBlue,
              secondary: AppConstants.accentGold,
            ),
            scaffoldBackgroundColor: AppConstants.bgCanvas,
            fontFamily: 'Roboto',
          ),
          home: initialUser != null
              ? (initialUser!['accountStatus'] == 'PENDING_APPROVAL'
                  ? PendingApprovalScreen(user: initialUser!)
                  : HomeScreen(user: initialUser!))
              : const PublicNewsScreen(),
        );
      },
    );
  }
}
