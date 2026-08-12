import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../chat/chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  final String userName;

  const OrderDetailScreen({
    Key? key,
    required this.order,
    required this.userName,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isDetailExpanded = true;

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'SELESAI':
      case 'CONFIRMED':
        return const Color(0xFF10B981);
      case 'REJECTED':
      case 'DITOLAK':
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      case 'IN_PROGRESS':
      case 'DIPROSES':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'CONFIRMED':
        return 'Disetujui';
      case 'SELESAI':
        return 'Selesai';
      case 'REJECTED':
      case 'DITOLAK':
        return 'Ditolak';
      case 'IN_PROGRESS':
      case 'DIPROSES':
        return 'Sedang Diproses';
      default:
        return 'Menunggu Konfirmasi';
    }
  }

  Color _getUrgencyColor(String urgency) {
    if (urgency.toLowerCase().contains('sangat')) return const Color(0xFFEF4444);
    if (urgency.toLowerCase().contains('penting')) return const Color(0xFFF59E0B);
    return const Color(0xFF1E5399);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);
    final urgencyColor = _getUrgencyColor(order.urgencyName);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Main Scrollable View
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero Image Header ──
                Stack(
                  children: [
                    SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/images/church_1.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.75),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Top App Bar Icons
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 18,
                                ),
                              ),
                            ),

                            // Order Number Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Text(
                                '#${order.orderNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ── 2. Recipient Info Card (Overlapping Hero Image) ──
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryBlue
                                      .withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.person_pin_rounded,
                                  color: AppConstants.primaryBlue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.penerimaName,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Gender : ${order.genderLabel.isNotEmpty ? order.genderLabel : 'Pria'}, Usia : ${order.usiaLabel.isNotEmpty ? order.usiaLabel : '-'}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          _buildLocationMetaRow(
                            icon: Icons.account_balance_rounded,
                            label: 'Keuskupan',
                            value: order.keuskupanName,
                          ),
                          const SizedBox(height: 8),
                          _buildLocationMetaRow(
                            icon: Icons.church_rounded,
                            label: 'Paroki',
                            value: order.parokiName,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── 3. Sakramen Perminyakan Order Details Card ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.categoryName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Urgensi Tag
                        _buildDetailItemRow(
                          icon: Icons.warning_amber_rounded,
                          iconColor: urgencyColor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: urgencyColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.urgencyName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: urgencyColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Schedule Time Row
                        _buildDetailItemRow(
                          icon: Icons.calendar_today_rounded,
                          iconColor: const Color(0xFF64748B),
                          child: Text(
                            order.jamSelesaiLabel.isNotEmpty
                                ? '${order.scheduledDate} ${order.jamMulaiLabel} - ${order.jamSelesaiLabel}'
                                : order.fullScheduleLabel,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Address Row
                        _buildDetailItemRow(
                          icon: Icons.location_on_rounded,
                          iconColor: const Color(0xFF64748B),
                          child: Text(
                            order.displayAddress,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Status Row
                        _buildDetailItemRow(
                          icon: Icons.hourglass_top_rounded,
                          iconColor: statusColor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 4. Expandable Accordion Detail Section ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Accordion Header
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDetailExpanded = !_isDetailExpanded;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Detail Permintaan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Icon(
                                  _isDetailExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF64748B),
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Accordion Content Body
                        if (_isDetailExpanded) ...[
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Notes Content
                                const Text(
                                  'Catatan Permintaan:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    order.catatanLabel.isNotEmpty
                                        ? order.catatanLabel
                                        : 'Tidak ada catatan tambahan.',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF334155),
                                      height: 1.4,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Requester Umat Info Card
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_outline_rounded,
                                          color: AppConstants.primaryBlue,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.pemohonName,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Umat Dari Lingkungan ${order.lingkunganName}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 5. Bottom Sticky Action Button ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          groupId: order.id,
                          orderNumber: order.orderNumber,
                          userName: widget.userName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text(
                    'Buka Diskusi / Chat Pelayanan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItemRow({
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}
