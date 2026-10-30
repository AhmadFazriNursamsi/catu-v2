import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import 'news_image.dart';

const _ink = Color(0xFF1F2937);
const _boilerplate = r'^(read all|read more|baca selengkapnya|baca juga)\W*$';

class _Style {
  final bool bold, italic, quote;
  final String? link;
  const _Style({this.bold = false, this.italic = false, this.quote = false, this.link});
  _Style copy({bool? bold, bool? italic, bool? quote, String? link}) =>
      _Style(bold: bold ?? this.bold, italic: italic ?? this.italic, quote: quote ?? this.quote, link: link ?? this.link);
}

class _Run {
  final String text;
  final _Style style;
  const _Run(this.text, this.style);
}

sealed class _Block {}

class _Para extends _Block {
  final List<_Run> runs;
  final int heading; // 0 = paragraf biasa, 1..6 = judul bagian
  final bool quote;
  _Para(this.runs, {this.heading = 0, this.quote = false});
}

class _Item extends _Block {
  final List<_Run> runs;
  final String marker;
  _Item(this.runs, this.marker);
}

class _Pic extends _Block {
  final String url;
  _Pic(this.url);
}

String _stripQuery(String url) => url.split('?').first;

/// Mengubah HTML artikel menjadi blok teks/gambar; tag tak dikenal dibaca sebagai teks biasa.
List<_Block> _parse(String html, String? heroUrl) {
  final out = <_Block>[];
  var runs = <_Run>[];

  List<_Run> tidy() {
    final kept = runs.where((r) => r.text.isNotEmpty).toList();
    runs = [];
    while (kept.isNotEmpty && kept.first.text.trim().isEmpty) {
      kept.removeAt(0);
    }
    while (kept.isNotEmpty && kept.last.text.trim().isEmpty) {
      kept.removeLast();
    }
    if (kept.isEmpty) return kept;
    kept[0] = _Run(kept.first.text.trimLeft(), kept.first.style);
    kept[kept.length - 1] = _Run(kept.last.text.trimRight(), kept.last.style);
    return kept;
  }

  void flush({int heading = 0, bool quote = false}) {
    final r = tidy();
    final plain = r.map((e) => e.text).join().trim();
    if (plain.isEmpty || RegExp(_boilerplate, caseSensitive: false).hasMatch(plain)) return;
    out.add(_Para(r, heading: heading, quote: quote));
  }

  void walk(dom.Node n, _Style st) {
    if (n is dom.Text) {
      runs.add(_Run(n.text.replaceAll(RegExp(r'\s+'), ' '), st));
      return;
    }
    if (n is! dom.Element) return;
    final tag = n.localName ?? '';
    void kids(_Style s) {
      for (final c in n.nodes) {
        walk(c, s);
      }
    }
    switch (tag) {
      case 'script' || 'style' || 'iframe' || 'noscript' || 'form' || 'svg' || 'button':
        return;
      case 'br':
        runs.add(_Run('\n', st));
      case 'img':
        flush(quote: st.quote);
        final src = n.attributes['src'] ?? '';
        final w = int.tryParse(n.attributes['width'] ?? '') ?? 999;
        final h = int.tryParse(n.attributes['height'] ?? '') ?? 999;
        if (src.startsWith('http') && w > 80 && h > 80 && (heroUrl == null || _stripQuery(src) != _stripQuery(heroUrl))) out.add(_Pic(src));
      case 'strong' || 'b':
        kids(st.copy(bold: true));
      case 'em' || 'i':
        kids(st.copy(italic: true));
      case 'a':
        kids(st.copy(link: n.attributes['href']));
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        flush(quote: st.quote);
        kids(st);
        flush(heading: int.parse(tag.substring(1)), quote: st.quote);
      case 'ul' || 'ol':
        flush(quote: st.quote);
        var i = 0;
        for (final li in n.children.where((c) => c.localName == 'li')) {
          i++;
          for (final c in li.nodes) {
            walk(c, st);
          }
          final r = tidy();
          if (r.isNotEmpty) out.add(_Item(r, tag == 'ol' ? '$i.' : '•'));
        }
      case 'blockquote':
        flush();
        kids(st.copy(quote: true));
        flush(quote: true);
      case 'p' || 'div' || 'section' || 'article' || 'figure' || 'figcaption' || 'main' || 'center' || 'li':
        flush(quote: st.quote);
        kids(st);
        flush(quote: st.quote);
      default:
        kids(st);
    }
  }

  for (final n in html_parser.parseFragment(html).nodes) {
    walk(n, const _Style());
  }
  flush();
  return out;
}

/// Isi artikel dengan tipografi nyaman dibaca: paragraf, judul bagian, daftar, kutipan, dan gambar.
class NewsContent extends StatefulWidget {
  final String html;
  final String? heroUrl;
  final Color accent;
  const NewsContent({super.key, required this.html, this.heroUrl, this.accent = AppConstants.primaryBlue});

  @override
  State<NewsContent> createState() => _NewsContentState();
}

class _NewsContentState extends State<NewsContent> {
  final List<TapGestureRecognizer> _taps = [];
  late List<_Block> _blocks = _parse(widget.html, widget.heroUrl);

  @override
  void didUpdateWidget(NewsContent old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _disposeTaps();
      _blocks = _parse(widget.html, widget.heroUrl);
    }
  }

  void _disposeTaps() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  Future<void> _open(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  InlineSpan _span(_Run r, TextStyle base) {
    final link = r.style.link;
    final style = base.copyWith(
      fontWeight: r.style.bold ? FontWeight.w700 : null,
      fontStyle: r.style.italic ? FontStyle.italic : null,
      color: link != null ? widget.accent : null,
      decoration: link != null ? TextDecoration.underline : null,
    );
    if (link == null) return TextSpan(text: r.text, style: style);
    final tap = TapGestureRecognizer()..onTap = () => _open(link);
    _taps.add(tap);
    return TextSpan(text: r.text, style: style, recognizer: tap);
  }

  Widget _text(List<_Run> runs, TextStyle base) => Text.rich(TextSpan(children: [for (final r in runs) _span(r, base)]));

  @override
  Widget build(BuildContext context) {
    _disposeTaps(); // dibuat ulang tiap build agar tidak menumpuk
    const body = TextStyle(fontSize: 17, height: 1.65, color: _ink);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final b in _blocks) _blockWidget(b, body)]);
  }

  Widget _blockWidget(_Block b, TextStyle body) {
    if (b is _Para && b.heading > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: _text(b.runs, body.copyWith(fontSize: b.heading <= 2 ? 21 : 18, height: 1.3, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
      );
    }
    if (b is _Para && b.quote) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          border: Border(left: BorderSide(color: widget.accent, width: 3)),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        ),
        child: _text(b.runs, body.copyWith(fontStyle: FontStyle.italic, color: const Color(0xFF475569))),
      );
    }
    if (b is _Para) return Padding(padding: const EdgeInsets.only(bottom: 18), child: _text(b.runs, body));
    if (b is _Item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, child: Text(b.marker, style: body.copyWith(color: widget.accent, fontWeight: FontWeight.w800))),
            Expanded(child: _text(b.runs, body)),
          ],
        ),
      );
    }
    final pic = b as _Pic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(aspectRatio: 16 / 10, child: NewsImage(url: pic.url, cacheWidth: 400)),
      ),
    );
  }
}
