import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

class OrderReviewCard extends StatelessWidget {
  final Order order;
  final OrderItem? targetItem;
  final bool isRomo;
  final VoidCallback? onReviewPressed;

  const OrderReviewCard({
    super.key,
    required this.order,
    this.targetItem,
    required this.isRomo,
    this.onReviewPressed,
  });

  @override
  Widget build(BuildContext context) {
    final String? notes = targetItem?.reviewNotes ?? order.reviewNotes;
    final bool hasReview = notes != null && notes.trim().isNotEmpty;

    if (isRomo) {
      if (!hasReview) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 20, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menunggu Ulasan Umat',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pelayanan selesai. Menunggu kesan atau ulasan dari umat.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return _buildReviewedCard(notes, 'Ulasan dari Umat');
      }
    } else {
      if (!hasReview) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF1D4ED8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ulasan Pelayanan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pelayanan telah selesai dilaksanakan. Mohon kesediaan Anda memberikan kesan, ulasan, atau ucapan terima kasih kepada Romo.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onReviewPressed,
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: const Text('Beri Ulasan Pelayanan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return _buildReviewedCard(notes, 'Ulasan Anda');
      }
    }
  }

  Widget _buildReviewedCard(String notes, String title) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRomo ? Icons.chat_bubble_outline_rounded : Icons.check_circle_outline_rounded,
                size: 18,
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Text(
              '"$notes"',
              style: const TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
