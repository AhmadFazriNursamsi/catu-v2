import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';

/// Header detail Misa Kedukaan: latar foto gereja, potret almarhum berbingkai emas, dan keterangan berpulang.

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF5D77D);
const _night = Color(0xFF0B1220);

final Map<String, Uint8List> _photoCache = {};

/// Foto almarhum dari data URI, URL, aset, atau berkas lokal; ikon orang bila tidak ada.
class DeceasedPhoto extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const DeceasedPhoto({super.key, required this.url, this.fit = BoxFit.cover});

  Widget _fallback() => const ColoredBox(
        color: Color(0xFF21262D),
        child: Center(child: Icon(Icons.person_rounded, size: 52, color: Color(0xFF8B949E))),
      );

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    Widget err(BuildContext _, Object __, StackTrace? ___) => _fallback();
    if (u.isEmpty) return _fallback();
    if (u.startsWith('data:image')) {
      try {
        final bytes = _photoCache[u] ??= base64Decode(u.substring(u.indexOf(',') + 1));
        return Image.memory(bytes, fit: fit, gaplessPlayback: true, errorBuilder: err);
      } catch (_) {
        return _fallback();
      }
    }
    if (u.startsWith('http://') || u.startsWith('https://')) return Image.network(u, fit: fit, errorBuilder: err);
    if (u.startsWith('assets/')) return Image.asset(u, fit: fit, errorBuilder: err);
    final file = File(u);
    return file.existsSync() ? Image.file(file, fit: fit, errorBuilder: err) : _fallback();
  }
}

class KedukaanHero extends StatelessWidget {
  final Order order;
  const KedukaanHero({super.key, required this.order});

  String get _passedLine {
    final date = order.tanggalMeninggalLabel;
    final time = order.waktuMeninggalLabel;
    if (date.isEmpty) return '';
    return time.isEmpty ? 'Berpulang $date' : 'Berpulang $date · $time WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/katedral_jakarta.jpg', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_night.withValues(alpha: 0.55), _night.withValues(alpha: 0.7), _night.withValues(alpha: 0.95)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.18),
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_gold.withValues(alpha: 0.22), Colors.transparent]),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Portrait(url: order.attachmentUrl),
                const SizedBox(height: 18),
                Text('DALAM KENANGAN',
                    style: TextStyle(
                        fontSize: 10.5, letterSpacing: 3, fontWeight: FontWeight.w700, color: _goldLight.withValues(alpha: 0.85))),
                const SizedBox(height: 6),
                Text(order.penerimaName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                        color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 10),
                const _Ornament(),
                if (_passedLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_passedLine,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB6BDC8), fontSize: 12.5, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Potret bulat dengan bingkai emas dua lapis dan lencana salib.
class _Portrait extends StatelessWidget {
  final String? url;
  const _Portrait({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 132,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 124,
            height: 124,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.28), blurRadius: 28, spreadRadius: 2)],
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [_gold, _goldLight, Color(0xFFB8860B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: ClipOval(child: DeceasedPhoto(url: url)),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _night,
                border: Border.all(color: _gold, width: 1.4),
              ),
              alignment: Alignment.center,
              child: const Text('✝', style: TextStyle(color: _goldLight, fontSize: 14, height: 1.1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis emas dengan bintang kecil di tengah.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Container(
          width: 46,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: left ? [Colors.transparent, _gold] : [_gold, Colors.transparent]),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      line(true),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('✦', style: TextStyle(color: _gold, fontSize: 10)),
      ),
      line(false),
    ]);
  }
}
