import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/widgets/liquid_bottom_nav_bar.dart';

class RomoDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Order> orders;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const RomoDashboardView({
    Key? key,
    required this.user,
    required this.orders,
    required this.onRefresh,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<RomoDashboardView> createState() => _RomoDashboardViewState();
}

class _RomoDashboardViewState extends State<RomoDashboardView> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final String userName = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Romo Samuel';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Header with Name & Notification Badges ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Hi, $userName',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        // Bell Notification Icon with Badge '1'
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E5399), size: 26),
                              onPressed: () {},
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: const Text(
                                  '1',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        // Mail Notification Icon with Badge '2'
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF1E5399), size: 26),
                              onPressed: () {},
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                child: const Text(
                                  '2',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 2. Header Cross Banner ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      'assets/images/cross_banner.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // ── 3. Spiritual Quote ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                child: Column(
                  children: const [
                    Text(
                      '" Sungguh, Allah itu keselamatanku; aku percaya dengan tidak gementar, sebab Tuhan Allah itu kekuatanku dan mazmurku, Ia telah menjadi keselamatanku. "',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '- Yesaya 12:2 -',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 4. Section 1: Jadwal Pelayanan Hari Ini ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 180,
                          child: Text(
                            'Jadwal\nPelayanan\nHari Ini',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5399),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat Lainnya',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sunday, 6 March 2023',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Horizontal Cards for "Jadwal Pelayanan Hari Ini"
              SizedBox(
                height: 230,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildServiceCard(
                      statusBadge: 'Kehadiran Dikonfirmasi',
                      isConfirmed: true,
                      location: 'GMAHK Jehovah-Jireh BSD',
                      dateTime: 'Sunday, 6/3/23 - 11:00',
                      category: 'Acara Keagamaan',
                      priorityLabel: 'Penting',
                      priorityColor: Colors.amber.shade800,
                      priorityIcon: Icons.error_outline_rounded,
                      userPhoto: null,
                      onTapChat: () {},
                    ),
                    const SizedBox(width: 14),
                    _buildServiceCard(
                      statusBadge: 'Kehadiran Dikonfirmasi',
                      isConfirmed: true,
                      location: 'GKY BSD',
                      dateTime: 'Sunday, 5/3/23 - 15:30',
                      category: 'Acara Keagamaan',
                      priorityLabel: 'Standar',
                      priorityColor: Colors.blue.shade700,
                      priorityIcon: Icons.info_outline_rounded,
                      userPhoto: null,
                      onTapChat: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── 5. Section 2: Daftar Permintaan Pelayanan ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 180,
                      child: Text(
                        'Daftar\nPermintaan\nPelayanan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5399),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat Lainnya',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Horizontal Cards for "Daftar Permintaan Pelayanan"
              SizedBox(
                height: 230,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildServiceCard(
                      statusBadge: 'Menunggu Konfirmasi Kehadiran',
                      isConfirmed: false,
                      location: 'GPPK House of Grace BSD City',
                      dateTime: 'Sunday, 6/3/23 - 09:30',
                      category: 'Kategori Permintaan',
                      priorityLabel: 'Sangat Penting/Butuh Segera',
                      priorityColor: Colors.red.shade700,
                      priorityIcon: Icons.error_outline_rounded,
                      userPhoto: null,
                      onTapChat: () {},
                    ),
                    const SizedBox(width: 14),
                    _buildServiceCard(
                      statusBadge: 'Kehadiran Dikonfirmasi',
                      isConfirmed: true,
                      location: 'GMAHK Jehovah-Jireh BSD',
                      dateTime: 'Sunday, 6/3/23 - 11:00',
                      category: 'Acara Keagamaan',
                      priorityLabel: 'Penting',
                      priorityColor: Colors.amber.shade800,
                      priorityIcon: Icons.error_outline_rounded,
                      userPhoto: null,
                      onTapChat: () {},
                    ),
                    const SizedBox(width: 14),
                    _buildServiceCard(
                      statusBadge: 'Menunggu Konfirmasi Kehadiran',
                      isConfirmed: false,
                      location: 'GKY BSD',
                      dateTime: 'Sunday, 5/3/23 - 13:30',
                      category: 'Kategori Permintaan',
                      priorityLabel: 'Penting',
                      priorityColor: Colors.amber.shade800,
                      priorityIcon: Icons.error_outline_rounded,
                      userPhoto: null,
                      onTapChat: () {},
                    ),
                    const SizedBox(width: 14),
                    _buildServiceCard(
                      statusBadge: 'Kehadiran Dikonfirmasi',
                      isConfirmed: true,
                      location: 'GKY BSD',
                      dateTime: 'Sunday, 5/3/23 - 15:30',
                      category: 'Acara Keagamaan',
                      priorityLabel: 'Standar',
                      priorityColor: Colors.blue.shade700,
                      priorityIcon: Icons.info_outline_rounded,
                      userPhoto: null,
                      onTapChat: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Liquid Floating Bottom Navigation Bar ──
      bottomNavigationBar: LiquidBottomNavBar(
        selectedIndex: _currentNavIndex,
        onTabSelected: (index) {
          setState(() => _currentNavIndex = index);
          if (index == 3) {
            _showMenuBottomSheet();
          }
        },
        items: const [
          LiquidNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Beranda',
          ),
          LiquidNavItem(
            icon: Icons.history_outlined,
            activeIcon: Icons.history_rounded,
            label: 'Histori',
          ),
          LiquidNavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Jadwal',
          ),
          LiquidNavItem(
            icon: Icons.menu_outlined,
            activeIcon: Icons.menu_rounded,
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final userName = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Romo';
        final phone = widget.user['phoneNumber'] ?? widget.user['phone_number'] ?? '';
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1E5399), child: Icon(Icons.person, color: Colors.white)),
                title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(phone),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: Color(0xFF1E5399)),
                title: const Text('Refresh Data Pelayanan'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onRefresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Keluar (Logout)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onLogout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceCard({
    required String statusBadge,
    required bool isConfirmed,
    required String location,
    required String dateTime,
    required String category,
    required String priorityLabel,
    required Color priorityColor,
    required IconData priorityIcon,
    String? userPhoto,
    required VoidCallback onTapChat,
  }) {
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack Container with Gradient & Badges
            SizedBox(
              height: 135,
              child: Stack(
                children: [
                  // Church Background Image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/church_1.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Dark Gradient Overlay for Text Legibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Top Left Status Badge (White Pill with Icon)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 44,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              statusBadge,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isConfirmed ? Icons.check_box_rounded : Icons.hourglass_bottom_rounded,
                            size: 14,
                            color: isConfirmed ? Colors.teal : Colors.amber.shade800,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Right User Avatar Badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isConfirmed ? Icons.person_rounded : Icons.person_outline_rounded,
                        size: 16,
                        color: isConfirmed ? Colors.teal : Colors.amber.shade800,
                      ),
                    ),
                  ),

                  // Bottom Text Overlay (Location & Time)
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 11),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dateTime,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom White Area: Category & Priority
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(priorityIcon, size: 14, color: priorityColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          priorityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
