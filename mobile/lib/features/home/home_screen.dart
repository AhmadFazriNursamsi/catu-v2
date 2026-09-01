// CATU — Home Screen (Root State Handler with Profile Sync)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../auth/login_screen.dart';
import 'romo_dashboard_view.dart';
import 'umat_dashboard_view.dart';
import '../admin/admin_dashboard_view.dart';

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
  Timer? _pollTimer;
  bool _isSilentRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentUserMap = Map<String, dynamic>.from(widget.user);
    _loadOrders();
    _startPolling();
    final uid = _currentUserMap['id'] ?? _currentUserMap['userId'] ?? _currentUserMap['user_id'];
    if (uid != null) {
      NotificationService.startPolling(uid);
    }
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    NotificationService.stopPolling();
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefresh();
    });
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _isSilentRefreshing || _isLoading) return;
    _isSilentRefreshing = true;
    try {
      final rawId = _currentUserMap['id'] ?? _currentUserMap['userId'] ?? _currentUserMap['user_id'];
      final int? userId = rawId != null ? int.tryParse(rawId.toString()) : null;

      final String roleCode = (_currentUserMap['roleCode'] ??
          _currentUserMap['role_code'] ??
          _currentUserMap['role'] ??
          'UMAT').toString().toUpperCase();

      final rawParoki = _currentUserMap['parokiId'] ?? _currentUserMap['paroki_id'];
      final int? parokiId = rawParoki != null ? int.tryParse(rawParoki.toString()) : null;

      final rawKota = _currentUserMap['kabupatenKotaId'] ?? _currentUserMap['kabupaten_kota_id'];
      final int? kabupatenKotaId = rawKota != null ? int.tryParse(rawKota.toString()) : null;

      final latestOrders = await ApiService.getOrders(
        userId: roleCode.startsWith('ROMO') ? null : userId,
        parokiId: roleCode.startsWith('ROMO') ? null : parokiId,
        kabupatenKotaId: roleCode.startsWith('ROMO') ? null : kabupatenKotaId,
        romoId: roleCode.startsWith('ROMO') ? userId : null,
      );

      if (mounted) {
        bool hasChanges = latestOrders.length != _orders.length;
        if (!hasChanges && latestOrders.isNotEmpty && _orders.isNotEmpty) {
          if (latestOrders.first.id != _orders.first.id ||
              latestOrders.first.status != _orders.first.status ||
              latestOrders.last.status != _orders.last.status) {
            hasChanges = true;
          }
        }
        if (hasChanges) {
          setState(() {
            _orders = latestOrders;
          });
        }
      }
    } catch (_) {}
    _isSilentRefreshing = false;
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _loadOrders({bool showLoading = false}) async {
    if (showLoading || (_orders.isEmpty && _isLoading)) {
      setState(() => _isLoading = true);
    }

    try {
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

      final String roleCode = (_currentUserMap['roleCode'] ??
          _currentUserMap['role_code'] ??
          _currentUserMap['role'] ??
          'UMAT').toString().toUpperCase();

      final rawParoki = _currentUserMap['parokiId'] ?? _currentUserMap['paroki_id'];
      final int? parokiId = rawParoki != null ? int.tryParse(rawParoki.toString()) : null;

      final rawKota = _currentUserMap['kabupatenKotaId'] ?? _currentUserMap['kabupaten_kota_id'];
      final int? kabupatenKotaId = rawKota != null ? int.tryParse(rawKota.toString()) : null;

      final orders = await ApiService.getOrders(
        userId: roleCode.startsWith('ROMO') ? null : userId,
        parokiId: roleCode.startsWith('ROMO') ? null : parokiId,
        kabupatenKotaId: roleCode.startsWith('ROMO') ? null : kabupatenKotaId,
        romoId: roleCode.startsWith('ROMO') ? userId : null,
      );

      if (mounted) {
        setState(() {
          _orders = orders;
        });
      }
    } catch (e) {
      debugPrint('Error loading orders in HomeScreen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    if (roleCode == 'ADMIN' || roleCode.contains('ADMIN')) {
      return AdminDashboardView(
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
