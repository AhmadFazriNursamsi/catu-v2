import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import 'chat_screen.dart';

enum ChatTimeFilter {
  sevenDays,
  thirtyDays,
  all,
}

enum ChatCategoryFilter {
  all,
  kedukaan,
  perminyakan,
}

class ChatListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Order> orders;

  const ChatListScreen({
    Key? key,
    required this.user,
    required this.orders,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static List<ChatGroupItem>? _cachedGroups;

  List<ChatGroupItem> _chatGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _pollTimer;
  bool _isSilentRefreshing = false;

  // Filter state (Default: 7 Hari Terakhir)
  ChatTimeFilter _timeFilter = ChatTimeFilter.sevenDays;
  ChatCategoryFilter _categoryFilter = ChatCategoryFilter.all;
  bool _onlyUnread = false;
  bool _sortAscending = false;

  int? get _userId {
    final raw = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    return raw != null ? int.tryParse(raw.toString()) : 1;
  }

  String get _userName =>
      widget.user['fullName'] ?? widget.user['full_name'] ?? (_isRomo ? 'Romo' : 'Umat');

  bool get _isRomo {
    final role = (widget.user['roleCode'] ?? widget.user['role_code'] ?? widget.user['role'] ?? '').toString().toUpperCase();
    return role.startsWith('ROMO');
  }

  @override
  void initState() {
    super.initState();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);

    // Instant rendering if cache is available
    if (_cachedGroups != null && _cachedGroups!.isNotEmpty) {
      _chatGroups = List.from(_cachedGroups!);
      _isLoading = false;
    }

    _loadChatGroups();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefreshGroups();
    });
  }

  Future<void> _silentRefreshGroups() async {
    if (!mounted || _isSilentRefreshing || _isLoading) return;
    _isSilentRefreshing = true;
    try {
      final groups = await ApiService.getChatGroups(_userId ?? 1);
      if (mounted) {
        _cachedGroups = groups;
        setState(() {
          _chatGroups = groups;
        });
      }
    } catch (_) {}
    _isSilentRefreshing = false;
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChatGroups() async {
    if (_chatGroups.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final groups = await ApiService.getChatGroups(_userId ?? 1);
      if (mounted) {
        _cachedGroups = groups;
        setState(() {
          _chatGroups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading backend chat groups: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int get _totalUnreadCount {
    return _chatGroups.fold<int>(0, (sum, g) => sum + g.unreadCount);
  }

  List<ChatGroupItem> get _filteredGroups {
    final now = DateTime.now();
    var list = _chatGroups.where((g) {
      // 1. Time range filter (Default: 7 Hari Terakhir)
      if (_timeFilter == ChatTimeFilter.sevenDays) {
        // Always include groups with unread messages so user doesn't miss incoming chat!
        if (g.unreadCount <= 0) {
          final dt = g.lastMessageDateTime;
          if (dt != null) {
            final diff = now.difference(dt);
            if (diff.inDays > 7) return false;
          }
        }
      } else if (_timeFilter == ChatTimeFilter.thirtyDays) {
        if (g.unreadCount <= 0) {
          final dt = g.lastMessageDateTime;
          if (dt != null) {
            final diff = now.difference(dt);
            if (diff.inDays > 30) return false;
          }
        }
      }

      // 2. Only unread filter
      if (_onlyUnread && g.unreadCount <= 0) {
        return false;
      }

      // 3. Category filter
      if (_categoryFilter == ChatCategoryFilter.kedukaan) {
        if (!g.orderCategory.toLowerCase().contains('kedukaan')) return false;
      } else if (_categoryFilter == ChatCategoryFilter.perminyakan) {
        if (!g.orderCategory.toLowerCase().contains('perminyakan')) return false;
      }

      // 4. Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = g.displayTitle.toLowerCase().contains(query) ||
            g.displayServiceDetail.toLowerCase().contains(query) ||
            g.groupTitle.toLowerCase().contains(query) ||
            g.orderTitle.toLowerCase().contains(query) ||
            g.penerimaName.toLowerCase().contains(query) ||
            g.requesterName.toLowerCase().contains(query) ||
            (g.lastMessageText ?? '').toLowerCase().contains(query);
        if (!matches) return false;
      }

      return true;
    }).toList();

    if (_sortAscending) {
      list = list.reversed.toList();
    }

    return list;
  }

  void _showFilterModal() {
    HapticFeedback.mediumImpact();
    ChatTimeFilter tempTime = _timeFilter;
    ChatCategoryFilter tempCat = _categoryFilter;
    bool tempUnread = _onlyUnread;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Pesan Chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempTime = ChatTimeFilter.sevenDays;
                            tempCat = ChatCategoryFilter.all;
                            tempUnread = false;
                          });
                        },
                        child: const Text('Reset', style: TextStyle(color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Rentang Waktu ──
                  const Text(
                    'Rentang Waktu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalFilterChip(
                        label: '7 Hari Terakhir (Default)',
                        selected: tempTime == ChatTimeFilter.sevenDays,
                        onSelected: () => setModalState(() => tempTime = ChatTimeFilter.sevenDays),
                      ),
                      _buildModalFilterChip(
                        label: '30 Hari Terakhir',
                        selected: tempTime == ChatTimeFilter.thirtyDays,
                        onSelected: () => setModalState(() => tempTime = ChatTimeFilter.thirtyDays),
                      ),
                      _buildModalFilterChip(
                        label: 'Semua Waktu',
                        selected: tempTime == ChatTimeFilter.all,
                        onSelected: () => setModalState(() => tempTime = ChatTimeFilter.all),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Kategori Pelayanan ──
                  const Text(
                    'Kategori Pelayanan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalFilterChip(
                        label: 'Semua Kategori',
                        selected: tempCat == ChatCategoryFilter.all,
                        onSelected: () => setModalState(() => tempCat = ChatCategoryFilter.all),
                      ),
                      _buildModalFilterChip(
                        label: 'Misa Kedukaan',
                        selected: tempCat == ChatCategoryFilter.kedukaan,
                        onSelected: () => setModalState(() => tempCat = ChatCategoryFilter.kedukaan),
                      ),
                      _buildModalFilterChip(
                        label: 'Sakramen Perminyakan',
                        selected: tempCat == ChatCategoryFilter.perminyakan,
                        onSelected: () => setModalState(() => tempCat = ChatCategoryFilter.perminyakan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Status Pesan ──
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Hanya Tampilkan Pesan Belum Dibaca',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                    subtitle: Text(
                      _totalUnreadCount > 0 ? '$_totalUnreadCount pesan baru' : 'Tidak ada pesan baru',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: tempUnread,
                    activeTrackColor: const Color(0xFF1E5399),
                    onChanged: (val) => setModalState(() => tempUnread = val),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _timeFilter = tempTime;
                          _categoryFilter = tempCat;
                          _onlyUnread = tempUnread;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5399),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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

  Widget _buildModalFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF334155),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFF1E5399),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? const Color(0xFF1E5399) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGroups;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Cari pesan atau pelayanan...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Row(
                children: [
                  const Text(
                    'Pesan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (_totalUnreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_totalUnreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: const Color(0xFF1E5399),
              size: 24,
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Action Buttons Row (Filter & Sort) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.tune_rounded,
                  label: _hasActiveFilters ? 'Filter (Aktif)' : 'Filter',
                  isActive: _hasActiveFilters,
                  onTap: _showFilterModal,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.swap_vert_rounded,
                  label: _sortAscending ? 'Terlama' : 'Terbaru',
                  isActive: _sortAscending,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _sortAscending = !_sortAscending;
                    });
                  },
                ),
              ],
            ),
          ),

          // ── Quick Filter Pills (Horizontal Scroll) ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildQuickChip(
                  label: '7 Hari',
                  selected: _timeFilter == ChatTimeFilter.sevenDays && !_onlyUnread,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _timeFilter = ChatTimeFilter.sevenDays;
                      _onlyUnread = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  label: '30 Hari',
                  selected: _timeFilter == ChatTimeFilter.thirtyDays && !_onlyUnread,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _timeFilter = ChatTimeFilter.thirtyDays;
                      _onlyUnread = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  label: 'Semua',
                  selected: _timeFilter == ChatTimeFilter.all && !_onlyUnread,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _timeFilter = ChatTimeFilter.all;
                      _onlyUnread = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  label: _totalUnreadCount > 0 ? 'Belum Dibaca ($_totalUnreadCount)' : 'Belum Dibaca',
                  selected: _onlyUnread,
                  badgeCount: _onlyUnread ? null : (_totalUnreadCount > 0 ? _totalUnreadCount : null),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _onlyUnread = !_onlyUnread;
                    });
                  },
                ),
                if (_categoryFilter != ChatCategoryFilter.all) ...[
                  const SizedBox(width: 8),
                  Chip(
                    backgroundColor: const Color(0xFFEEF2FF),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1E5399)),
                    onDeleted: () {
                      setState(() => _categoryFilter = ChatCategoryFilter.all);
                    },
                    label: Text(
                      _categoryFilter == ChatCategoryFilter.kedukaan ? 'Kedukaan' : 'Perminyakan',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E5399)),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Chat List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5399)))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadChatGroups,
                        color: const Color(0xFF1E5399),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 70, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final group = filtered[index];
                            return _buildChatItem(group);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters {
    return _timeFilter != ChatTimeFilter.sevenDays ||
        _categoryFilter != ChatCategoryFilter.all ||
        _onlyUnread;
  }

  Widget _buildQuickChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E5399) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1E5399) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFF1E5399).withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _timeFilter == ChatTimeFilter.sevenDays
                  ? 'Tidak ada pesan dalam 7 hari terakhir.'
                  : 'Belum ada pesan chat pelayanan.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            if (_timeFilter == ChatTimeFilter.sevenDays) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _timeFilter = ChatTimeFilter.all;
                    _onlyUnread = false;
                  });
                },
                icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF1E5399)),
                label: const Text(
                  'Tampilkan Semua Riwayat Chat',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E5399)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1E5399)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: isActive ? Colors.white : const Color(0xFF1E5399)),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF1E5399),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(
            color: isActive ? const Color(0xFF1E5399) : const Color(0xFF1E5399),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: isActive ? const Color(0xFF1E5399) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatGroupItem group) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              groupId: group.groupId,
              orderNumber: group.orderId.toString(),
              userName: _userName,
              userId: _userId,
              isRomo: _isRomo,
              groupItem: group,
            ),
          ),
        ).then((_) => _loadChatGroups());
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1E5399).withValues(alpha: 0.1),
                  backgroundImage: const AssetImage('assets/images/church_1.jpg'),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Middle Content: Title, Judul Permintaan, Last Chat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1: User / Group Title (Perminyakan: a/n penerima, Kedukaan: detail misa)
                  Text(
                    group.displayTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: group.unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Line 2: Dynamic Urgency Icon + Judul Permintaan / Detail Misa • Tanggal
                  Row(
                    children: [
                      Icon(
                        group.urgencyIcon,
                        size: 13,
                        color: group.urgencyColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          group.displayServiceDetail,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Line 3: Checkmark + Last Message Preview with Sender Name
                  Row(
                    children: [
                      Icon(
                        group.unreadCount > 0 ? Icons.done_rounded : Icons.done_all_rounded,
                        size: 14,
                        color: group.unreadCount > 0 ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          group.formatLastMessage(currentUserId: _userId),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: group.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                            color: group.unreadCount > 0 ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right Content: Time & Unread Badge (Matching listChat.png)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  group.formattedLastTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: group.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                    color: group.unreadCount > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                if (group.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${group.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
