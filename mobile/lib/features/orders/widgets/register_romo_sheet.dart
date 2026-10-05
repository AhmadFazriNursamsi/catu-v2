import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Kredensial sementara Romo baru; kata sandi hanya ditampilkan sekali.
Future<void> showRomoCredentialsDialog(BuildContext context, RegisteredRomo r) {
  final text = 'Akun CATU ${r.romo.fullName}\nNomor HP: ${r.phoneNumber}\nKata sandi sementara: ${r.temporaryPassword}';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Akun Romo Aktif', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.assigned ? '${r.romo.fullName} sudah terdaftar, langsung aktif, dan otomatis menerima pelayanan ini. Sampaikan data masuk berikut kepada Romo:' : '${r.romo.fullName} sudah terdaftar dan langsung aktif. Sampaikan data masuk berikut kepada Romo:', style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nomor HP', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              SelectableText(r.phoneNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              Text('Kata sandi sementara', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              SelectableText(r.temporaryPassword, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1.5)),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('Kata sandi hanya ditampilkan sekali. Romo dapat menggantinya setelah masuk.', style: TextStyle(fontSize: 12, color: _muted, height: 1.4)),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Data masuk disalin'), behavior: SnackBarBehavior.floating));
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Salin'),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Selesai')),
      ],
    ),
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
  int? _parokiId;
  int? _ordoId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.optionsLoader(widget.orderId).then((o) {
      if (mounted) setState(() { _options = o; _parokiId = o.defaultParokiId; });
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
    final choices = isParoki ? options?.parokis : options?.ordos;
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
              else if (choices != null)
                DropdownButtonFormField<int>(
                  key: ValueKey(_role),
                  initialValue: isParoki ? _parokiId : _ordoId,
                  isExpanded: true,
                  decoration: _deco(isParoki ? 'Paroki' : 'Ordo / Tarekat', isParoki ? Icons.church_rounded : Icons.groups_rounded),
                  items: [for (final c in choices) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => isParoki ? _parokiId = v : _ordoId = v),
                  validator: (v) => v == null ? (isParoki ? 'Pilih paroki' : 'Pilih ordo') : null,
                ),
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
