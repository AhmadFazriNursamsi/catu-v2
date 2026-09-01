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
  final bool isRomo;
  final int? romoId;

  const HistoriScreen({
    Key? key,
    required this.orders,
    required this.userName,
    required this.onRefresh,
    this.isRomo = false,
    this.romoId,
  }) : super(key: key);

  @override
  State<HistoriScreen> createState() => _HistoriScreenState();
}

class HistoriEntryItem {
  final Order parentOrder;
  final OrderItem? subItem;

  HistoriEntryItem({required this.parentOrder, this.subItem});

  static bool _isDatePassed(String dateStr) {
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

  String get effectiveStatus {
    if (subItem != null) {
      final st = subItem!.status.toUpperCase();
      if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') return st;
      final bool romoAccepted = subItem!.acceptedRomoId != null || parentOrder.acceptedRomoId != null;
      final bool datePassed = _isDatePassed(subItem!.scheduledDate) || _isDatePassed(parentOrder.scheduledDate);
      if (datePassed) {
        return romoAccepted ? 'CLOSE' : 'FAIL';
      }
      return st;
    } else {
      final st = parentOrder.status.toUpperCase();
      if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') return st;
      final bool romoAccepted = parentOrder.acceptedRomoId != null;
      final bool datePassed = _isDatePassed(parentOrder.scheduledDate);
      if (datePassed) {
        return romoAccepted ? 'CLOSE' : 'FAIL';
      }
      return st;
    }
  }
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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFD97706);
      case 'ACCEPTED':
      case 'CONFIRMED':
        return const Color(0xFF059669);
      case 'IN_PROGRESS':
        return const Color(0xFF1D4ED8);
      case 'DONE':
        return const Color(0xFF2563EB);
      case 'CLOSE':
        return const Color(0xFF0D9488);
      case 'FAIL':
      case 'DECLINED':
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Konfirmasi';
      case 'ACCEPTED':
      case 'CONFIRMED':
        return 'Telah Dikonfirmasi';
      case 'IN_PROGRESS':
        return 'Sedang Berlangsung';
      case 'DONE':
        return 'Telah Selesai';
      case 'CLOSE':
        return 'Closed (Ditutup Sistem)';
      case 'FAIL':
        return 'Gagal / Kadaluarsa';
      case 'DECLINED':
      case 'REJECTED':
        return 'Ditolak';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.hourglass_empty_rounded;
      case 'ACCEPTED':
      case 'CONFIRMED':
        return Icons.check_circle_outline_rounded;
      case 'IN_PROGRESS':
        return Icons.directions_run_rounded;
      case 'DONE':
        return Icons.task_alt_rounded;
      case 'CLOSE':
        return Icons.task_alt_rounded;
      case 'FAIL':
      case 'DECLINED':
      case 'REJECTED':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _urgencyColor(String urgencyName) {
    final u = urgencyName.toLowerCase();
    if (u.contains('darurat') || u.contains('sangat')) {
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

  List<HistoriEntryItem> get _historyBaseEntries {
    final List<HistoriEntryItem> entries = [];

    for (final o in widget.orders) {
      final st = o.status.toUpperCase();
      final bool isParentDone = st == 'DONE' || st == 'CLOSE' || st == 'FAIL' || _isDateBeforeToday(o.scheduledDate);

      if (widget.isRomo) {
        if (o.items.isNotEmpty) {
          for (final item in o.items) {
            final itemSt = item.status.toUpperCase();
            if (widget.romoId != null && item.acceptedRomoId != widget.romoId) continue;
            if (item.acceptedRomoId == null) continue;

            if (isParentDone || itemSt == 'DONE' || itemSt == 'CLOSE' || itemSt == 'FAIL' || _isDateBeforeToday(item.scheduledDate)) {
              entries.add(HistoriEntryItem(parentOrder: o, subItem: item));
            }
          }
        } else {
          if (st == 'PENDING') continue;
          if (widget.romoId != null && o.acceptedRomoId != widget.romoId) continue;
          if (o.acceptedRomoId == null) continue;

          if (isParentDone) {
            entries.add(HistoriEntryItem(parentOrder: o, subItem: null));
          }
        }
      } else {
        // Umat / Parishioner
        if (o.items.isNotEmpty) {
          for (final item in o.items) {
            final itemSt = item.status.toUpperCase();
            if (isParentDone || itemSt == 'DONE' || itemSt == 'CLOSE' || itemSt == 'FAIL' || _isDateBeforeToday(item.scheduledDate)) {
              entries.add(HistoriEntryItem(parentOrder: o, subItem: item));
            }
          }
        } else {
          if (isParentDone || o.isHistoryOrder) {
            entries.add(HistoriEntryItem(parentOrder: o, subItem: null));
          }
        }
      }
    }

    return entries;
  }

  List<HistoriEntryItem> get _filtered {
    List<HistoriEntryItem> result = _historyBaseEntries;

    // Filter by status
    if (_filterStatus != 'SEMUA') {
      result = result.where((e) => e.effectiveStatus == _filterStatus).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) {
        final o = e.parentOrder;
        final subName = e.subItem?.itemName ?? '';
        return o.penerimaName.toLowerCase().contains(q) ||
            o.categoryName.toLowerCase().contains(q) ||
            subName.toLowerCase().contains(q) ||
            o.displayAddress.toLowerCase().contains(q) ||
            o.orderNumber.toLowerCase().contains(q);
      }).toList();
    }

    // Sort
    if (_sortBy == 'TERBARU') {
      result.sort((a, b) {
        final idA = a.subItem?.id ?? a.parentOrder.id;
        final idB = b.subItem?.id ?? b.parentOrder.id;
        return idB.compareTo(idA);
      });
    } else if (_sortBy == 'TERLAMA') {
      result.sort((a, b) {
        final idA = a.subItem?.id ?? a.parentOrder.id;
        final idB = b.subItem?.id ?? b.parentOrder.id;
        return idA.compareTo(idB);
      });
    } else if (_sortBy == 'STATUS') {
      result.sort((a, b) => a.effectiveStatus.compareTo(b.effectiveStatus));
    }

    return result;
  }

