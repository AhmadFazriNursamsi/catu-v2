import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../orders/order_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String role; // 'UMAT', 'ROMO_ORDO', 'ROMO_PAROKI', 'PENGURUS'
  final List<Order> orders;
  final Map<String, dynamic> user;
  final bool isRomo;
  final int? romoId;

  const NotificationScreen({
    super.key,
    required this.role,
    required this.orders,
    required this.user,
    this.isRomo = false,
    this.romoId,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

enum _TimeFilter { all, oneDay, oneWeek, oneMonth }

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationItem> _allItems = [];
  _TimeFilter _filter = _TimeFilter.all;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final items = await NotificationService.getForRole(widget.role);
    if (mounted) {
      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    }
    // Mark all as read after viewing
    await NotificationService.markAllRead(widget.role);
  }

  List<NotificationItem> get _filteredItems {
    final now = DateTime.now();
    var items = _allItems.where((n) {
      final diff = now.difference(n.createdAt);
      switch (_filter) {
        case _TimeFilter.oneDay:
          return diff.inHours <= 24;
        case _TimeFilter.oneWeek:
          return diff.inDays <= 7;
        case _TimeFilter.oneMonth:
          return diff.inDays <= 30;
        case _TimeFilter.all:
          return true;
      }
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((n) {
        return n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q);
      }).toList();
    }

    return items;
  }

  Future<void> _deleteItem(NotificationItem item) async {
    HapticFeedback.mediumImpact();
    await NotificationService.delete(item.id);
    setState(() {
      _allItems.removeWhere((n) => n.id == item.id);
    });
  }

  Future<void> _deleteAll() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Semua Notifikasi?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Semua notifikasi akan dihapus secara permanen.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService.deleteAll(widget.role);
      setState(() => _allItems.clear());
    }
  }

  String get _filterLabel {
    switch (_filter) {
      case _TimeFilter.oneDay:
        return '1 Hari';
      case _TimeFilter.oneWeek:
        return '1 Minggu';
      case _TimeFilter.oneMonth:
        return '1 Bulan';
      case _TimeFilter.all:
        return 'Semua';
    }
  }

  Color _typeAccentColor(String type) {
    switch (type) {
      case 'NEW_REQUEST':
        return const Color(0xFF1E3A8A);
      case 'ROMO_ACCEPTED':
        return const Color(0xFF059669);
      case 'ROMO_DECLINED':
        return const Color(0xFFDC2626);
      case 'STATUS_UPDATE':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF1E3A8A);
    }
  }

  IconData _typeIcon(String type, String? category) {
    if (type == 'NEW_REQUEST') {
      final isKedukaan = (category ?? '').toLowerCase().contains('kedukaan');
      return isKedukaan ? Icons.church_rounded : Icons.water_drop_rounded;
    }
    if (type == 'ROMO_ACCEPTED') return Icons.check_circle_rounded;
    if (type == 'ROMO_DECLINED') return Icons.cancel_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final unread = _allItems.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(unread),

            // ── Search Bar ──
            _buildSearchBar(),

            // ── Filter Row ──
            _buildFilterRow(),

            // ── List ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A8A),
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: const Color(0xFF1E3A8A),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationCard(filtered[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int unread) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF1E3A8A),
            onPressed: () => Navigator.pop(context),
          ),
          // Title
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Pemberitahuan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unread baru',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Delete All
          if (_allItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              color: const Color(0xFFDC2626),
              tooltip: 'Hapus semua',
              onPressed: _deleteAll,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Cari notifikasi...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          // Filter Dropdown
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF0F4FF),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 6),
                  Text(
                    _filterLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E3A8A)),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Count label
          Text(
            '${_filteredItems.length} notifikasi',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20, left: 0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(),
              ),
              const Text(
                'Filter Waktu',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              ...[
                (_TimeFilter.all, 'Semua Waktu', Icons.all_inclusive_rounded),
                (_TimeFilter.oneDay, '1 Hari Terakhir', Icons.today_rounded),
                (_TimeFilter.oneWeek, '1 Minggu Terakhir', Icons.date_range_rounded),
                (_TimeFilter.oneMonth, '1 Bulan Terakhir', Icons.calendar_month_rounded),
              ].map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _filter == e.$1
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(e.$3,
                        size: 18,
                        color: _filter == e.$1 ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8)),
                  ),
                  title: Text(
                    e.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _filter == e.$1 ? FontWeight.w700 : FontWeight.w500,
                      color: _filter == e.$1 ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: _filter == e.$1
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1E3A8A), size: 20)
                      : null,
                  onTap: () {
                    setState(() => _filter = e.$1);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final accent = _typeAccentColor(item.type);
    final icon = _typeIcon(item.type, item.categoryName);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text(
              'Hapus',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFCBF4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              HapticFeedback.selectionClick();
              await NotificationService.markRead(item.id);
              if (mounted) setState(() => item.isRead = true);

              // Navigate to order detail — fetch fresh from backend
              if (item.orderId == null || !mounted) return;
              final orderId = int.tryParse(item.orderId!);
              if (orderId == null) return;

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                ),
              );

              final Order? order = await ApiService.getOrderById(orderId);

              // Dismiss loading
              if (mounted) Navigator.of(context).pop();

              if (order == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Detail pelayanan tidak ditemukan.'),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
                return;
              }

              if (mounted) {
                final userName = widget.user['fullName'] ?? widget.user['full_name'] ?? 'Pengguna';
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      order: order,
                      userName: userName,
                      isRomo: widget.isRomo,
                      romoId: widget.romoId,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Body
                        Text(
                          item.body,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Footer: category chip + time
                        Row(
                          children: [
                            if (item.categoryName != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.categoryName!.toLowerCase().contains('kedukaan')
                                      ? '✝ Misa Kedukaan'
                                      : '🕯️ Perminyakan',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              item.timeAgo,
                              style: TextStyle(
                                fontSize: 11,
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            // Swipe hint
                            Text(
                              '← geser hapus',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
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
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFCBF4), width: 1.5),
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 36,
                color: Color(0xFF93A5D1),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum ada notifikasi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filter != _TimeFilter.all
                  ? 'Tidak ada notifikasi dalam periode $_filterLabel.\nCoba ubah filter waktu.'
                  : 'Semua aktivitas pelayanan\nakan muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
