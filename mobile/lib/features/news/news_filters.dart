import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/news_model.dart';

class NewsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;

  const NewsSearchField({super.key, required this.controller, required this.hasQuery, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: 'Cari warta Katolik, Paus, renungan…',
        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 21),
        suffixIcon: hasQuery
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F4F8),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class NewsCategoryChips extends StatelessWidget {
  final List<NewsCategory> categories;
  final String selectedSlug;
  final ValueChanged<String> onSelected;

  const NewsCategoryChips({super.key, required this.categories, required this.selectedSlug, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = cat.slug == selectedSlug;
          return GestureDetector(
            onTap: () => onSelected(cat.slug),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppConstants.primaryBlue : const Color(0xFFF1F4F8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                cat.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
