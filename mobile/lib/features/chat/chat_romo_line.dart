import 'package:flutter/material.dart';

import '../../core/models/models.dart';

/// Baris penanda Romo di daftar chat: ungu "Romo X" bila pelayanan sudah diambil Romo,
/// kuning "Menunggu Romo" bila masih menunggu. Pelayanan selesai/gagal tanpa Romo tidak diberi baris.
class ChatRomoLine extends StatelessWidget {
  final ChatGroupItem group;
  const ChatRomoLine({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final romo = group.romoDisplayName;
    final waiting = romo == null && group.orderStatus.toUpperCase() == 'PENDING';
    if (romo == null && !waiting) return const SizedBox.shrink();
    final color = waiting ? const Color(0xFFB45309) : const Color(0xFF7C3AED);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(waiting ? Icons.hourglass_top_rounded : Icons.person_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              romo ?? 'Menunggu Romo',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
