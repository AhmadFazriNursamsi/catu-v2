import 'dart:convert';
import 'auth_http.dart' as http;
import 'api_service.dart';

class AssignableRomo {
  final int id;
  final String fullName;
  final String roleCode;
  final String affiliation;
  final bool local;
  const AssignableRomo({required this.id, required this.fullName, required this.roleCode, required this.affiliation, required this.local});

  bool get isOrdo => roleCode == 'ROMO_ORDO';
  String get roleLabel => isOrdo ? 'Romo Ordo' : 'Romo Paroki';

  factory AssignableRomo.fromJson(Map<String, dynamic> j) => AssignableRomo(
        id: (j['id'] as num).toInt(),
        fullName: j['fullName']?.toString() ?? '',
        roleCode: j['roleCode']?.toString() ?? '',
        affiliation: j['affiliation']?.toString() ?? '',
        local: j['local'] == true,
      );
}

class NamedOption {
  final int id;
  final String name;
  const NamedOption(this.id, this.name);
}

/// Pilihan formulir pendaftaran Romo: paroki se-keuskupan pelayanan, daftar ordo, dan paroki bawaan.
class RomoRegisterOptions {
  final List<NamedOption> parokis;
  final List<NamedOption> ordos;
  final int? defaultParokiId;
  const RomoRegisterOptions({required this.parokis, required this.ordos, this.defaultParokiId});

  factory RomoRegisterOptions.fromJson(Map<String, dynamic> j) {
    List<NamedOption> list(String key) => ((j[key] as List?) ?? const []).cast<Map>().map((e) => NamedOption((e['id'] as num).toInt(), e['name']?.toString() ?? '')).toList();
    return RomoRegisterOptions(parokis: list('parokis'), ordos: list('ordos'), defaultParokiId: (j['defaultParokiId'] as num?)?.toInt());
  }
}

/// Romo yang baru didaftarkan Koordinator, beserta kredensial sementara (hanya diberikan sekali oleh server).
class RegisteredRomo {
  final AssignableRomo romo;
  final String phoneNumber;
  final String temporaryPassword;
  /// Pelayanan otomatis diterima Romo baru; bila false, [assignError] berisi alasannya dan Romo dipilih manual.
  final bool assigned;
  final String? assignError;
  const RegisteredRomo({required this.romo, required this.phoneNumber, required this.temporaryPassword, this.assigned = false, this.assignError});

  factory RegisteredRomo.fromJson(Map<String, dynamic> j) => RegisteredRomo(
        romo: AssignableRomo.fromJson((j['romo'] as Map).cast<String, dynamic>()),
        phoneNumber: j['phoneNumber']?.toString() ?? '',
        temporaryPassword: j['temporaryPassword']?.toString() ?? '',
        assigned: j['assigned'] == true,
        assignError: j['assignError']?.toString(),
      );
}

class AssignableItem {
  final int id;
  final String name;
  final String schedule;
  const AssignableItem({required this.id, required this.name, required this.schedule});
}

/// Hasil `GET /orders/:id/koordinator-assignment`: apakah Koordinator boleh mencarikan Romo, dan daftar Romo terdaftar.
class KoordinatorAssignment {
  final bool eligible;
  /// OPEN (siap dicarikan Romo), WAITING (belum lewat batas menit), CLOSED (sudah diterima/ditutup).
  final String state;
  final String? reason;
  final String categoryName;
  final String orderNumber;
  final String summary;
  final List<AssignableItem> pendingItems;
  final List<AssignableRomo> romos;
  const KoordinatorAssignment({
    required this.eligible,
    this.state = 'OPEN',
    required this.reason,
    required this.categoryName,
    required this.orderNumber,
    required this.summary,
    required this.pendingItems,
    required this.romos,
  });

  /// Salinan dengan [romo] ditaruh paling atas (mis. Romo yang baru didaftarkan).
  KoordinatorAssignment withRomo(AssignableRomo romo) => KoordinatorAssignment(
        eligible: eligible,
        state: state,
        reason: reason,
        categoryName: categoryName,
        orderNumber: orderNumber,
        summary: summary,
        pendingItems: pendingItems,
        romos: [romo, ...romos.where((r) => r.id != romo.id)],
      );

