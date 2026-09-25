import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

class CreateOrderScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? categoryName;
  final Map<String, dynamic>? user;

  const CreateOrderScreen({
    super.key,
    this.initialCategoryId,
    this.categoryName,
    this.user,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  int? _selectedCategory;
  int _selectedUrgency = 1;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> _categories = [];
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategoryId;
    _locationController = TextEditingController();
    _addressController = TextEditingController(text: (widget.user?['address'] ?? '').toString());
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await ApiService.getServiceCategories();
    if (!mounted) return;
    setState(() {
      _categories = list.where((c) => c['is_active'] != false).toList();
      _isLoadingCategories = false;
      if (_selectedCategory == null && _categories.isNotEmpty) {
        _selectedCategory = int.tryParse(_categories.first['id'].toString());
      }
      final currentCat = _categories.firstWhere(
        (c) => c['id'].toString() == _selectedCategory.toString(),
        orElse: () => {},
      );
      if (currentCat['is_urgent_by_default'] == true) {
        _selectedUrgency = 3;
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _handleSubmitOrder() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih kategori pelayanan')),
      );
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lokasi wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final formattedDate = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final formattedTime = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final kunjMap = widget.user?['kunjungan'] is Map ? (widget.user!['kunjungan'] as Map) : null;
    final kunjId = kunjMap?['id']?.toString() ?? '';
    final notesText = _notesController.text.trim();
    final combinedNotes = [
      if (notesText.isNotEmpty) notesText,
      if (kunjId.isNotEmpty) '[KunjunganId: $kunjId]',
    ].join(' | ');

    final res = await ApiService.createOrder(
      serviceCategoryId: _selectedCategory!,
      urgencyLevelId: _selectedUrgency,
      scheduledDate: formattedDate,
      scheduledTime: formattedTime,
      locationName: _locationController.text.trim(),
      addressDetail: _addressController.text.trim(),
      notes: combinedNotes,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message'] ?? 'Order pelayanan berhasil dibuat')),
    );

    final dynamic rawOrderId = res['order'] != null ? res['order']['id'] : (res['id'] ?? res['orderId']);
    if (res['statusCode'] == 200 || res['success'] == true || res['id'] != null || rawOrderId != null) {
      Navigator.pop(context, rawOrderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppConstants.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryBlue,
        title: Text(widget.categoryName ?? 'Buat Permohonan Pelayanan', style: const TextStyle(color: Colors.white, fontSize: 17)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kategori Pelayanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _categories.map((c) {
                      final id = int.tryParse(c['id'].toString()) ?? 0;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          final chosen = _categories.firstWhere((c) => c['id'].toString() == val.toString(), orElse: () => {});
                          if (chosen['is_urgent_by_default'] == true) {
                            _selectedUrgency = 3;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Tingkat Urgensi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedUrgency,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Biasa (Rutin)')),
                      DropdownMenuItem(value: 2, child: Text('Penting')),
                      DropdownMenuItem(value: 3, child: Text('Darurat / Kritis')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedUrgency = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal Pelayanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, size: 18, color: AppConstants.primaryBlue),
                                    const SizedBox(width: 8),
                                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Waktu Pelayanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 18, color: AppConstants.primaryBlue),
                                    const SizedBox(width: 8),
                                    Text(timeStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lokasi / Tempat *',
                      hintText: 'Contoh: Rumah Kediaman, RS, dll',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Alamat Lengkap *',
                      hintText: 'Nama jalan, RT/RW, nomor rumah...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Catatan Tambahan untuk Romo',
                      hintText: 'Tuliskan permohonan khusus jika ada...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryBlue,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('KIRIM PERMINTAAN PELAYANAN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }
}
