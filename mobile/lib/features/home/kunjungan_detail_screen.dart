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

  const KunjunganDetailScreen({super.key, required this.kunjungan, required this.user, required this.orders, required this.onRefresh});

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
      if (mounted) setState(() => _orders = fetched);
    }
  }

  void _showServiceSelectionModal() {
    final rawId = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    final userId = rawId != null ? int.tryParse(rawId.toString()) : null;
    final visitUser = Map<String, dynamic>.from(widget.user);
    final alamatKunjungan = widget.kunjungan['alamat'] ?? '', kotaKunjungan = widget.kunjungan['kota'] ?? '', provKunjungan = widget.kunjungan['provinsi'] ?? '';
    if (alamatKunjungan.toString().isNotEmpty) {
      visitUser['address'] = '$alamatKunjungan, $kotaKunjungan, $provKunjungan'.replaceAll(RegExp(r'(, )+'), ', ').trim();
      visitUser['alamat'] = visitUser['address'];
    }
    visitUser['kunjungan'] = widget.kunjungan;
    visitUser['provinsi'] = provKunjungan;
    visitUser['kota'] = kotaKunjungan;
    visitUser['kabupatenKota'] = kotaKunjungan;
    visitUser['alamat_kunjungan'] = alamatKunjungan;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: Colors.white,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
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
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
                    final categories = (snapshot.data ?? []).where((c) => c['is_active'] != false).toList();
                    if (categories.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Tidak ada kategori pelayanan aktif')));
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                          subtitle: desc.isNotEmpty ? Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))) : null,
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final screen = isPerm ? CreatePerminyakanScreen(userId: userId, user: visitUser) : isKedu ? CreateKedukaanScreen(userId: userId, user: visitUser) : CreateOrderScreen(initialCategoryId: catId, categoryName: name, user: visitUser);
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
    Color bg = Colors.amber.shade50, fg = Colors.amber.shade800;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final clean = raw.contains('T') ? raw.split('T').first : raw;
      final parts = clean.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    } catch (_) {}
    return raw;
  }

  Widget _buildLocationCard(String tanggal, String prov, String kota, String alamat) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF1E5399)), const SizedBox(width: 6), Text(tanggal, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E5399)))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)), child: const Text('Lokasi Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF1E5399)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(alamat.isNotEmpty ? alamat : '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))), const SizedBox(height: 2), Text('$kota, $prov', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)))])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('TUTUP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _showServiceSelectionModal,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('MINTA PELAYANAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E5399), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersSection() {
    final rawId = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    final userId = rawId != null ? int.tryParse(rawId.toString()) : null;
    final userName = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Umat';

    final List<Map<String, dynamic>> rows = [];
    for (final o in _orders) {
      if (o.items.isNotEmpty) {
        for (final item in o.items) {
          rows.add({'order': o, 'date': item.scheduledDate.isNotEmpty ? item.scheduledDate : o.scheduledDate, 'title': item.itemName, 'status': item.status});
        }
      } else {
        rows.add({'order': o, 'date': o.scheduledDate, 'title': o.categoryName, 'status': o.status});
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pelayanan Pada Kunjungan Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: Text('${rows.length} Permintaan', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Center(child: Text('Belum ada pelayanan yang diajukan untuk kunjungan ini.\nKlik tombol "MINTA PELAYANAN" di atas.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5))),
          )
        else
          ...rows.map((row) {
            final Order o = row['order'] as Order;
            final String date = row['date'] as String, title = row['title'] as String, status = row['status'] as String;
            final isPerm = title.toLowerCase().contains('perminyakan');
            final isKedu = title.toLowerCase().contains('kedukaan') || title.toLowerCase().contains('misa');
            final icon = isPerm ? Icons.sanitizer_rounded : (isKedu ? Icons.personal_injury_rounded : Icons.church_rounded);
            final color = isPerm ? const Color(0xFF1E5399) : (isKedu ? const Color(0xFF0D9488) : const Color(0xFFD97706));

            return Card(
              margin: const EdgeInsets.only(bottom: 10), elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o, userName: userName, userId: userId, selectedItemTitle: title))).then((_) => _loadOrders()),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Row(children: [const Icon(Icons.event_outlined, size: 13, color: Color(0xFF64748B)), const SizedBox(width: 4), Text(_formatDate(date), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))]),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detail Kunjungan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0, surfaceTintColor: Colors.transparent, leading: const BackButton(color: Color(0xFF0F172A)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationCard(widget.kunjungan['tanggal'] ?? '', widget.kunjungan['provinsi'] ?? '', widget.kunjungan['kota'] ?? '', widget.kunjungan['alamat'] ?? ''),
              const SizedBox(height: 14),
              _buildActionButtons(),
              const SizedBox(height: 22),
              _buildOrdersSection(),
            ],
          ),
        ),
      ),
    );
  }
}
