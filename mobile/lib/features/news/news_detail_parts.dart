import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/news_model.dart';
import '../auth/login_screen.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Tombol bulat putih di atas foto; tetap terbaca baik di atas gambar maupun di bilah putih.
class NewsRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const NewsRoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          shape: const CircleBorder(),
          elevation: 1.5,
          shadowColor: Colors.black38,
          child: IconButton(tooltip: tooltip, icon: Icon(icon, size: 20, color: _ink), onPressed: onPressed),
        ),
      );
}

/// Kategori, judul, dan baris penulis/sumber di atas isi artikel.
class NewsArticleHeader extends StatelessWidget {
  final NewsArticle article;
  final int? readMinutes;
  const NewsArticleHeader({super.key, required this.article, this.readMinutes});

  @override
  Widget build(BuildContext context) {
    final color = article.categoryColor;
    final author = article.author.trim();
    final byline = author.isNotEmpty && author != article.sourceName ? author : article.sourceName;
    final meta = [
      if (byline != article.sourceName) article.sourceName,
      article.formattedPublishedDate,
      if (readMinutes != null) '$readMinutes mnt baca',
    ].join('  ·  ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(article.categoryName.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        const SizedBox(height: 10),
        Text(article.title, style: const TextStyle(fontSize: 26, height: 1.22, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(byline.isEmpty ? '?' : byline[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(byline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 2),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFE8ECF2)),
        const SizedBox(height: 22),
      ],
    );
  }
}

/// Penahan isi artikel selama teks lengkap diambil.
class NewsContentSkeleton extends StatelessWidget {
  const NewsContentSkeleton({super.key});

  Widget _bar(double widthFactor) => FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(height: 14, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFE9EDF3), borderRadius: BorderRadius.circular(6))),
      );

  @override
  Widget build(BuildContext context) => Column(children: [for (final f in const [1.0, 1.0, 0.9, 1.0, 0.6, 1.0, 1.0, 0.8]) _bar(f)]);
}

/// Tautan ke artikel asli beserta keterangan sumber.
class NewsSourceFooter extends StatelessWidget {
  final String sourceName;
  final VoidCallback onOpen;
  const NewsSourceFooter({super.key, required this.sourceName, required this.onOpen});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: Text('Baca lengkap di $sourceName', style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryBlue,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Dikutip dari $sourceName', style: const TextStyle(fontSize: 12, color: _muted)),
        ],
      );
}

/// Ajakan masuk untuk layanan Romo; sengaja ringkas agar tidak menyaingi artikel.
class NewsLoginPromo extends StatelessWidget {
  const NewsLoginPromo({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.church_rounded, color: Colors.white70, size: 30),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Layanan Sakramen & Misa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Misa arwah, kedukaan, dan perminyakan orang sakit.', style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.accentGold,
                foregroundColor: const Color(0xFF78350F),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}
