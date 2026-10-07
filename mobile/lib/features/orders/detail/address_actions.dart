import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tombol "Buka Peta" dan "Salin Alamat" di bawah alamat pelayanan.
class AddressActions extends StatelessWidget {
  final String address;
  final Color color;
  const AddressActions({super.key, required this.address, required this.color});

  Future<void> _openMap(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka aplikasi peta')));
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alamat disalin')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (address.trim().isEmpty || address.trim() == '-') return const SizedBox.shrink();
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _openMap(context),
            icon: const Icon(Icons.map_rounded, size: 18),
            label: const Text('Buka Peta'),
            style: FilledButton.styleFrom(
                backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 12), shape: shape),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Salin Alamat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: shape,
            ),
          ),
        ),
      ]),
    );
  }
}
