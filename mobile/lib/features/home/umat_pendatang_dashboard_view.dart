import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/models.dart';
import '../../core/services/language_service.dart';
import '../../core/widgets/liquid_bottom_nav_bar.dart';
import '../orders/histori_screen.dart';
import '../orders/schedule_screen.dart';
import '../profile/main_menu_screen.dart';
import 'kunjungan_dialog.dart';

List<LiquidNavItem> _buildNavItems() => [
      LiquidNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: LanguageService.tr('nav_home'),
      ),
      LiquidNavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: LanguageService.tr('nav_history'),
      ),
      LiquidNavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: LanguageService.tr('nav_schedule'),
      ),
      LiquidNavItem(
        icon: Icons.menu_outlined,
        activeIcon: Icons.menu_rounded,
        label: LanguageService.tr('nav_profile'),
      ),
    ];

class UmatPendatangDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Order> orders;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const UmatPendatangDashboardView({
    super.key,
    required this.user,
    required this.orders,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<UmatPendatangDashboardView> createState() => _UmatPendatangDashboardViewState();
}

class _UmatPendatangDashboardViewState extends State<UmatPendatangDashboardView> {
  int _currentNavIndex = 0;
  String _activeProvinsi = 'DI YOGYAKARTA';
  String _activeKota = 'KOTA YOGYAKARTA';
  List<Map<String, String>> _history = [];

  String get _storageKey {
    final uid = widget.user['id'] ?? widget.user['userId'] ?? 'pendatang';
    return 'kunjungan_pendatang_$uid';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _activeProvinsi = decoded['provinsi'] ?? _activeProvinsi;
            _activeKota = decoded['kota'] ?? _activeKota;
            if (decoded['history'] is List) {
              _history = (decoded['history'] as List)
                  .map((e) => Map<String, String>.from(e as Map))
                  .toList();
            }
          });
          return;
        }
      }
    } catch (_) {}
    if (_history.isEmpty) {
      setState(() {
        _history = [
          {
            'tanggal': '23 September 2026',
            'provinsi': 'DKI JAKARTA',
            'kota': 'KOTA JAKARTA UTARA',
            'alamat': 'Kelapa Gading',
          }
        ];
      });
    }
  }

  Future<void> _persistData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'provinsi': _activeProvinsi,
        'kota': _activeKota,
        'history': _history,
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (_) {}
  }

  void _openKunjunganDialog() {
    showDialog(
      context: context,
      builder: (ctx) => KunjunganDialog(
        onSaved: (tanggal, provinsi, kota, alamat) {
          setState(() {
            _activeProvinsi = provinsi;
            _activeKota = kota;
            _history.insert(0, {
              'tanggal': tanggal,
              'provinsi': provinsi,
              'kota': kota,
              'alamat': alamat,
            });
          });
          _persistData();
        },
      ),
    );
  }

  Widget _buildBox(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1B4B82), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBody() {
    final name = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Testing';
    final keuskupan = widget.user['keuskupanName'] ?? widget.user['keuskupan_name'] ?? 'Keuskupan Agung Jakarta';
    final paroki = widget.user['parokiName'] ?? widget.user['paroki_name'] ?? 'Paroki Alam Sutera - St. Laurensius';
    final alamatAsal = widget.user['address'] ?? widget.user['alamat'] ?? 'Tes';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 14),
          _buildBox('Nama', name),
          _buildBox('Keuskupan Asal', keuskupan),
          _buildBox('Paroki Asal', paroki),
          _buildBox('Provinsi', _activeProvinsi),
          _buildBox('Kota', _activeKota),
          _buildBox('Alamat Asal', alamatAsal),
          const SizedBox(height: 10),
          _buildActionButton('PELAYANAN YANG SEDANG DIMINTA DAN HISTORY', () {
            setState(() => _currentNavIndex = 1);
          }),
          const SizedBox(height: 12),
          _buildActionButton('LOKASI YANG SEDANG DIKUNJUNGI', _openKunjunganDialog),
          const SizedBox(height: 20),
          const Text(
            'History Kunjungan Dan Pelayanan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 14),
          _buildHistoryTable(),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B4B82),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 2,
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTable() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(flex: 3, child: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
            Expanded(flex: 3, child: Text('Provinsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
            Expanded(flex: 3, child: Text('Kota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
            Expanded(flex: 3, child: Text('Alamat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
          ],
        ),
        const SizedBox(height: 12),
        ..._history.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: Text(item['tanggal'] ?? '', style: const TextStyle(fontSize: 12.5))),
                Expanded(flex: 3, child: Text(item['provinsi'] ?? '', style: const TextStyle(fontSize: 12.5))),
                Expanded(flex: 3, child: Text(item['kota'] ?? '', style: const TextStyle(fontSize: 12.5))),
                Expanded(flex: 3, child: Text(item['alamat'] ?? '', style: const TextStyle(fontSize: 12.5))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Umat';
    final rawId = widget.user['id'] ?? widget.user['userId'];
    final userId = rawId != null ? int.tryParse(rawId.toString()) : null;

    if (_currentNavIndex == 1) {
      return Scaffold(
        body: HistoriScreen(orders: widget.orders, userName: userName, userId: userId, onRefresh: widget.onRefresh),
        bottomNavigationBar: LiquidBottomNavBar(
          selectedIndex: _currentNavIndex,
          onTabSelected: (i) => setState(() => _currentNavIndex = i),
          items: _buildNavItems(),
        ),
      );
    }

    if (_currentNavIndex == 2) {
      return Scaffold(
        body: ScheduleScreen(orders: widget.orders, userName: userName, userId: userId, onRefresh: widget.onRefresh),
        bottomNavigationBar: LiquidBottomNavBar(
          selectedIndex: _currentNavIndex,
          onTabSelected: (i) => setState(() => _currentNavIndex = i),
          items: _buildNavItems(),
        ),
      );
    }

    if (_currentNavIndex == 3) {
      return Scaffold(
        body: MainMenuScreen(user: widget.user, onRefresh: widget.onRefresh, onLogout: widget.onLogout),
        bottomNavigationBar: LiquidBottomNavBar(
          selectedIndex: _currentNavIndex,
          onTabSelected: (i) => setState(() => _currentNavIndex = i),
          items: _buildNavItems(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildHomeBody()),
      bottomNavigationBar: LiquidBottomNavBar(
        selectedIndex: _currentNavIndex,
        onTabSelected: (i) => setState(() => _currentNavIndex = i),
        items: _buildNavItems(),
      ),
    );
  }
}
