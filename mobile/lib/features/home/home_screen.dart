import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../orders/create_order_screen.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await ApiService.getOrders();
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.user['role_code'] ?? widget.user['role'] ?? 'UMAT';
    final String userName = widget.user['full_name'] ?? widget.user['fullName'] ?? 'Pengguna';

    return Scaffold(
      backgroundColor: AppConstants.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryBlue,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/images/logoCatu.png',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text('— $role', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadOrders,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppConstants.primaryBlue,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppConstants.accentGold,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status Akun: ${widget.user['account_status'] ?? 'APPROVED'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Pelayanan & Monitoring',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textDark),
                ),
                if (role == 'UMAT')
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateOrderScreen()),
                      );
                      _loadOrders();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    label: const Text('Buat Order', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.accentGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text('Belum ada pesanan pelayanan.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1.5,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        order.orderNumber,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryBlue),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: order.status == 'ACCEPTED' ? Colors.green.shade100 : Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          order.status,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: order.status == 'ACCEPTED' ? Colors.green.shade800 : Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    order.categoryName,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: AppConstants.textMuted),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          order.locationName,
                                          style: const TextStyle(fontSize: 13, color: AppConstants.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Pemohon: ${order.pemohonName}',
                                        style: const TextStyle(fontSize: 12, color: AppConstants.textMuted),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                groupId: order.id,
                                                orderNumber: order.orderNumber,
                                                userName: userName,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.chat_rounded, size: 16),
                                        label: const Text('Buka Chat WA'),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
