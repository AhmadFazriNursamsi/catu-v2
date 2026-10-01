import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

Future<void> showHandoverRomoBottomSheet({
  required BuildContext context,
  required Order order,
  OrderItem? targetItem,
  required int currentRomoId,
  required Future<void> Function({
    required int orderId,
    OrderItem? targetItem,
    int? targetRomoId,
    String? externalRomoName,
    required String reason,
  }) onHandoverSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => HandoverRomoSheet(
      order: order,
      targetItem: targetItem,
      currentRomoId: currentRomoId,
      onHandoverSubmit: onHandoverSubmit,
    ),
  );
}

class HandoverRomoSheet extends StatefulWidget {
  final Order order;
  final OrderItem? targetItem;
  final int currentRomoId;
  final Future<void> Function({
    required int orderId,
    OrderItem? targetItem,
    int? targetRomoId,
    String? externalRomoName,
    required String reason,
  }) onHandoverSubmit;

  const HandoverRomoSheet({
    super.key,
    required this.order,
    this.targetItem,
    required this.currentRomoId,
    required this.onHandoverSubmit,
  });

  @override
  State<HandoverRomoSheet> createState() => _HandoverRomoSheetState();
}

class _HandoverRomoSheetState extends State<HandoverRomoSheet> {
  int _selectedTab = 0;
  int? _selectedTargetRomoId;
  final _searchCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _extNameCtrl = TextEditingController();
  final _extNotesCtrl = TextEditingController();

  bool _hasReasonError = false;
  bool _hasExtNameError = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRomos = [];
  List<Map<String, dynamic>> _filteredRomos = [];

