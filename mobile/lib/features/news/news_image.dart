import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _kFallbackAsset = 'assets/images/katedral_jakarta.jpg';

/// Foto stok Unsplash yang dulu diisi otomatis oleh scraper bukan gambar artikel; anggap saja tidak ada gambar.
bool _isStockPhoto(String url) => url.contains('images.unsplash.com');

/// Gambar berita: disimpan di disk (tidak diunduh ulang tiap buka aplikasi), berplaceholder lembut dan fade-in.
/// Artikel tanpa gambar, bergambar stok, atau yang gambarnya gagal dimuat memakai foto Katedral Jakarta.
/// Gambar sumber bisa berukuran besar, jadi didekode sebesar tampilannya saja ([cacheWidth] = lebar tampil logis).
class NewsImage extends StatelessWidget {
  final String? url;
  final double cacheWidth;
  final BoxFit fit;

  const NewsImage({super.key, required this.url, this.cacheWidth = 400, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty || _isStockPhoto(src)) return const NewsFallbackImage();
    final px = (cacheWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      memCacheWidth: px,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => const ColoredBox(color: Color(0xFFE9EDF3)),
      errorWidget: (_, __, ___) => const NewsFallbackImage(),
    );
  }
}

class NewsFallbackImage extends StatelessWidget {
  const NewsFallbackImage({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(_kFallbackAsset, fit: BoxFit.cover, cacheWidth: 600);
}
