import 'package:flutter/material.dart';
import '../../core/services/koordinator_assignment_api.dart';
import 'widgets/register_romo_sheet.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF1E5399);

typedef AssignmentLoader = Future<KoordinatorAssignment> Function(int orderId);
typedef RomoAssigner = Future<String> Function(int orderId, {required int romoId, int? itemId});

/// Koordinator mencarikan Romo: pilih dari seluruh Romo terdaftar, pelayanan otomatis diterima atas nama Romo itu.
class KoordinatorAssignScreen extends StatefulWidget {
  final int orderId;
  final AssignmentLoader? loader;
  final RomoAssigner? assigner;
  final RegisterOptionsLoader? optionsLoader;
  final RomoRegistrar? registrar;
  const KoordinatorAssignScreen({super.key, required this.orderId, this.loader, this.assigner, this.optionsLoader, this.registrar});

  @override
  State<KoordinatorAssignScreen> createState() => _KoordinatorAssignScreenState();
}

class _KoordinatorAssignScreenState extends State<KoordinatorAssignScreen> {
  KoordinatorAssignment? _data;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int? _romoId;
  int? _itemId; // null = semua misa yang belum diterima
  String _query = '';

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
      final data = await (widget.loader ?? KoordinatorAssignmentApi.load)(widget.orderId);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AssignableRomo? get _selected => _data?.romos.cast<AssignableRomo?>().firstWhere((r) => r!.id == _romoId, orElse: () => null);

  /// Romo yang belum terdaftar: didaftarkan (langsung aktif) dan pelayanan otomatis diterimanya.
  /// Bila penetapan gagal, Romo tetap masuk daftar dan terpilih agar dapat ditetapkan manual.
  Future<void> _registerRomo() async {
    final result = await showRegisterRomoSheet(context, widget.orderId, itemId: _itemId, optionsLoader: widget.optionsLoader, registrar: widget.registrar);
    if (result == null || !mounted) return;
    if (!result.assigned) {
      setState(() {
        _data = _data!.withRomo(result.romo);
        _romoId = result.romo.id;
        _query = '';
      });
    }
    await showRomoCredentialsDialog(context, result);
    if (!mounted) return;
    if (result.assigned) {
      Navigator.pop(context, true);
    } else if (result.assignError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Akun dibuat, tetapi penetapan gagal: ${result.assignError}'), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _confirm() async {
    final romo = _selected;
    if (romo == null || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tetapkan Romo?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('${romo.fullName} akan ditetapkan untuk pelayanan ini dan pelayanan otomatis tercatat diterima olehnya.', style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tetapkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final message = await (widget.assigner ?? KoordinatorAssignmentApi.assign)(widget.orderId, romoId: romo.id, itemId: _itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF059669), behavior: SnackBarBehavior.floating));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final canPick = data != null && data.eligible;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Carikan Romo', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _message(Icons.error_outline_rounded, _error!, action: TextButton(onPressed: _load, child: const Text('Coba Lagi')))
              : Column(
                  children: [
                    Expanded(child: _content(data!)),
                    if (canPick) _bottomBar(),
                  ],
                ),
    );
  }

  Widget _content(KoordinatorAssignment data) {
    final query = _query.trim().toLowerCase();
    final romos = data.romos.where((r) => query.isEmpty || r.fullName.toLowerCase().contains(query) || r.affiliation.toLowerCase().contains(query)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _summaryCard(data),
        if (!data.eligible)
          Padding(padding: const EdgeInsets.only(top: 16), child: _notice(data.reason ?? 'Pelayanan ini belum dapat dicarikan Romo.'))
        else ...[
          if (data.pendingItems.length > 1) ..._itemPicker(data),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama Romo, paroki, atau ordo',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _registerRomo, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Romo belum terdaftar? Daftarkan', style: TextStyle(fontWeight: FontWeight.w800))),
          ),
          Text('${romos.length} Romo terdaftar', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(height: 8),
          if (romos.isEmpty) _notice('Tidak ada Romo yang cocok dengan pencarian.') else ...romos.map(_romoTile),
        ],
      ],
    );
  }

  Widget _summaryCard(KoordinatorAssignment data) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.categoryName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 2),
            Text(data.orderNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
            if (data.summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(data.summary, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3)),
            ],
          ],
        ),
      );

  List<Widget> _itemPicker(KoordinatorAssignment data) => [
        const SizedBox(height: 16),
        const Text('Misa yang dicarikan Romo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Semua yang belum diterima', _itemId == null, () => setState(() => _itemId = null)),
            for (final item in data.pendingItems) _chip(item.name, _itemId == item.id, () => setState(() => _itemId = item.id)),
          ],
        ),
      ];

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _blue.withValues(alpha: 0.12),
        checkmarkColor: _blue,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _blue : const Color(0xFFE2E8F0)),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: selected ? _blue : const Color(0xFF334155)),
      );

  Widget _romoTile(AssignableRomo r) {
    final selected = r.id == _romoId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _romoId = r.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? _blue.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _blue : const Color(0xFFE2E8F0), width: selected ? 1.8 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: _blue.withValues(alpha: 0.12), child: Text(r.fullName.isEmpty ? '?' : r.fullName.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: _blue))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink)),
                    const SizedBox(height: 2),
                    Text('${r.roleLabel} • ${r.affiliation}${r.local ? ' • Setempat' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? _blue : const Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _romoId == null || _saving ? null : _confirm,
              style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Tetapkan Romo', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      );

  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFED7AA))),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.4))),
        ]),
      );

  Widget _message(IconData icon, String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 40, color: _muted), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted)), if (action != null) action]),
        ),
      );
}
