import 'package:flutter/material.dart';
import '../../core/models/news_model.dart';
import 'news_detail_screen.dart';
import 'news_image.dart';

/// Baris artikel: teks di kiri, gambar kecil di kanan, dipisah garis tipis (tanpa kartu berbingkai).
class NewsArticleTile extends StatelessWidget {
  final NewsArticle article;
  const NewsArticleTile({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(article: article))),
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
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: article.categoryName.toUpperCase(), style: TextStyle(color: article.categoryColor, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                      TextSpan(text: '  ·  ${article.timeAgo}', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), height: 1.32),
                  ),
                  const SizedBox(height: 8),
                  Text(article.sourceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 104, height: 82, child: NewsImage(url: article.imageUrl, cacheWidth: 104)),
            ),
          ],
        ),
      ),
    );
  }
}
