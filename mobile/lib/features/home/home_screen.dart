// CATU — Home Screen (Root State Handler with Profile Sync)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../auth/login_screen.dart';
import 'romo_dashboard_view.dart';
import 'umat_dashboard_view.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  late Map<String, dynamic> _currentUserMap;

  @override
  void initState() {
    super.initState();
    _currentUserMap = Map<String, dynamic>.from(widget.user);
    _loadOrders();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    final rawId =
        _currentUserMap['id'] ?? _currentUserMap['userId'] ?? _currentUserMap['user_id'];
    final int? userId = rawId != null ? int.tryParse(rawId.toString()) : null;

    if (userId != null) {
      try {
        final profileRes = await http.get(
          Uri.parse('${ApiService.baseUrl}/auth/profile/$userId'),
        );
        if (profileRes.statusCode == 200) {
          final resData = jsonDecode(profileRes.body);
          if (resData['user'] != null) {
            _currentUserMap = Map<String, dynamic>.from(resData['user']);
          }
        }
      } catch (e) {
        debugPrint('Error reloading profile in HomeScreen: $e');
      }
    }

    final String roleCode = _currentUserMap['roleCode'] ??
        _currentUserMap['role_code'] ??
        _currentUserMap['role'] ??
        'UMAT';
    final orders = await ApiService.getOrders(
      userId: roleCode.startsWith('ROMO') ? null : userId,
    );

    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String roleCode = _currentUserMap['roleCode'] ??
        _currentUserMap['role_code'] ??
        _currentUserMap['role'] ??
        'UMAT';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (roleCode.startsWith('ROMO')) {
      return RomoDashboardView(
        user: _currentUserMap,
        orders: _orders,
        onRefresh: _loadOrders,
        onLogout: () {
          Navigator.pushReplacement(
            context,
            FadeSlideRoute(page: const LoginScreen()),
          );
        },
      );
    }

    return UmatDashboardView(
      user: _currentUserMap,
      orders: _orders,
      onRefresh: _loadOrders,
      onLogout: () {
        Navigator.pushReplacement(
          context,
          FadeSlideRoute(page: const LoginScreen()),
        );
      },
    );
  }
}
