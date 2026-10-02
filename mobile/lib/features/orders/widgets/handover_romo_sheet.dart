import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

Future<void> showHandoverRomoBottomSheet({
  required BuildContext context,
  required Order order,
  OrderItem? targetItem,
  required int currentRomoId,
  required Future<void> Function({required int orderId, OrderItem? targetItem, int? targetRomoId, String? externalRomoName, required String reason}) onHandoverSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => HandoverRomoSheet(order: order, targetItem: targetItem, currentRomoId: currentRomoId, onHandoverSubmit: onHandoverSubmit),
  );
}

class HandoverRomoSheet extends StatefulWidget {
  final Order order;
  final OrderItem? targetItem;
  final int currentRomoId;
  final Future<void> Function({required int orderId, OrderItem? targetItem, int? targetRomoId, String? externalRomoName, required String reason}) onHandoverSubmit;

  const HandoverRomoSheet({super.key, required this.order, this.targetItem, required this.currentRomoId, required this.onHandoverSubmit});

  @override
  State<HandoverRomoSheet> createState() => _HandoverRomoSheetState();
}

class _HandoverRomoSheetState extends State<HandoverRomoSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _contactedUmat = false;
  bool _contactedRomo = false;
  int? _selectedTargetRomoId;
  String? _selectedRomoLabel;
  List<Map<String, dynamic>> _allRomos = [];
  List<Map<String, dynamic>> _filteredRomos = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
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
    });
  }

  List<Map<String, dynamic>> _filterRomos(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return List.from(_allRomos);
    return _allRomos.where((r) {
      final name = (r['fullName'] ?? '').toString().toLowerCase();
      final paroki = (r['parokiName'] ?? '').toString().toLowerCase();
      final ordo = (r['ordoName'] ?? r['ordoCode'] ?? '').toString().toLowerCase();
      return name.contains(q) || paroki.contains(q) || ordo.contains(q);
    }).toList();
  }

  InputDecoration _inputDec({required String hint}) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFF1E5399), width: 1.5),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF1E5399), width: 2),
      ),
    );
  }

  Future<void> _showInternalRomoPicker() async {
    if (_allRomos.isEmpty) await _loadRomos();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              const Text('Pilih Romo Internal CATU', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari Romo, Paroki, atau Ordo...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF1E5399)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (q) => setModalState(() => _filteredRomos = _filterRomos(q)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filteredRomos.isEmpty
                    ? Center(child: Text('Tidak ditemukan Romo.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)))
                    : ListView.separated(
                        itemCount: _filteredRomos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (c, idx) {
                          final r = _filteredRomos[idx];
                          final rId = int.tryParse(r['id']?.toString() ?? '') ?? 0;
                          final name = (r['fullName'] ?? '').toString();
                          final sub = (r['parokiName'] ?? r['ordoName'] ?? r['ordoCode'] ?? '').toString();
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: const CircleAvatar(radius: 15, backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.person, size: 18, color: Color(0xFF1E5399))),
                            title: Text('Romo $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: sub.isNotEmpty ? Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)) : null,
                            onTap: () {
                              setState(() {
                                _selectedTargetRomoId = rId;
                                _selectedRomoLabel = 'Romo $name';
                                _nameCtrl.text = 'Romo $name';
                                _phoneCtrl.text = (r['phoneNumber'] ?? r['phone'] ?? '').toString();
                              });
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_contactedUmat || !_contactedRomo) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap centang konfirmasi telah menghubungi Umat dan Romo Pengganti.'), backgroundColor: Colors.red));
      return;
    }
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama Romo wajib diisi.'), backgroundColor: Colors.red));
      return;
    }
    final label = _selectedTargetRomoId != null ? (_selectedRomoLabel ?? name) : 'Romo Eksternal: $name';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Pengalihan', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin mengajukan pergantian Romo kepada $label?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5399), foregroundColor: Colors.white), child: const Text('Ya, Ajukan')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pop(context);
      final ext = _selectedTargetRomoId == null ? (phone.isNotEmpty ? '$name ($phone)' : name) : null;
      widget.onHandoverSubmit(
        orderId: widget.order.id,
        targetItem: widget.targetItem,
        targetRomoId: _selectedTargetRomoId,
        externalRomoName: ext,
        reason: 'Berhalangan hadir (telah dikonfirmasi ke keluarga & Romo pengganti)',
      );
    }
  }

  Widget _buildBullet({required String boldPrefix, required String suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('● ', style: TextStyle(fontSize: 12, height: 1.4)),
          Expanded(
            child: Text.rich(
              TextSpan(children: [TextSpan(text: boldPrefix, style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: suffix)]),
              style: const TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow({required String question, required bool value, required ValueChanged<bool?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 2),
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(value: value, onChanged: onChanged, activeColor: const Color(0xFF0D9488), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                const SizedBox(width: 4),
                const Text('Sudah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            const Text('Romo Pengganti diajukan setelah konfirmasi terlebih dahulu, kepada:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            _buildBullet(boldPrefix: 'Keluarga Umat Peminta Layanan', suffix: ' sebagai konfirmasi bahwa romo yang sudah konfirmasi tidak bisa hadir.'),
            _buildBullet(boldPrefix: 'Romo Pengganti', suffix: ', agar Romo yang menggantikan dapat mempersiapkan diri.'),
            const SizedBox(height: 8),
            _buildConfirmRow(question: 'Sudah Menghubungi Umat/Keluarga Peminta Layanan?', value: _contactedUmat, onChanged: (v) => setState(() => _contactedUmat = v ?? false)),
            const SizedBox(height: 8),
            _buildConfirmRow(question: 'Sudah Menghubungi Romo Pengganti?', value: _contactedRomo, onChanged: (v) => setState(() => _contactedRomo = v ?? false)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showInternalRomoPicker,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E5399),
                  side: const BorderSide(color: Color(0xFF1E5399), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(_selectedTargetRomoId != null ? 'GANTI ROMO INTERNAL' : 'PILIH ROMO INTERNAL', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
            if (_selectedTargetRomoId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF0D9488)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Internal: ${_selectedRomoLabel ?? ""}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold))),
                  InkWell(
                    onTap: () => setState(() {
                      _selectedTargetRomoId = null;
                      _selectedRomoLabel = null;
                      _nameCtrl.clear();
                      _phoneCtrl.clear();
                    }),
                    child: const Text('Reset', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Text('Nama Romo', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              onChanged: (v) {
                if (_selectedTargetRomoId != null && v.trim() != _selectedRomoLabel) {
                  setState(() {
                    _selectedTargetRomoId = null;
                    _selectedRomoLabel = null;
                  });
                }
              },
              decoration: _inputDec(hint: 'Nama Romo'),
            ),
            const SizedBox(height: 12),
            const Text('Nomor ponsel', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black)),
            const SizedBox(height: 6),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDec(hint: 'Phone Number : 08***')),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5399),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                child: const Text('AJUKAN PERGANTIAN ROMO', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
