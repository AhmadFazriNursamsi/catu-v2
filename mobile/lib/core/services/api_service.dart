import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/models.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:3005';
      }
      return 'http://127.0.0.1:3005';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:3005';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AppConstants.apiBaseUrl.isNotEmpty ? AppConstants.apiBaseUrl : 'http://10.0.2.2:3005';
    }
    return AppConstants.apiBaseUrl;
  }

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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {'statusCode': response.statusCode, 'message': 'Gagal Login: ${response.body}'};
      }
    } catch (e) {
      return {'statusCode': 500, 'message': 'Koneksi ke backend ($baseUrl) gagal: $e'};
    }
  }

  // 1a. Forgot Password: Request OTP
  static Future<Map<String, dynamic>> requestForgotPasswordOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal menghubungi server: $e'};
    }
  }

  // 1a-2. Forgot Password: Verify OTP
  static Future<Map<String, dynamic>> verifyForgotPasswordOtp(String phoneNumber, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'otpCode': otpCode,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal menghubungi server: $e'};
    }
  }

  // 1a-3. Forgot Password: Reset Password
  static Future<Map<String, dynamic>> resetPassword({
    required String phoneNumber,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'otpCode': otpCode,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal menghubungi server: $e'};
    }
  }

  // ── Pengurus Lingkungan Approval API Methods ──

  static Future<List<Map<String, dynamic>>> getPengurusPendingUmat({int? lingkunganId, int? pengurusUserId}) async {
    try {
      final queryParams = <String, String>{};
      if (lingkunganId != null) queryParams['lingkunganId'] = lingkunganId.toString();
      if (pengurusUserId != null) queryParams['pengurusUserId'] = pengurusUserId.toString();

      final uri = Uri.parse('$baseUrl/auth/pengurus/pending-umat').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('Error getPengurusPendingUmat: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> processPengurusApproval({
    required int targetUserId,
    required int approverUserId,
    required String action, // 'APPROVE' or 'REJECT'
    String? rejectionReason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/pengurus/process-approval'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'targetUserId': targetUserId,
          'approverUserId': approverUserId,
          'action': action,
          'rejectionReason': rejectionReason,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal memproses persetujuan: $e'};
    }
  }

  // ── Admin Dashboard API Methods ──

  static Future<Map<String, dynamic>> getAdminAnalytics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/admin/analytics')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getAdminAnalytics: $e');
    }
    return {'statusCode': 500, 'orders': {}, 'users': {}, 'categories': []};
  }

  static Future<List<Map<String, dynamic>>> getAdminUsers({String? role, String? status, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/auth/admin/users').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['users'] is List) {
          return List<Map<String, dynamic>>.from(data['users']);
        }
      }
    } catch (e) {
      print('Error getAdminUsers: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> updateAdminUserStatus(int userId, String status, {bool? isJabatanActive}) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (isJabatanActive != null) body['isJabatanActive'] = isJabatanActive;

      final response = await http.put(
        Uri.parse('$baseUrl/auth/admin/users/$userId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal update status: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateAdminUserRole(int userId, String roleCode) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/admin/users/$userId/role'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roleCode': roleCode}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal update role: $e'};
    }
  }

  static Future<Map<String, dynamic>> approveRegistration({
    required int targetUserId,
    required String action,
    String? rejectionReason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/approve-registration'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'targetUserId': targetUserId,
          'action': action,
          if (rejectionReason != null) 'rejectionReason': rejectionReason,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal memproses persetujuan: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateAdminOrderStatus(int orderId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/admin/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal update status order: $e'};
    }
  }

  static Future<Map<String, dynamic>> runUnitTests() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/test-runner/run-unit-tests')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error runUnitTests: $e');
    }
    return {'statusCode': 500, 'message': 'Gagal menjalankan unit tests'};
  }

  // 1b. Auth Register
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    required String roleCode,
    String? email,
    String? birthDate,
    String? address,
    int? keuskupanId,
    int? parokiId,
    int? wilayahId,
    int? lingkunganId,
    int? kabupatenKotaId,
    int? ordoId,
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
      };

      if (email != null && email.isNotEmpty) payload['email'] = email;
      if (birthDate != null && birthDate.isNotEmpty) payload['birthDate'] = birthDate;
      if (address != null && address.isNotEmpty) payload['address'] = address;
      if (keuskupanId != null) payload['keuskupanId'] = keuskupanId;
      if (parokiId != null) payload['parokiId'] = parokiId;
      if (wilayahId != null) payload['wilayahId'] = wilayahId;
      if (lingkunganId != null) payload['lingkunganId'] = lingkunganId;
      if (kabupatenKotaId != null) payload['kabupatenKotaId'] = kabupatenKotaId;
      if (ordoId != null) payload['ordoId'] = ordoId;

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
  static Future<List<Map<String, dynamic>>> getKeuskupan() => getKeuskupanList();
  static Future<List<Map<String, dynamic>>> getParoki({int? keuskupanId}) => getParokiList(keuskupanId: keuskupanId);
  static Future<List<Map<String, dynamic>>> getWilayah({int? parokiId}) => getWilayahList(parokiId: parokiId);
  static Future<List<Map<String, dynamic>>> getLingkungan({int? wilayahId}) => getLingkunganList(wilayahId: wilayahId);
  static Future<List<Map<String, dynamic>>> getOrdo() => getOrdoList();
  static Future<List<Map<String, dynamic>>> getProvinsi() => getProvinsiList();
  static Future<List<Map<String, dynamic>>> getKabupatenKota({int? provinsiId}) => getKabupatenKotaList(provinsiId: provinsiId);

  static Future<List<Map<String, dynamic>>> getProvinsiList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/provinsi'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getProvinsiList: $e');
    }
    return [
      {'id': 31, 'name': 'DKI JAKARTA'},
      {'id': 36, 'name': 'BANTEN'},
    ];
  }

  static Future<List<Map<String, dynamic>>> getKabupatenKotaList({int? provinsiId}) async {
    try {
      final url = provinsiId != null ? '$baseUrl/auth/kabupaten-kota?provinsiId=$provinsiId' : '$baseUrl/auth/kabupaten-kota';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getKabupatenKotaList: $e');
    }
    return [
      {'id': 3175, 'provinsi_id': 31, 'name': 'JAKARTA TIMUR', 'type': 'KOTA'},
      {'id': 3173, 'provinsi_id': 31, 'name': 'JAKARTA PUSAT', 'type': 'KOTA'},
    ];
  }

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

  // 2. Fetch Orders - filtered by userId for Umat, parokiId/romoId/kabupatenKotaId for Romo
  static Future<List<Order>> getOrders({int? userId, int? parokiId, int? romoId, int? kabupatenKotaId}) async {
    try {
      String url = '$baseUrl/orders';
      final params = <String>[];
      if (userId != null) params.add('userId=$userId');
      if (parokiId != null) params.add('parokiId=$parokiId');
      if (romoId != null) params.add('romoId=$romoId');
      if (kabupatenKotaId != null) params.add('kabupatenKotaId=$kabupatenKotaId');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getOrders: $e');
    }
    return [];
  }

  // 2b. Fetch Single Order by ID
  static Future<Order?> getOrderById(int orderId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/orders/$orderId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['id'] != null) {
          return Order.fromJson(data);
        }
      }
    } catch (e) {
      print('Error getOrderById: $e');
    }
    try {
      final orders = await getOrders();
      for (final o in orders) {
        if (o.id == orderId) return o;
      }
    } catch (_) {}
    return null;
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
    String? attachmentUrl,
    List<OrderItem>? items,
    int? userId,
    int? keuskupanId,
    int? parokiId,
    int? wilayahId,
    int? lingkunganId,
    int? kabupatenKotaId,
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
        if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachmentUrl': attachmentUrl,
        if (userId != null) 'userId': userId,
        if (keuskupanId != null) 'keuskupanId': keuskupanId,
        if (parokiId != null) 'parokiId': parokiId,
        if (wilayahId != null) 'wilayahId': wilayahId,
        if (lingkunganId != null) 'lingkunganId': lingkunganId,
        if (kabupatenKotaId != null) 'kabupatenKotaId': kabupatenKotaId,
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
  static Future<Map<String, dynamic>> respondAssignment(int orderId, String status, {int? romoId, int? itemId}) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (romoId != null) body['romoId'] = romoId;
      if (itemId != null) body['itemId'] = itemId;
      final response = await http.post(
        Uri.parse('$baseUrl/assignments/$orderId/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Gagal update status penugasan Romo'};
    }
  }

  // 4.1. Romo Propose Reschedule
  static Future<Map<String, dynamic>> proposeReschedule(
    int orderId, {
    required int romoId,
    int? itemId,
    String? newDate,
    required String newTimeStart,
    String? newTimeEnd,
    required String reason,
  }) async {
    try {
      final body = <String, dynamic>{
        'romoId': romoId,
        'newTimeStart': newTimeStart,
        'reason': reason,
      };
      if (itemId != null) body['itemId'] = itemId;
      if (newDate != null && newDate.isNotEmpty) body['newDate'] = newDate;
      if (newTimeEnd != null && newTimeEnd.isNotEmpty) body['newTimeEnd'] = newTimeEnd;

      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/reschedule/propose'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal mengajukan perubahan jadwal: $e'};
    }
  }

  // 4.2. Umat Respond Reschedule (ACCEPT / REJECT)
  static Future<Map<String, dynamic>> respondReschedule(
    int orderId, {
    required int userId,
    int? itemId,
    required String action,
  }) async {
    try {
      final body = <String, dynamic>{
        'userId': userId,
        'action': action,
      };
      if (itemId != null) body['itemId'] = itemId;

      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/reschedule/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal merespon perubahan jadwal: $e'};
    }
  }

  // 4c. Fetch Available Romo list for Handover
  static Future<List<Map<String, dynamic>>> getAvailableRomos({int? parokiId}) async {
    try {
      final url = parokiId != null
          ? '$baseUrl/orders/available-romos?parokiId=$parokiId'
          : '$baseUrl/orders/available-romos';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      print('Error getAvailableRomos: $e');
    }
    return [];
  }

  // 4d. Romo Handover / Ganti Romo
  static Future<Map<String, dynamic>> handoverServiceOrder(
    int orderId, {
    required int romoId,
    int? itemId,
    int? targetRomoId,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/handover'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'romoId': romoId,
          if (itemId != null) 'itemId': itemId,
          if (targetRomoId != null && targetRomoId > 0) 'targetRomoId': targetRomoId,
          'reason': reason,
        }),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'statusCode': response.statusCode, 'message': 'Berhasil memproses pengalihan romo.'};
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal melakukan pengalihan romo: $e'};
    }
  }

  // 4e. Respond to Handover (Accept / Reject)
  static Future<Map<String, dynamic>> respondHandoverServiceOrder(
    int orderId, {
    required int romoId,
    int? itemId,
    required String action, // 'ACCEPT' | 'REJECT'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/handover/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'romoId': romoId,
          if (itemId != null) 'itemId': itemId,
          'action': action,
        }),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'statusCode': response.statusCode, 'message': 'Berhasil merespon pengalihan tugas.'};
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal merespon pengalihan tugas: $e'};
    }
  }

  // 4f. Notifications from Backend PostgreSQL
  static Future<List<Map<String, dynamic>>> getNotifications({int? userId, String? role}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null) queryParams['userId'] = userId.toString();
      if (role != null) queryParams['role'] = role;
      final uri = Uri.parse('$baseUrl/notifications').replace(queryParameters: queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      print('Error getNotifications: $e');
    }
    return [];
  }

  static Future<void> markNotificationRead(int id) async {
    try {
      await http.post(Uri.parse('$baseUrl/notifications/$id/read'));
    } catch (_) {}
  }

  static Future<void> markAllNotificationsRead(int userId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
    } catch (_) {}
  }

  static Future<void> deleteNotification(int id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/notifications/$id'));
    } catch (_) {}
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
  static Future<Map<String, dynamic>> sendChatMessage(int groupId, String messageType, String message, {int? senderId, String? attachmentUrl}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/groups/$groupId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': senderId ?? 1,
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

  // 7. Fetch User Chat Groups
  static Future<List<ChatGroupItem>> getChatGroups(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/user/$userId/groups'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.map((json) => ChatGroupItem.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Error getChatGroups: $e');
    }
    return [];
  }

  // 7b. Fetch Chat Group ID for Order
  static Future<int> getChatGroupIdForOrder(int orderId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/order/$orderId'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final raw = data['groupId'];
        return raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? orderId;
      }
    } catch (e) {
      print('Error getChatGroupIdForOrder: $e');
    }
    return orderId;
  }

  // 8. Fetch Chat Group Members
  static Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/groups/$groupId/members'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error getGroupMembers: $e');
    }
    return [];
  }

  // ── Romo Approval System (Kepala Romo Paroki & Ketua Romo Ordo) ──
  static Future<List<Map<String, dynamic>>> getPendingRomoList({
    int? romoUserId,
    int? parokiId,
    int? ordoId,
  }) async {
    try {
      final queryParams = <String>[];
      if (romoUserId != null) queryParams.add('romoUserId=$romoUserId');
      if (parokiId != null) queryParams.add('parokiId=$parokiId');
      if (ordoId != null) queryParams.add('ordoId=$ordoId');

      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final response = await http.get(Uri.parse('$baseUrl/auth/romo/pending-romo$queryString'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print('Error getPendingRomoList: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> processRomoApproval({
    required int targetUserId,
    required int approverUserId,
    required String action,
    String? rejectionReason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/romo/process-approval'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'targetUserId': targetUserId,
          'approverUserId': approverUserId,
          'action': action,
          if (rejectionReason != null) 'rejectionReason': rejectionReason,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'statusCode': 500, 'message': 'Gagal memproses persetujuan romo: $e'};
    }
  }
}
