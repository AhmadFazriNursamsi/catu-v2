// CATU — Halaman Jadwal Pelayanan (Precision Timeline & Default Today Filter)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import 'order_detail_screen.dart';
import '../../core/services/language_service.dart';
import '../../core/services/api_service.dart';

/// Individual schedule item entry for exact date & time timeline precision
class ScheduleTimelineEntry {
  final Order parentOrder;
  final OrderItem? item;
  final String title;
  final String categoryName;
  final String scheduledDate; // e.g. "2026-08-20"
  final String scheduledTimeStr; // e.g. "18:00 – 19:30 WIB"
  final String locationStr;
  final DateTime? parsedDate;

  ScheduleTimelineEntry({
    required this.parentOrder,
    this.item,
    required this.title,
    required this.categoryName,
    required this.scheduledDate,
    required this.scheduledTimeStr,
    required this.locationStr,
    required this.parsedDate,
  });

  bool get isPastDate {
    final d = parsedDate;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).isBefore(today);
  }
}

class ScheduleScreen extends StatefulWidget {
  final List<Order> orders;
  final String userName;
  final VoidCallback onRefresh;
  final bool isRomo;
  final int? romoId;
  final bool showPendingOnly;

  const ScheduleScreen({
    Key? key,
    required this.orders,
    required this.userName,
    required this.onRefresh,
    this.isRomo = false,
    this.romoId,
    this.showPendingOnly = false,
  }) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────────
  late DateTime _selectedMonth;
  DateTime? _selectedDateFilter; // default = TODAY
  bool _isMonthFilterActive = false;

  String _selectedCategory = 'SEMUA';
  String _selectedStatus = 'SEMUA';
  String _sortBy = 'TERDEKAT';
  String _searchQuery = '';

