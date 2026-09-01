import 'package:flutter/material.dart';
import 'models.dart';

class NewsCategory {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String iconName;
  final int displayOrder;
  final int articleCount;

  NewsCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.iconName,
    required this.displayOrder,
    this.articleCount = 0,
  });

  factory NewsCategory.fromJson(Map<String, dynamic> json) {
    return NewsCategory(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      iconName: json['iconName'] ?? json['icon_name'] ?? 'newspaper',
      displayOrder: int.tryParse(json['displayOrder']?.toString() ?? '0') ?? 0,
      articleCount: int.tryParse(json['articleCount']?.toString() ?? '0') ?? 0,
    );
  }

  IconData get icon {
    switch (iconName.toLowerCase()) {
      case 'location_city':
        return Icons.location_city_rounded;
      case 'church':
        return Icons.church_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'wb_sunny':
        return Icons.wb_sunny_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'newspaper':
      default:
        return Icons.newspaper_rounded;
    }
  }
}

class NewsArticle {
  final String id;
  final String sourceId;
  final String sourceName;
  final String sourceCode;
  final String? sourceLogo;
  final String categoryId;
  final String categoryName;
  final String categorySlug;
  final String? categoryIcon;
  final String title;
  final String slug;
  final String summary;
  final String contentHtml;
  final String author;
  final String originalUrl;
  final String? imageUrl;
  final String publishedAt;
  final String scrapedAt;
  final int viewCount;
  final bool isFeatured;
  final bool isEditorsChoice;
  final List<NewsArticle>? relatedArticles;

  NewsArticle({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.sourceCode,
    this.sourceLogo,
    required this.categoryId,
    required this.categoryName,
    required this.categorySlug,
    this.categoryIcon,
    required this.title,
    required this.slug,
    required this.summary,
    this.contentHtml = '',
    required this.author,
    required this.originalUrl,
    this.imageUrl,
    required this.publishedAt,
    required this.scrapedAt,
    this.viewCount = 0,
    this.isFeatured = false,
    this.isEditorsChoice = false,
    this.relatedArticles,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    List<NewsArticle>? related;
    if (json['relatedArticles'] != null && json['relatedArticles'] is List) {
      related = (json['relatedArticles'] as List)
          .map((item) => NewsArticle.fromJson(item))
          .toList();
    }

    return NewsArticle(
      id: json['id']?.toString() ?? '',
      sourceId: json['sourceId']?.toString() ?? json['source_id']?.toString() ?? '',
      sourceName: json['sourceName'] ?? json['source_name'] ?? 'Warta Katolik',
      sourceCode: json['sourceCode'] ?? json['source_code'] ?? 'CATU_NEWS',
      sourceLogo: json['sourceLogo'] ?? json['source_logo'],
      categoryId: json['categoryId']?.toString() ?? json['category_id']?.toString() ?? '1',
      categoryName: json['categoryName'] ?? json['category_name'] ?? 'Gereja Katolik',
      categorySlug: json['categorySlug'] ?? json['category_slug'] ?? 'gereja-indonesia',
      categoryIcon: json['categoryIcon'] ?? json['category_icon'],
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      summary: json['summary'] ?? '',
      contentHtml: json['contentHtml'] ?? json['content_html'] ?? '',
      author: json['author'] ?? 'Redaksi Katolik',
      originalUrl: json['originalUrl'] ?? json['original_url'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      publishedAt: json['publishedAt'] ?? json['published_at'] ?? '',
      scrapedAt: json['scrapedAt'] ?? json['scraped_at'] ?? '',
      viewCount: int.tryParse(json['viewCount']?.toString() ?? '0') ?? 0,
      isFeatured: json['isFeatured'] == true || json['is_featured'] == true,
      isEditorsChoice: json['isEditorsChoice'] == true || json['is_editors_choice'] == true,
      relatedArticles: related,
    );
  }

  /// Formatted date in "nama hari, dd/mm/yy" (e.g. "Senin, 01/09/26")
  String get formattedPublishedDate => formatServiceDate(publishedAt);

  /// Relative time ago (e.g. "2 jam yang lalu", "3 hari yang lalu")
  String get timeAgo {
    if (publishedAt.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return formatServiceDate(publishedAt);
    } catch (_) {
      return formatServiceDate(publishedAt);
    }
  }

  Color get categoryColor {
    switch (categorySlug) {
      case 'vatikan-dan-paus':
        return const Color(0xFFD97706); // Amber / Gold Vatikan
      case 'gereja-indonesia':
        return const Color(0xFF1D4ED8); // Royal Blue
      case 'liturgi-dan-doa':
        return const Color(0xFF7C3AED); // Purple
      case 'renungan-oase':
        return const Color(0xFF059669); // Emerald Green
      case 'orang-muda-katolik':
        return const Color(0xFFE11D48); // Rose / Red
      default:
        return const Color(0xFF475569);
    }
  }
}
