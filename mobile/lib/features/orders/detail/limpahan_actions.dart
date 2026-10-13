import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_http.dart' as http;

/// Romo limpahan: Romo yang menerima pelayanan lewat pelimpahan. Ia tidak dapat mengajukan ubah jam;
/// bila berhalangan, ia membatalkan pelayanan (dengan alasan wajib).

const _red = Color(0xFFDC2626);
const _maxReason = 500;

/// [romoId] menerima pelayanan/misa [item] (atau seluruh order) lewat pelimpahan dan kini bertugas.
bool isRomoLimpahan(Order order, OrderItem? item, int? romoId) {
  if (romoId == null) return false;
  final perItem = order.items.isNotEmpty && item != null;
  final assigned = perItem ? item.acceptedRomoId : order.acceptedRomoId;
  if (assigned != romoId) return false;
  return order.handoverHistory.any((h) =>
      h.status.toUpperCase() == 'ACCEPTED' &&
      h.newRomoId == romoId &&
      (!perItem || h.itemId == null || h.itemId == item.id));
}

/// Mengirim pembatalan; mengembalikan pesan galat, atau null bila berhasil.
Future<String?> cancelServiceByRomo({required int orderId, int? itemId, required int romoId, required String reason}) async {
  try {
    final res = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/orders/$orderId/cancel-by-romo'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'romoId': romoId, if (itemId != null) 'itemId': itemId, 'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) return null;
    final data = jsonDecode(res.body);
    final msg = data is Map ? data['message'] : null;
    return (msg is List ? msg.join('\n') : msg ?? 'Pelayanan gagal dibatalkan.').toString();
  } catch (e) {
    return 'Koneksi ke server gagal. Periksa jaringan lalu coba lagi.';
  }
}

/// Form alasan pembatalan. Mengembalikan alasan bila Romo mengonfirmasi, atau null bila batal.
Future<String?> showRomoCancelSheet(BuildContext context, {required String serviceName}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancelSheet(serviceName: serviceName),
  );
}

class _CancelSheet extends StatefulWidget {
  final String serviceName;
  const _CancelSheet({required this.serviceName});

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _ctrl = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _attempted = true);
    if (_ctrl.text.trim().isEmpty) return;
    Navigator.pop(context, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final error = _attempted && _ctrl.text.trim().isEmpty ? 'Alasan pembatalan wajib diisi.' : null;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.event_busy_rounded, color: _red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Batalkan Pelayanan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppConstants.textDark)),
                Text(widget.serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Anda menerima pelayanan ini lewat pelimpahan, sehingga jam tidak dapat diubah. '
              'Bila Anda berhalangan, pelayanan akan dibatalkan sepenuhnya: Umat dan pengurus diberi tahu beserta alasannya, '
              'dan Umat perlu mengajukan ulang bila masih membutuhkan pelayanan. Tindakan ini tidak dapat diurungkan.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B), height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Alasan pembatalan', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppConstants.textDark)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            maxLength: _maxReason,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Contoh: Sakit mendadak dan tidak dapat hadir',
              errorText: error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _red, width: 1.6)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Ya, Batalkan Pelayanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali'))),
        ]),
      ),
    );
  }
}

/// Aksi bawah Romo limpahan: Chat Grup, Batalkan, Selesaikan (tanpa Ubah Jam).
class LimpahanBottomActions extends StatelessWidget {
  final VoidCallback onChat, onCancel;
  final VoidCallback? onComplete;
  final bool submitting;
  const LimpahanBottomActions({super.key, required this.onChat, required this.onCancel, required this.onComplete, required this.submitting});

  Widget _button({required Color color, required IconData icon, required String label, VoidCallback? onTap, bool outlined = false}) {
    return Material(
      color: outlined ? Colors.white : color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: outlined ? BorderSide(color: color, width: 1.4) : BorderSide.none),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: outlined ? color : Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: TextStyle(color: outlined ? color : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(flex: 3, child: _button(color: AppConstants.primaryBlue, icon: Icons.chat_bubble_outline_rounded, label: 'Chat', onTap: onChat)),
      const SizedBox(width: 8),
      Expanded(flex: 3, child: _button(color: _red, icon: Icons.event_busy_rounded, label: 'Batalkan', onTap: submitting ? null : onCancel, outlined: true)),
      const SizedBox(width: 8),
      Expanded(
        flex: 4,
        child: _button(color: const Color(0xFF059669), icon: Icons.check_circle_rounded, label: 'Selesaikan', onTap: submitting ? null : onComplete),
      ),
    ]);
  }
}

/// Catatan pembatalan oleh Romo limpahan untuk [item] (atau seluruh order); null bila tidak dibatalkan Romo.
OrderRomoHandover? romoCancellationOf(Order order, OrderItem? item) {
  final perItem = order.items.isNotEmpty && item != null;
  for (final h in order.handoverHistory) {
    if (h.handoverType.toUpperCase() != 'CANCELLED_BY_ROMO') continue;
    if (!perItem || h.itemId == null || h.itemId == item.id) return h;
  }
  return null;
}

/// Kartu keterangan bahwa pelayanan dibatalkan oleh Romo limpahan, beserta alasannya.
class RomoCancelledCard extends StatelessWidget {
  final OrderRomoHandover cancellation;
  final bool isRomo;
  const RomoCancelledCard({super.key, required this.cancellation, required this.isRomo});

  @override
  Widget build(BuildContext context) {
    final reason = cancellation.reason.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.event_busy_rounded, color: _red, size: 22),
          SizedBox(width: 8),
          Expanded(child: Text('Pelayanan Dibatalkan Romo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)))),
        ]),
        const SizedBox(height: 8),
        Text(
          'Romo ${cancellation.previousRomoName} (Romo limpahan) membatalkan pelayanan ini.',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7F1D1D)),
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Alasan: "$reason"', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Color(0xFF991B1B))),
        ],
        if (!isRomo) ...[
          const SizedBox(height: 8),
          const Text('Silakan ajukan pelayanan baru bila masih membutuhkan.', style: TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D))),
        ],
      ]),
    );
  }
}
