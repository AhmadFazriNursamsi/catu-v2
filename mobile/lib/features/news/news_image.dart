import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Gambar berita: disimpan di disk (tidak diunduh ulang tiap buka aplikasi), berplaceholder lembut dan fade-in.
/// Gambar sumber bisa berukuran besar, jadi didekode sebesar tampilannya saja ([cacheWidth] = lebar tampil logis).
class NewsImage extends StatelessWidget {
  final String? url;
  final double cacheWidth;
  final BoxFit fit;

  /// Sorotan berlatar gelap memakai varian biru agar kartu tanpa gambar tetap rapi.
  final bool dark;

  const NewsImage({super.key, required this.url, this.cacheWidth = 400, this.fit = BoxFit.cover, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return NewsImagePlaceholder(showIcon: true, dark: dark);
    final px = (cacheWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      memCacheWidth: px,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => NewsImagePlaceholder(dark: dark),
      errorWidget: (_, __, ___) => NewsImagePlaceholder(showIcon: true, dark: dark),
    );
  }
}

class NewsImagePlaceholder extends StatelessWidget {
  final bool showIcon;
  final bool dark;
  const NewsImagePlaceholder({super.key, this.showIcon = false, this.dark = false});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: dark ? const Color(0xFF1E3A8A) : const Color(0xFFE9EDF3),
        child: showIcon ? Center(child: Icon(Icons.church_rounded, color: dark ? const Color(0x66FFFFFF) : const Color(0xFFA9B4C4), size: dark ? 44 : 26)) : null,
      );
}