  late List<Order> _localOrders;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
    _localOrders = List.from(widget.orders);
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    // Default select TODAY for crisp, intuitive schedule viewing
    _selectedDateFilter = DateTime(now.year, now.month, now.day);
    _isMonthFilterActive = true;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void didUpdateWidget(ScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orders != oldWidget.orders) {
      _localOrders = List.from(widget.orders);
    }
  }

  Future<void> _refreshLocalOrders() async {
    try {
      final fetched = await ApiService.getOrders(
        romoId: widget.romoId,
      );
      if (mounted && fetched.isNotEmpty) {
        setState(() {
          _localOrders = fetched;
        });
      } else if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _animController.dispose();
    super.dispose();
  }

  // ── Entry Extraction & Filtering ──────────────────────────────────────────────

  /// Extract all timeline entries from orders (expanded per item)
  List<ScheduleTimelineEntry> get _allRawEntries {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<ScheduleTimelineEntry> entries = [];

    for (final order in _localOrders) {
      if (!order.isActiveDashboardOrder) continue;
      final st = order.status.toUpperCase();
      if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') continue;

      if (order.items.isNotEmpty) {
        for (final item in order.items) {
          if (widget.isRomo) {
            if (widget.showPendingOnly) {
              // Permintaan Masuk: Only show unaccepted items
              if (item.acceptedRomoId != null) continue;
            } else {
              // Jadwal Dikonfirmasi: Only show items accepted by THIS Romo
              if (widget.romoId != null && item.acceptedRomoId != widget.romoId) continue;
              if (item.acceptedRomoId == null) continue;
            }
          }

          DateTime? itemDate;
          if (item.scheduledDate.isNotEmpty) {
            try {
              itemDate = DateTime.parse(item.scheduledDate);
            } catch (_) {}
          }
          itemDate ??= order.parsedDate;

          if (itemDate != null &&
              DateTime(itemDate.year, itemDate.month, itemDate.day)
                  .isBefore(today)) {
            continue; // Exclude past items
          }

          String timeStr = item.scheduledTimeStart;
          if (item.scheduledTimeEnd.isNotEmpty) {
            timeStr = '$timeStr–${item.scheduledTimeEnd} WIB';
          } else if (timeStr.isNotEmpty) {
            timeStr = '$timeStr WIB';
          } else {
            timeStr = order.scheduledTime;
          }

          entries.add(
            ScheduleTimelineEntry(
              parentOrder: order,
              item: item,
              title: item.itemName,
              categoryName: order.categoryName,
              scheduledDate: item.scheduledDate.isNotEmpty
                  ? item.scheduledDate
                  : order.scheduledDate,
              scheduledTimeStr: timeStr,
              locationStr: item.locationName.isNotEmpty
                  ? item.locationName
                  : order.displayAddress,
              parsedDate: itemDate,
            ),
          );
        }
      } else {
        if (widget.isRomo) {
          if (widget.showPendingOnly) {
            if (st != 'PENDING' || order.acceptedRomoId != null) continue;
          } else {
            if (widget.romoId != null && order.acceptedRomoId != widget.romoId) continue;
            if (order.acceptedRomoId == null) continue;
          }
        }

        final orderDate = order.parsedDate;
        if (orderDate != null &&
            DateTime(orderDate.year, orderDate.month, orderDate.day)
                .isBefore(today)) {
          continue;
        }

        entries.add(
          ScheduleTimelineEntry(
            parentOrder: order,
            item: null,
            title: order.categoryName,
            categoryName: order.categoryName,
            scheduledDate: order.scheduledDate,
            scheduledTimeStr: order.fullScheduleLabel,
            locationStr: order.displayAddress,
            parsedDate: orderDate,
          ),
        );
      }
    }

    return entries;
  }

  /// Filtered entries based on active UI selections
  List<ScheduleTimelineEntry> get _filteredEntries {
    List<ScheduleTimelineEntry> list = _allRawEntries;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.parentOrder.penerimaName.toLowerCase().contains(q) ||
            e.categoryName.toLowerCase().contains(q) ||
            e.locationStr.toLowerCase().contains(q) ||
            e.parentOrder.orderNumber.toLowerCase().contains(q);
      }).toList();
    }

    // Filter by selected date pill
    if (_selectedDateFilter != null) {
      list = list.where((e) {
        final d = e.parsedDate;
        if (d == null) return false;
        return d.year == _selectedDateFilter!.year &&
            d.month == _selectedDateFilter!.month &&
            d.day == _selectedDateFilter!.day;
      }).toList();
    } else if (_isMonthFilterActive) {
      // Filter by selected month
      list = list.where((e) {
        final d = e.parsedDate;
        if (d == null) return true;
        return d.year == _selectedMonth.year && d.month == _selectedMonth.month;
      }).toList();
    }

    // Filter by category
    if (_selectedCategory != 'SEMUA') {
      list = list.where((e) {
        final cat = e.categoryName.toLowerCase();
        final title = e.title.toLowerCase();
        final target = _selectedCategory.toLowerCase();
        return cat.contains(target) || title.contains(target);
      }).toList();
    }

    // Filter by status
    if (_selectedStatus != 'SEMUA') {
      list = list
          .where((e) =>
              e.parentOrder.status.toUpperCase() ==
              _selectedStatus.toUpperCase())
          .toList();
    }

    // Sort entries chronologically
    if (_sortBy == 'TERDEKAT') {
      list.sort((a, b) {
        final dA = a.parsedDate ?? DateTime(2099);
        final dB = b.parsedDate ?? DateTime(2099);
        return dA.compareTo(dB);
      });
    } else {
      list.sort((a, b) {
        final dA = a.parsedDate ?? DateTime(1970);
        final dB = b.parsedDate ?? DateTime(1970);
        return dB.compareTo(dA);
      });
    }

    return list;
  }

  /// Group entries by scheduled date string for vertical timeline
  Map<String, List<ScheduleTimelineEntry>> get _groupedEntries {
    final map = <String, List<ScheduleTimelineEntry>>{};
    for (final entry in _filteredEntries) {
      final dateKey = entry.scheduledDate.isNotEmpty
          ? entry.scheduledDate
          : 'Mendatang';
      map.putIfAbsent(dateKey, () => []).add(entry);
    }

    // Sort map keys chronologically
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final dA = DateTime.tryParse(a) ?? DateTime(2099);
        final dB = DateTime.tryParse(b) ?? DateTime(2099);
        return _sortBy == 'TERDEKAT' ? dA.compareTo(dB) : dB.compareTo(dA);
      });

    final sortedMap = <String, List<ScheduleTimelineEntry>>{};
    for (final k in sortedKeys) {
      sortedMap[k] = map[k]!;
    }
    return sortedMap;
  }

  /// Set of day numbers in selected month that have active events
  Set<int> get _daysWithEvents {
    final set = <int>{};
    for (final e in _allRawEntries) {
      final d = e.parsedDate;
      if (d != null &&
          d.year == _selectedMonth.year &&
          d.month == _selectedMonth.month) {
        set.add(d.day);
      }
    }
    return set;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'SEMUA') count++;
    if (_selectedStatus != 'SEMUA') count++;
    if (_selectedDateFilter != null) count++;
    if (_isMonthFilterActive && _selectedDateFilter == null) count++;
    return count;
  }

  // ── Status Helpers ──────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFF0891B2); // cyan
      case 'IN_PROGRESS':
        return const Color(0xFF7C3AED); // ungu
      case 'PENDING':
      default:
        return const Color(0xFFD97706); // oranye
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Kehadiran Dikonfirmasi';
      case 'IN_PROGRESS':
        return 'Berlangsung';
      case 'PENDING':
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
      case 'PENDING':
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _urgencyColor(String urgency) {
    final u = urgency.toLowerCase();
    if (u.contains('darurat') || u.contains('kritis')) {
      return const Color(0xFFDC2626);
    }
    if (u.contains('penting')) return const Color(0xFFD97706);
    return const Color(0xFF1D4ED8);
  }

  String _categoryEmoji(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('kedukaan') || lower.contains('misa')) return '⛪';
    if (lower.contains('minyak') || lower.contains('perminyakan')) return '🕯️';
    if (lower.contains('baptis')) return '✝️';
    return '📿';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedEntries;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: FadeTransition(
          opacity: _fadeIn,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Top Bar ──
              SliverToBoxAdapter(child: _buildTopHeader()),

              // ── Date Strip Carousel & Month Picker ──
              SliverToBoxAdapter(child: _buildDateCarousel()),

              // ── Filter & Sort Action Bar ──
              SliverToBoxAdapter(child: _buildFilterAndSortBar()),

              // ── Active Filter Summary / Counter ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        _selectedDateFilter != null
                            ? 'Jadwal ${_formatDateHeader(_selectedDateFilter!)}'
                            : (_isMonthFilterActive
                                ? 'Jadwal ${_formatMonthYear(_selectedMonth)}'
                                : 'Jadwal Mendatang (${_filteredEntries.length} Pelayanan)'),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      if (_selectedDateFilter != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedDateFilter = null;
                            _isMonthFilterActive = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              LanguageService.tr('view_all_days'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Timeline List ──
              grouped.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == grouped.keys.length) {
                            return const SizedBox(height: 100);
                          }
                          final dateKey = grouped.keys.elementAt(index);
                          final entries = grouped[dateKey]!;
                          return _buildTimelineGroup(dateKey, entries, index);
                        },
                        childCount: grouped.keys.length + 1,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Header ──────────────────────────────────────────────────────────────

  Widget _buildTopHeader() {
    final bool canGoBack = Navigator.canPop(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canGoBack) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showPendingOnly) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.hourglass_top_rounded, size: 11, color: Color(0xFFEA580C)),
                            SizedBox(width: 4),
                            Text(
                              'Menunggu Konfirmasi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEA580C),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  widget.showPendingOnly
                      ? 'Permintaan Pelayanan'
                      : LanguageService.tr('schedule_title'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.showPendingOnly
                      ? 'Daftar permintaan pelayanan paroki yang perlu diproses.'
                      : LanguageService.tr('schedule_subtitle'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date Strip Carousel ──────────────────────────────────────────────────────

  Widget _buildDateCarousel() {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(
        _selectedMonth.year, _selectedMonth.month);
    final daysWithEvents = _daysWithEvents;

    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Month/Year Selector row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),

                // "Hari Ini" chip
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedMonth = DateTime(now.year, now.month, 1);
                      _selectedDateFilter =
                          DateTime(now.year, now.month, now.day);
                      _isMonthFilterActive = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      LanguageService.tr('today_label'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Month Nav Arrows
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month - 1, 1);
                      _selectedDateFilter = null;
                      _isMonthFilterActive = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        size: 20, color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month + 1, 1);
                      _selectedDateFilter = null;
                      _isMonthFilterActive = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        size: 20, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Days Horizontal Scroll List
          SizedBox(
            height: 68,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final dayNum = index + 1;
                final date = DateTime(
                    _selectedMonth.year, _selectedMonth.month, dayNum);

                final todayMidnight = DateTime(now.year, now.month, now.day);
                final isPastDay = date.isBefore(todayMidnight);

                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                final isSelected = _selectedDateFilter != null &&
                    _selectedDateFilter!.year == date.year &&
                    _selectedDateFilter!.month == date.month &&
                    _selectedDateFilter!.day == date.day;

                final hasEvent = daysWithEvents.contains(dayNum);
                final dayAbbr = _getDayAbbr(date.weekday);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: isPastDay
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isSelected) {
                                _selectedDateFilter = null;
                                _isMonthFilterActive = false;
                              } else {
                                _selectedDateFilter = date;
                                _isMonthFilterActive = true;
                              }
                            });
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : (isToday
                                ? const Color(0xFF1D4ED8).withValues(alpha: 0.1)
                                : (isPastDay
                                    ? const Color(0xFFF8FAFC)
                                    : Colors.white)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1D4ED8)
                              : (isToday
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFFE2E8F0)),
                          width: isToday || isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayAbbr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : (isPastDay
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF64748B)),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : (isPastDay
                                      ? const Color(0xFF94A3B8)
                                      : (isToday
                                          ? const Color(0xFF1D4ED8)
                                          : const Color(0xFF0F172A))),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Event Indicator Dot
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: hasEvent
                                  ? (isSelected
                                      ? Colors.white
                                      : const Color(0xFF059669))
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
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

  String _getDayAbbr(int weekday) {
    switch (weekday) {
      case DateTime.monday: return LanguageService.tr('mon');
      case DateTime.tuesday: return LanguageService.tr('tue');
      case DateTime.wednesday: return LanguageService.tr('wed');
      case DateTime.thursday: return LanguageService.tr('thu');
      case DateTime.friday: return LanguageService.tr('fri');
      case DateTime.saturday: return LanguageService.tr('sat');
      case DateTime.sunday: return LanguageService.tr('sun');
      default: return '';
    }
  }

  // ── Filter & Sort Action Bar ─────────────────────────────────────────────

  Widget _buildFilterAndSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Filter Pill Button
          Expanded(
            child: GestureDetector(
              onTap: _showFilterModal,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeFilterCount > 0
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF1D4ED8),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: _activeFilterCount > 0
                          ? Colors.white
                          : const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _activeFilterCount > 0
                          ? '${LanguageService.tr('filter_label')} ($_activeFilterCount)'
                          : LanguageService.tr('filter_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _activeFilterCount > 0
                            ? Colors.white
                            : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Sort Pill Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _sortBy = _sortBy == 'TERDEKAT' ? 'TERJAUH' : 'TERDEKAT';
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF1D4ED8),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.swap_vert_rounded,
                      size: 16,
                      color: Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _sortBy == 'TERDEKAT' ? 'Sort: Terdekat' : 'Sort: Terjauh',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Modal Bottom Sheet ─────────────────────────────────────────────

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Filter Jadwal Pelayanan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _selectedCategory = 'SEMUA';
                            _selectedStatus = 'SEMUA';
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Kategori Filter Section
                  const Text(
                    'Kategori Pelayanan',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalChip('SEMUA', 'Semua Kategori', _selectedCategory,
                          (v) => setModalState(() => _selectedCategory = v)),
                      _buildModalChip('Kedukaan', 'Misa Kedukaan', _selectedCategory,
                          (v) => setModalState(() => _selectedCategory = v)),
                      _buildModalChip('Perminyakan', 'Perminyakan Orang Sakit',
                          _selectedCategory, (v) => setModalState(() => _selectedCategory = v)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Status Filter Section
                  const Text(
                    'Status Konfirmasi',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalChip('SEMUA', 'Semua Status', _selectedStatus,
                          (v) => setModalState(() => _selectedStatus = v)),
                      _buildModalChip('PENDING', LanguageService.tr('status_pending'), _selectedStatus,
                          (v) => setModalState(() => _selectedStatus = v)),
                      _buildModalChip('CONFIRMED', 'Kehadiran Dikonfirmasi', _selectedStatus,
                          (v) => setModalState(() => _selectedStatus = v)),
                      _buildModalChip('IN_PROGRESS', 'Berlangsung', _selectedStatus,
                          (v) => setModalState(() => _selectedStatus = v)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChip(
      String value, String label, String currentVal, Function(String) onSelect) {
    final selected = currentVal == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1D4ED8)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  void _resetAllFilters() {
    setState(() {
      _selectedDateFilter = null;
      _isMonthFilterActive = false;
      _selectedCategory = 'SEMUA';
      _selectedStatus = 'SEMUA';
      _searchQuery = '';
    });
  }

  // ── Timeline Group ──────────────────────────────────────────────────────────

  Widget _buildTimelineGroup(
      String dateKey, List<ScheduleTimelineEntry> entries, int groupIndex) {
    final dateHeader = _formatDateHeaderStr(dateKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Timeline Node Track
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 2,
                height: entries.length * 280.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Right Content Block: Date badge + Schedule cards
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Node Header Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        dateHeader.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entries.length}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                ...entries.map((entry) => _buildScheduleCard(entry)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Schedule Card ────────────────────────────────────────────────────────────

  Widget _buildScheduleCard(ScheduleTimelineEntry entry) {
    final order = entry.parentOrder;
    final bool isItemAccepted = entry.item?.acceptedRomoId != null || order.acceptedRomoId != null;
    final String effectiveStatus = isItemAccepted
        ? (order.status.toUpperCase() == 'DONE' ? 'DONE' : 'CONFIRMED')
        : order.status;
    final statusColor = _statusColor(effectiveStatus);
    final statusLabel = _statusLabel(effectiveStatus);
    final statusIcon = _statusIcon(effectiveStatus);
    final urgencyColor = _urgencyColor(order.urgencyName);
    final emoji = _categoryEmoji(entry.categoryName);

    final bool isKedukaan =
        entry.categoryName.toLowerCase().contains('kedukaan');
    final String cardTitle = entry.title;
    final String cardSubtitle =
        isKedukaan ? order.penerimaName : entry.categoryName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.selectionClick();
          final bool? refreshed = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                order: order,
                userName: widget.userName,
                selectedItemTitle: entry.item?.itemName,
                isRomo: widget.isRomo,
                romoId: widget.romoId,
              ),
            ),
          );
          if (refreshed == true) {
            order.status = 'CONFIRMED';
            if (widget.romoId != null) {
              order.acceptedRomoId = widget.romoId;
            }
            if (widget.showPendingOnly) {
              _localOrders.removeWhere((o) => o.id == order.id);
            }
            if (mounted) {
              setState(() {});
            }
            widget.onRefresh();
            _refreshLocalOrders();
          }
        },
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
              // ── Banner Image Header ──
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 125,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/church_1.jpg',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),

                      // Status Badge pill top-right
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Category Emoji Badge top-left
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),

                      // Location & Schedule Overlay on Banner Bottom
                      Positioned(
                        bottom: 10,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.place_rounded,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.locationStr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                            blurRadius: 4,
                                            color: Colors.black54),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 13, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(
                                  entry.scheduledTimeStr,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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

              // ── Card Body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cardSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.urgencyName,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: urgencyColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                LanguageService.tr('view_detail'),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _formatDateHeader(DateTime dt) {
    final days = [
      'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'
    ];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatMonthYear(DateTime dt) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDateHeaderStr(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'Mendatang') return 'Mendatang';
    try {
      final parsed = DateTime.parse(dateStr);
      return _formatDateHeader(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  // ── Empty State ──────────────────────────────────────────────────────────────

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
                Icons.event_busy_rounded,
                size: 38,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tidak Ada Pelayanan Aktif',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDateFilter != null
                  ? 'Tidak ada pelayanan aktif pada tanggal\n${_formatDateHeader(_selectedDateFilter!)}.'
                  : (_activeFilterCount > 0
                      ? 'Tidak ditemukan pelayanan dengan filter terpilih.'
                      : 'Belum ada jadwal pelayanan aktif mendatang.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            if (_activeFilterCount > 0) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _resetAllFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Reset Semua Filter',
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
