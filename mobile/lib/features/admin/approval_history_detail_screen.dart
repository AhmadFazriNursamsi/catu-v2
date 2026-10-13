import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_http.dart' as http;
import '../orders/detail/kedukaan_hero.dart' show DeceasedPhoto;
import 'approval_history_screen.dart' show approvalRoleLabel, approvalWhen;

/// Detail lengkap akun pada satu entri riwayat persetujuan.
class ApprovalHistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> entry;
  const ApprovalHistoryDetailScreen({super.key, required this.entry});

  @override
  State<ApprovalHistoryDetailScreen> createState() => _ApprovalHistoryDetailScreenState();
}

const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _muted = Color(0xFF64748B);

class _ApprovalHistoryDetailScreenState extends State<ApprovalHistoryDetailScreen> {
  late Map<String, dynamic> _data = widget.entry;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('${ApiService.baseUrl}/auth/approvals/history/${widget.entry['id']}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Status ${res.statusCode}');
      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        if (data is Map) _data = Map<String, dynamic>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Data lengkap tidak dapat dimuat. Tarik ke bawah untuk mencoba lagi.';
        _loading = false;
      });
    }
  }

  String _v(String key) => (_data[key] ?? '').toString().trim();

  String get _gender => switch (_v('gender').toUpperCase()) { 'L' => 'Laki-laki', 'P' => 'Perempuan', _ => '' };

  String get _phone {
    final p = _v('phone_number');
    return p.startsWith('62') ? '+62 ${p.substring(2)}' : p;
  }

  String get _accountStatus => switch (_v('account_status').toUpperCase()) {
        'APPROVED' => 'Aktif',
        'REJECTED' => 'Ditolak',
        'PENDING_APPROVAL' => 'Menunggu Persetujuan',
        final s => s,
      };

  String get _jabatanPeriod {
    final a = _v('jabatan_start_year'), b = _v('jabatan_end_year');
    if (a.isEmpty && b.isEmpty) return '';
    return '${a.isEmpty ? '?' : a} – ${b.isEmpty ? 'sekarang' : b}';
  }

  @override
  Widget build(BuildContext context) {
    final approved = _data['action'] == 'APPROVED';
    final color = approved ? _green : _red;
    final reason = _v('rejection_reason');
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Detail Persetujuan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
        iconTheme: const IconThemeData(color: AppConstants.textDark),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _header(color, approved),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _red)),
              ),
            _Section(title: 'Keputusan Anda', rows: [
              ('Status', approved ? 'Disetujui' : 'Ditolak'),
              ('Waktu diproses', approvalWhen(_v('created_at'))),
              if (!approved) ('Alasan penolakan', reason.isEmpty ? '-' : reason),
              ('Status akun saat ini', _accountStatus),
            ]),
            _Section(title: 'Data Pribadi', rows: [
              ('Nama lengkap', _v('full_name')),
              ('No. WhatsApp', _phone),
              ('Email', _v('email')),
              ('Jenis kelamin', _gender),
              ('Tanggal lahir', _v('birth_date')),
              ('Alamat', _v('address')),
              ('Terdaftar sejak', approvalWhen(_v('registered_at'))),
            ]),
            _Section(title: 'Peran & Jabatan', rows: [
              ('Peran', approvalRoleLabel(_data)),
              ('Periode jabatan', _jabatanPeriod),
              ('Ordo', _v('ordo_name')),
            ]),
            _Section(title: 'Wilayah Gereja', rows: [
              ('Keuskupan', _v('keuskupan_name')),
              ('Paroki', _v('paroki_name')),
              ('Wilayah', _v('wilayah_name')),
              ('Lingkungan', _v('lingkungan_name')),
            ]),
            _Section(title: 'Domisili', rows: [
              ('Provinsi', _v('provinsi_name')),
              ('Kota / Kabupaten', _v('kota_name')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _header(Color color, bool approved) {
    final name = _v('full_name');
    final avatar = _v('avatar_url');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        SizedBox(
          width: 60,
          height: 60,
          child: ClipOval(
            child: avatar.isEmpty
                ? ColoredBox(
                    color: AppConstants.primaryBlue.withValues(alpha: 0.08),
                    child: Center(
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppConstants.primaryBlue)),
                    ),
                  )
                : DeceasedPhoto(url: avatar),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? '-' : name,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
            const SizedBox(height: 2),
            Text(approvalRoleLabel(_data), style: const TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(approved ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: color),
                const SizedBox(width: 4),
                Text(approved ? 'Anda setujui' : 'Anda tolak',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Kartu berisi pasangan label–nilai; baris yang nilainya kosong tidak ditampilkan.
class _Section extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => r.$2.trim().isNotEmpty && r.$2 != '-' || r.$1 == 'Alasan penolakan').toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
        const SizedBox(height: 8),
        for (final r in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 128, child: Text(r.$1, style: const TextStyle(fontSize: 12.5, color: _muted))),
              Expanded(
                child: SelectableText(r.$2,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppConstants.textDark, height: 1.3)),
              ),
            ]),
          ),
      ]),
    );
  }
}
