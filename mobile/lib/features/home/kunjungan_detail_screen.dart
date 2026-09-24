import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../orders/create_order_screen.dart';

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
  Widget _buildBox(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1B4B82), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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
            onPressed: _openCreatePelayanan,
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

  Future<void> _openCreatePelayanan() async {
    final visitUser = Map<String, dynamic>.from(widget.user);
    final alamatKunjungan = widget.kunjungan['alamat'] ?? '';
    final kotaKunjungan = widget.kunjungan['kota'] ?? '';
    final provKunjungan = widget.kunjungan['provinsi'] ?? '';
    if (alamatKunjungan.toString().isNotEmpty) {
      visitUser['address'] = '$alamatKunjungan, $kotaKunjungan, $provKunjungan'.replaceAll(RegExp(r'(, )+'), ', ').trim();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(user: visitUser),
      ),
    );
    widget.onRefresh();
    if (mounted) setState(() {});
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    final s = status.toUpperCase();
    if (s == 'COMPLETED') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      label = 'SELESAI';
    } else if (s == 'APPROVED' || s == 'ASSIGNED') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
      label = 'DITERIMA';
    } else if (s == 'REJECTED' || s == 'CANCELLED') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      label = 'DITOLAK';
    } else {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
      label = 'MENUNGGU';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOrdersTable() {
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
        if (widget.orders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Belum ada pelayanan yang diajukan',
                style: TextStyle(color: Colors.grey, fontSize: 12.5),
              ),
            ),
          )
        else
          ...widget.orders.map((o) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(o.scheduledDate, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
                  Expanded(flex: 4, child: Text(o.categoryName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black87))),
                  Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: _buildStatusBadge(o.status))),
                ],
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
