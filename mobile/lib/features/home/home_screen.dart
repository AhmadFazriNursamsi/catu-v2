import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../orders/create_order_screen.dart';
import '../chat/chat_screen.dart';
import '../auth/login_screen.dart';

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

  String _formatRoleDisplay(String roleCode, String? pengurusPos, String? romoPos) {
    if (roleCode == 'UMAT' || roleCode == 'PENGURUS_LINGKUNGAN' || roleCode == 'KOORDINATOR_KEUSKUPAN') {
      if (pengurusPos == 'KETUA') return 'Umat — Ketua Lingkungan';
      if (pengurusPos == 'WAKIL') return 'Umat — Wakil Ketua Lingkungan';
      if (pengurusPos == 'SEKRETARIS') return 'Umat — Sekretaris Lingkungan';
      return 'Umat (Anggota)';
    } else if (roleCode == 'ROMO_PAROKI') {
      if (romoPos == 'KETUA_ROMO') return 'Romo Paroki — Pastor Kepala';
      return 'Romo Paroki (Pastor Rekan)';
    } else if (roleCode == 'ROMO_ORDO') {
      if (romoPos == 'KETUA_ROMO') return 'Romo Ordo — Ketua Ordo';
      return 'Romo Ordo (Romo Ordo Biasa)';
    }
    return roleCode;
  }

  String _formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    if (phone.startsWith('62')) {
      return '+62 ${phone.substring(2)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final String roleCode = u['roleCode'] ?? u['role_code'] ?? u['role'] ?? 'UMAT';
    final String userName = u['fullName'] ?? u['full_name'] ?? 'Pengguna';
    final String phone = u['phoneNumber'] ?? u['phone_number'] ?? '';
    final String email = u['email'] ?? '';
    final String accountStatus = u['accountStatus'] ?? u['account_status'] ?? 'APPROVED';
    final String pengurusPosition = u['pengurusPosition'] ?? u['pengurus_position'] ?? '';
    final String romoPosition = u['romoPosition'] ?? u['romo_position'] ?? '';

    final String keuskupanName = u['keuskupanName'] ?? u['keuskupan_name'] ?? 'Keuskupan Agung Jakarta';
    final String parokiName = u['parokiName'] ?? u['paroki_name'] ?? 'Paroki Otista';
    final String lingkunganName = u['lingkunganName'] ?? u['lingkungan_name'] ?? 'Lingkungan St. Agnes 1';
    final String wilayahName = u['wilayahName'] ?? u['wilayah_name'] ?? '';

    final String formattedRole = _formatRoleDisplay(roleCode, pengurusPosition, romoPosition);
    final isApproved = accountStatus == 'APPROVED';

    return Scaffold(
      backgroundColor: AppConstants.bgCanvas,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryBlue,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/logoCatu.png',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                formattedRole,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadOrders,
          ),
          IconButton(
            tooltip: 'Keluar (Logout)',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // User Profile Card Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppConstants.primaryBlue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppConstants.accentGold,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  userName,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isApproved ? Colors.green.shade600 : Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isApproved ? 'APPROVED' : 'PENDING',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedRole,
                            style: const TextStyle(color: AppConstants.accentGold, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _formatPhone(phone),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.email_outlined, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Demographics & Location Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.church_outlined, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$parokiName • $lingkunganName (${keuskupanName})',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Header List Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Pelayanan & Monitoring',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textDark),
                ),
                if (roleCode == 'UMAT' || roleCode == 'PENGURUS_LINGKUNGAN' || roleCode == 'KOORDINATOR_KEUSKUPAN')
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ),

          // ListView Order Items
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
