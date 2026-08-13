import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/services/language_service.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.init();
  runApp(const CatuApp());
}

class CatuApp extends StatelessWidget {
  const CatuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguage,
      builder: (context, langCode, child) {
        return MaterialApp(
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
          home: const LoginScreen(),
        );
      },
    );
  }
}