  // ── Summary counts ──────────────────────────────────────────────────────────

  Map<String, int> get _summaryCounts {
    final all = _historyBaseEntries;
    return {
      'total': all.length,
      'pending': all
          .where((e) => e.effectiveStatus == 'PENDING')
          .length,
      'berlangsung': all
          .where((e) =>
              e.effectiveStatus == 'CONFIRMED' ||
              e.effectiveStatus == 'IN_PROGRESS')
          .length,
      'selesai': all
          .where((e) => e.effectiveStatus == 'DONE' || e.effectiveStatus == 'FAIL' || e.effectiveStatus == 'CLOSE')
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

  Widget _buildOrderCard(HistoriEntryItem entry, int index) {
    final order = entry.parentOrder;
    final displayItem = entry.subItem;

    final String effectiveStatus = entry.effectiveStatus;
    final statusColor = _statusColor(effectiveStatus);
    final statusLabel = _statusLabel(effectiveStatus);
    final statusIcon = _statusIcon(effectiveStatus);
    final urgencyColor = _urgencyColor(order.urgencyName);
    final emoji = _categoryShortIcon(order.categoryName);

    String scheduleStr = order.fullScheduleLabel;
    String locationStr = order.displayAddress;
    if (displayItem != null) {
      locationStr = displayItem.locationName.isNotEmpty ? displayItem.locationName : locationStr;
      String t = formatServiceDate(displayItem.scheduledDate);
      if (displayItem.scheduledTimeStart.isNotEmpty) {
        t += ' · ${displayItem.scheduledTimeStart}';
        if (displayItem.scheduledTimeEnd.isNotEmpty) t += '–${displayItem.scheduledTimeEnd} WIB';
      }
      scheduleStr = t;
    }

    final bool isKedukaan = order.categoryName.toLowerCase().contains('kedukaan');
    final String cardTitle = displayItem != null
        ? displayItem.itemName
        : (isKedukaan ? order.penerimaName : order.categoryName);
    final String cardSubtitle = isKedukaan ? order.penerimaName : order.categoryName;
    final bool showDetail = effectiveStatus.toUpperCase() == 'DONE' ||
        effectiveStatus.toUpperCase() == 'CLOSE' ||
        effectiveStatus.toUpperCase() == 'FAIL' ||
        effectiveStatus.toUpperCase() == 'CONFIRMED';

    void goToDetail() async {
      HapticFeedback.lightImpact();
      final bool? refreshed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            order: order,
            userName: widget.userName,
            selectedItemTitle: displayItem?.itemName,
            isRomo: widget.isRomo,
            romoId: widget.romoId,
          ),
        ),
      );
      if (refreshed == true) {
        widget.onRefresh();
      }
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
