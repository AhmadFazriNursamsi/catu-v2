import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class KunjunganDialog extends StatefulWidget {
  final void Function(String tanggal, String provinsi, String kota, String alamat) onSaved;
  const KunjunganDialog({super.key, required this.onSaved});

  @override
  State<KunjunganDialog> createState() => _KunjunganDialogState();
}

class _KunjunganDialogState extends State<KunjunganDialog> {
  final _alamatCtrl = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedProvinsi;
  String? _selectedKota;
  List<Map<String, dynamic>> _provinsiList = [];
  List<Map<String, dynamic>> _kotaList = [];
  bool _isLoadingProv = true;
  bool _isLoadingKota = false;
  bool _isSaving = false;

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadProvinsi();
  }

  @override
  void dispose() {
    _alamatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProvinsi() async {
    final list = await ApiService.getProvinsiList();
    if (mounted) {
      setState(() {
        _provinsiList = list;
        _isLoadingProv = false;
      });
    }
  }

  Future<void> _loadKota(int provinsiId) async {
    setState(() {
      _isLoadingKota = true;
      _selectedKota = null;
      _kotaList = [];
    });
    final list = await ApiService.getKabupatenKotaList(provinsiId: provinsiId);
    if (mounted) {
      setState(() {
        _kotaList = list;
        _isLoadingKota = false;
      });
    }
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Pilih Tanggal';
    return '${_selectedDate!.day} ${_months[_selectedDate!.month - 1]} ${_selectedDate!.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1E5399)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    if (_isSaving) return;
    final alamat = _alamatCtrl.text.trim();
    if (_selectedProvinsi == null || _selectedKota == null || alamat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Mohon lengkapi tanggal, provinsi, kota, dan alamat kunjungan.')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final defaultDate = '${now.day} ${_months[now.month - 1]} ${now.year}';
    final tanggalStr = _selectedDate != null ? _formattedDate : defaultDate;

    Navigator.of(context).pop();
    widget.onSaved(tanggalStr, _selectedProvinsi!, _selectedKota!, alamat);
  }

  Widget _buildFieldWrapper({required String label, required IconData icon, required Widget child, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF1E5399)),
                const SizedBox(width: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildDialogHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF1E5399).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF1E5399), size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tambah Kunjungan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('Tentukan lokasi saat Anda berada di luar paroki', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialogActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5399),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogHeader(),
              const SizedBox(height: 18),
              _buildFieldWrapper(
                label: 'Tanggal Kunjungan',
                icon: Icons.calendar_month_rounded,
                onTap: _pickDate,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formattedDate, style: TextStyle(color: _selectedDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w500)),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                  ],
                ),
              ),
              _buildFieldWrapper(
                label: 'Provinsi Tujuan',
                icon: Icons.map_rounded,
                child: _isLoadingProv
                    ? const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          isDense: true,
                          value: _selectedProvinsi,
                          hint: const Text('Pilih Provinsi', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5)),
                          items: _provinsiList.map((p) {
                            final name = p['name'].toString();
                            return DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A))));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedProvinsi = val);
                              final item = _provinsiList.firstWhere((p) => p['name'] == val, orElse: () => {});
                              if (item['id'] != null) _loadKota(int.parse(item['id'].toString()));
                            }
                          },
                        ),
                      ),
              ),
              _buildFieldWrapper(
                label: 'Kota / Kabupaten Tujuan',
                icon: Icons.location_city_rounded,
                child: _isLoadingKota
                    ? const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          isDense: true,
                          value: _selectedKota,
                          hint: Text(_selectedProvinsi == null ? 'Pilih provinsi terlebih dahulu' : 'Pilih Kota / Kabupaten', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5)),
                          items: _kotaList.map((k) {
                            final name = k['name'].toString();
                            return DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A))));
                          }).toList(),
                          onChanged: _selectedProvinsi == null ? null : (val) => setState(() => _selectedKota = val),
                        ),
                      ),
              ),
              _buildFieldWrapper(
                label: 'Alamat / Tempat Kunjungan',
                icon: Icons.pin_drop_rounded,
                child: TextField(
                  controller: _alamatCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Hotel / Rumah Sakit / Jl. Merdeka No. 1',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 6),
              _buildDialogActions(),
            ],
          ),
        ),
      ),
    );
  }
}
