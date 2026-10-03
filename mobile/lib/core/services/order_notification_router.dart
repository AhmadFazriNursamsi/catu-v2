import 'package:flutter/material.dart';
import '../../features/orders/order_detail_screen.dart';
import 'api_service.dart';

/// Membuka detail pelayanan untuk notifikasi yang membawa `orderId`, langsung ke misa (`itemId`)
/// yang dimaksud. Mengembalikan false bila notifikasi tidak terkait order atau order tidak ditemukan,
/// sehingga pemanggil dapat jatuh ke daftar notifikasi.
Future<bool> openOrderFromNotification(
  NavigatorState nav, {
  required Map<String, dynamic> data,
  required String userName,
  required int? userId,
  required bool isRomo,
}) async {
  final orderId = int.tryParse('${data['orderId'] ?? data['order_id'] ?? ''}');
  if (orderId == null || orderId <= 0) return false;
  final itemId = int.tryParse('${data['itemId'] ?? data['item_id'] ?? ''}');

  final order = await ApiService.getOrderById(orderId);
  if (order == null || !nav.mounted) return false;

  await nav.push(
    MaterialPageRoute(
      builder: (_) => OrderDetailScreen(
        order: order,
        userName: userName,
        userId: userId,
        selectedItemId: itemId,
        isRomo: isRomo,
        romoId: isRomo ? userId : null,
      ),
    ),
  );
  return true;
}
