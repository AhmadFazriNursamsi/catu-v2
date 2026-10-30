import 'package:flutter/material.dart';

/// Kerangka baris artikel saat memuat; berdenyut halus agar terasa hidup.
class NewsArticleSkeleton extends StatefulWidget {
  const NewsArticleSkeleton({super.key});

  @override
  State<NewsArticleSkeleton> createState() => _NewsArticleSkeletonState();
}

class _NewsArticleSkeletonState extends State<NewsArticleSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE9EDF3), borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5)))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(120, 10),
                  const SizedBox(height: 10),
                  _bar(double.infinity, 14),
                  const SizedBox(height: 7),
                  _bar(double.infinity, 14),
                  const SizedBox(height: 7),
                  _bar(150, 14),
                  const SizedBox(height: 12),
                  _bar(90, 10),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 104,
              height: 82,
              decoration: BoxDecoration(color: const Color(0xFFE9EDF3), borderRadius: BorderRadius.circular(12)),
            ),
          ],
        ),
      ),
    );
  }
}
