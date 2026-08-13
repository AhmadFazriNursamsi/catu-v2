// CATU — Halaman Histori Permintaan Pelayanan (Modern Redesign)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/language_service.dart';
import '../orders/order_detail_screen.dart';

class HistoriScreen extends StatefulWidget {
  final List<Order> orders;
  final String userName;
  final VoidCallback onRefresh;

  const HistoriScreen({
    Key? key,
    required this.orders,
    required this.userName,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<HistoriScreen> createState() => _HistoriScreenState();
}

class _HistoriScreenState extends State<HistoriScreen>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _filterStatus = 'SEMUA';
  String _sortBy = 'TERBARU';
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  static const List<String> _statusFilters = [
    'SEMUA',
    'PENDING',
    'CONFIRMED',
    'IN_PROGRESS',
    'DONE',
    'CLOSE',
    'FAIL',
  ];

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _animController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFF0891B2);   // cyan — dikonfirmasi
      case 'IN_PROGRESS':
        return const Color(0xFF7C3AED);   // ungu — berlangsung
      case 'DONE':
        return const Color(0xFF059669);   // hijau — selesai
      case 'CLOSE':
        return const Color(0xFF92400E);   // coklat tua — ditutup
      case 'FAIL':
        return const Color(0xFFDC2626);   // merah — gagal
      case 'PENDING':
      default:
        return const Color(0xFFD97706);   // oranye — menunggu
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return LanguageService.tr('status_pending');
      case 'CONFIRMED':
        return 'Kehadiran Dikonfirmasi';
      case 'IN_PROGRESS':
        return LanguageService.tr('status_in_progress');
      case 'DONE':
        return LanguageService.tr('status_done');
      case 'CLOSE':
        return 'Ditutup';
      case 'FAIL':
        return 'Gagal';
      default:
        return LanguageService.tr('status_pending');
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return Icons.how_to_reg_rounded;
      case 'IN_PROGRESS':
        return Icons.timelapse_rounded;
      case 'DONE':
        return Icons.check_circle_rounded;
      case 'CLOSE':
        return Icons.block_rounded;
      case 'FAIL':
        return Icons.cancel_rounded;
      case 'PENDING':
      default:
        return Icons.schedule_rounded;
    }
  }



  Color _urgencyColor(String urgency) {
    final u = urgency.toLowerCase();
    if (u.contains('sangat') || u.contains('darurat')) {
      return const Color(0xFFDC2626);
    }
    if (u.contains('penting')) return const Color(0xFFD97706);
    return const Color(0xFF1D4ED8);
  }

  String _categoryShortIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('kedukaan') || lower.contains('misa')) return '⛪';
    if (lower.contains('minyak') || lower.contains('perminyakan')) return '🕯️';
    if (lower.contains('baptis')) return '✝️';
    return '📿';
  }

  List<Order> get _historyBaseOrders {
    return widget.orders.where((o) => o.isHistoryOrder).toList();
  }

  List<Order> get _filtered {
    List<Order> result = _historyBaseOrders;

    // Filter by status
    if (_filterStatus != 'SEMUA') {
      result =
          result.where((o) => o.status.toUpperCase() == _filterStatus).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((o) {
        return o.penerimaName.toLowerCase().contains(q) ||
            o.categoryName.toLowerCase().contains(q) ||
            o.displayAddress.toLowerCase().contains(q) ||
            o.orderNumber.toLowerCase().contains(q);
      }).toList();
    }

    // Sort
    if (_sortBy == 'TERBARU') {
      result.sort((a, b) => b.id.compareTo(a.id));
    } else if (_sortBy == 'TERLAMA') {
      result.sort((a, b) => a.id.compareTo(b.id));
    } else if (_sortBy == 'STATUS') {
      result.sort((a, b) => a.status.compareTo(b.status));
    }

    return result;
  }

  // ── Summary counts ──────────────────────────────────────────────────────────

  Map<String, int> get _summaryCounts {
    final all = _historyBaseOrders;
    return {
      'total': all.length,
      'pending': all
          .where((o) => o.status.toUpperCase() == 'PENDING')
          .length,
      'berlangsung': all
          .where((o) =>
              o.status.toUpperCase() == 'CONFIRMED' ||
              o.status.toUpperCase() == 'IN_PROGRESS')
          .length,
      'selesai': all
          .where((o) => o.status.toUpperCase() == 'DONE' || o.status.toUpperCase() == 'FAIL' || o.status.toUpperCase() == 'CLOSE')
          .length,
    };
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final counts = _summaryCounts;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: FadeTransition(
          opacity: _fadeIn,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──
              SliverToBoxAdapter(child: _buildTopBar()),

              // ── Stats Row ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: _buildStatsRow(counts),
                ),
              ),

              // ── Filter Chips ──
              SliverToBoxAdapter(child: _buildFilterRow()),

              // ── Divider ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} Permintaan',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      _buildSortButton(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── List ──
              filtered.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == filtered.length) {
                            return const SizedBox(height: 100);
                          }
                          return _buildOrderCard(filtered[index], index);
                        },
                        childCount: filtered.length + 1,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 14),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _isSearchActive
            ? Row(
                key: const ValueKey('search'),
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: LanguageService.tr('search_hint'),
                          hintStyle:
                              const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearchActive = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: Text(
                      LanguageService.tr('cancel'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('title'),
                children: [
                  Expanded(
                    child: Text(
                      LanguageService.tr('history_title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  _buildIconBtn(
                    Icons.search_rounded,
                    onTap: () {
                      setState(() => _isSearchActive = true);
                      Future.delayed(const Duration(milliseconds: 100),
                          () => _searchFocus.requestFocus());
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildIconBtn(
                    Icons.refresh_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onRefresh();
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF334155)),
      ),
    );
  }

  // ── Stats Row ───────────────────────────────────────────────────────────────

  Widget _buildStatsRow(Map<String, int> counts) {
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: Row(
        children: [
          _buildStatItem(
            '${counts['total']}',
            'Total',
            const Color(0xFF1D4ED8),
            Icons.list_alt_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem(
            '${counts['pending']}',
            LanguageService.tr('status_pending_short'),
            const Color(0xFFD97706),
            Icons.schedule_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem(
            '${counts['berlangsung']}',
            LanguageService.tr('status_in_progress'),
            const Color(0xFF2563EB),
            Icons.timelapse_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem(
            '${counts['selesai']}',
            LanguageService.tr('status_done'),
            const Color(0xFF059669),
            Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 48,
      color: const Color(0xFFF1F5F9),
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  // ── Filter Row ──────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      margin: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusFilters.map((s) {
            final selected = _filterStatus == s;
            final color = s == 'SEMUA'
                ? const Color(0xFF1D4ED8)
                : _statusColor(s);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filterStatus = s);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? color : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? color
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    _filterChipLabel(s),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _filterChipLabel(String s) {
    switch (s) {
      case 'SEMUA':       return 'Semua';
      case 'PENDING':     return LanguageService.tr('status_pending_short');
      case 'CONFIRMED':   return 'Dikonfirmasi';
      case 'IN_PROGRESS': return LanguageService.tr('status_in_progress');
      case 'DONE':        return LanguageService.tr('status_done');
      case 'CLOSE':       return 'Ditutup';
      case 'FAIL':        return 'Gagal';
      default:            return s;
    }
  }

  // ── Sort Button ─────────────────────────────────────────────────────────────

  Widget _buildSortButton() {
    return GestureDetector(
      onTap: _showSortSheet,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded,
                size: 16, color: Color(0xFF334155)),
            const SizedBox(width: 5),
            Text(
              _sortBy == 'TERBARU'
                  ? 'Terbaru'
                  : _sortBy == 'TERLAMA'
                      ? 'Terlama'
                      : 'Status',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                LanguageService.tr('sort_title'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              ...['TERBARU', 'TERLAMA', 'STATUS'].map((opt) {
                final selected = _sortBy == opt;
                final labels = {
                  'TERBARU': 'Terbaru Pertama',
                  'TERLAMA': 'Terlama Pertama',
                  'STATUS': 'Berdasarkan Status',
                };
                return GestureDetector(
                  onTap: () {
                    setState(() => _sortBy = opt);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1D4ED8).withValues(alpha: 0.06)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1D4ED8).withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          labels[opt]!,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF334155),
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check_rounded,
                              size: 18, color: Color(0xFF1D4ED8)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── Order Card ──────────────────────────────────────────────────────────────

  Widget _buildOrderCard(Order order, int index) {
    final statusColor = _statusColor(order.status);
    final statusLabel = _statusLabel(order.status);
    final statusIcon = _statusIcon(order.status);
    final urgencyColor = _urgencyColor(order.urgencyName);
    final emoji = _categoryShortIcon(order.categoryName);

    String scheduleStr = order.fullScheduleLabel;
    String locationStr = order.displayAddress;
    if (order.items.isNotEmpty) {
      final item = order.items.first;
      locationStr = item.locationName.isNotEmpty ? item.locationName : locationStr;
      String t = item.scheduledDate;
      if (item.scheduledTimeStart.isNotEmpty) {
        t += ' · ${item.scheduledTimeStart}';
        if (item.scheduledTimeEnd.isNotEmpty) t += '–${item.scheduledTimeEnd} WIB';
      }
      scheduleStr = t;
    }

    final bool isKedukaan = order.categoryName.toLowerCase().contains('kedukaan');
    final String cardTitle = isKedukaan && order.items.isNotEmpty
        ? order.items.first.itemName
        : order.penerimaName;
    final String cardSubtitle = isKedukaan ? order.penerimaName : order.categoryName;
    final bool showDetail = order.status.toUpperCase() == 'DONE' ||
        order.status.toUpperCase() == 'CLOSE' ||
        order.status.toUpperCase() == 'FAIL' ||
        order.status.toUpperCase() == 'CONFIRMED';

    void goToDetail() {
      HapticFeedback.lightImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            order: order,
            userName: widget.userName,
            selectedItemTitle:
                order.items.isNotEmpty ? order.items.first.itemName : null,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: goToDetail,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top colour strip ──
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Container(height: 3, color: statusColor),
              ),

              // ── Header row: thumbnail + info ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset('assets/images/church_1.jpg',
                                fit: BoxFit.cover),
                            Container(
                                color: Colors.black.withValues(alpha: 0.28)),
                            Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info — expands to fill all remaining space
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title (2 lines)
                          Text(
                            cardTitle,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Subtitle + urgency pill
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cardSubtitle,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      urgencyColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  order.urgencyName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: urgencyColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          // Status badge — own row, no competition
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon,
                                    size: 12, color: statusColor),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──
              Container(
                height: 1,
                color: const Color(0xFFF1F5F9),
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              ),

              // ── Location & Schedule — stacked so each gets full width ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.place_rounded,
                      iconColor: const Color(0xFF0D9488),
                      bgColor:
                          const Color(0xFF0D9488).withValues(alpha: 0.1),
                      text: locationStr.isNotEmpty ? locationStr : '-',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 7),
                    _infoRow(
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFF1D4ED8),
                      bgColor:
                          const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                      text: scheduleStr.isNotEmpty ? scheduleStr : '-',
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              // ── Footer ──
              Container(
                height: 1,
                color: const Color(0xFFF1F5F9),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: goToDetail,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: showDetail
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              showDetail
                                  ? Icons.visibility_rounded
                                  : Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: showDetail
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                            if (showDetail) ...[
                              const SizedBox(width: 5),
                              Text(
                                LanguageService.tr('view_detail'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String text,
    int maxLines = 1,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 38,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              LanguageService.tr('no_requests'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ditemukan hasil untuk\n"$_searchQuery"'
                  : 'Belum ada histori permintaan\npelayanan yang ditemukan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _isSearchActive = false;
                  _filterStatus = 'SEMUA';
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Reset Pencarian',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
