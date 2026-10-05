import 'package:flutter/material.dart';

/// Pilihan jenis kelamin (L/P) yang ikut validasi Form: border dan pesan merah bila belum dipilih.
class GenderFormField extends FormField<String> {
  GenderFormField({
    super.key,
    required String? value,
    required ValueChanged<String> onChanged,
    String requiredMessage = 'Pilih jenis kelamin',
  }) : super(
          initialValue: value,
          validator: (v) => (v ?? value) == null ? requiredMessage : null,
          builder: (state) {
            final error = state.errorText;
            Widget option(String code, String label, IconData icon) {
              final selected = value == code;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    onChanged(code);
                    state.didChange(code);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1E5399).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: error != null && !selected ? Colors.red : (selected ? const Color(0xFF1E5399) : const Color(0xFFCBD5E1)),
                        width: selected || error != null ? 1.8 : 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 19, color: selected ? const Color(0xFF1E5399) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF1E5399) : const Color(0xFF334155)))),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jenis Kelamin', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                Row(children: [option('L', 'Laki-laki', Icons.male_rounded), const SizedBox(width: 12), option('P', 'Perempuan', Icons.female_rounded)]),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: Text(error, style: const TextStyle(fontSize: 11.5, color: Colors.red, height: 1.3))),
              ],
            );
          },
        );
}
