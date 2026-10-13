import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'kedukaan_hero.dart';

/// Pemilih foto almarhum pada form Misa Kedukaan: pratinjau berbingkai emas, ganti, dan hapus.
class DeceasedPhotoPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const DeceasedPhotoPicker({super.key, required this.value, required this.onChanged});

  static const _gold = Color(0xFFD4AF37);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      HapticFeedback.selectionClick();
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      onChanged('data:image/jpeg;base64,${base64Encode(bytes)}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memilih foto: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _chooseSource(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _ink),
            title: const Text('Pilih dari Galeri'),
            onTap: () {
              Navigator.pop(sheet);
              _pick(context, ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: _ink),
            title: const Text('Ambil dengan Kamera'),
            onTap: () {
              Navigator.pop(sheet);
              _pick(context, ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = value != null && value!.isNotEmpty;
    return Material(
      color: hasPhoto ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _chooseSource(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasPhoto ? _gold.withValues(alpha: 0.6) : const Color(0xFFCBD5E1),
              width: hasPhoto ? 1.4 : 1,
            ),
          ),
          child: Row(children: [
            _Avatar(url: hasPhoto ? value : null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hasPhoto ? 'Foto Almarhum/ah' : 'Tambah Foto Almarhum/ah',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 3),
                Text(
                  hasPhoto ? 'Foto ini akan tampil di halaman detail misa.' : 'Opsional · ketuk untuk memilih dari galeri atau kamera.',
                  style: const TextStyle(fontSize: 12, color: _muted, height: 1.3),
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _Action(icon: Icons.sync_rounded, label: 'Ganti', color: _ink, onTap: () => _chooseSource(context)),
                    _Action(icon: Icons.delete_outline_rounded, label: 'Hapus', color: Colors.red.shade600, onTap: () => onChanged(null)),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(36)),
        child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF1E5399), size: 28),
      );
    }
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5D77D), Color(0xFFB8860B)]),
      ),
      child: ClipOval(child: DeceasedPhoto(url: url)),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}
