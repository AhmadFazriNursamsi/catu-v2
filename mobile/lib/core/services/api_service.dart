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
      {'code': 'UMAT', 'label': 'Umat (Anggota)', 'category': 'Umat'},
      {'code': 'PENGURUS_LINGKUNGAN', 'label': 'Umat (Pengurus Lingkungan)', 'category': 'Umat'},
      {'code': 'KOORDINATOR_KEUSKUPAN', 'label': 'Umat (Koordinator Keuskupan)', 'category': 'Umat'},
      {'code': 'ROMO_PAROKI', 'label': 'Romo Paroki', 'category': 'Romo'},
      {'code': 'ROMO_ORDO', 'label': 'Romo Ordo', 'category': 'Romo'},
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
