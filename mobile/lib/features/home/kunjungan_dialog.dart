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
    if (mounted) setState(() => _provinsiList = list);
  }

  Future<void> _loadKota(int provinsiId) async {
    final list = await ApiService.getKabupatenKotaList(provinsiId: provinsiId);
    if (mounted) {
      setState(() {
        _kotaList = list;
        _selectedKota = null;
      });
    }
  }

  String get _formattedDate {
    if (_selectedDate == null) return 'Tanggal';
    return '${_selectedDate!.day} ${_months[_selectedDate!.month - 1]} ${_selectedDate!.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    if (_selectedProvinsi == null || _selectedKota == null || _alamatCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi tanggal, provinsi, kota, dan alamat')),
      );
      return;
    }
    widget.onSaved(
      _selectedDate != null ? _formattedDate : '23 September 2026',
      _selectedProvinsi!,
      _selectedKota!,
      _alamatCtrl.text.trim(),
    );
    Navigator.pop(context);
  }

  Widget _buildFieldBox({required String label, required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1B4B82), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kunjungan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _buildFieldBox(
                label: 'Tanggal',
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formattedDate, style: TextStyle(color: _selectedDate != null ? Colors.black : Colors.grey.shade500, fontSize: 14)),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              _buildFieldBox(
                label: 'Provinsi',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedProvinsi,
                    hint: Text('Pilih Provinsi:', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    items: _provinsiList.map((p) {
                      final name = p['name'].toString();
                      return DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedProvinsi = val);
                        final item = _provinsiList.firstWhere((p) => p['name'] == val, orElse: () => {});
                        if (item['id'] != null) {
                          _loadKota(int.parse(item['id'].toString()));
                        }
                      }
                    },
                  ),
                ),
              ),
              _buildFieldBox(
                label: 'Kota',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedKota,
                    hint: Text('Pilih Kota:', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    items: _kotaList.map((k) {
                      final name = k['name'].toString();
                      return DropdownMenuItem<String>(value: name, child: Text(name, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedKota = val),
                  ),
                ),
              ),
              _buildFieldBox(
                label: 'Alamat',
                child: TextField(
                  controller: _alamatCtrl,
                  decoration: InputDecoration(
                    hintText: 'Alamat',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4B82),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B0000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('BATAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
