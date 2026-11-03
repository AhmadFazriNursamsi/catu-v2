import 'package:flutter/material.dart';

/// Dialog tolak dengan alasan WAJIB (pendaftar membacanya untuk memperbaiki data).
/// Mengembalikan alasan yang sudah dipangkas, atau null bila dibatalkan.
Future<String?> askRejectionReason(BuildContext context, {required String title, required String message}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
        const SizedBox(height: 14),
        TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 500,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Alasan penolakan (wajib)',
            hintText: 'Contoh: Alamat belum lengkap / bukan warga lingkungan ini',
            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (c, v, w) => ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: v.text.trim().isEmpty ? null : () => Navigator.pop(ctx, v.text.trim()),
            child: const Text('Tolak'),
          ),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
