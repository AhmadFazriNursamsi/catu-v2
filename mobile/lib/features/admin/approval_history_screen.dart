import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_http.dart' as http;
import 'approval_history_detail_screen.dart';
import 'approval_pending_list.dart';

/// Riwayat akun yang pernah disetujui / ditolak oleh penyetuju yang sedang login.
/// Dengan [user], layar ini punya tab "Menunggu" (keputusan yang belum diambil) di samping riwayat;
/// [startOnPending] membukanya langsung di tab itu (dipakai notifikasi pendaftaran baru).
class ApprovalHistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final bool startOnPending;
  const ApprovalHistoryScreen({super.key, this.user, this.startOnPending = false});

  @override
  State<ApprovalHistoryScreen> createState() => _ApprovalHistoryScreenState();
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _muted = Color(0xFF64748B);

String approvalWhen(String? raw) {
  final d = DateTime.tryParse(raw ?? '')?.toLocal();
  if (d == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}.${two(d.minute)}';
}

String approvalRoleLabel(Map<String, dynamic> e) {
  final role = (e['role_code'] ?? '').toString().toUpperCase();
  final pengurus = (e['pengurus_position'] ?? '').toString().trim();
  final romo = (e['romo_position'] ?? '').toString().toUpperCase();
  if (pengurus.isNotEmpty) return pengurus;
  if (role == 'ROMO_PAROKI') return romo.contains('KETUA') || romo.contains('KEPALA') ? 'Kepala Romo Paroki' : 'Romo Paroki';
  if (role == 'ROMO_ORDO') return romo.contains('KETUA') ? 'Ketua Romo Ordo' : 'Romo Ordo';
  if (role == 'UMAT_PENDATANG') return 'Umat Pendatang';
  return 'Umat';
}

String _placeLabel(Map<String, dynamic> e) {
  final role = (e['role_code'] ?? '').toString().toUpperCase();
  String? s(String k) => (e[k] ?? '').toString().trim().isEmpty ? null : e[k].toString();
  final parts = role == 'ROMO_ORDO'
      ? [s('ordo_name')]
      : role == 'ROMO_PAROKI'
          ? [s('paroki_name')]
          : [s('lingkungan_name'), s('paroki_name')];
  return parts.whereType<String>().join(' · ');
}

class _ApprovalHistoryScreenState extends State<ApprovalHistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';
  String _query = '';
  late bool _onPending = widget.user != null && widget.startOnPending;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _tabs() {
    Widget tab(bool pending, String label) {
      final selected = _onPending == pending;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _onPending = pending),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppConstants.primaryBlue : Colors.transparent, width: 2.5))),
            child: Center(child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: selected ? AppConstants.primaryBlue : _muted))),
          ),
        ),
      );
    }

    return Container(color: Colors.white, child: Row(children: [tab(true, 'Menunggu ($_pendingCount)'), tab(false, 'Riwayat (${_items.length})')]));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/auth/approvals/history')).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Status ${res.statusCode}');
      final data = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        _items = data is List ? List<Map<String, dynamic>>.from(data) : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Riwayat persetujuan tidak dapat dimuat. Periksa koneksi lalu coba lagi.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((e) {
      if (_filter != 'ALL' && e['action'] != _filter) return false;
      if (q.isEmpty) return true;
      return '${e['full_name']} ${e['phone_number']} ${e['lingkungan_name']}'.toLowerCase().contains(q);
    }).toList();
  }

  int _count(String action) => _items.where((e) => e['action'] == action).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(widget.user == null ? 'Riwayat Persetujuan' : 'Persetujuan',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
        iconTheme: const IconThemeData(color: AppConstants.textDark),
        bottom: widget.user == null ? null : PreferredSize(preferredSize: const Size.fromHeight(46), child: _tabs()),
      ),
      body: widget.user == null
          ? RefreshIndicator(onRefresh: _load, child: _body())
          : IndexedStack(index: _onPending ? 0 : 1, children: [
              ApprovalPendingList(
                user: widget.user!,
                onPendingChanged: (n) => setState(() => _pendingCount = n),
                onDecided: () {
                  _load();
                  setState(() => _onPending = false);
                },
              ),
              RefreshIndicator(onRefresh: _load, child: _body()),
            ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat',
          text: _error!,
          action: TextButton(onPressed: _load, child: const Text('Coba Lagi')));
    }
    final list = _visible;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Cari nama, nomor, atau lingkungan',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          _chip('ALL', 'Semua', _items.length, AppConstants.primaryBlue),
          _chip('APPROVED', 'Disetujui', _count('APPROVED'), _green),
          _chip('REJECTED', 'Ditolak', _count('REJECTED'), _red),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty)
          _Message(
            icon: Icons.history_rounded,
            title: _items.isEmpty ? 'Belum ada riwayat' : 'Tidak ditemukan',
            text: _items.isEmpty
                ? 'Akun yang Anda setujui atau tolak akan tercatat di sini.'
                : 'Tidak ada riwayat yang cocok dengan pencarian atau filter.',
          )
        else
          ...list.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _HistoryCard(entry: e))),
      ],
    );
  }

  Widget _chip(String code, String label, int count, Color color) {
    final selected = _filter == code;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _filter = code);
      },
      showCheckmark: false,
      selectedColor: color.withValues(alpha: 0.12),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? color : const Color(0xFFE2E8F0)),
      labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? color : _muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final approved = entry['action'] == 'APPROVED';
    final color = approved ? _green : _red;
    final name = (entry['full_name'] ?? '-').toString();
    final place = _placeLabel(entry);
    final reason = (entry['rejection_reason'] ?? '').toString().trim();
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => ApprovalHistoryDetailScreen(entry: entry)));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppConstants.primaryBlue.withValues(alpha: 0.08),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.primaryBlue)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(approved ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(approved ? 'Disetujui' : 'Ditolak',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(approvalRoleLabel(entry),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(place, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted)),
                ],
                if (!approved && reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Alasan: $reason', style: const TextStyle(fontSize: 12, color: _red, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(approvalWhen(entry['created_at']?.toString()),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                  const Spacer(),
                  const Text('Lihat detail',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppConstants.primaryBlue)),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppConstants.primaryBlue),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.title, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ]),
    );
  }
}
