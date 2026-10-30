import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catu_mobile/core/models/news_model.dart';
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
}
