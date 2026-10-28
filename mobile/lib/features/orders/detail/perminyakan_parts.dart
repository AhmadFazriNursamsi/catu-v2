import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

/// Komponen tampilan detail pelayanan Sakramen Perminyakan.

const _teal = Color(0xFF0F766E);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Ringkasan penerima: "Laki-laki · 72 tahun" (bagian yang kosong tidak ditampilkan).
String _recipientMeta(Order order) =>
    [order.genderLabel, order.usiaLabel].where((s) => s.trim().isNotEmpty).join(' · ');

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;
  const _Chip(this.label, this.color, {this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color.withValues(alpha: 0.9) : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: solid ? Colors.white : color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7)),
    );
  }
}

/// Latar header: foto gereja + nama penerima dan gender/usia (tanggal & jam ada di kartu ringkasan).
class PerminyakanHero extends StatelessWidget {
  final Order order;
  final OrderItem item;
  final Color urgencyColor;
  const PerminyakanHero({super.key, required this.order, required this.item, required this.urgencyColor});

  @override
  Widget build(BuildContext context) {
    final meta = _recipientMeta(order);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/katedral_jakarta.jpg', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.2), const Color(0xFF042F2E).withValues(alpha: 0.92)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 6, children: [
                const _Chip('✚ SAKRAMEN PERMINYAKAN', Color(0xFF5EEAD4)),
                if (order.urgencyName.isNotEmpty) _Chip(order.urgencyName.toUpperCase(), urgencyColor, solid: true),
              ]),
              const SizedBox(height: 10),
              Text(order.penerimaName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu ringkasan: status, judul pelayanan, dan fakta penting (tanggal, jam, urgensi) sekilas.
class PerminyakanSummaryCard extends StatelessWidget {
  final Order order;
  final OrderItem item;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final Color urgencyColor;
  final Widget rescheduleChip;
  const PerminyakanSummaryCard({
    super.key,
    required this.order,
    required this.item,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.urgencyColor,
    required this.rescheduleChip,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.scheduledDate.isNotEmpty ? item.scheduledDate : order.scheduledDate;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _teal.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.healing_rounded, color: _teal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('Untuk ${order.penerimaName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Fact(icon: Icons.calendar_month_rounded, label: 'Tanggal', value: formatServiceDate(date)),
            _Fact(icon: Icons.access_time_rounded, label: 'Jam', value: '${item.scheduledTimeStart} WIB'),
            _Fact(
                icon: Icons.priority_high_rounded,
                label: 'Urgensi',
                value: order.urgencyName.isNotEmpty ? order.urgencyName : '-',
                color: urgencyColor),
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
  final Color? color;
  const _Fact({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? _ink, height: 1.25)),
      ]),
    );
  }
}
