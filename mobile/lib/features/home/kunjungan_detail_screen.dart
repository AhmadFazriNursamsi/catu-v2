import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../orders/create_kedukaan_screen.dart';
import '../orders/create_order_screen.dart';
import '../orders/create_perminyakan_screen.dart';
import '../orders/order_detail_screen.dart';

class KunjunganDetailScreen extends StatefulWidget {
  final Map<String, dynamic> kunjungan;
  final Map<String, dynamic> user;
  final List<Order> orders;
  final VoidCallback onRefresh;

  const KunjunganDetailScreen({
    super.key,
    required this.kunjungan,
    required this.user,
    required this.orders,
    required this.onRefresh,
  });

  @override
  State<KunjunganDetailScreen> createState() => _KunjunganDetailScreenState();
}

class _KunjunganDetailScreenState extends State<KunjunganDetailScreen> {
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    _orders = List.from(widget.orders);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final rawId = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    final userId = rawId != null ? int.tryParse(rawId.toString()) : null;
    if (userId != null) {
      final fetched = await ApiService.getOrders(userId: userId);
      if (mounted) {
        setState(() => _orders = fetched);
      }
    }
  }

  Widget _buildBox(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1B4B82), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(value.isNotEmpty ? value : '-', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4B82),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: _showServiceSelectionModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4B82),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Text('PELAYANAN BARU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }

  void _showServiceSelectionModal() {
    final rawId = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    final userId = rawId != null ? int.tryParse(rawId.toString()) : null;
    final visitUser = Map<String, dynamic>.from(widget.user);
    final alamatKunjungan = widget.kunjungan['alamat'] ?? '';
    final kotaKunjungan = widget.kunjungan['kota'] ?? '';
    final provKunjungan = widget.kunjungan['provinsi'] ?? '';
    if (alamatKunjungan.toString().isNotEmpty) {
      visitUser['address'] = '$alamatKunjungan, $kotaKunjungan, $provKunjungan'.replaceAll(RegExp(r'(, )+'), ', ').trim();
      visitUser['alamat'] = visitUser['address'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Pilih Jenis Pelayanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Silakan pilih jenis sakramen / misa pelayanan yang Anda butuhkan', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ApiService.getServiceCategories(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
                    }
                    final categories = (snapshot.data ?? []).where((c) => c['is_active'] != false).toList();
                    if (categories.isEmpty) {
                      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Tidak ada kategori pelayanan aktif')));
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final cat = categories[index];
                        final catId = (cat['id'] as num?)?.toInt() ?? 0;
                        final name = cat['name']?.toString() ?? 'Pelayanan';
                        final desc = cat['description']?.toString() ?? '';
                        final isPerm = catId == 1 || name.toLowerCase().contains('perminyakan');
                        final isKedu = catId == 2 || name.toLowerCase().contains('kedukaan');
                        final icon = isPerm ? Icons.sanitizer_rounded : (isKedu ? Icons.personal_injury_rounded : Icons.home_repair_service_rounded);
                        final color = isPerm ? const Color(0xFF1E5399) : (isKedu ? const Color(0xFF0D9488) : const Color(0xFFD97706));

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: desc.isNotEmpty ? Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))) : null,
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final screen = isPerm
                                ? CreatePerminyakanScreen(userId: userId, user: visitUser)
                                : isKedu
                                    ? CreateKedukaanScreen(userId: userId, user: visitUser)
                                    : CreateOrderScreen(initialCategoryId: catId, categoryName: name, user: visitUser);
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
                            await _loadOrders();
                            widget.onRefresh();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Versi Aplikasi: ${AppConstants.appVersion}', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.amber.shade50;
    Color fg = Colors.amber.shade800;
    String label = 'MENUNGGU';
    final s = status.toUpperCase();
    if (s == 'COMPLETED' || s == 'DONE') {
      bg = Colors.green.shade50; fg = Colors.green.shade700; label = 'SELESAI';
    } else if (s == 'APPROVED' || s == 'ASSIGNED' || s == 'ACCEPTED' || s == 'CONFIRMED') {
      bg = Colors.blue.shade50; fg = Colors.blue.shade700; label = 'DITERIMA';
    } else if (s == 'REJECTED' || s == 'CANCELLED' || s == 'DECLINED' || s == 'FAIL') {
      bg = Colors.red.shade50; fg = Colors.red.shade700; label = 'DITOLAK';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final clean = raw.contains('T') ? raw.split('T').first : raw;
      final parts = clean.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return raw;
  }

  Widget _buildOrdersTable() {
    final rawId = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    final userId = rawId != null ? int.tryParse(rawId.toString()) : null;
    final userName = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Umat';

    final List<Map<String, dynamic>> rows = [];
    for (final o in _orders) {
      if (o.items.isNotEmpty) {
        for (final item in o.items) {
          rows.add({
            'order': o,
            'date': item.scheduledDate.isNotEmpty ? item.scheduledDate : o.scheduledDate,
            'title': item.itemName,
            'status': item.status,
          });
        }
      } else {
        rows.add({
          'order': o,
          'date': o.scheduledDate,
          'title': o.categoryName,
          'status': o.status,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Expanded(flex: 4, child: Text('Jenis Pelayanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Expanded(flex: 3, child: Text('Status', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Belum ada pelayanan yang diajukan', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
            ),
          )
        else
          ...rows.map((row) {
            final Order o = row['order'] as Order;
            final String date = row['date'] as String;
            final String title = row['title'] as String;
            final String status = row['status'] as String;
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      order: o,
                      userName: userName,
                      userId: userId,
                      selectedItemTitle: title,
                    ),
                  ),
                ).then((_) => _loadOrders());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(_formatDate(date), style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
                    Expanded(flex: 4, child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87))),
                    Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: _buildStatusBadge(status))),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tanggal = widget.kunjungan['tanggal'] ?? '';
    final provinsi = widget.kunjungan['provinsi'] ?? '';
    final kota = widget.kunjungan['kota'] ?? '';
    final alamat = widget.kunjungan['alamat'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Kunjungan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBox('Tanggal', tanggal),
              _buildBox('Provinsi', provinsi),
              _buildBox('Kabupaten/Kota', kota),
              _buildBox('Alamat', alamat),
              const SizedBox(height: 12),
              _buildButtons(),
              const SizedBox(height: 24),
              _buildOrdersTable(),
            ],
          ),
        ),
      ),
    );
  }
}
