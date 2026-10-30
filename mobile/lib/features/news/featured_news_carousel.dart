import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/news_model.dart';
import 'news_detail_screen.dart';
import 'news_image.dart';

const double _kCarouselHeight = 224;

/// Carousel sorotan; berdiri sendiri agar perpindahan halaman tidak membangun ulang seluruh layar.
class FeaturedNewsCarousel extends StatefulWidget {
  final List<NewsArticle> articles;

  const FeaturedNewsCarousel({super.key, required this.articles});

  @override
  State<FeaturedNewsCarousel> createState() => _FeaturedNewsCarouselState();
}

class _FeaturedNewsCarouselState extends State<FeaturedNewsCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.articles.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = _currentIndex + 1 >= widget.articles.length ? 0 : _currentIndex + 1;
      _pageController.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Sorotan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _kCarouselHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.articles.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (_, index) => _FeaturedCard(article: widget.articles[index]),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.articles.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentIndex == i ? AppConstants.primaryBlue : const Color(0xFFD5DBE4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final NewsArticle article;
  const _FeaturedCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NewsImage(url: article.imageUrl, cacheWidth: 360, dark: true),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.25, 1],
                    colors: [Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: article.categoryColor, borderRadius: BorderRadius.circular(8)),
                      child: Text(article.categoryName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${article.sourceName}  ·  ${article.timeAgo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penahan ruang selama sorotan belum tiba, agar daftar di bawahnya tidak melompat saat data masuk.
class FeaturedNewsCarouselSkeleton extends StatelessWidget {
  const FeaturedNewsCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(21, 16, 21, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sorotan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Container(
            height: _kCarouselHeight,
            decoration: BoxDecoration(color: const Color(0xFFE9EDF3), borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}
