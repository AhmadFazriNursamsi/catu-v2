import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/models/news_model.dart';
import 'package:catu_mobile/features/news/news_content.dart';
import 'package:catu_mobile/features/news/news_filters.dart';

void main() {
  testWidgets('chip kategori memanggil onSelected dengan slug', (tester) async {
    String? picked;
    final cats = [
      NewsCategory(id: 0, name: 'Semua', slug: 'semua', description: '', iconName: 'newspaper', displayOrder: 0),
      NewsCategory(id: 1, name: 'Liturgi', slug: 'liturgi', description: '', iconName: 'church', displayOrder: 1),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NewsCategoryChips(categories: cats, selectedSlug: 'semua', onSelected: (s) => picked = s)),
    ));
    await tester.tap(find.text('Liturgi'));
    expect(picked, 'liturgi');
  });

  testWidgets('kolom cari meneruskan teks ketikan', (tester) async {
    String typed = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NewsSearchField(controller: TextEditingController(), hasQuery: false, onChanged: (v) => typed = v)),
    ));
    await tester.enterText(find.byType(TextField), 'paus');
    expect(typed, 'paus');
  });

  testWidgets('isi artikel: entitas terbaca, daftar & judul tampil, sisa "Read more" dibuang', (tester) async {
    const html = '<p><strong>Bacaan I &#8211; Flp 3:3-8a</strong></p>\n\n<p>Karena kitalah  orang\nbersunat &amp; beriman.</p>'
        '<h3>Renungan</h3><ul><li>Satu</li><li>Dua</li></ul><blockquote><p>Kutipan</p></blockquote><p>Read more</p><p>&nbsp;</p>';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: NewsContent(html: html)))));
    expect(find.textContaining('Bacaan I – Flp 3:3-8a', findRichText: true), findsOneWidget);
    expect(find.textContaining('kitalah orang bersunat & beriman.', findRichText: true), findsOneWidget);
    expect(find.text('Renungan', findRichText: true), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('Kutipan', findRichText: true), findsOneWidget);
    expect(find.textContaining('Read more', findRichText: true), findsNothing);
  });
}
