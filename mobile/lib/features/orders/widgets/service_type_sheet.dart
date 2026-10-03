import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Jenis pelayanan yang dipilih pengguna di sheet.
class ServiceType {
  final int id;
  final String name;
  const ServiceType({required this.id, required this.name});

  bool get isPerminyakan => id == 1 || name.toLowerCase().contains('perminyakan');
  bool get isKedukaan => id == 2 || name.toLowerCase().contains('kedukaan');

  IconData get icon => isPerminyakan ? Icons.volunteer_activism_rounded : (isKedukaan ? Icons.church_rounded : Icons.event_note_rounded);
  Color get color => isPerminyakan ? const Color(0xFF1E5399) : (isKedukaan ? const Color(0xFF0D9488) : const Color(0xFFD97706));
}

typedef CategoryLoader = Future<List<Map<String, dynamic>>> Function();

/// Sheet pemilih jenis pelayanan: hanya judul tiap pelayanan. [onSelected] dipanggil setelah sheet tertutup.
Future<void> showServiceTypeSheet(
  BuildContext context, {
  required Future<void> Function(ServiceType type) onSelected,
  CategoryLoader? loadCategories,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Text('Pilih Jenis Pelayanan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            const Text('Silakan pilih jenis sakramen / misa pelayanan yang Anda butuhkan', style: TextStyle(fontSize: 12.5, color: _muted, height: 1.3)),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: (loadCategories ?? ApiService.getServiceCategories)(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()));
                  }
                  final types = (snapshot.data ?? [])
                      .where((c) => c['is_active'] != false)
                      .map((c) => ServiceType(id: (c['id'] as num?)?.toInt() ?? 0, name: c['name']?.toString() ?? 'Pelayanan'))
                      .toList();
                  if (types.isEmpty) return const _EmptyServices();
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: types.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ServiceTile(
                      type: types[i],
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(types[i]);
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Center(child: Text('Versi Aplikasi: ${AppConstants.appVersion}', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    ),
  );
}

class _ServiceTile extends StatelessWidget {
  final ServiceType type;
  final VoidCallback onTap;
  const _ServiceTile({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: Icon(type.icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(type.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.2))),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 34, color: Color(0xFFCBD5E1)),
              SizedBox(height: 8),
              Text('Belum ada jenis pelayanan yang tersedia', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _muted)),
            ],
          ),
        ),
      );
}
