import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/models/news_model.dart';
import '../../core/services/api_service.dart';
import '../auth/login_screen.dart';
import 'featured_news_carousel.dart';
import 'news_article_tile.dart';
import 'news_filters.dart';
import 'news_header.dart';
import 'news_skeleton.dart';

const _kCachedArticles = 'catu_cached_news_v1';
const _kCachedFeatured = 'catu_cached_news_featured_v1';

class PublicNewsScreen extends StatefulWidget {
  const PublicNewsScreen({super.key});

  @override
  State<PublicNewsScreen> createState() => _PublicNewsScreenState();
}

class _PublicNewsScreenState extends State<PublicNewsScreen> {
  List<NewsCategory> _categories = [];
  List<NewsArticle> _articles = [];
  List<NewsArticle> _featuredArticles = [];
  String _selectedCategorySlug = 'semua';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadFailed = false;
  int _currentPage = 1;
  int _totalPages = 1;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  bool get _showFeatured => _searchQuery.isEmpty && _selectedCategorySlug == 'semua';

  @override
  void initState() {
    super.initState();
    _restoreCachedArticles();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<NewsArticle> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).map((a) => NewsArticle.fromJson(a)).toList();
  }

  /// Tampilkan berita tersimpan lebih dulu agar layar langsung terisi saat dibuka; data baru menyusul.
  Future<void> _restoreCachedArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = _decode(prefs.getString(_kCachedArticles));
      final featured = _decode(prefs.getString(_kCachedFeatured));
      if (cached.isNotEmpty && _articles.isEmpty && mounted) {
        setState(() {
          _articles = cached;
          _featuredArticles = featured;
          _isLoading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    if (_articles.isEmpty) setState(() => _isLoading = true);
    await Future.wait([_loadCategories(), _loadArticles(refresh: true)]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCategories() async {
    try {
      final raw = await ApiService.getNewsCategories();
      if (raw.isEmpty || !mounted) return;
      final list = raw
          .map((c) => NewsCategory.fromJson(c))
          .where((c) => c.slug.toLowerCase() != 'semua' && c.name.toLowerCase() != 'semua')
          .toList();
      setState(() {
        _categories = [
          NewsCategory(id: 0, name: 'Semua', slug: 'semua', description: 'Semua berita Katolik', iconName: 'newspaper', displayOrder: 0),
          ...list,
        ];
      });
    } catch (_) {}
  }

  Future<void> _loadArticles({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
    } else {
      if (_isLoadingMore || _currentPage >= _totalPages) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await ApiService.getNews(categorySlug: _selectedCategorySlug, search: _searchQuery, page: _currentPage, limit: 10);
      final List<dynamic> rawArticles = data['articles'] ?? [];
      final List<dynamic> rawFeatured = data['featuredArticles'] ?? [];
      final items = rawArticles.map((a) => NewsArticle.fromJson(a)).toList();
      final feat = rawFeatured.map((a) => NewsArticle.fromJson(a)).toList();
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _articles = items;
          if (feat.isNotEmpty) _featuredArticles = feat;
        } else {
          _articles.addAll(items);
        }
        _totalPages = data['totalPages'] ?? 1;
        _loadFailed = data['offline'] == true;
        _isLoadingMore = false;
      });
      if (refresh && items.isNotEmpty && _showFeatured) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_kCachedArticles, jsonEncode(rawArticles));
          prefs.setString(_kCachedFeatured, jsonEncode(rawFeatured));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _reload() async {
    await _loadArticles(refresh: true);
    if (mounted) setState(() => _isLoading = false);
  }

  void _onCategorySelected(String slug) {
    HapticFeedback.selectionClick();
    if (_selectedCategorySlug == slug) return;
    setState(() {
      _selectedCategorySlug = slug;
      _isLoading = true;
    });
    _reload();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = query.trim();
        _isLoading = true;
      });
      _reload();
    });
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadArticles(refresh: true);
  }

  void _navigateToLogin() {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final loadingFirst = _isLoading && _articles.isEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: NewsHeader(dateLabel: formatServiceDate(DateTime.now().toIso8601String()), onLogin: _navigateToLogin),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppConstants.primaryBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: NewsSearchField(controller: _searchController, hasQuery: _searchQuery.isNotEmpty, onChanged: _onSearchChanged),
              ),
            ),
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: NewsCategoryChips(categories: _categories, selectedSlug: _selectedCategorySlug, onSelected: _onCategorySelected),
              ),
            if (_showFeatured && _featuredArticles.isNotEmpty)
              SliverToBoxAdapter(child: FeaturedNewsCarousel(articles: _featuredArticles))
            else if (_showFeatured && loadingFirst)
              const SliverToBoxAdapter(child: FeaturedNewsCarouselSkeleton()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  _searchQuery.isNotEmpty ? 'Hasil pencarian "$_searchQuery"' : 'Terbaru',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
            ),
            if (loadingFirst)
              SliverList(delegate: SliverChildBuilderDelegate((_, __) => const NewsArticleSkeleton(), childCount: 5))
            else if (_articles.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => index == _articles.length ? _buildLoadMore() : NewsArticleTile(article: _articles[index]),
                  childCount: _articles.length + (_currentPage < _totalPages ? 1 : 0),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : OutlinedButton(
                onPressed: () {
                  _currentPage++;
                  _loadArticles();
                },
                style: OutlinedButton.styleFrom(shape: const StadiumBorder(), foregroundColor: AppConstants.primaryBlue),
                child: const Text('Muat lebih banyak'),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final offline = _loadFailed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(offline ? Icons.wifi_off_rounded : Icons.newspaper_rounded, size: 52, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 14),
            Text(offline ? 'Berita belum dapat dimuat' : 'Belum ada berita', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            Text(
              offline ? 'Periksa koneksi internet Anda, lalu coba lagi.' : 'Coba kata kunci atau kategori lain.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _reload();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
              style: FilledButton.styleFrom(backgroundColor: AppConstants.primaryBlue, shape: const StadiumBorder()),
            ),
          ],
        ),
      ),
    );
  }
}
