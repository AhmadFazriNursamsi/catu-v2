import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/liquid_bottom_nav_bar.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import '../orders/histori_screen.dart';
import '../orders/order_detail_screen.dart';
import '../orders/schedule_screen.dart';
import '../profile/main_menu_screen.dart';
import '../notifications/notification_screen.dart';

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
  int _unreadNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    final role = _romoRole;
    final count = await NotificationService.unreadCount(role);
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  String get _romoRole {
    final rawRole = widget.user['roleCode'] ?? widget.user['role_code'] ?? '';
    if (rawRole.toString().toUpperCase().contains('PAROKI')) return 'ROMO_PAROKI';
    return 'ROMO_ORDO';
  }

  Future<void> _openNotifications() async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationScreen(role: _romoRole),
      ),
    );
    _refreshUnreadCount();
  }

  List<LiquidNavItem> _buildNavItems() {
    return const [
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
    ];
  }

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

    final int? romoId = widget.user['id'] != null
        ? int.tryParse(widget.user['id'].toString())
        : (widget.user['userId'] != null ? int.tryParse(widget.user['userId'].toString()) : null);

    // ── Histori Tab (Nav Index 1) ──
    if (_currentNavIndex == 1) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: HistoriScreen(
          orders: widget.orders,
          userName: userName,
          onRefresh: widget.onRefresh,
          isRomo: true,
          romoId: romoId,
        ),
        bottomNavigationBar: LiquidBottomNavBar(
          selectedIndex: _currentNavIndex,
          onTabSelected: (index) {
            setState(() => _currentNavIndex = index);
          },
          items: _buildNavItems(),
        ),
      );
    }

    // ── Schedule / Jadwal Tab (Nav Index 2) ──
    if (_currentNavIndex == 2) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: ScheduleScreen(
          orders: widget.orders,
          userName: userName,
          onRefresh: widget.onRefresh,
          isRomo: true,
          romoId: romoId,
        ),
        bottomNavigationBar: LiquidBottomNavBar(
          selectedIndex: _currentNavIndex,
          onTabSelected: (index) {
            setState(() => _currentNavIndex = index);
          },
          items: _buildNavItems(),
        ),
      );
    }

    // ── Menu Utama Tab (Nav Index 3) ──
    if (_currentNavIndex == 3) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: MainMenuScreen(
          user: widget.user,
          onRefresh: widget.onRefresh,
          onLogout: widget.onLogout,
        ),
        bottomNavigationBar: LiquidBottomNavBar(
          selectedIndex: _currentNavIndex,
          onTabSelected: (index) {
            setState(() => _currentNavIndex = index);
          },
          items: _buildNavItems(),
        ),
      );
    }

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
                      // Bell Notification Icon with dynamic badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E5399), size: 26),
                            onPressed: _openNotifications,
                          ),
                          if (_unreadNotifCount > 0)
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
                                child: Text(
                                  _unreadNotifCount > 99 ? '99+' : '$_unreadNotifCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
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
                          onPressed: () {
                            setState(() => _currentNavIndex = 2);
                          },
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
                    Text(
                      '${DateTime.now().day} Masehi ${DateTime.now().year}',
                      style: const TextStyle(
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
                      onPressed: () async {
                        final bool? refreshed = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScheduleScreen(
                              orders: widget.orders,
                              userName: userName,
                              onRefresh: widget.onRefresh,
                              isRomo: true,
                              romoId: romoId,
                              showPendingOnly: true,
                            ),
                          ),
                        );
                        if (refreshed == true) {
                          widget.onRefresh();
                          if (mounted) {
                            setState(() {});
                          }
                        }
                      },
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
        },
        items: _buildNavItems(),
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

  bool _isDateToday(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      String cleanStr = dateStr;
      if (cleanStr.contains('T')) cleanStr = cleanStr.split('T').first;
      final d = DateTime.parse(cleanStr);
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    } catch (_) {
      return false;
    }
  }

  List<RomoDashboardCardItem> get _displayParishRequestsCardItems {
    final List<RomoDashboardCardItem> cardList = [];

    for (final order in widget.orders) {
      if (!order.isActiveDashboardOrder) continue;
      final st = order.status.toUpperCase();
      if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') continue;

      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          // EXCLUDE items that are already accepted by ANY Romo!
          if (item.acceptedRomoId != null) continue;
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
        if (st != 'PENDING' || order.acceptedRomoId != null) continue;
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

    // Limit to max 5 items
    return cardList.take(5).toList();
  }

  List<RomoDashboardCardItem> get _displayTodayScheduleCardItems {
    final int? romoId = widget.user['id'] != null
        ? int.tryParse(widget.user['id'].toString())
        : (widget.user['userId'] != null ? int.tryParse(widget.user['userId'].toString()) : null);

    final List<RomoDashboardCardItem> cardList = [];

    for (final order in widget.orders) {
      if (!order.isActiveDashboardOrder) continue;

      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          // ONLY display items accepted by THIS Romo that are NOT yet DONE!
          if (romoId == null || item.acceptedRomoId != romoId) continue;
          final itemSt = item.status.toUpperCase();
          if (itemSt == 'DONE' || itemSt == 'CLOSE' || itemSt == 'FAIL') continue;
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
        if (romoId == null || order.acceptedRomoId != romoId) continue;
        final st = order.status.toUpperCase();
        if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') continue;
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

    // Limit to max 5 items
    return cardList.take(5).toList();
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
      height: 255,
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
      height: 255,
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'CONFIRMED':
        return const Color(0xFF059669);
      case 'DONE':
        return const Color(0xFF059669);
      case 'REJECTED':
      case 'FAIL':
      case 'CLOSE':
        return const Color(0xFFDC2626);
      case 'PENDING':
      default:
        return const Color(0xFFD97706);
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'CONFIRMED':
        return 'Telah Dikonfirmasi';
      case 'DONE':
        return 'Telah Selesai';
      case 'REJECTED':
      case 'FAIL':
      case 'CLOSE':
        return 'Batal / Gagal';
      case 'PENDING':
      default:
        return 'Menunggu Konfirmasi';
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
      case 'CONFIRMED':
      case 'DONE':
        return Icons.check_circle_rounded;
      case 'REJECTED':
      case 'FAIL':
      case 'CLOSE':
        return Icons.cancel_rounded;
      case 'PENDING':
      default:
        return Icons.hourglass_bottom_rounded;
    }
  }

  Color _urgencyColor(String urgencyName) {
    final lower = urgencyName.toLowerCase();
    if (lower.contains('darurat') || lower.contains('kritis') || lower.contains('segera')) {
      return const Color(0xFFDC2626);
    } else if (lower.contains('penting') || lower.contains('tinggi')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF2563EB);
  }

  Widget _buildServiceCardFromCardItem(RomoDashboardCardItem item) {
    final order = item.parentOrder;
    final bool isSubItemAccepted = item.subItem != null
        ? (item.subItem!.acceptedRomoId != null || item.subItem!.status.toUpperCase() == 'ACCEPTED' || item.subItem!.status.toUpperCase() == 'CONFIRMED' || item.subItem!.status.toUpperCase() == 'DONE')
        : (order.acceptedRomoId != null && order.status.toUpperCase() != 'PENDING');

    final String effectiveStatus = item.subItem != null
        ? (isSubItemAccepted
            ? (item.subItem!.status.toUpperCase() == 'DONE' ? 'DONE' : 'CONFIRMED')
            : 'PENDING')
        : (isSubItemAccepted
            ? (order.status.toUpperCase() == 'DONE' ? 'DONE' : 'CONFIRMED')
            : order.status.toUpperCase());

    final statusColor = _statusColor(effectiveStatus);
    final statusLabel = _statusLabel(effectiveStatus);
    final statusIcon = _statusIcon(effectiveStatus);
    final urgencyColor = _urgencyColor(order.urgencyName);

    final bool isKedukaan = item.title.toLowerCase().contains('kedukaan') || order.categoryName.toLowerCase().contains('kedukaan');
    final String cardTitle = item.title;
    final String cardSubtitle = isKedukaan ? 'Alm. ${order.penerimaName}' : 'Penerima: ${order.penerimaName}';
    final String romoName = item.subItem != null
        ? (item.subItem!.acceptedRomoName ?? '')
        : (order.acceptedRomoName ?? '');

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
          if (mounted) setState(() {});
        }
      },
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Banner Image Header ──
              SizedBox(
                height: 125,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/church_1.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Category & Status Badges Row (top)
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isKedukaan
                                    ? const Color(0xFF1E1B4B).withValues(alpha: 0.9)
                                    : const Color(0xFF1E3A8A).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isKedukaan
                                      ? const Color(0xFFD4AF37)
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isKedukaan ? '✝ MISA KEDUKAAN' : '🕯️ PERMINYAKAN',
                                style: TextStyle(
                                  color: isKedukaan ? const Color(0xFFF5D77D) : Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: Colors.white, size: 10),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      statusLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location / Address (bottom of image)
                    Positioned(
                      bottom: 8,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location.isNotEmpty ? item.location : order.displayAddress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 1)),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Urgency accent strip ──
              Container(height: 3, color: urgencyColor),

              // ── Card body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    Text(
                      cardSubtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isKedukaan ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (romoName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF059669).withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                romoName,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.dateSchedule,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            order.urgencyName,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: urgencyColor,
                            ),
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
      ),
    );
  }
}
