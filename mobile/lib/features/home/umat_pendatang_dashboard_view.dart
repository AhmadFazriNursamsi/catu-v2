import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import 'kunjungan_detail_screen.dart';
import 'kunjungan_dialog.dart';
import 'umat_dashboard_view.dart';

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
  String _activeProvinsi = 'DI YOGYAKARTA';
  String _activeKota = 'KOTA YOGYAKARTA';
  List<Map<String, String>> _history = [];
  Map<String, dynamic> _userData = {};

  String get _storageKey {
    final uid = widget.user['id'] ?? widget.user['userId'] ?? 'pendatang';
    return 'kunjungan_pendatang_$uid';
  }

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.user);
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final rawId = widget.user['id'] ?? widget.user['userId'];
    if (rawId != null) {
      try {
        final res = await http.get(Uri.parse('${ApiService.baseUrl}/auth/profile/$rawId')).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic> && data['user'] is Map) {
            final u = Map<String, dynamic>.from(data['user'] as Map);
            if (mounted) setState(() => _userData = u);
            AuthService.saveSession(u);
          }
        }
      } catch (_) {}
    }

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
              _history = (decoded['history'] as List).map((e) => Map<String, String>.from(e as Map)).toList();
            }
          });
          return;
        }
      }
    } catch (_) {}
    if (_history.isEmpty) {
      setState(() {
        _history = [
          {'tanggal': '23 September 2026', 'provinsi': 'DKI JAKARTA', 'kota': 'KOTA JAKARTA UTARA', 'alamat': 'Kelapa Gading'}
        ];
      });
    }
  }

  Future<void> _persistData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {'provinsi': _activeProvinsi, 'kota': _activeKota, 'history': _history};
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (_) {}
  }

  void _openKunjunganDialog() {
    showDialog(
      context: context,
      builder: (ctx) => KunjunganDialog(
        onSaved: (tanggal, provinsi, kota, alamat) {
          final item = {'tanggal': tanggal, 'provinsi': provinsi, 'kota': kota, 'alamat': alamat};
          setState(() {
            _activeProvinsi = provinsi;
            _activeKota = kota;
            _history.insert(0, item);
          });
          _persistData();
          _openKunjunganDetail(item);
        },
      ),
    );
  }

  void _openKunjunganDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KunjunganDetailScreen(
          kunjungan: item,
          user: _userData.isNotEmpty ? _userData : widget.user,
          orders: widget.orders,
          onRefresh: widget.onRefresh,
        ),
      ),
    ).then((_) => widget.onRefresh());
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
    final name = _userData['fullName'] ?? _userData['full_name'] ?? widget.user['fullName'] ?? widget.user['full_name'] ?? 'Testing';
    final keuskupan = _userData['keuskupanName'] ?? _userData['keuskupan_name'] ?? widget.user['keuskupanName'] ?? widget.user['keuskupan_name'] ?? '-';
    final paroki = _userData['parokiName'] ?? _userData['paroki_name'] ?? widget.user['parokiName'] ?? widget.user['paroki_name'] ?? '-';
    final kotaAsal = _userData['kabupatenKotaName'] ?? _userData['kota_name'] ?? widget.user['kabupatenKotaName'] ?? widget.user['kota_name'] ?? '-';
    String provAsal = _userData['provinsiName'] ?? _userData['provinsi_name'] ?? widget.user['provinsiName'] ?? widget.user['provinsi_name'] ?? '';
    if (provAsal.isEmpty || provAsal == '-') {
      final ku = kotaAsal.toUpperCase();
      provAsal = ku.contains('JAKARTA')
          ? 'DKI JAKARTA'
          : ku.contains('TANGERANG')
              ? 'BANTEN'
              : (ku.contains('BANDUNG') || ku.contains('BOGOR') || ku.contains('BEKASI'))
                  ? 'JAWA BARAT'
                  : ku.contains('YOGYA')
                      ? 'DI YOGYAKARTA'
                      : '-';
    }
    final alamatAsal = _userData['address'] ?? _userData['alamat'] ?? widget.user['address'] ?? widget.user['alamat'] ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
              IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), tooltip: 'Logout', onPressed: widget.onLogout),
            ],
          ),
          const SizedBox(height: 14),
          _buildBox('Nama', name),
          _buildBox('Keuskupan Asal', keuskupan),
          _buildBox('Paroki Asal', paroki),
          _buildBox('Provinsi', provAsal),
          _buildBox('Kota', kotaAsal),
          _buildBox('Alamat Asal', alamatAsal),
          const SizedBox(height: 10),
          _buildActionButton('PELAYANAN YANG SEDANG DIMINTA DAN HISTORY', () {
            final targetUser = Map<String, dynamic>.from(_userData.isNotEmpty ? _userData : widget.user);
            if (_history.isNotEmpty) {
              targetUser['kunjungan'] = _history.first;
              targetUser['provinsi'] = _history.first['provinsi'];
              targetUser['kota'] = _history.first['kota'];
              targetUser['alamat'] = _history.first['alamat'];
              targetUser['alamat_kunjungan'] = _history.first['alamat'];
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UmatDashboardView(
                  user: targetUser,
                  orders: widget.orders,
                  onRefresh: widget.onRefresh,
                  onLogout: widget.onLogout,
                ),
              ),
            ).then((_) {
              widget.onRefresh();
              _loadSavedData();
            });
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
          (item) => InkWell(
            onTap: () => _openKunjunganDetail(item),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Text(item['tanggal'] ?? '', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1B4B82)))),
                  Expanded(flex: 3, child: Text(item['provinsi'] ?? '', style: const TextStyle(fontSize: 12.5))),
                  Expanded(flex: 3, child: Text(item['kota'] ?? '', style: const TextStyle(fontSize: 12.5))),
                  Expanded(flex: 3, child: Text(item['alamat'] ?? '', style: const TextStyle(fontSize: 12.5))),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildHomeBody()),
    );
  }
}
