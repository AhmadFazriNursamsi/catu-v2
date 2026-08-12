import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';

void main() {
  runApp(const CatuApp());
}

class CatuApp extends StatelessWidget {
  const CatuApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
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
  }
}
