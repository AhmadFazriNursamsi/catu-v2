import 'package:flutter/material.dart';
import '../../../core/services/koordinator_assignment_api.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _blue = Color(0xFF1E5399);

typedef RegisterOptionsLoader = Future<RomoRegisterOptions> Function(int orderId);
typedef RomoRegistrar = Future<RegisteredRomo> Function(int orderId, {required String fullName, required String phoneNumber, required String roleCode, int? parokiId, int? ordoId, int? itemId});

/// Formulir Koordinator untuk mendaftarkan Romo yang belum terdaftar. Mengembalikan Romo baru bila berhasil.
Future<RegisteredRomo?> showRegisterRomoSheet(BuildContext context, int orderId, {int? itemId, RegisterOptionsLoader? optionsLoader, RomoRegistrar? registrar}) {
  return showModalBottomSheet<RegisteredRomo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _RegisterRomoForm(orderId: orderId, itemId: itemId, optionsLoader: optionsLoader ?? KoordinatorAssignmentApi.registerOptions, registrar: registrar ?? KoordinatorAssignmentApi.registerRomo),
  );
}

class _RegisterRomoForm extends StatefulWidget {
  final int orderId;
  final int? itemId;
  final RegisterOptionsLoader optionsLoader;
  final RomoRegistrar registrar;
  const _RegisterRomoForm({required this.orderId, this.itemId, required this.optionsLoader, required this.registrar});

  @override
  State<_RegisterRomoForm> createState() => _RegisterRomoFormState();
}

class _RegisterRomoFormState extends State<_RegisterRomoForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  RomoRegisterOptions? _options;
  String _role = 'ROMO_PAROKI';
  int? _parokiId, _keuskupanId;
  int? _ordoId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.optionsLoader(widget.orderId).then((o) {
      if (mounted) setState(() { _options = o; _keuskupanId = o.defaultKeuskupanId; _parokiId = o.defaultParokiId; });
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      final result = await widget.registrar(widget.orderId, fullName: _name.text.trim(), phoneNumber: _phone.text.trim(), roleCode: _role, parokiId: _role == 'ROMO_PAROKI' ? _parokiId : null, ordoId: _role == 'ROMO_ORDO' ? _ordoId : null, itemId: widget.itemId);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final isParoki = _role == 'ROMO_PAROKI';
    final showKeuskupan = isParoki && (options?.keuskupans.isNotEmpty ?? false);
    final choices = isParoki ? options?.parokis.where((p) => !showKeuskupan || p.parentId == _keuskupanId).toList() : options?.ordos;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Daftarkan Romo', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 4),
              const Text('Akun langsung aktif tanpa persetujuan, kata sandi dibuat otomatis, dan Romo langsung menerima pelayanan ini.', style: TextStyle(fontSize: 12.5, color: _muted)),
              const SizedBox(height: 16),
              TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: _deco('Nama Lengkap Romo', Icons.person_rounded), validator: (v) => (v ?? '').trim().length < 3 ? 'Nama minimal 3 karakter' : null),
              const SizedBox(height: 14),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _deco('Nomor HP / WhatsApp', Icons.phone_android_rounded), validator: (v) => RegExp(r'^\+?[\d\s-]{9,16}$').hasMatch((v ?? '').trim()) ? null : 'Nomor HP tidak valid'),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'ROMO_PAROKI', label: Text('Romo Paroki')), ButtonSegment(value: 'ROMO_ORDO', label: Text('Romo Ordo'))],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 14),
              if (options == null && _error == null)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else if (choices != null) ...[
                if (showKeuskupan) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _keuskupanId,
                    isExpanded: true,
                    decoration: _deco('Keuskupan', Icons.account_balance_outlined),
                    items: [for (final k in options!.keuskupans) DropdownMenuItem(value: k.id, child: Text(k.name, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() { _keuskupanId = v; _parokiId = null; }),
                    validator: (v) => v == null ? 'Pilih keuskupan' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                DropdownButtonFormField<int>(
                  key: ValueKey('$_role-$_keuskupanId'),
                  initialValue: choices.any((c) => c.id == (isParoki ? _parokiId : _ordoId)) ? (isParoki ? _parokiId : _ordoId) : null,
                  isExpanded: true,
                  decoration: _deco(isParoki ? 'Paroki' : 'Ordo / Tarekat', isParoki ? Icons.church_rounded : Icons.groups_rounded),
                  items: [for (final c in choices) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => isParoki ? _parokiId = v : _ordoId = v),
                  validator: (v) => v == null ? (isParoki ? 'Pilih paroki' : 'Pilih ordo') : null,
                ),
              ],
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5, height: 1.3))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving || options == null ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Daftarkan Romo', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
