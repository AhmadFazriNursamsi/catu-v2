import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

/// Komponen tampilan detail pelayanan Misa Kedukaan.

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5D77D);
const _slate = Color(0xFF94A3B8);

String _timeRange(OrderItem item) {
  final end = item.scheduledTimeEnd.trim();
  final hasEnd = end.isNotEmpty && end.toLowerCase() != 'selesai';
  return hasEnd ? '${item.scheduledTimeStart} – $end WIB' : '${item.scheduledTimeStart} WIB';
}

/// Kartu ringkasan misa yang sedang dilihat: urutan misa, status, intensi, serta tanggal & jam sekilas.
class KedukaanSummaryCard extends StatelessWidget {
  final Order order;
  final OrderItem item;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final Widget rescheduleChip;
  const KedukaanSummaryCard({
    super.key,
    required this.order,
    required this.item,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.rescheduleChip,
  });

  @override
  Widget build(BuildContext context) {
    final count = order.items.length;
    final index = order.items.indexWhere((i) => i.id != null && i.id == item.id);
    final date = item.scheduledDate.isNotEmpty ? item.scheduledDate : order.scheduledDate;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withValues(alpha: 0.45), width: 0.8),
              ),
              child: const Text('✝ MISA KEDUKAAN',
                  style: TextStyle(fontSize: 11, color: _goldLight, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
            const Spacer(),
            if (count > 1 && index >= 0)
              Text('Misa ${index + 1} dari $count',
                  style: const TextStyle(fontSize: 12, color: _slate, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          Text(item.itemName,
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4, height: 1.2)),
          const SizedBox(height: 4),
          Text('Intensi: Alm. ${order.penerimaName}',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.45), width: 0.8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 15, color: statusColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ]),
          ),
          rescheduleChip,
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Fact(icon: Icons.calendar_month_rounded, label: 'Tanggal Misa', value: formatServiceDate(date)),
            _Fact(icon: Icons.access_time_rounded, label: 'Jam', value: _timeRange(item)),
          ]),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: _gold),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: _slate, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.25)),
      ]),
    );
  }
}
