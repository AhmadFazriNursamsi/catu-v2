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
    final int? rating = targetItem?.rating ?? order.rating;
    final String? notes = targetItem?.reviewNotes ?? order.reviewNotes;
    final bool hasReview = rating != null && rating > 0;

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
                      'Pelayanan selesai. Menunggu penilaian & ulasan dari umat.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return _buildReviewedCard(rating, notes, 'Ulasan dari Umat');
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
                  Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ulasan Pelayanan',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pelayanan telah selesai dilaksanakan. Mohon kesediaan Anda memberikan penilaian atas pelayanan Romo.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onReviewPressed,
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: const Text('Beri Ulasan Pelayanan ⭐', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
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
        return _buildReviewedCard(rating, notes, 'Ulasan Anda ⭐');
      }
    }
  }

  Widget _buildReviewedCard(int rating, String? notes, String title) {
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
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: i < rating ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$rating/5',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                '"$notes"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
