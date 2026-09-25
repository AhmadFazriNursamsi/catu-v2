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
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic> _userData = {};

  String get _storageKey => 'kunjungan_pendatang_${widget.user['id'] ?? widget.user['userId'] ?? 'pendatang'}';

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
          final rawList = (decoded['history'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final List<Map<String, dynamic>> deduped = [];
          for (final h in rawList) {
            h['id'] ??= 'kunj_${(h['tanggal'] ?? '').hashCode.abs()}_${(h['alamat'] ?? '').hashCode.abs()}';
            h['orderIds'] = (h['orderIds'] as List? ?? []).map((id) => int.tryParse(id.toString()) ?? 0).where((id) => id > 0).toList();
            if (deduped.isEmpty || deduped.last['tanggal'] != h['tanggal'] || deduped.last['alamat'] != h['alamat'] || deduped.last['kota'] != h['kota']) {
              deduped.add(h);
            }
          }
          setState(() {
            _activeProvinsi = decoded['provinsi'] ?? _activeProvinsi;
            _activeKota = decoded['kota'] ?? _activeKota;
            _history = deduped;
          });
          _persistData();
          return;
        }
      }
    } catch (_) {}
    if (_history.isEmpty) {
      setState(() => _history = [{'id': 'kunj_init', 'tanggal': '23 September 2026', 'provinsi': 'DKI JAKARTA', 'kota': 'KOTA JAKARTA UTARA', 'alamat': 'Kelapa Gading', 'orderIds': <int>[]}]);
    }
  }

  Future<void> _persistData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode({'provinsi': _activeProvinsi, 'kota': _activeKota, 'history': _history}));
    } catch (_) {}
  }

  int _countOrdersForKunjungan(Map<String, dynamic> item) {
    final kunjId = item['id']?.toString() ?? '';
    final orderIds = (item['orderIds'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final kunjAlamat = (item['alamat'] ?? '').toString().trim().toLowerCase();
    int count = 0;
    for (final o in widget.orders) {
      final rawNotes = o.notes;
      if (kunjId.isNotEmpty && rawNotes.contains('[KunjunganId: $kunjId]')) {
        count++;
      } else if (orderIds.contains(o.id.toString())) {
        count++;
      } else if (kunjAlamat.isNotEmpty && o.locationName.trim().toLowerCase() == kunjAlamat && !rawNotes.contains('[KunjunganId:')) {
        count++;
      }
    }
    return count;
  }

  void _openKunjunganDialog() {
    showDialog(
      context: context,
      builder: (ctx) => KunjunganDialog(
        onSaved: (tanggal, provinsi, kota, alamat) {
          final item = {'id': 'kunj_${DateTime.now().millisecondsSinceEpoch}', 'tanggal': tanggal, 'provinsi': provinsi, 'kota': kota, 'alamat': alamat, 'orderIds': <int>[]};
          if (_history.isNotEmpty && _history.first['tanggal'] == tanggal && _history.first['alamat'] == alamat && _history.first['kota'] == kota) return;
          setState(() { _activeProvinsi = provinsi; _activeKota = kota; _history.insert(0, item); });
          _persistData();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white, size: 20), SizedBox(width: 10), Expanded(child: Text('Lokasi kunjungan berhasil disimpan!', style: TextStyle(fontWeight: FontWeight.bold)))]),
            backgroundColor: const Color(0xFF0D9488), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2),
          ));
          _openKunjunganDetail(item);
        },
      ),
    );
  }

  void _openKunjunganDetail(Map<String, dynamic> item) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => KunjunganDetailScreen(
      kunjungan: item, user: _userData.isNotEmpty ? _userData : widget.user, orders: widget.orders, onRefresh: widget.onRefresh,
      onUpdateKunjungan: (up) {
        final idx = _history.indexWhere((h) => h['id'] == up['id'] || (h['tanggal'] == up['tanggal'] && h['alamat'] == up['alamat']));
        if (idx != -1) setState(() => _history[idx] = up);
        _persistData();
      },
    ))).then((_) => widget.onRefresh());
  }

  void _deleteHistory(int idx) {
    setState(() => _history.removeAt(idx));
    _persistData();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Riwayat kunjungan dihapus'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); widget.onLogout(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white), child: const Text('Keluar')),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name) {
    return Row(
      children: [
        CircleAvatar(radius: 26, backgroundColor: const Color(0xFF1E5399).withValues(alpha: 0.12), child: const Icon(Icons.person_rounded, size: 28, color: Color(0xFF1E5399))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1E5399).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: const Text('UMAT PENDATANG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E5399)))),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.redAccent), tooltip: 'Logout', onPressed: _confirmLogout),
      ],
    );
  }

  Widget _buildInfoCard(String keuskupan, String paroki, String prov, String kota, String alamat) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.home_work_outlined, size: 18, color: Color(0xFF1E5399)), SizedBox(width: 8), Text('Informasi Domisili Asal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)))]),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildInfoRow('Keuskupan', keuskupan, Icons.account_balance_rounded),
          _buildInfoRow('Paroki', paroki, Icons.church_outlined),
          _buildInfoRow('Wilayah', '$prov, $kota', Icons.location_city_rounded),
          _buildInfoRow('Alamat', alamat, Icons.pin_drop_outlined, isLast: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)), children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))), TextSpan(text: value.isNotEmpty ? value : '-')]))),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            onPressed: _openKunjunganDialog,
            icon: const Icon(Icons.add_location_alt_rounded, size: 20),
            label: const Text('+ TAMBAH LOKASI KUNJUNGAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5399), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 1),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              final tu = Map<String, dynamic>.from(_userData.isNotEmpty ? _userData : widget.user);
              if (_history.isNotEmpty) {
                tu['kunjungan'] = _history.first;
                tu['provinsi'] = tu['kota'] = tu['alamat'] = tu['alamat_kunjungan'] = _history.first['alamat'];
                tu['provinsi'] = _history.first['provinsi']; tu['kota'] = _history.first['kota'];
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => UmatDashboardView(user: tu, orders: widget.orders, onRefresh: widget.onRefresh, onLogout: widget.onLogout))).then((_) { widget.onRefresh(); _loadSavedData(); });
            },
            icon: const Icon(Icons.assignment_turned_in_rounded, size: 20, color: Color(0xFF1E5399)),
            label: const Text('PELAYANAN & RIWAYAT PERMINTAAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E5399))),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1E5399), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Riwayat Kunjungan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: Text('${_history.length} Lokasi', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
          ],
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Center(child: Text('Belum ada riwayat kunjungan.\nKlik "+ Tambah Lokasi Kunjungan" untuk memulai.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
          )
        else
          ..._history.asMap().entries.map((entry) {
            final idx = entry.key, item = entry.value, count = _countOrdersForKunjungan(item);
            return Card(
              margin: const EdgeInsets.only(bottom: 10), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: InkWell(
                onTap: () => _openKunjunganDetail(item),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF1E5399).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.location_on_rounded, color: Color(0xFF1E5399), size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)), child: Text(item['tanggal']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E5399)))),
                                const SizedBox(width: 6),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: count > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)), child: Text('$count Pelayanan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: count > 0 ? const Color(0xFF059669) : const Color(0xFF64748B)))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(item['alamat']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                            Text('${item['kota'] ?? ''}, ${item['provinsi'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20), tooltip: 'Hapus Kunjungan', onPressed: () => _deleteHistory(idx)),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _userData.isNotEmpty ? _userData : widget.user;
    final name = u['fullName'] ?? u['full_name'] ?? 'Umat Pendatang';
    final keuskupan = u['keuskupanName'] ?? u['keuskupan_name'] ?? '-';
    final paroki = u['parokiName'] ?? u['paroki_name'] ?? '-';
    final kotaAsal = u['kabupatenKotaName'] ?? u['kota_name'] ?? '-';
    final rawProv = u['provinsiName'] ?? u['provinsi_name'] ?? '';
    final ku = kotaAsal.toUpperCase();
    final provAsal = (rawProv.isNotEmpty && rawProv != '-') ? rawProv : (ku.contains('JAKARTA') ? 'DKI JAKARTA' : ku.contains('TANGERANG') ? 'BANTEN' : (ku.contains('BANDUNG') || ku.contains('BOGOR') || ku.contains('BEKASI')) ? 'JAWA BARAT' : ku.contains('YOGYA') ? 'DI YOGYAKARTA' : '-');
    final alamatAsal = u['address'] ?? u['alamat'] ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(name),
              const SizedBox(height: 16),
              _buildInfoCard(keuskupan, paroki, provAsal, kotaAsal, alamatAsal),
              const SizedBox(height: 18),
              _buildActionButtons(),
              const SizedBox(height: 22),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }
}
