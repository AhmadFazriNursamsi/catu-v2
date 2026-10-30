import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/news_model.dart';
import '../../core/services/api_service.dart';
import 'news_article_tile.dart';
import 'news_content.dart';
import 'news_detail_parts.dart';
import 'news_image.dart';

const double _kHeroHeight = 320;

class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;

  const NewsDetailScreen({super.key, required this.article});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late NewsArticle _article = widget.article;
  final ScrollController _scroll = ScrollController();
  bool _isLoading = false;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFullDetail();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Ikon status bar mengikuti latar: terang di atas foto, gelap setelah bilah menjadi putih.
  void _onScroll() {
    final collapsed = _scroll.hasClients && _scroll.offset > _kHeroHeight - kToolbarHeight - MediaQuery.paddingOf(context).top - 24;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  Future<void> _loadFullDetail() async {
    if (_article.contentHtml.isNotEmpty && _article.relatedArticles != null) return;
    setState(() => _isLoading = true);
    final data = await ApiService.getNewsDetail(_article.id.isNotEmpty ? _article.id : _article.slug);
    if (!mounted) return;
    setState(() {
      if (data != null) _article = NewsArticle.fromJson(data);
      _isLoading = false;
    });
  }

  Future<void> _openSource() async {
    if (_article.originalUrl.isEmpty) return;
    try {
      await launchUrl(Uri.parse(_article.originalUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast('Tidak dapat membuka tautan');
    }
  }

  void _copyLink() {
    if (_article.originalUrl.isEmpty) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: '${_article.title}\n${_article.originalUrl}'));
    _toast('Tautan berita disalin');
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );

  /// Perkiraan lama baca (200 kata/menit); disembunyikan untuk teks pendek.
  int? get _readMinutes {
    final words = RegExp(r'\S+').allMatches(html_parser.parseFragment(_article.contentHtml).text ?? '').length;
    return words < 80 ? null : (words / 200).ceil().clamp(1, 60);
  }

  SystemUiOverlayStyle get _overlay {
    final light = !_collapsed;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
      statusBarBrightness: light ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
    );
  }

  Widget _heroBar() {
    final back = NewsRoundButton(icon: Icons.arrow_back_rounded, tooltip: 'Kembali', onPressed: () => Navigator.pop(context));
    final share = NewsRoundButton(icon: Icons.link_rounded, tooltip: 'Salin tautan', onPressed: _copyLink);
    return SliverAppBar(
      pinned: true,
      expandedHeight: _kHeroHeight,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: _overlay,
      leading: back,
      actions: [share],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            NewsImage(url: _article.imageUrl, cacheWidth: 420),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Color(0x66000000), Colors.transparent]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const NewsContentSkeleton();
    final html = _article.contentHtml.isNotEmpty ? _article.contentHtml : '<p>${const HtmlEscape().convert(_article.summary)}</p>';
    return NewsContent(html: html, heroUrl: _article.imageUrl, accent: _article.categoryColor);
  }

  @override
  Widget build(BuildContext context) {
    final related = _article.relatedArticles ?? const <NewsArticle>[];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            _heroBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NewsArticleHeader(article: _article, readMinutes: _isLoading ? null : _readMinutes),
                    _body(),
                    if (!_isLoading) ...[
                      const SizedBox(height: 8),
                      NewsSourceFooter(sourceName: _article.sourceName, onOpen: _openSource),
                    ],
                    const SizedBox(height: 28),
                    const NewsLoginPromo(),
                  ],
                ),
              ),
            ),
            if (related.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 32, 16, 4),
                  child: Text('Berita terkait', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ),
              ),
            if (related.isNotEmpty) SliverList.builder(itemCount: related.length, itemBuilder: (_, i) => NewsArticleTile(article: related[i])),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
