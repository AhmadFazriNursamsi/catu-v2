import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

/// Daftar pendaftaran yang menunggu keputusan penyetuju (Ketua Romo atau Pengurus Lingkungan),
/// lengkap dengan aksi Setujui/Tolak. Dipakai sebagai tab "Menunggu" di Riwayat Persetujuan.
class ApprovalPendingList extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(int pendingLeft) onPendingChanged;
  final VoidCallback onDecided;
  const ApprovalPendingList({super.key, required this.user, required this.onPendingChanged, required this.onDecided});

  @override
  State<ApprovalPendingList> createState() => _ApprovalPendingListState();
}

const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _muted = Color(0xFF64748B);

class _ApprovalPendingListState extends State<ApprovalPendingList> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final Set<int> _busy = {};

  Map<String, dynamic> get _u => widget.user;
  bool get _isRomo => (_u['roleCode'] ?? _u['role_code'] ?? '').toString().toUpperCase().contains('ROMO');
  int _int(List<String> keys) {
    for (final k in keys) {
      final v = int.tryParse('${_u[k] ?? ''}');
      if (v != null) return v;
    }
    return 0;
  }

  int get _userId => _int(['id', 'userId', 'user_id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = _isRomo
        ? await ApiService.getPendingRomoList(
            romoUserId: _userId,
            parokiId: _int(['parokiId', 'paroki_id']) == 0 ? null : _int(['parokiId', 'paroki_id']),
            ordoId: _int(['ordoId', 'ordo_id']) == 0 ? null : _int(['ordoId', 'ordo_id']))
        : await ApiService.getPengurusPendingUmat(
            lingkunganId: _int(['lingkunganId', 'lingkungan_id']) == 0 ? null : _int(['lingkunganId', 'lingkungan_id']),
            pengurusUserId: _userId);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
    widget.onPendingChanged(list.length);
  }

  Future<void> _decide(Map<String, dynamic> t, String action, {String? reason}) async {
    final id = int.tryParse('${t['id']}');
    if (id == null) return;
    setState(() => _busy.add(id));
    HapticFeedback.mediumImpact();
    final res = _isRomo
        ? await ApiService.processRomoApproval(targetUserId: id, approverUserId: _userId, action: action, rejectionReason: reason)
        : await ApiService.processPengurusApproval(targetUserId: id, approverUserId: _userId, action: action, rejectionReason: reason);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    final ok = res['statusCode'] == 200;
    final approve = action == 'APPROVE';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (approve ? '${t['full_name']} berhasil disetujui!' : 'Pendaftaran ${t['full_name']} telah ditolak.')
          : (res['message'] ?? 'Gagal memproses persetujuan.').toString()),
      backgroundColor: ok ? (approve ? _green : _red) : _red,
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) {
      await _load();
      widget.onDecided();
    }
  }

  Future<void> _reject(Map<String, dynamic> t) async {
    final ctrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tolak Pendaftaran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tolak pendaftaran dari ${t['full_name']}?', style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Alasan Penolakan (Opsional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak Pendaftaran'),
          ),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (go == true) await _decide(t, 'REJECT', reason: reason);
  }

  String _label(Map<String, dynamic> t) {
    final role = (t['role_code'] ?? '').toString().toUpperCase();
    final pos = (t['pengurus_position'] ?? t['romo_position'] ?? '').toString().trim();
    if (pos.isNotEmpty && !pos.contains('_')) return pos;
    return switch (role) { 'ROMO_PAROKI' => 'Romo Paroki', 'ROMO_ORDO' => 'Romo Ordo', 'PENGURUS_LINGKUNGAN' => 'Pengurus Lingkungan', _ => 'Umat' };
  }

  String _place(Map<String, dynamic> t) {
    String? s(String k) => ('${t[k] ?? ''}').trim().isEmpty ? null : '${t[k]}';
    final parts = _isRomo
        ? [s('ordo_name') ?? s('paroki_name')]
        : [s('lingkungan_name'), s('paroki_name')];
    return parts.whereType<String>().join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: _items.isEmpty
            ? [
                const SizedBox(height: 60),
                const Icon(Icons.task_alt_rounded, size: 48, color: Color(0xFFCBD5E1)),
                const SizedBox(height: 12),
                const Center(child: Text('Tidak ada yang menunggu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppConstants.textDark))),
                const SizedBox(height: 4),
                const Text('Pendaftaran baru yang perlu keputusan Anda akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: _muted)),
              ]
            : [for (final t in _items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(t))],
      ),
    );
  }

  Widget _card(Map<String, dynamic> t) {
    final name = '${t['full_name'] ?? '-'}';
    final id = int.tryParse('${t['id']}') ?? -1;
    final busy = _busy.contains(id);
    final place = _place(t);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppConstants.primaryBlue.withValues(alpha: 0.08),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.primaryBlue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppConstants.textDark)),
              Text(_label(t), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              if (place.isNotEmpty) Text(place, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted)),
              if ('${t['phone_number'] ?? ''}'.isNotEmpty) Text('${t['phone_number']}', style: const TextStyle(fontSize: 12, color: _muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => _reject(t),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Tolak'),
              style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: Color(0xFFFCA5A5))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: busy ? null : () => _decide(t, 'APPROVE'),
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Setujui'),
              style: FilledButton.styleFrom(backgroundColor: _green),
            ),
          ),
        ]),
      ]),
    );
  }
}
