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

/// Ikon bendera berwarna sebagai pengganti teks urgensi di kartu. Nama urgensi tetap tersedia
/// sebagai tooltip dan label aksesibilitas.
class UrgencyFlag extends StatelessWidget {
  final String urgencyName;
  final double size;
  const UrgencyFlag({super.key, required this.urgencyName, this.size = 15});

  @override
  Widget build(BuildContext context) {
    final color = urgencyColorOf(urgencyName);
    return Tooltip(
      message: urgencyName,
      child: Semantics(
        label: 'Urgensi: $urgencyName',
        child: Container(
          padding: EdgeInsets.all(size * 0.38),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(Icons.flag_rounded, size: size, color: color),
        ),
      ),
    );
  }
}
