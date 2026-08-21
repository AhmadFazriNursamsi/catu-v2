import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

class RomoApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const RomoApprovalScreen({super.key, required this.user});

  @override
  State<RomoApprovalScreen> createState() => _RomoApprovalScreenState();
}

class _RomoApprovalScreenState extends State<RomoApprovalScreen> {
  List<Map<String, dynamic>> _pendingList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<int, bool> _processingMap = {};

  int get _romoUserId {
    final raw = widget.user['id'] ?? widget.user['userId'];
    return raw != null ? int.tryParse(raw.toString()) ?? 0 : 0;
  }

  bool get _isOrdo {
    final rawRole = widget.user['roleCode'] ?? widget.user['role_code'] ?? '';
    return rawRole.toString().toUpperCase().contains('ORDO');
  }

  int? get _parokiId {
    final raw = widget.user['parokiId'] ?? widget.user['paroki_id'];
    return raw != null ? int.tryParse(raw.toString()) : null;
  }

  int? get _ordoId {
    final raw = widget.user['ordoId'] ?? widget.user['ordo_id'];
    return raw != null ? int.tryParse(raw.toString()) : null;
  }

  String get _scopeTitle {
    if (_isOrdo) {
      final ordoName = widget.user['ordoName'] ?? widget.user['ordo_name'] ?? 'Ordo Anda';
      return 'Ordo: $ordoName';
    }
    final parokiName = widget.user['parokiName'] ?? widget.user['paroki_name'] ?? 'Paroki Anda';
    return parokiName;
  }

  @override
  void initState() {
    super.initState();
    _fetchPendingList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingList() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getPendingRomoList(
      romoUserId: _romoUserId,
      parokiId: _parokiId,
      ordoId: _ordoId,
    );
    if (mounted) {
      setState(() {
        _pendingList = list;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_searchQuery.isEmpty) return _pendingList;
    final q = _searchQuery.toLowerCase();
    return _pendingList.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final phone = (u['phone_number'] ?? '').toString().toLowerCase();
      final par = (u['paroki_name'] ?? '').toString().toLowerCase();
      final ord = (u['ordo_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || par.contains(q) || ord.contains(q);
    }).toList();
  }

  Future<void> _handleApproval(Map<String, dynamic> targetUser, String action, {String? reason}) async {
    final targetId = int.tryParse(targetUser['id'].toString());
    if (targetId == null) return;

    setState(() => _processingMap[targetId] = true);
    HapticFeedback.mediumImpact();

    final res = await ApiService.processRomoApproval(
      targetUserId: targetId,
      approverUserId: _romoUserId,
      action: action,
      rejectionReason: reason,
    );

    setState(() => _processingMap[targetId] = false);

    if (!mounted) return;

    if (res['statusCode'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                action == 'APPROVE' ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action == 'APPROVE'
                      ? 'Romo ${targetUser['full_name']} berhasil disetujui!'
                      : 'Pendaftaran Romo ${targetUser['full_name']} telah ditolak.',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: action == 'APPROVE' ? const Color(0xFF059669) : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      _fetchPendingList();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal memproses persetujuan romo.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showRejectDialog(Map<String, dynamic> targetUser) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield_outlined, color: Colors.red.shade700, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tolak Pendaftaran Romo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berikan alasan penolakan untuk Romo ${targetUser['full_name']}:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Contoh: Data klerus belum terverifikasi di sekretariat...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppConstants.primaryBlue, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              Navigator.pop(ctx);
              _handleApproval(targetUser, 'REJECT', reason: reason.isNotEmpty ? reason : null);
            },
            child: const Text('Tolak Pendaftaran', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmApproveDialog(Map<String, dynamic> targetUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_outlined, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Setujui Romo Baru',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menyetujui akun Romo ${targetUser['full_name']}?\n\nRomo ini akan segera aktif dan dapat menerima permohonan sakramen serta misa di aplikasi CATU.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleApproval(targetUser, 'APPROVE');
            },
            child: const Text('Ya, Setujui Romo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _pendingList.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppConstants.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isOrdo ? 'Persetujuan Romo Ordo' : 'Persetujuan Romo Paroki',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _scopeTitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Segarkan Data',
            onPressed: _fetchPendingList,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header Summary Card ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: AppConstants.primaryBlue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.church_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOrdo ? 'Panel Ketua Romo Ordo' : 'Panel Kepala Romo Paroki',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            count == 0
                                ? 'Tidak ada pendaftaran romo yang menunggu'
                                : '$count Romo menunggu persetujuan Anda',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: count > 0 ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count Menunggu',
                        style: TextStyle(
                          color: count > 0 ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Cari nama romo, nomor WhatsApp, atau ordo...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── List Section ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppConstants.primaryBlue),
                  )
                : _filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFF059669),
                                  size: 38,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Semua Pendaftaran Romo Selesai',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ditemukan pendaftaran romo dengan kata kunci "$_searchQuery".'
                                    : 'Tidak ada permohonan akun romo baru yang tertunda untuk wilayah pelayanan Anda saat ini.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchPendingList,
                        color: AppConstants.primaryBlue,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: _filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, idx) {
                            final target = _filteredList[idx];
                            final targetId = int.tryParse(target['id'].toString()) ?? 0;
                            final isProcessing = _processingMap[targetId] ?? false;

                            return _buildRomoApprovalCard(target, isProcessing);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRomoApprovalCard(Map<String, dynamic> u, bool isProcessing) {
    final fullName = u['full_name'] ?? 'Romo Baru';
    final phone = u['phone_number'] ?? '-';
    final email = u['email'] ?? '-';
    final paroki = u['paroki_name'] ?? '-';
    final ordo = u['ordo_name'] ?? u['ordo_code'] ?? '-';
    final keuskupan = u['keuskupan_name'] ?? '-';
    final kota = u['kota_name'] ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Avatar & Status Badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    fullName.isNotEmpty ? fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase() : 'RM',
                    style: const TextStyle(
                      color: AppConstants.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_top, size: 11, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text(
                        'Menunggu',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // ── Info Grid ──
            if (_isOrdo) ...[
              _buildInfoRow(Icons.account_balance_outlined, 'Ordo / Kongregasi', ordo),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.location_city_outlined, 'Domisili Pelayanan', kota),
            ] else ...[
              _buildInfoRow(Icons.church_outlined, 'Paroki Pelayanan', paroki),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.account_balance_outlined, 'Keuskupan', keuskupan),
            ],
            if (email != '-' && email.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoRow(Icons.email_outlined, 'Email', email),
            ],

            const SizedBox(height: 16),

            // ── Action Buttons ──
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppConstants.primaryBlue),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showRejectDialog(u),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showConfirmApproveDialog(u),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Setujui Romo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
