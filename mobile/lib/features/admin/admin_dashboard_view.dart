import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../orders/order_detail_screen.dart';

class AdminDashboardView extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Order> orders;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const AdminDashboardView({
    Key? key,
    required this.user,
    required this.orders,
    required this.onRefresh,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  // Analytics data
  Map<String, dynamic> _analyticsData = {};

  // Users data
  List<Map<String, dynamic>> _adminUsers = [];
  String _userRoleFilter = 'ALL';
  String _userStatusFilter = 'ALL';
  final _userSearchController = TextEditingController();

  // Orders data
  List<Order> _allOrders = [];
  String _orderStatusFilter = 'ALL';
  String _orderCategoryFilter = 'ALL';
  final _orderSearchController = TextEditingController();

  // Master Data
  List<Map<String, dynamic>> _keuskupanList = [];
  List<Map<String, dynamic>> _parokiList = [];
  List<Map<String, dynamic>> _ordoList = [];
  String _masterSubTab = 'PAROKI';

  // QA Test Runner data
  bool _isRunningTests = false;
  Map<String, dynamic>? _testResults;

  @override
  void initState() {
    super.initState();
    _allOrders = widget.orders;
    _loadAllAdminData();
  }

  @override
  void didUpdateWidget(covariant AdminDashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders) {
      setState(() => _allOrders = widget.orders);
    }
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _orderSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAnalytics(),
      _loadUsers(),
      _loadOrders(),
      _loadMasterData(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAnalytics() async {
    final res = await ApiService.getAdminAnalytics();
    if (mounted) setState(() => _analyticsData = res);
  }

  Future<void> _loadUsers() async {
    final users = await ApiService.getAdminUsers(
      role: _userRoleFilter != 'ALL' ? _userRoleFilter : null,
      status: _userStatusFilter != 'ALL' ? _userStatusFilter : null,
      search: _userSearchController.text.trim(),
    );
    if (mounted) setState(() => _adminUsers = users);
  }

  Future<void> _loadOrders() async {
    final orders = await ApiService.getOrders();
    if (mounted) setState(() => _allOrders = orders);
  }

  Future<void> _loadMasterData() async {
    final kList = await ApiService.getKeuskupan();
    final pList = await ApiService.getParoki();
    final oList = await ApiService.getOrdo();
    if (mounted) {
      setState(() {
        _keuskupanList = kList;
        _parokiList = pList;
        _ordoList = oList;
      });
    }
  }

  Future<void> _handleApproveUser(int userId, String action, String userName) async {
    HapticFeedback.mediumImpact();
    final res = await ApiService.approveRegistration(
      targetUserId: userId,
      action: action,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Status akun berhasil diperbarui!'),
          backgroundColor: action == 'APPROVED' ? const Color(0xFF059669) : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadUsers();
      _loadAnalytics();
    }
  }

  Future<void> _handleUpdateOrderStatus(int orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    final res = await ApiService.updateAdminOrderStatus(orderId, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Status pelayanan diperbarui!'),
          backgroundColor: const Color(0xFF1E3A8A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadOrders();
      _loadAnalytics();
    }
  }

  Future<void> _handleRunTests() async {
    setState(() => _isRunningTests = true);
    HapticFeedback.mediumImpact();
    final res = await ApiService.runUnitTests();
    if (mounted) {
      setState(() {
        _testResults = res;
        _isRunningTests = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: isDesktop ? null : _buildDrawer(),
      appBar: isDesktop ? null : _buildMobileAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(isDesktop),
                Expanded(
                  child: _isLoading && _analyticsData.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                      : _buildActiveTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Header Bar ──
  Widget _buildTopHeader(bool isDesktop) {
    String tabTitle = 'Ringkasan & Analytics';
    if (_selectedTabIndex == 1) tabTitle = 'Manajemen Pelayanan';
    if (_selectedTabIndex == 2) tabTitle = 'Manajemen Pengguna & Persetujuan';
    if (_selectedTabIndex == 3) tabTitle = 'Master Data Wilayah & Gereja';
    if (_selectedTabIndex == 4) tabTitle = 'Monitoring Group Chat';
    if (_selectedTabIndex == 5) tabTitle = 'QA & Live Test Runner';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Admin Portal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(tabTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                tabTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Server Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text(
                  'Backend Online (Port 3005)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A), size: 20),
            tooltip: 'Segarkan Data',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadAllAdminData();
            },
          ),
          const SizedBox(width: 8),

          // Admin Profile Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFF1E3A8A),
                  child: Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user['fullName'] ?? widget.user['full_name'] ?? 'Super Admin CATU',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Text('SUPER ADMINISTRATOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      title: const Text('CATU Admin Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadAllAdminData,
        ),
      ],
    );
  }

  // ── Left Sidebar Navigation (Desktop) ──
  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Column(
        children: [
          // Brand Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD97706), width: 1.5),
                  ),
                  child: const Center(
                    child: Text('✝', style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('CATU ADMIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                    Text('PORTAL PUSAT SISTEM', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706), letterSpacing: 0.8)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 12),

          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Ringkasan & Analytics'),
                _buildNavItem(1, Icons.assignment_rounded, 'Manajemen Pelayanan', badgeCount: _analyticsData['orders']?['pending']),
                _buildNavItem(2, Icons.people_alt_rounded, 'Pengguna & Persetujuan', badgeCount: _analyticsData['users']?['pending_approvals'], badgeColor: const Color(0xFFD97706)),
                _buildNavItem(3, Icons.church_rounded, 'Master Data Gereja'),
                _buildNavItem(4, Icons.chat_bubble_rounded, 'Monitoring Group Chat'),
                _buildNavItem(5, Icons.biotech_rounded, 'Live QA Test Runner'),
              ],
            ),
          ),

          // Bottom Logout
          const Divider(color: Color(0xFF1E293B), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 10),
                    Text('Keluar Akun Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: _buildSidebar(),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title, {dynamic badgeCount, Color? badgeColor}) {
    final isSelected = _selectedTabIndex == index;
    final int count = badgeCount != null ? (int.tryParse(badgeCount.toString()) ?? 0) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
          if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Active Tab Dispatcher ──
  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTab0Overview();
      case 1:
        return _buildTab1Orders();
      case 2:
        return _buildTab2Users();
      case 3:
        return _buildTab3MasterData();
      case 4:
        return _buildTab4GroupChat();
      case 5:
        return _buildTab5TestRunner();
      default:
        return _buildTab0Overview();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0: RINGKASAN (ANALYTICS & OVERVIEW)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTab0Overview() {
    final orders = _analyticsData['orders'] ?? {};
    final users = _analyticsData['users'] ?? {};
    final categories = _analyticsData['categories'] is List ? _analyticsData['categories'] as List : [];
    final recentOrders = _analyticsData['recentOrders'] is List ? _analyticsData['recentOrders'] as List : [];

    final int pendingKoordinatorCount = int.tryParse(users['pending_koordinator']?.toString() ?? '0') ??
        _adminUsers.where((u) =>
            (u['account_status'] ?? '').toString() == 'PENDING_APPROVAL' &&
            ((u['pengurus_position'] ?? u['pengurusPosition'] ?? '').toString().toLowerCase().contains('koordinator') ||
             (u['role_code'] ?? '').toString() == 'KOORDINATOR')).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner Khusus: Persetujuan Koordinator Keuskupan ──
          if (pendingKoordinatorCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Persetujuan Koordinator Keuskupan',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingKoordinatorCount Menunggu',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Terdapat pendaftaran akun Koordinator Keuskupan baru yang memerlukan persetujuan Admin pusat.',
                          style: TextStyle(fontSize: 12, color: Color(0xFFE0E7FF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Tinjau & Setujui', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() {
                        _userRoleFilter = 'KOORDINATOR';
                        _userStatusFilter = 'PENDING_APPROVAL';
                        _selectedTabIndex = 2;
                      });
                    },
                  ),
                ],
              ),
            ),

          // ── Stat Cards Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardW = constraints.maxWidth > 900 ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard(
                    width: cardW,
                    title: 'Total Pelayanan',
                    value: '${orders['total'] ?? _allOrders.length}',
                    subtext: '${orders['confirmed'] ?? 0} aktif • ${orders['done'] ?? 0} selesai',
                    icon: Icons.assignment_rounded,
                    accentColor: const Color(0xFF1E3A8A),
                    badge: '${orders['pending'] ?? 0} Menunggu',
                    badgeColor: const Color(0xFFD97706),
                  ),
                  _buildStatCard(
                    width: cardW,
                    title: 'Total Pengguna',
                    value: '${users['total'] ?? _adminUsers.length}',
                    subtext: '${users['total_umat'] ?? 0} Umat • ${users['total_koordinator'] ?? 0} Koordinator • ${users['total_pengurus'] ?? 0} Pengurus',
                    icon: Icons.people_alt_rounded,
                    accentColor: const Color(0xFF059669),
                    badge: '${users['pending_approvals'] ?? 0} Approval',
                    badgeColor: const Color(0xFFDC2626),
                  ),
                  _buildStatCard(
                    width: cardW,
                    title: 'Romo Pelayan',
                    value: '${(int.tryParse(users['total_romo_paroki']?.toString() ?? '0') ?? 0) + (int.tryParse(users['total_romo_ordo']?.toString() ?? '0') ?? 0)}',
                    subtext: '${users['total_romo_paroki'] ?? 0} Paroki • ${users['total_romo_ordo'] ?? 0} Ordo',
                    icon: Icons.church_rounded,
                    accentColor: const Color(0xFF7C3AED),
                  ),
                  _buildStatCard(
                    width: cardW,
                    title: 'Sistem Backend',
                    value: '100% Healthy',
                    subtext: 'NestJS v10 + PostgreSQL 16',
                    icon: Icons.dns_rounded,
                    accentColor: const Color(0xFF0284C7),
                    badge: 'Online',
                    badgeColor: const Color(0xFF10B981),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Charts & Categories Section ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Breakdown Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF1E3A8A)),
                          SizedBox(width: 8),
                          Text('Distribusi Kategori Pelayanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (categories.isEmpty)
                        const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada data', style: TextStyle(color: Color(0xFF94A3B8))))
                      else
                        ...categories.map((c) {
                          final count = int.tryParse(c['count']?.toString() ?? '0') ?? 0;
                          final total = int.tryParse(orders['total']?.toString() ?? '1') ?? 1;
                          final double pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(c['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    Text('$count permintaan (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    valueColor: AlwaysStoppedAnimation(
                                      (c['name'] ?? '').toString().toLowerCase().contains('kedukaan')
                                          ? const Color(0xFF1E3A8A)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Recent Activities Feed
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.history_rounded, size: 18, color: Color(0xFF1E3A8A)),
                              SizedBox(width: 8),
                              Text('Aktivitas Pelayanan Terbaru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedTabIndex = 1),
                            child: const Text('Lihat Semua →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (recentOrders.isEmpty)
                        const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada pesanan aktif', style: TextStyle(color: Color(0xFF94A3B8)))))
                      else
                        ...recentOrders.map((o) => _buildRecentOrderTile(o)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? accentColor).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor ?? accentColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildRecentOrderTile(dynamic o) {
    final status = (o['status'] ?? 'PENDING').toString().toUpperCase();
    Color statusColor = const Color(0xFFD97706);
    if (status == 'CONFIRMED' || status == 'ACCEPTED') statusColor = const Color(0xFF059669);
    if (status == 'DONE') statusColor = const Color(0xFF10B981);
    if (status == 'FAIL') statusColor = const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_rounded, size: 16, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${o['order_number']} • ${o['category_name']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text('Pemohon: ${o['pemohon_name'] ?? '-'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: MANAJEMEN PELAYANAN (ORDERS)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTab1Orders() {
    final query = _orderSearchController.text.trim().toLowerCase();
    final filtered = _allOrders.where((o) {
      if (_orderStatusFilter != 'ALL' && o.status.toUpperCase() != _orderStatusFilter) return false;
      if (_orderCategoryFilter != 'ALL' && !o.categoryName.toLowerCase().contains(_orderCategoryFilter.toLowerCase())) return false;
      if (query.isNotEmpty) {
        final matchNum = o.orderNumber.toLowerCase().contains(query);
        final matchPemohon = o.pemohonName.toLowerCase().contains(query);
        final matchPenerima = o.penerimaName.toLowerCase().contains(query);
        final matchParoki = o.parokiName.toLowerCase().contains(query);
        if (!matchNum && !matchPemohon && !matchPenerima && !matchParoki) return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            // Filter Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _orderSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari no. order, pemohon, penerima...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter Status
                  DropdownButton<String>(
                    value: _orderStatusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Semua Status')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                      DropdownMenuItem(value: 'CONFIRMED', child: Text('Dikonfirmasi')),
                      DropdownMenuItem(value: 'DONE', child: Text('Selesai')),
                      DropdownMenuItem(value: 'FAIL', child: Text('Gagal/Ditolak')),
                    ],
                    onChanged: (val) => setState(() => _orderStatusFilter = val ?? 'ALL'),
                  ),
                  const SizedBox(width: 12),
                  // Filter Category
                  DropdownButton<String>(
                    value: _orderCategoryFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Semua Kategori')),
                      DropdownMenuItem(value: 'kedukaan', child: Text('Misa Kedukaan')),
                      DropdownMenuItem(value: 'perminyakan', child: Text('Perminyakan')),
                    ],
                    onChanged: (val) => setState(() => _orderCategoryFilter = val ?? 'ALL'),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // Orders Table
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Tidak ada data pelayanan ditemukan', style: TextStyle(color: Color(0xFF94A3B8))))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('NO. ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('KATEGORI & PELAYANAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('PEMOHON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('LOKASI / PAROKI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('JADWAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ROMO DITUGASKAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('AKSI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: filtered.map((order) {
                            final status = order.status.toUpperCase();
                            Color statusColor = const Color(0xFFD97706);
                            if (status == 'CONFIRMED' || status == 'ACCEPTED') statusColor = const Color(0xFF059669);
                            if (status == 'DONE') statusColor = const Color(0xFF10B981);
                            if (status == 'FAIL') statusColor = const Color(0xFFDC2626);

                            return DataRow(
                              cells: [
                                DataCell(Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)))),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(order.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      if (order.items.isNotEmpty)
                                        Text('${order.items.length} misa: ${order.items.map((i) => i.itemName).join(', ')}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                DataCell(Text(order.pemohonName.isNotEmpty ? order.pemohonName : '-')),
                                DataCell(Text(order.parokiName.isNotEmpty ? order.parokiName : (order.locationName.isNotEmpty ? order.locationName : '-'))),
                                DataCell(Text(order.scheduledDate.isNotEmpty ? order.scheduledDate : '-')),
                                DataCell(
                                  (order.acceptedRomoName != null && order.acceptedRomoName!.isNotEmpty)
                                      ? Text('Romo ${order.acceptedRomoName}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF059669)))
                                      : const Text('Belum ada Romo', style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                    child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF1E3A8A)),
                                        tooltip: 'Detail Order',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OrderDetailScreen(
                                                order: order,
                                                userName: 'Super Admin CATU',
                                                isRomo: false,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                                        onSelected: (newStatus) => _handleUpdateOrderStatus(order.id, newStatus),
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'CONFIRMED', child: Text('Ubah: CONFIRMED')),
                                          PopupMenuItem(value: 'DONE', child: Text('Ubah: SELESAI (DONE)')),
                                          PopupMenuItem(value: 'FAIL', child: Text('Ubah: BATAL / GAGAL')),
                                          PopupMenuItem(value: 'PENDING', child: Text('Ubah: PENDING')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: MANAJEMEN PENGGUNA & PERSETUJUAN (USERS & APPROVALS)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTab2Users() {
    final query = _userSearchController.text.trim().toLowerCase();
    final filtered = _adminUsers.where((u) {
      final pos = (u['pengurus_position'] ?? u['pengurusPosition'] ?? '').toString().toLowerCase();
      final role = (u['role_code'] ?? '').toString().toUpperCase();
      final isKoor = pos.contains('koordinator') || role == 'KOORDINATOR';

      if (_userRoleFilter != 'ALL') {
        if (_userRoleFilter == 'KOORDINATOR') {
          if (!isKoor) return false;
        } else if (_userRoleFilter == 'UMAT') {
          if (isKoor || role != 'UMAT' || (pos.isNotEmpty && pos != 'null')) return false;
        } else if (_userRoleFilter == 'PENGURUS_LINGKUNGAN') {
          if (isKoor || (role != 'PENGURUS_LINGKUNGAN' && (pos.isEmpty || pos == 'null'))) return false;
        } else if (role != _userRoleFilter) {
          return false;
        }
      }
      if (_userStatusFilter != 'ALL' && (u['account_status'] ?? '').toString() != _userStatusFilter) return false;
      if (query.isNotEmpty) {
        final matchName = (u['full_name'] ?? '').toString().toLowerCase().contains(query);
        final matchPhone = (u['phone_number'] ?? '').toString().toLowerCase().contains(query);
        final matchParoki = (u['paroki_name'] ?? '').toString().toLowerCase().contains(query);
        final matchKeuskupan = (u['keuskupan_name'] ?? '').toString().toLowerCase().contains(query);
        final matchKota = (u['kota_name'] ?? '').toString().toLowerCase().contains(query);
        if (!matchName && !matchPhone && !matchParoki && !matchKeuskupan && !matchKota) return false;
      }
      return true;
    }).toList();

    final int pendingTotal = _adminUsers.where((u) => (u['account_status'] ?? '').toString() == 'PENDING_APPROVAL').length;
    final int koordinatorTotal = _adminUsers.where((u) =>
        (u['pengurus_position'] ?? u['pengurusPosition'] ?? '').toString().toLowerCase().contains('koordinator') ||
        (u['role_code'] ?? '').toString() == 'KOORDINATOR').length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            // Quick Filter Pills Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildUserFilterPill(
                      label: 'Semua (${_adminUsers.length})',
                      isSelected: _userRoleFilter == 'ALL' && _userStatusFilter == 'ALL',
                      onTap: () => setState(() {
                        _userRoleFilter = 'ALL';
                        _userStatusFilter = 'ALL';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _buildUserFilterPill(
                      label: '⏳ Menunggu Approval ($pendingTotal)',
                      badgeColor: const Color(0xFFDC2626),
                      isSelected: _userStatusFilter == 'PENDING_APPROVAL',
                      onTap: () => setState(() {
                        _userStatusFilter = 'PENDING_APPROVAL';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _buildUserFilterPill(
                      label: '⭐ Koordinator Keuskupan ($koordinatorTotal)',
                      badgeColor: const Color(0xFF4F46E5),
                      isSelected: _userRoleFilter == 'KOORDINATOR',
                      onTap: () => setState(() {
                        _userRoleFilter = 'KOORDINATOR';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _buildUserFilterPill(
                      label: '🏛️ Pengurus Lingkungan',
                      isSelected: _userRoleFilter == 'PENGURUS_LINGKUNGAN',
                      onTap: () => setState(() {
                        _userRoleFilter = 'PENGURUS_LINGKUNGAN';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _buildUserFilterPill(
                      label: '✝️ Romo Paroki & Ordo',
                      isSelected: _userRoleFilter == 'ROMO_PAROKI' || _userRoleFilter == 'ROMO_ORDO',
                      onTap: () => setState(() {
                        _userRoleFilter = 'ROMO_PAROKI';
                      }),
                    ),
                    const SizedBox(width: 8),
                    _buildUserFilterPill(
                      label: '👥 Umat',
                      isSelected: _userRoleFilter == 'UMAT',
                      onTap: () => setState(() {
                        _userRoleFilter = 'UMAT';
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // Search Bar & Filter Dropdowns
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _userSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cari nama, no. HP, paroki, keuskupan...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Role Filter
                  DropdownButton<String>(
                    value: _userRoleFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Semua Role / Jabatan')),
                      DropdownMenuItem(value: 'KOORDINATOR', child: Text('⭐ Koordinator (Keuskupan)')),
                      DropdownMenuItem(value: 'UMAT', child: Text('Umat')),
                      DropdownMenuItem(value: 'ROMO_PAROKI', child: Text('Romo Paroki')),
                      DropdownMenuItem(value: 'ROMO_ORDO', child: Text('Romo Ordo')),
                      DropdownMenuItem(value: 'PENGURUS_LINGKUNGAN', child: Text('Pengurus Lingkungan')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    ],
                    onChanged: (val) => setState(() => _userRoleFilter = val ?? 'ALL'),
                  ),
                  const SizedBox(width: 12),
                  // Status Filter
                  DropdownButton<String>(
                    value: _userStatusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Semua Status')),
                      DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('⏳ Menunggu Approval')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('✓ Disetujui (Approved)')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('✗ Ditolak (Rejected)')),
                    ],
                    onChanged: (val) => setState(() => _userStatusFilter = val ?? 'ALL'),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // Users Table
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Tidak ada data pengguna ditemukan', style: TextStyle(color: Color(0xFF94A3B8))))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: const [
                            DataColumn(label: Text('PENGGUNA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('NO. WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('ROLE / JABATAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('KEUSKUPAN / PAROKI / DOMISILI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('STATUS AKUN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataColumn(label: Text('AKSI APPROVAL / KELOLA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                          rows: filtered.map((u) {
                            final userId = int.tryParse(u['id']?.toString() ?? '0') ?? 0;
                            final status = (u['account_status'] ?? 'PENDING_APPROVAL').toString();
                            final isPending = status == 'PENDING_APPROVAL';

                            final roleCode = (u['role_code'] ?? u['role_name'] ?? 'UMAT').toString().toUpperCase();
                            final pengurusPos = (u['pengurus_position'] ?? u['pengurusPosition'] ?? '').toString();
                            final isKoordinator = pengurusPos.toLowerCase().contains('koordinator') || roleCode == 'KOORDINATOR';

                            Color statusColor = isPending ? const Color(0xFFD97706) : (status == 'APPROVED' ? const Color(0xFF059669) : const Color(0xFFDC2626));

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isKoordinator
                                            ? const Color(0xFF4F46E5).withOpacity(0.15)
                                            : const Color(0xFF1E3A8A).withOpacity(0.1),
                                        child: isKoordinator
                                            ? const Icon(Icons.stars_rounded, color: Color(0xFF4F46E5), size: 16)
                                            : Text(
                                                (u['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(u['full_name'] ?? 'Pengguna', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                          if (u['email'] != null && u['email'].toString().isNotEmpty)
                                            Text(u['email'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(u['phone_number'] ?? '-')),
                                DataCell(
                                  isKoordinator
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4F46E5).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.stars_rounded, size: 13, color: Color(0xFF4F46E5)),
                                              SizedBox(width: 4),
                                              Text(
                                                'KOORDINATOR (KEUSKUPAN)',
                                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                                              ),
                                            ],
                                          ),
                                        )
                                      : (pengurusPos.isNotEmpty && pengurusPos != 'null')
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD97706).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'PENGURUS (${pengurusPos.toUpperCase()})',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E3A8A).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                u['role_name'] ?? roleCode,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                              ),
                                            ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (u['keuskupan_name'] != null && u['keuskupan_name'].toString().isNotEmpty)
                                        Text(
                                          u['keuskupan_name'].toString(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)),
                                        ),
                                      Text(
                                        u['paroki_name'] ?? u['kota_name'] ?? '-',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      if (u['lingkungan_name'] != null && u['lingkungan_name'].toString().isNotEmpty)
                                        Text(
                                          'Lkg. ${u['lingkungan_name']}',
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                    child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                                  ),
                                ),
                                DataCell(
                                  isPending
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                              ElevatedButton.icon(
                                              icon: const Icon(Icons.check_rounded, size: 14),
                                              label: const Text('Setujui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF059669),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _handleApproveUser(userId, 'APPROVED', u['full_name'] ?? ''),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                                              label: const Text('Tolak', style: TextStyle(fontSize: 11, color: Colors.red)),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _handleApproveUser(userId, 'REJECTED', u['full_name'] ?? ''),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              child: const Text('Ubah Status', style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A))),
                                              onPressed: () {
                                                _showChangeStatusDialog(userId, u['full_name'] ?? '', status);
                                              },
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    final color = badgeColor ?? const Color(0xFF1E3A8A);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showChangeStatusDialog(int userId, String name, String currentStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ubah Status: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('APPROVED (Disetujui)'),
              leading: const Icon(Icons.check_circle_rounded, color: Colors.green),
              onTap: () {
                Navigator.pop(ctx);
                _handleApproveUser(userId, 'APPROVED', name);
              },
            ),
            ListTile(
              title: const Text('PENDING_APPROVAL (Menunggu)'),
              leading: const Icon(Icons.hourglass_top_rounded, color: Colors.amber),
              onTap: () {
                Navigator.pop(ctx);
                _handleApproveUser(userId, 'PENDING_APPROVAL', name);
              },
            ),
            ListTile(
              title: const Text('REJECTED / BLOCKED (Tolak/Blokir)'),
              leading: const Icon(Icons.block_rounded, color: Colors.red),
              onTap: () {
                Navigator.pop(ctx);
                _handleApproveUser(userId, 'REJECTED', name);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: MASTER DATA GEREJA & WILAYAH
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTab3MasterData() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Sub-Tab Switcher
          Row(
            children: [
              _buildMasterTabPill('PAROKI', 'Daftar Paroki (${_parokiList.length})'),
              const SizedBox(width: 8),
              _buildMasterTabPill('KEUSKUPAN', 'Daftar Keuskupan (${_keuskupanList.length})'),
              const SizedBox(width: 8),
              _buildMasterTabPill('ORDO', 'Daftar Ordo / Kongregasi (${_ordoList.length})'),
            ],
          ),
          const SizedBox(height: 16),

          // Master Data Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _buildMasterDataGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterTabPill(String key, String title) {
    final isSelected = _masterSubTab == key;
    return InkWell(
      onTap: () => setState(() => _masterSubTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          title,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildMasterDataGrid() {
    if (_masterSubTab == 'PAROKI') {
      return ListView.separated(
        itemCount: _parokiList.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 1),
        itemBuilder: (context, idx) {
          final p = _parokiList[idx];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.08),
              child: const Icon(Icons.church_rounded, color: Color(0xFF1E3A8A), size: 18),
            ),
            title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: Text('ID Paroki: ${p['id']} • Keuskupan ID: ${p['keuskupan_id'] ?? '-'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          );
        },
      );
    } else if (_masterSubTab == 'KEUSKUPAN') {
      return ListView.separated(
        itemCount: _keuskupanList.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 1),
        itemBuilder: (context, idx) {
          final k = _keuskupanList[idx];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFD97706).withOpacity(0.08),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFFD97706), size: 18),
            ),
            title: Text(k['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: Text('ID Keuskupan: ${k['id']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          );
        },
      );
    } else {
      return ListView.separated(
        itemCount: _ordoList.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFFE2E8F0), height: 1),
        itemBuilder: (context, idx) {
          final o = _ordoList[idx];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF7C3AED).withOpacity(0.08),
              child: const Icon(Icons.people_alt_rounded, color: Color(0xFF7C3AED), size: 18),
            ),
            title: Text(o['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            subtitle: Text('ID Ordo: ${o['id']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          );
        },
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 4: MONITORING GROUP CHAT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTab4GroupChat() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.chat_rounded, color: Color(0xFF1E3A8A), size: 20),
                SizedBox(width: 8),
                Text('Monitoring WhatsApp-Style Group Chat Pelayanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Setiap permintaan pelayanan secara otomatis memiliki grup chat koordinasi antara Umat, Romo, dan Pengurus Lingkungan.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            Expanded(
              child: _allOrders.isEmpty
                  ? const Center(child: Text('Belum ada grup chat pelayanan', style: TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.builder(
                      itemCount: _allOrders.length,
                      itemBuilder: (context, idx) {
                        final order = _allOrders[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                            ),
                            title: Text('Group Pelayanan ${order.categoryName} (${order.orderNumber})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text('Pemohon: ${order.pemohonName} • Romo: ${(order.acceptedRomoName != null && order.acceptedRomoName!.isNotEmpty) ? order.acceptedRomoName : "Menunggu"}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            trailing: ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: const Text('Buka Chat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailScreen(
                                      order: order,
                                      userName: 'Super Admin CATU',
                                      isRomo: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 5: QA & LIVE TEST RUNNER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTab5TestRunner() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Live Quality Assurance & Unit Test Runner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Eksekusi otomatis seluruh test suite backend NestJS (Jest Runner) langsung dari browser.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  ],
                ),
                ElevatedButton.icon(
                  icon: _isRunningTests
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(_isRunningTests ? 'Menjalankan...' : '▶ Jalankan Live Tests', style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isRunningTests ? null : _handleRunTests,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Results Viewer Terminal
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: _testResults == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.terminal_rounded, size: 48, color: Color(0xFF475569)),
                            SizedBox(height: 12),
                            Text('Klik "Jalankan Live Tests" untuk menguji seluruh modul API CATU v2', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981)),
                                  ),
                                  child: const Text('PASS', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${_testResults!['message'] ?? 'Unit Tests Passed'} • ${_testResults!['timestamp'] ?? ''}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFF1E293B)),
                            const SizedBox(height: 12),
                            if (_testResults!['results'] is List)
                              ...(_testResults!['results'] as List).map((t) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                      const SizedBox(width: 8),
                                      Text('[${t['suite'] ?? 'Test'}] ', style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold, fontSize: 12)),
                                      Expanded(
                                        child: Text(t['name'] ?? '', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                        child: Text(t['status'] ?? 'PASSED', style: const TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