  @override
  void initState() {
    super.initState();
    _loadRomos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _reasonCtrl.dispose();
    _extNameCtrl.dispose();
    _extNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRomos() async {
    final list = await ApiService.getAvailableRomos();
    if (!mounted) return;
    final available = list.where((r) {
      final rId = int.tryParse(r['id']?.toString() ?? '') ?? 0;
      return rId != widget.currentRomoId && rId > 0;
    }).toList();
    setState(() {
      _allRomos = available;
      _filteredRomos = available;
      _isLoading = false;
    });
  }

  void _filterList(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filteredRomos = _allRomos.where((r) {
        final name = (r['fullName'] ?? '').toString().toLowerCase();
        final paroki = (r['parokiName'] ?? '').toString().toLowerCase();
        final ordo = (r['ordoName'] ?? r['ordoCode'] ?? '').toString().toLowerCase();
        return name.contains(q) || paroki.contains(q) || ordo.contains(q);
      }).toList();
    });
  }

  InputDecoration _inputDec({required String hint, bool hasError = false, Widget? prefix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey.shade300, width: hasError ? 1.5 : 1),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
      prefixIcon: prefix,
      filled: true,
      fillColor: hasError ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
    );
  }

  Future<void> _onSubmit() async {
    final reason = _reasonCtrl.text.trim();
    bool valid = true;
    if (reason.isEmpty) { setState(() => _hasReasonError = true); valid = false; }
    if (_selectedTab == 0) {
      if (_selectedTargetRomoId == null || _selectedTargetRomoId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan pilih Romo pengganti terlebih dahulu.')));
        valid = false;
      }
    } else if (_extNameCtrl.text.trim().isEmpty) {
      setState(() => _hasExtNameError = true);
      valid = false;
    }
    if (!valid) return;

    String label = _selectedTab == 0
        ? 'Romo ${_allRomos.firstWhere((r) => int.tryParse(r['id']?.toString() ?? '') == _selectedTargetRomoId, orElse: () => {})['fullName'] ?? 'Terpilih'}'
        : 'Romo Eksternal: ${_extNameCtrl.text.trim()}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Konfirmasi Pengalihan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin melimpahkan tugas pelayanan ini kepada $label?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            child: const Text('Ya, Limpahkan'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context);
      final ext = _selectedTab == 1
          ? '${_extNameCtrl.text.trim()}${_extNotesCtrl.text.trim().isNotEmpty ? ' (${_extNotesCtrl.text.trim()})' : ''}'
          : null;
      widget.onHandoverSubmit(
        orderId: widget.order.id,
        targetItem: widget.targetItem,
        targetRomoId: _selectedTab == 0 ? _selectedTargetRomoId : null,
        externalRomoName: ext,
        reason: reason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.published_with_changes_rounded, color: Color(0xFF0284C7), size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Limpahkan Pelayanan (Ganti Romo)', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)))),
          ]),
          const SizedBox(height: 10),
          _buildTabs(),
          const SizedBox(height: 10),
          Expanded(child: _selectedTab == 0 ? _buildInternalList() : _buildExternalForm()),
          const SizedBox(height: 8),
          _buildReasonInput(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSubmit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Limpahkan Pelayanan Sekarang', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _tabItem(0, 'Romo Terdaftar CATU', Icons.verified_user_rounded),
        _tabItem(1, 'Romo Eksternal (Belum Daftar)', Icons.person_add_alt_1_rounded),
      ]),
    );
  }

  Widget _tabItem(int idx, String title, IconData icon) {
    final active = _selectedTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = idx),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? const Color(0xFF0284C7) : Colors.grey.shade600),
              const SizedBox(width: 4),
              Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.w600, color: active ? const Color(0xFF0284C7) : Colors.grey.shade600))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInternalList() {
    return Column(
      children: [
        TextField(controller: _searchCtrl, onChanged: _filterList, decoration: _inputDec(hint: 'Cari Romo, Paroki, atau Ordo...', prefix: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0284C7)))),
        const SizedBox(height: 6),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredRomos.isEmpty
                  ? Center(child: Text('Tidak ditemukan Romo yang sesuai.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)))
                  : ListView.separated(
                      itemCount: _filteredRomos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 5),
                      itemBuilder: (ctx, idx) {
                        final r = _filteredRomos[idx];
                        final rId = int.tryParse(r['id']?.toString() ?? '') ?? 0;
                        final isSel = _selectedTargetRomoId == rId;
                        final isOrdo = (r['roleCode'] ?? '').toString() == 'ROMO_ORDO' || (r['ordoName'] ?? '').toString().isNotEmpty;
                        return InkWell(
                          onTap: () => setState(() => _selectedTargetRomoId = rId),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: isSel ? const Color(0xFFEFF6FF) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSel ? const Color(0xFF2563EB) : Colors.grey.shade200, width: isSel ? 1.5 : 1)),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 15, backgroundColor: isOrdo ? const Color(0xFF8B5CF6).withValues(alpha: 0.12) : const Color(0xFF0284C7).withValues(alpha: 0.12), child: Icon(isOrdo ? Icons.auto_awesome_rounded : Icons.church_rounded, size: 16, color: isOrdo ? const Color(0xFF7C3AED) : const Color(0xFF0284C7))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Romo ${r['fullName'] ?? ''}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B))),
                                      Text(isOrdo ? 'Romo Ordo (${r['ordoName'] ?? r['ordoCode'] ?? ''})' : 'Paroki: ${r['parokiName'] ?? '-'}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Icon(isSel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: isSel ? const Color(0xFF2563EB) : Colors.grey.shade400, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildExternalForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 16),
              SizedBox(width: 6),
              Expanded(child: Text('Gunakan opsi ini jika Romo pengganti belum mendaftar aplikasi CATU.', style: TextStyle(fontSize: 11, color: Color(0xFF166534)))),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('Nama Romo Pengganti (Wajib):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 4),
          TextField(
            controller: _extNameCtrl,
            onChanged: (v) { if (_hasExtNameError && v.trim().isNotEmpty) setState(() => _hasExtNameError = false); },
            decoration: _inputDec(hint: 'Contoh: Romo Antonius Subroto, Pr', hasError: _hasExtNameError),
          ),
          if (_hasExtNameError) const Padding(padding: EdgeInsets.only(top: 2), child: Text('* Nama Romo wajib diisi', style: TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          const Text('Asal Paroki / Ordo / Kontak Romo (Opsional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 4),
          TextField(controller: _extNotesCtrl, decoration: _inputDec(hint: 'Contoh: Paroki St. Paulus Pringsewu / 08123456789')),
        ],
      ),
    );
  }

  Widget _buildReasonInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Alasan Pengalihan Tugas (Wajib):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          if (_hasReasonError) const Padding(padding: EdgeInsets.only(left: 6), child: Text('* Wajib diisi', style: TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: _reasonCtrl,
          maxLines: 2,
          onChanged: (v) { if (_hasReasonError && v.trim().isNotEmpty) setState(() => _hasReasonError = false); },
          decoration: _inputDec(hint: 'Contoh: Sakit mendadak / ada pemakaman keluarga / jadwal bentrok...', hasError: _hasReasonError),
        ),
      ],
    );
  }
}
