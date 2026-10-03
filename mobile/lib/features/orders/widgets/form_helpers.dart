import 'package:flutter/material.dart';
import 'reschedule_validation.dart' show formatLongDate;

/// Kolom pilihan jam: berpartisipasi dalam Form (border + pesan merah saat tidak valid).
/// [validator] menerima nilai kosong; gunakan nilai terkini dari state layar, bukan argumennya.
class TimeFormField extends FormField<String> {
  TimeFormField({
    super.key,
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    super.validator,
    String placeholder = 'Pilih Jam',
  }) : super(
          initialValue: value,
          builder: (state) {
            final error = state.errorText;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: error != null ? Colors.red : const Color(0xFFCBD5E1), width: error != null ? 1.8 : 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: error != null ? Colors.red : const Color(0xFF1E5399), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            value ?? placeholder,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: value != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(error, style: const TextStyle(fontSize: 11.5, color: Colors.red, height: 1.3)),
                  ),
              ],
            );
          },
        );
}

/// Menggulir ke kolom Form pertama (dari atas) yang sedang menampilkan error.
void scrollToFirstFormError(BuildContext? formContext) {
  if (formContext == null) return;
  FormFieldState<dynamic>? first;
  void visit(Element element) {
    if (first != null) return;
    if (element is StatefulElement && element.state is FormFieldState && (element.state as FormFieldState).hasError) {
      first = element.state as FormFieldState;
      return;
    }
    element.visitChildren(visit);
  }

  (formContext as Element).visitChildren(visit);
  final target = first?.context;
  if (target != null) {
    Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.15, curve: Curves.easeOut);
  }
}

/// "18:30" + 60 menit = "19:30"; dibatasi sampai 23:59.
String plusMinutes(String hhmm, int minutes) {
  final parts = hhmm.split(':');
  final total = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0) + minutes;
  final capped = total > 23 * 60 + 59 ? 23 * 60 + 59 : total;
  return '${(capped ~/ 60).toString().padLeft(2, '0')}:${(capped % 60).toString().padLeft(2, '0')}';
}

/// Petunjuk di bawah kolom tanggal ("Minggu, 4 Oktober 2026") dari teks dd/mm/yyyy; kosong bila belum dipilih.
Widget dateHint(String ddmmyyyy) {
  final p = ddmmyyyy.split('/').map(int.tryParse).toList();
  if (p.length != 3 || p.contains(null)) return const SizedBox.shrink();
  final d = DateTime(p[2]!, p[1]!, p[0]!);
  // DateTime menormalkan tanggal mustahil (32/13 -> bulan berikutnya); tolak yang berubah.
  if (d.day != p[0] || d.month != p[1] || d.year != p[2]) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Row(
      children: [
        const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF0D9488)),
        const SizedBox(width: 5),
        Text(formatLongDate(d), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
      ],
    ),
  );
}
