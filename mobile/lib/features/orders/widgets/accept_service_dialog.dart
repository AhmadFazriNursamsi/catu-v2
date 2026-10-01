import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

Future<bool> showAcceptServiceDialog(
  BuildContext context, {
  required Order order,
  OrderItem? targetItem,
}) async {
  final itemName = targetItem != null ? targetItem.itemName : order.categoryName;
  final dateStr = targetItem != null ? targetItem.scheduledDate : order.scheduledDate;
  final timeStr = targetItem != null
      ? (targetItem.scheduledTimeEnd.isNotEmpty
          ? '${targetItem.scheduledTimeStart} - ${targetItem.scheduledTimeEnd}'
          : targetItem.scheduledTimeStart)
      : order.scheduledTime;
  final locStr = targetItem != null ? targetItem.locationName : order.locationName;
  final pemohonStr = order.pemohonName.isNotEmpty ? order.pemohonName : 'Umat Pemohon';

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Konfirmasi Terima Pelayanan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apakah Romo sungguh bersedia dan berkomitmen untuk hadir melayani permohonan ini?',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildRow(Icons.church_rounded, 'Pelayanan', itemName),
                const Divider(height: 12, thickness: 0.5),
                _buildRow(Icons.person_rounded, 'Pemohon', pemohonStr),
                const Divider(height: 12, thickness: 0.5),
                _buildRow(Icons.calendar_today_rounded, 'Jadwal', '$dateStr • $timeStr'),
                const Divider(height: 12, thickness: 0.5),
                _buildRow(Icons.location_on_rounded, 'Lokasi', locStr),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dengan menerima, Romo resmi bertugas dan akan langsung bergabung ke grup chat koordinasi.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Ya, Saya Bersedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    ),
  );
  return result == true;
}

Widget _buildRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: const Color(0xFF64748B)),
      const SizedBox(width: 6),
      SizedBox(
        width: 64,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
