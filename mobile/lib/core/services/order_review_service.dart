import 'dart:convert';
import 'auth_http.dart' as http;
import '../constants/app_constants.dart';

class OrderReviewService {
  static String get baseUrl => AppConstants.apiBaseUrl;

  /// Submit review notes for an order or order item
  static Future<Map<String, dynamic>> submitReview(
    int orderId, {
    int? userId,
    int? itemId,
    required String reviewNotes,
    int? rating,
  }) async {
    try {
      final body = <String, dynamic>{
        'reviewNotes': reviewNotes.trim(),
      };
      if (rating != null) body['rating'] = rating;
      if (userId != null) body['userId'] = userId;
      if (itemId != null) body['itemId'] = itemId;

      final response = await http.post(
        Uri.parse('$baseUrl/orders/$orderId/review'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      } else {
        return {
          'success': false,
          'message': decoded is Map ? (decoded['message'] ?? 'Gagal mengirim ulasan') : 'Gagal mengirim ulasan',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan koneksi: $e'};
    }
  }
}
