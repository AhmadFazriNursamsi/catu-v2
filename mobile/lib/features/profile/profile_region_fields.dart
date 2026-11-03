import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../widgets/searchable_select_field.dart';

typedef _Rows = List<Map<String, dynamic>>;

int? _asId(dynamic v) => int.tryParse(v.toString());

_Rows _sorted(_Rows rows) => [...rows]..sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));

Widget _select({required String label, required IconData icon, required int? value, required _Rows rows, required ValueChanged<int> onPick, required String empty}) {
  return SearchableSelectField<int>(
    label: label,
    icon: icon,
    value: value,
    items: [for (final r in rows) SearchableSelectItem<int>(value: _asId(r['id'])!, label: r['name'].toString())],
    onChanged: (v) {
      if (v != null) onPick(v);
    },
    emptyMessage: empty,
  );
}

/// Pilihan Keuskupan > Paroki > Wilayah > Lingkungan yang saling berjenjang; induk berganti, anak dikosongkan.
class ChurchRegionFields extends StatefulWidget {
  final int? keuskupanId, parokiId, wilayahId, lingkunganId;
  final bool showArea;
  final void Function(int? keuskupan, int? paroki, int? wilayah, int? lingkungan) onChanged;

  const ChurchRegionFields({super.key, this.keuskupanId, this.parokiId, this.wilayahId, this.lingkunganId, this.showArea = true, required this.onChanged});

  @override
  State<ChurchRegionFields> createState() => _ChurchRegionFieldsState();
}

class _ChurchRegionFieldsState extends State<ChurchRegionFields> {
  _Rows _keuskupan = [], _paroki = [], _wilayah = [], _lingkungan = [];
  String _loadedKey = '';

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ChurchRegionFields old) {
    super.didUpdateWidget(old);
    _sync();
  }

  Future<void> _sync() async {
    final key = '${widget.keuskupanId}/${widget.parokiId}/${widget.wilayahId}';
    if (key == _loadedKey) return;
    _loadedKey = key;
    final k = _keuskupan.isEmpty ? await ApiService.getKeuskupan() : _keuskupan;
    final p = widget.keuskupanId == null ? <Map<String, dynamic>>[] : await ApiService.getParoki(keuskupanId: widget.keuskupanId);
    final w = widget.parokiId == null ? <Map<String, dynamic>>[] : await ApiService.getWilayah(parokiId: widget.parokiId);
    final l = widget.wilayahId == null ? <Map<String, dynamic>>[] : await ApiService.getLingkungan(wilayahId: widget.wilayahId);
    if (!mounted || key != _loadedKey) return;
    setState(() {
      _keuskupan = _sorted(k);
      _paroki = _sorted(p);
      _wilayah = _sorted(w);
      _lingkungan = _sorted(l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget;
    return Column(
      children: [
        _select(label: 'Keuskupan', icon: Icons.account_balance_rounded, value: c.keuskupanId, rows: _keuskupan, empty: 'Keuskupan tidak ditemukan', onPick: (v) => c.onChanged(v, null, null, null)),
        const SizedBox(height: 14),
        _select(label: 'Paroki', icon: Icons.location_city_rounded, value: c.parokiId, rows: _paroki, empty: 'Paroki tidak ditemukan pada keuskupan ini', onPick: (v) => c.onChanged(c.keuskupanId, v, null, null)),
        if (c.showArea) ...[
          const SizedBox(height: 14),
          _select(label: 'Wilayah', icon: Icons.map_rounded, value: c.wilayahId, rows: _wilayah, empty: 'Wilayah tidak ditemukan pada paroki ini', onPick: (v) => c.onChanged(c.keuskupanId, c.parokiId, v, null)),
          const SizedBox(height: 14),
          _select(label: 'Lingkungan', icon: Icons.groups_rounded, value: c.lingkunganId, rows: _lingkungan, empty: 'Lingkungan tidak ditemukan pada wilayah ini', onPick: (v) => c.onChanged(c.keuskupanId, c.parokiId, c.wilayahId, v)),
        ],
      ],
    );
  }
}

/// Pilihan Provinsi > Kota/Kabupaten; saat provinsi berganti, kota diisi kota pertama provinsi itu.
class ProvinsiKotaFields extends StatefulWidget {
  final int? provinsiId, kotaId;
  final void Function(int? provinsi, int? kota) onChanged;

  const ProvinsiKotaFields({super.key, this.provinsiId, this.kotaId, required this.onChanged});

  @override
  State<ProvinsiKotaFields> createState() => _ProvinsiKotaFieldsState();
}

class _ProvinsiKotaFieldsState extends State<ProvinsiKotaFields> {
  _Rows _provinsi = [], _kota = [];
  int? _kotaFor;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ProvinsiKotaFields old) {
    super.didUpdateWidget(old);
    _sync();
  }

  Future<_Rows> _kotaOf(int? provinsiId) async => provinsiId == null ? <Map<String, dynamic>>[] : _sorted(await ApiService.getKabupatenKotaList(provinsiId: provinsiId));

  Future<void> _sync() async {
    final prov = widget.provinsiId;
    if (_provinsi.isNotEmpty && prov == _kotaFor) return;
    _kotaFor = prov;
    final provinsi = _provinsi.isEmpty ? _sorted(await ApiService.getProvinsiList()) : _provinsi;
    final kota = await _kotaOf(prov);
    if (!mounted || prov != _kotaFor) return;
    setState(() {
      _provinsi = provinsi;
      _kota = kota;
    });
  }

  Future<void> _pickProvinsi(int id) async {
    final kota = await _kotaOf(id);
    widget.onChanged(id, kota.isEmpty ? null : _asId(kota.first['id']));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _select(label: 'Provinsi', icon: Icons.apartment_rounded, value: widget.provinsiId, rows: _provinsi, empty: 'Provinsi tidak ditemukan', onPick: _pickProvinsi),
        const SizedBox(height: 14),
        _select(label: 'Kota / Kabupaten', icon: Icons.location_on_rounded, value: widget.kotaId, rows: _kota, empty: 'Kota tidak ditemukan pada provinsi ini', onPick: (v) => widget.onChanged(widget.provinsiId, v)),
      ],
    );
  }
}
