import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  int _selectedCategory = 2;
  int _selectedUrgency = 2;
  final _locationController = TextEditingController(text: 'Rumah Duka Carolus Room 101');
  final _addressController = TextEditingController(text: 'Jl. Salemba Raya No. 41, Jakarta Pusat');
  final _notesController = TextEditingController(text: 'Mohon kehadiran Romo untuk penutupan peti dan misa requiem');
  bool _isLoading = false;

  final List<OrderItem> _misaItems = [
    OrderItem(
      itemName: 'Misa Penutupan Peti',
      scheduledDate: '2026-08-15',
      scheduledTimeStart: '18:00',
      scheduledTimeEnd: '19:30',
      locationName: 'Rumah Duka Carolus Room 101',
    ),
    OrderItem(
      itemName: 'Misa Requiem / Pemakaman',
      scheduledDate: '2026-08-16',
      scheduledTimeStart: '09:00',
      scheduledTimeEnd: '10:30',
      locationName: 'TPU Pondok Kelapa',
    ),
  ];

  void _handleSubmitOrder() async {
    setState(() => _isLoading = true);

    final res = await ApiService.createOrder(
      serviceCategoryId: _selectedCategory,
      urgencyLevelId: _selectedUrgency,
      scheduledDate: '2026-08-15',
      scheduledTime: '18:00',
      locationName: _locationController.text,
      addressDetail: _addressController.text,
      notes: _notesController.text,
      items: _selectedCategory == 2 ? _misaItems : null,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message'] ?? 'Order Berhasil dibuat')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryBlue,
        title: const Text('Buat Order Pelayanan', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kategori Pelayanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Perminyakan Orang Sakit')),
                DropdownMenuItem(value: 2, child: Text('Misa Kedukaan (Multi-Item Misa)')),
                DropdownMenuItem(value: 3, child: Text('Pemberkatan Rumah')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),
            const Text('Tingkat Urgensi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedUrgency,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Biasa')),
                DropdownMenuItem(value: 2, child: Text('Penting')),
                DropdownMenuItem(value: 3, child: Text('Darurat / Kritis')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedUrgency = val);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Nama Lokasi / RS / Rumah Duka',
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
                labelText: 'Alamat Lengkap',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan Tambahan untuk Romo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (_selectedCategory == 2) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rincian Misa Kedukaan (Multi-Item)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppConstants.primaryBlue),
                    onPressed: () {
                      setState(() {
                        _misaItems.add(OrderItem(
                          itemName: 'Misa Malam Kembang',
                          scheduledDate: '2026-08-15',
                          scheduledTimeStart: '19:30',
                          scheduledTimeEnd: '20:30',
                          locationName: _locationController.text,
                        ));
                      });
                    },
                  ),
                ],
              ),
              ..._misaItems.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.scheduledDate} (${item.scheduledTimeStart} - ${item.scheduledTimeEnd})\nLokasi: ${item.locationName}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _misaItems.remove(item);
                          });
                        },
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentGold,
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