  factory KoordinatorAssignment.fromJson(Map<String, dynamic> j) {
    final order = (j['order'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pendingIds = ((j['pendingItemIds'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();
    final items = ((order['items'] as List?) ?? const []).cast<Map>().where((i) => pendingIds.contains((i['id'] as num).toInt())).map((i) {
      final date = i['scheduledDate']?.toString() ?? '';
      final time = (i['scheduledTime']?.toString() ?? '').split(':').take(2).join(':');
      return AssignableItem(id: (i['id'] as num).toInt(), name: i['itemName']?.toString() ?? 'Misa', schedule: [date.split('T').first, time].where((e) => e.isNotEmpty).join(' • '));
    }).toList();
    final date = (order['scheduledDate']?.toString() ?? '').split('T').first;
    final time = (order['scheduledTime']?.toString() ?? '').split(':').take(2).join(':');
    return KoordinatorAssignment(
      eligible: j['eligible'] == true,
      state: j['state']?.toString() ?? (j['eligible'] == true ? 'OPEN' : 'CLOSED'),
      reason: j['reason']?.toString(),
      categoryName: order['categoryName']?.toString() ?? 'Pelayanan',
      orderNumber: order['orderNumber']?.toString() ?? '',
      summary: [date, time, order['locationName']?.toString() ?? ''].where((e) => e.isNotEmpty).join(' • '),
      pendingItems: items,
      romos: ((j['romos'] as List?) ?? const []).cast<Map>().map((r) => AssignableRomo.fromJson(r.cast<String, dynamic>())).toList(),
    );
  }
}

class KoordinatorAssignmentApi {
  static Future<KoordinatorAssignment> load(int orderId) async {
    final res = await http.get(Uri.parse('${ApiService.baseUrl}/orders/$orderId/koordinator-assignment'));
    if (res.statusCode != 200) throw Exception(_message(res.body) ?? 'Gagal memuat data (${res.statusCode})');
    return KoordinatorAssignment.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<RomoRegisterOptions> registerOptions(int orderId) async {
    final res = await http.get(Uri.parse('${ApiService.baseUrl}/orders/$orderId/koordinator-assignment/register-options'));
    if (res.statusCode != 200) throw Exception(_message(res.body) ?? 'Gagal memuat pilihan (${res.statusCode})');
    return RomoRegisterOptions.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Mendaftarkan Romo baru (langsung aktif); melempar Exception berisi pesan server bila ditolak.
  static Future<RegisteredRomo> registerRomo(int orderId, {required String fullName, required String phoneNumber, required String roleCode, int? parokiId, int? ordoId, int? itemId}) async {
    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/orders/$orderId/koordinator-assignment/register-romo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fullName': fullName, 'phoneNumber': phoneNumber, 'roleCode': roleCode, if (parokiId != null) 'parokiId': parokiId, if (ordoId != null) 'ordoId': ordoId, if (itemId != null) 'itemId': itemId}),
    );
    if (res.statusCode >= 300) throw Exception(_message(res.body) ?? 'Gagal mendaftarkan Romo (${res.statusCode})');
    return RegisteredRomo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Mengembalikan pesan sukses; melempar Exception berisi pesan server bila ditolak.
  static Future<String> assign(int orderId, {required int romoId, int? itemId}) async {
    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/orders/$orderId/koordinator-assignment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'romoId': romoId, if (itemId != null) 'itemId': itemId}),
    );
    if (res.statusCode >= 300) throw Exception(_message(res.body) ?? 'Gagal menetapkan Romo (${res.statusCode})');
    return (jsonDecode(res.body) as Map)['message']?.toString() ?? 'Romo berhasil ditetapkan.';
  }

  static String? _message(String body) {
    try {
      final m = (jsonDecode(body) as Map)['message'];
      return m is List ? m.join(', ') : m?.toString();
    } catch (_) {
      return null;
    }
  }
}
