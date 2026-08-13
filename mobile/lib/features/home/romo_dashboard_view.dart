import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/widgets/liquid_bottom_nav_bar.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import '../orders/order_detail_screen.dart';

class RomoDashboardCardItem {
  final Order parentOrder;
  final String title;
  final String dateSchedule;
  final String location;
  final String penerimaName;
  final OrderItem? subItem;

  RomoDashboardCardItem({
    required this.parentOrder,
    required this.title,
    required this.dateSchedule,
    required this.location,
    required this.penerimaName,
    this.subItem,
  });
}

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
    final String romoPos = widget.user['romoPosition'] ?? widget.user['romo_position'] ?? '';
    final String? startDate = widget.user['jabatanStartDate'] ?? widget.user['jabatan_start_date'];
    final String? endDate = widget.user['jabatanEndDate'] ?? widget.user['jabatan_end_date'];
    final int? startYear = widget.user['jabatanStartYear'] ?? widget.user['jabatan_start_year'];
    final int? endYear = widget.user['jabatanEndYear'] ?? widget.user['jabatan_end_year'];
    final bool isJabatanActive = widget.user['isJabatanActive'] ?? widget.user['is_jabatan_active'] ?? false;
    final String positionTitle = romoPos == 'KETUA_ROMO' ? 'Pastor Kepala' : 'Pastor Rekan';

    final String periodeText = (startDate != null && endDate != null && startDate.isNotEmpty && endDate.isNotEmpty)
        ? '$startDate - $endDate'
        : (startYear != null && endYear != null ? '$startYear - $endYear' : '');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Seamless Transparent Top Header Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $userName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        // Baris 1: Jabatan & Flag Status Badge
                        Row(
                          children: [
                            Text(
                              positionTitle,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E5399)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isJabatanActive ? Colors.green.shade600 : const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isJabatanActive ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                    size: 9.5,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isJabatanActive ? 'Jabatan Aktif' : 'Menunggu Verifikasi Admin',
                                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (startDate != null && endDate != null && startDate.isNotEmpty && endDate.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          // Baris 2: Masa Jabatan 2 Kolom (Mulai & Selesai)
                          Row(
                            children: [
                              Text(
                                'Mulai: $startDate',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Selesai: $endDate',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ] else if (periodeText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Masa Bakti: $periodeText',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
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
                              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                              child: const Text(
                                '1',
                                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
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
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatListScreen(
                                    user: widget.user,
                                    orders: widget.orders,
                                  ),
                                ),
                              );
                            },
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
                              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                              child: const Text(
                                '2',
                                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
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

            // ── 2. Scrollable Body Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Cross Banner with Shadow Depth
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E5399).withOpacity(0.18),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.asset(
                              'assets/images/cross_banner.jpg',
                              fit: BoxFit.cover,
                            ),
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

              // Horizontal Cards for "Jadwal Pelayanan Hari Ini" (Accepted/Confirmed orders)
              _buildTodayScheduleWidget(),

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

              // Horizontal Cards for "Daftar Permintaan Pelayanan" (All parish orders)
              _buildParishRequestsWidget(),
            ],
          ),
        ),
      ),
    ],
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

  bool _isDateBeforeToday(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      String cleanStr = dateStr;
      if (cleanStr.contains('T')) cleanStr = cleanStr.split('T').first;
      final d = DateTime.parse(cleanStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return DateTime(d.year, d.month, d.day).isBefore(today);
    } catch (_) {
      return false;
    }
  }

  List<RomoDashboardCardItem> get _displayParishRequestsCardItems {
    final List<RomoDashboardCardItem> cardList = [];

    for (final order in widget.orders.where((o) => o.isActiveDashboardOrder)) {
      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          if (_isDateBeforeToday(item.scheduledDate)) continue;

          String scheduleStr = item.scheduledDate;
          if (item.scheduledTimeStart.isNotEmpty) {
            scheduleStr = '${item.scheduledDate} • ${item.scheduledTimeStart}';
            if (item.scheduledTimeEnd.isNotEmpty) {
              scheduleStr += ' - ${item.scheduledTimeEnd} WIB';
            } else {
              scheduleStr += ' WIB';
            }
          }

          cardList.add(
            RomoDashboardCardItem(
              parentOrder: order,
              title: item.itemName,
              dateSchedule: scheduleStr,
              location: item.locationName.isNotEmpty
                  ? item.locationName
                  : order.displayAddress,
              penerimaName: order.penerimaName,
              subItem: item,
            ),
          );
        }
      } else {
        if (_isDateBeforeToday(order.scheduledDate)) continue;

        cardList.add(
          RomoDashboardCardItem(
            parentOrder: order,
            title: order.categoryName,
            dateSchedule: order.fullScheduleLabel,
            location: order.displayAddress,
            penerimaName: order.penerimaName,
          ),
        );
      }
    }

    cardList.sort((a, b) {
      final dateA = a.parentOrder.parsedDate ?? DateTime(2099);
      final dateB = b.parentOrder.parsedDate ?? DateTime(2099);
      return dateA.compareTo(dateB);
    });

    return cardList;
  }

  List<RomoDashboardCardItem> get _displayTodayScheduleCardItems {
    final acceptedOrders = widget.orders.where((o) {
      final st = o.status.toUpperCase();
      return (st == 'CONFIRMED' || st == 'IN_PROGRESS' || st == 'ACCEPTED' || st == 'DONE') && o.isActiveDashboardOrder;
    }).toList();

    final List<RomoDashboardCardItem> cardList = [];

    for (final order in acceptedOrders) {
      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          if (_isDateBeforeToday(item.scheduledDate)) continue;

          String scheduleStr = item.scheduledDate;
          if (item.scheduledTimeStart.isNotEmpty) {
            scheduleStr = '${item.scheduledDate} • ${item.scheduledTimeStart}';
            if (item.scheduledTimeEnd.isNotEmpty) {
              scheduleStr += ' - ${item.scheduledTimeEnd} WIB';
            } else {
              scheduleStr += ' WIB';
            }
          }

          cardList.add(
            RomoDashboardCardItem(
              parentOrder: order,
              title: item.itemName,
              dateSchedule: scheduleStr,
              location: item.locationName.isNotEmpty
                  ? item.locationName
                  : order.displayAddress,
              penerimaName: order.penerimaName,
              subItem: item,
            ),
          );
        }
      } else {
        if (_isDateBeforeToday(order.scheduledDate)) continue;

        cardList.add(
          RomoDashboardCardItem(
            parentOrder: order,
            title: order.categoryName,
            dateSchedule: order.fullScheduleLabel,
            location: order.displayAddress,
            penerimaName: order.penerimaName,
          ),
        );
      }
    }

    cardList.sort((a, b) {
      final dateA = a.parentOrder.parsedDate ?? DateTime(2099);
      final dateB = b.parentOrder.parsedDate ?? DateTime(2099);
      return dateA.compareTo(dateB);
    });

    return cardList;
  }

  Widget _buildTodayScheduleWidget() {
    final items = _displayTodayScheduleCardItems;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.calendar_today_rounded, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Belum ada jadwal pelayanan yang dikonfirmasi.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _buildServiceCardFromCardItem(item),
          );
        },
      ),
    );
  }

  Widget _buildParishRequestsWidget() {
    final items = _displayParishRequestsCardItems;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Tidak ada permintaan pelayanan di Paroki saat ini.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _buildServiceCardFromCardItem(item),
          );
        },
      ),
    );
  }

  Widget _buildServiceCardFromCardItem(RomoDashboardCardItem item) {
    final order = item.parentOrder;
    final bool isConfirmed = order.status.toUpperCase() != 'PENDING';
    final String statusBadge = isConfirmed ? 'Kehadiran Dikonfirmasi' : 'Menunggu Konfirmasi Kehadiran';

    Color priorityColor = Colors.blue.shade700;
    IconData priorityIcon = Icons.info_outline_rounded;
    final urg = order.urgencyName.toLowerCase();
    if (urg.contains('darurat') || urg.contains('kritis')) {
      priorityColor = Colors.red.shade700;
      priorityIcon = Icons.error_outline_rounded;
    } else if (urg.contains('penting')) {
      priorityColor = Colors.amber.shade800;
      priorityIcon = Icons.error_outline_rounded;
    }

    final int? romoId = widget.user['id'] != null
        ? int.tryParse(widget.user['id'].toString())
        : (widget.user['userId'] != null ? int.tryParse(widget.user['userId'].toString()) : null);

    return GestureDetector(
      onTap: () async {
        final bool? refreshed = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              order: order,
              userName: widget.user['fullName'] ?? widget.user['full_name'] ?? 'Romo',
              selectedItemTitle: item.title,
              isRomo: true,
              romoId: romoId,
            ),
          ),
        );
        if (refreshed == true) {
          widget.onRefresh();
        }
      },
      child: _buildServiceCard(
        statusBadge: statusBadge,
        isConfirmed: isConfirmed,
        location: item.location.isNotEmpty ? item.location : order.displayAddress,
        dateTime: item.dateSchedule,
        category: item.title,
        priorityLabel: order.urgencyName,
        priorityColor: priorityColor,
        priorityIcon: priorityIcon,
        onTapChat: () async {
          final bool? refreshed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                order: order,
                userName: widget.user['fullName'] ?? widget.user['full_name'] ?? 'Romo',
                selectedItemTitle: item.title,
                isRomo: true,
                romoId: romoId,
              ),
            ),
          );
          if (refreshed == true) {
            widget.onRefresh();
          }
        },
      ),
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
