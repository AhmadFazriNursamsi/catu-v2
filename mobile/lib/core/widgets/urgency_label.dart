import 'package:flutter/material.dart';

/// Tingkat urgensi dari nama yang tersimpan di server ("Standar"/"Biasa", "Penting", "Sangat Penting", "Darurat / Kritis").
enum UrgencyLevel { standar, penting, sangatPenting }

UrgencyLevel urgencyLevelOf(String? name) {
  final u = (name ?? '').toLowerCase();
  if (u.contains('sangat') || u.contains('darurat') || u.contains('kritis')) return UrgencyLevel.sangatPenting;
  if (u.contains('penting')) return UrgencyLevel.penting;
  return UrgencyLevel.standar;
}

/// Standar = biru, Penting = oranye, Sangat Penting = merah.
Color urgencyColorOf(String? name) => switch (urgencyLevelOf(name)) {
      UrgencyLevel.standar => const Color(0xFF1D4ED8),
      UrgencyLevel.penting => const Color(0xFFD97706),
      UrgencyLevel.sangatPenting => const Color(0xFFDC2626),
    };

/// Label singkat yang seragam di semua kartu, apa pun nama yang tersimpan di server.
String urgencyLabelOf(String? name) => switch (urgencyLevelOf(name)) {
      UrgencyLevel.standar => 'Standar',
      UrgencyLevel.penting => 'Penting',
      UrgencyLevel.sangatPenting => 'Sangat Penting',
    };

/// Label urgensi berwarna untuk kartu (Standar biru, Penting oranye, Sangat Penting merah).
class UrgencyLabel extends StatelessWidget {
  final String urgencyName;
  final double fontSize;
  const UrgencyLabel({super.key, required this.urgencyName, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final color = urgencyColorOf(urgencyName);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.25),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        urgencyLabelOf(urgencyName),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
