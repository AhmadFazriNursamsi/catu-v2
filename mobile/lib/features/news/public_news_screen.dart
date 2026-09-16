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
import 'news_detail_screen.dart';
import 'news_skeleton.dart';

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
  bool _hasAutoScraped = false;
  int _currentPage = 1;
  int _totalPages = 1;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _restoreCachedArticles();
    _loadInitialData();
  }

  Future<void> _restoreCachedArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('catu_cached_news_v1');
      if (raw != null && raw.isNotEmpty && mounted) {
        final list = (jsonDecode(raw) as List).map((a) => NewsArticle.fromJson(a)).toList();
        if (list.isNotEmpty && _articles.isEmpty) {
          setState(() {
            _articles = list;
            _isLoading = false;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_articles.isEmpty) setState(() => _isLoading = true);
    await Future.wait([
      _loadCategories(),
      _loadArticles(refresh: true),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final raw = await ApiService.getNewsCategories();
      if (raw.isNotEmpty) {
        final list = raw.map((c) => NewsCategory.fromJson(c)).toList();
        setState(() {
          _categories = [
            NewsCategory(
              id: 0,
              name: 'Semua',
              slug: 'semua',
              description: 'Semua berita Katolik',
              iconName: 'newspaper',
              displayOrder: 0,
            ),
            ...list,
          ];
        });
      }
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
      final data = await ApiService.getNews(
        categorySlug: _selectedCategorySlug,
        search: _searchQuery,
        page: _currentPage,
        limit: 10,
      );

      final List<dynamic> rawArticles = data['articles'] ?? [];
      final List<dynamic> rawFeatured = data['featuredArticles'] ?? [];
      final int totalPages = data['totalPages'] ?? 1;

      List<NewsArticle> items = rawArticles.map((a) => NewsArticle.fromJson(a)).toList();
      final feat = rawFeatured.map((a) => NewsArticle.fromJson(a)).toList();

      if (refresh && items.isEmpty && !_hasAutoScraped && _selectedCategorySlug == 'semua' && _searchQuery.isEmpty) {
        _hasAutoScraped = true;
        await ApiService.triggerNewsScrape();
        final retry = await ApiService.getNews(page: 1, limit: 10);
        final retryRaw = retry['articles'] ?? [];
        if (retryRaw.isNotEmpty) {
          items = retryRaw.map((a) => NewsArticle.fromJson(a)).toList();
        }
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _articles = items;
            if (feat.isNotEmpty) _featuredArticles = feat;
          } else {
            _articles.addAll(items);
          }
          _totalPages = totalPages;
          _isLoadingMore = false;
        });
        if (refresh && items.isNotEmpty) {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('catu_cached_news_v1', jsonEncode(rawArticles));
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onCategorySelected(String slug) {
    HapticFeedback.selectionClick();
    if (_selectedCategorySlug == slug) return;
    setState(() {
      _selectedCategorySlug = slug;
      _isLoading = true;
    });
    _loadArticles(refresh: true).then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = query.trim();
        _isLoading = true;
      });
      _loadArticles(refresh: true).then((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    });
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await ApiService.triggerNewsScrape();
    await _loadArticles(refresh: true);
  }

  void _navigateToLogin() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayFormatted = formatServiceDate(DateTime.now().toIso8601String());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // App Icon & Brand
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logoCatu.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catu News',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          todayFormatted,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Prominent Login Button
                  ElevatedButton.icon(
                    onPressed: _navigateToLogin,
                    icon: const Icon(Icons.login_rounded, size: 16, color: Color(0xFF78350F)),
                    label: const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.accentGold,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppConstants.primaryBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── Search & Filter Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    // Search Box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Cari warta Katolik, Paus, renungan...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Category Chips List
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, idx) {
                          final cat = _categories[idx];
                          final isSelected = _selectedCategorySlug == cat.slug;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cat.icon,
                                    size: 14,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: AppConstants.primaryBlue,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? AppConstants.primaryBlue : const Color(0xFFCBD5E1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              showCheckmark: false,
                              onSelected: (_) => _onCategorySelected(cat.slug),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Featured Headlines Carousel (Isolated State) ──
            if (_searchQuery.isEmpty && _selectedCategorySlug == 'semua' && _featuredArticles.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: FeaturedNewsCarousel(articles: _featuredArticles),
              ),
            ],

            // ── Section Title: Latest Articles ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Hasil Pencarian "$_searchQuery"'
                          : 'Kabar & Berita Terbaru',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),

            if (_isLoading && _articles.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const NewsArticleSkeleton(),
                    childCount: 4,
                  ),
                ),
              )
            else if (_articles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _articles.length) {
                        return _buildLoadMoreIndicator();
                      }
                      final item = _articles[index];
                      return _buildArticleItemCard(item);
                    },
                    childCount: _articles.length + (_currentPage < _totalPages ? 1 : 0),
                  ),
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleItemCard(NewsArticle item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NewsDetailScreen(article: item)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildFallbackImage(),
                          )
                        : _buildFallbackImage(),
                  ),
                ),
                const SizedBox(width: 14),
                // Article Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.categoryName,
                              style: TextStyle(
                                color: item.categoryColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.timeAgo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.newspaper_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.sourceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () {
                  _currentPage++;
                  _loadArticles();
                },
                child: const Text('Muat Lebih Banyak'),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.newspaper_rounded, size: 54, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 14),
            const Text(
              'Belum Ada Berita',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tarik layar ke bawah untuk memperbarui warta Katolik terkini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Perbarui Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFF1E3A8A),
      child: const Center(
        child: Icon(Icons.church_rounded, color: Colors.white54, size: 36),
      ),
    );
  }
}
