import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = AppConstants.apiBaseUrl;

  // 1. Auth Login
  static Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {'statusCode': response.statusCode, 'message': 'Gagal Login'};
      }
    } catch (e) {
      return {'statusCode': 500, 'message': 'Koneksi ke backend NestJS gagal'};
    }
  }

  // 1b. Auth Register
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    required String roleCode,
    String? pengurusPosition,
    String? romoPosition,
    int? jabatanStartYear,
    int? jabatanEndYear,
    String? jabatanStartDate,
    String? jabatanEndDate,
    bool? isJabatanActive,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'password': password,
        'roleCode': roleCode,
        'keuskupanId': 1,
        'parokiId': 10,
        'wilayahId': 101,
        'lingkunganId': 1001,
      };

      if (pengurusPosition != null && pengurusPosition.isNotEmpty) {
        payload['pengurusPosition'] = pengurusPosition;
      }
      if (romoPosition != null && romoPosition.isNotEmpty) {
        payload['romoPosition'] = romoPosition;
      }
      if (jabatanStartYear != null) {
        payload['jabatanStartYear'] = jabatanStartYear;
      }
      if (jabatanEndYear != null) {
        payload['jabatanEndYear'] = jabatanEndYear;
      }
      if (jabatanStartDate != null && jabatanStartDate.isNotEmpty) {
        payload['jabatanStartDate'] = jabatanStartDate;
      }
      if (jabatanEndDate != null && jabatanEndDate.isNotEmpty) {
        payload['jabatanEndDate'] = jabatanEndDate;
      }
      if (isJabatanActive != null) {
        payload['isJabatanActive'] = isJabatanActive;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Koneksi ke backend NestJS gagal'};
    }
  }

  // 1c. Fetch Roles Dynamically from Backend DB
  static Future<List<Map<String, String>>> getRoles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/roles'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          'code': item['code'].toString(),
          'label': item['name'].toString(),
          'category': (item['category'] ?? 'Umat').toString(),
        }).toList();
      }
    } catch (e) {
      print('Error getRoles: $e');
    }
    return [
      {'code': 'UMAT', 'label': 'Umat', 'category': 'Umat'},
      {'code': 'ROMO_PAROKI', 'label': 'Romo Paroki', 'category': 'Romo'},
      {'code': 'ROMO_ORDO', 'label': 'Romo Ordo', 'category': 'Romo'},
    ];
  }

  // 1d. Dynamic DB Master Data methods
  static Future<List<Map<String, dynamic>>> getKeuskupanList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/keuskupan'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getKeuskupanList: $e');
    }
    return [
      {'id': 1, 'name': 'Keuskupan Agung Jakarta'},
      {'id': 2, 'name': 'Keuskupan Agung Semarang'},
      {'id': 3, 'name': 'Keuskupan Bandung'},
      {'id': 4, 'name': 'Keuskupan Bogor'},
      {'id': 5, 'name': 'Keuskupan Surabaya'},
    ];
  }

  static Future<List<Map<String, dynamic>>> getParokiList({int? keuskupanId}) async {
    try {
      final url = keuskupanId != null ? '$baseUrl/auth/paroki?keuskupanId=$keuskupanId' : '$baseUrl/auth/paroki';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getParokiList: $e');
    }
    return [
      {'id': 10, 'keuskupan_id': 1, 'name': 'Paroki Santo Antonius Padua - Otista'},
      {'id': 11, 'keuskupan_id': 1, 'name': 'Paroki Katedral Jakarta'},
      {'id': 12, 'keuskupan_id': 1, 'name': 'Paroki Santo Joseph - Matraman'},
      {'id': 13, 'keuskupan_id': 1, 'name': 'Paroki Santa Monika - BSD'},
    ];
  }

  static Future<List<Map<String, dynamic>>> getWilayahList({int? parokiId}) async {
    try {
      final url = parokiId != null ? '$baseUrl/auth/wilayah?parokiId=$parokiId' : '$baseUrl/auth/wilayah';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getWilayahList: $e');
    }
    return [
      {'id': 101, 'paroki_id': 10, 'name': 'Wilayah St. Agustinus'},
      {'id': 102, 'paroki_id': 10, 'name': 'Wilayah St. Ignatius Loyola'},
      {'id': 103, 'paroki_id': 10, 'name': 'Wilayah St. Franciscus Xaverius'},
    ];
  }

  static Future<List<Map<String, dynamic>>> getLingkunganList({int? wilayahId}) async {
    try {
      final url = wilayahId != null ? '$baseUrl/auth/lingkungan?wilayahId=$wilayahId' : '$baseUrl/auth/lingkungan';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getLingkunganList: $e');
    }
    return [
      {'id': 1001, 'wilayah_id': 101, 'name': 'Lingkungan St. Agnes 1'},
      {'id': 1002, 'wilayah_id': 101, 'name': 'Lingkungan St. Agnes 2'},
      {'id': 1003, 'wilayah_id': 101, 'name': 'Lingkungan St. Bernadette'},
    ];
  }

  static Future<List<Map<String, dynamic>>> getOrdoList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/ordo'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getOrdoList: $e');
    }
    return [
      {'id': 1, 'code': 'SJ', 'name': 'SJ - Serikat Yesus (Jesuit)'},
      {'id': 2, 'code': 'OFM', 'name': 'OFM - Fransiskan'},
      {'id': 3, 'code': 'OFM Cap', 'name': 'OFM Cap - Fransiskan Kapusin'},
      {'id': 4, 'code': 'MSF', 'name': 'MSF - Misionaris Keluarga Kudus'},
      {'id': 5, 'code': 'SVD', 'name': 'SVD - Serikat Sabda Allah'},
      {'id': 6, 'code': 'CSsR', 'name': 'CSsR - Kongregasi Sang Penebus'},
    ];
  }

  // 2. Fetch Active Orders List
  static Future<List<Order>> getOrders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/orders'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getOrders: $e');
    }
    return [];
  }

  // 3. Create Order Pelayanan / Misa Kedukaan
  static Future<Map<String, dynamic>> createOrder({
    required int serviceCategoryId,
    required int urgencyLevelId,
    required String scheduledDate,
    required String scheduledTime,
    required String locationName,
    required String addressDetail,
    String? notes,
    List<OrderItem>? items,
  }) async {
    try {
      final body = {
        'serviceCategoryId': serviceCategoryId,
        'urgencyLevelId': urgencyLevelId,
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime,
        'locationName': locationName,
        'addressDetail': addressDetail,
        'notes': notes ?? '',
        if (items != null && items.isNotEmpty)
          'items': items.map((i) => i.toJson()).toList(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Gagal terhubung ke server backend NestJS'};
    }
  }

  // 4. Romo Respond Assignment (ACCEPT / DECLINE)
  static Future<Map<String, dynamic>> respondAssignment(int orderId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/assignments/$orderId/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Gagal update status penugasan Romo'};
    }
  }

  // 5. Fetch WhatsApp Group Messages
  static Future<List<ChatMessage>> getGroupMessages(int groupId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/groups/$groupId/messages'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChatMessage.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getGroupMessages: $e');
    }
    return [];
  }

  // 6. Send WhatsApp Group Message
  static Future<Map<String, dynamic>> sendChatMessage(int groupId, String messageType, String message, {String? attachmentUrl}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/groups/$groupId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messageType': messageType,
          'message': message,
          'attachmentUrl': attachmentUrl,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Gagal mengirim pesan chat'};
    }
  }
}
