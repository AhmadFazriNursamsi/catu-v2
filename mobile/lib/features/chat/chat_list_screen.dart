import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import 'chat_screen.dart';

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
  List<ChatGroupItem> _chatGroups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  int? get _userId {
    final raw = widget.user['id'] ?? widget.user['userId'] ?? widget.user['user_id'];
    return raw != null ? int.tryParse(raw.toString()) : 1;
  }

  String get _userName =>
      widget.user['fullName'] ?? widget.user['full_name'] ?? 'Umat';

  @override
  void initState() {
    super.initState();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
    _loadChatGroups();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChatGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await ApiService.getChatGroups(_userId ?? 1);
      if (groups.isNotEmpty) {
        if (mounted) {
          setState(() {
            _chatGroups = groups;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading backend chat groups: $e');
    }

    // Fallback: Build chat list from active orders
    final fallbackGroups = _buildFallbackGroupsFromOrders();
    if (mounted) {
      setState(() {
        _chatGroups = fallbackGroups;
        _isLoading = false;
      });
    }
  }

  List<ChatGroupItem> _buildFallbackGroupsFromOrders() {
    if (widget.orders.isEmpty) {
      // Return sample demonstration chat groups
      return [
        ChatGroupItem(
          groupId: 1,
          orderId: 101,
          groupTitle: 'Group Pelayanan Bp. Antonius',
          lastMessageText: 'Romo Fajar Pr telah bergabung ke grup chat.',
          lastMessageAt: '15:30',
          orderTitle: 'Sakramen Perminyakan',
          orderCategory: 'Sakramen Perminyakan',
          orderStatus: 'CONFIRMED',
          scheduledDate: '2026-08-15',
          scheduledTimeStart: '15:30',
          scheduledTimeEnd: '17:00',
          penerimaName: 'Bp. Antonius Subagyo',
          requesterName: 'Maria Subagyo',
          notes: 'Nama Penerima: Bp. Antonius Subagyo',
          unreadCount: 2,
        ),
        ChatGroupItem(
          groupId: 2,
          orderId: 102,
          groupTitle: 'Group Pelayanan Misa Kedukaan',
          lastMessageText: 'Terima kasih Romo, jadwal telah kami konfirmasi.',
          lastMessageAt: '12:15',
          orderTitle: 'Misa Kedukaan',
          orderCategory: 'Misa Kedukaan',
          orderStatus: 'IN_PROGRESS',
          scheduledDate: '2026-08-14',
          scheduledTimeStart: '10:00',
          scheduledTimeEnd: '11:30',
          penerimaName: 'Alm. Yohanes Setiawan',
          requesterName: 'Theresia Setiawan',
          notes: 'Misa: Misa Penutupan Peti | Nama Almarhum: Alm. Yohanes Setiawan',
          unreadCount: 0,
        ),
      ];
    }

    return widget.orders.map((o) {
      return ChatGroupItem(
        groupId: o.id,
        orderId: o.id,
        groupTitle: 'Group Pelayanan ${o.categoryName}',
        lastMessageText: o.status == 'CONFIRMED'
            ? 'Romo telah mengkonfirmasi kehadiran.'
            : 'Grup chat pelayanan aktif.',
        lastMessageAt: 'Hari ini',
        orderTitle: o.categoryName,
        orderCategory: o.categoryName,
        orderStatus: o.status,
        scheduledDate: o.scheduledDate,
        scheduledTimeStart: o.jamMulaiLabel,
        scheduledTimeEnd: o.jamSelesaiLabel,
        penerimaName: o.penerimaName,
        requesterName: _userName,
        notes: o.notes,
        unreadCount: o.status == 'CONFIRMED' ? 1 : 0,
      );
    }).toList();
  }

  List<ChatGroupItem> get _filteredGroups {
    if (_searchQuery.isEmpty) return _chatGroups;
    final query = _searchQuery.toLowerCase();
    return _chatGroups.where((g) {
      return g.displayTitle.toLowerCase().contains(query) ||
          g.displayServiceDetail.toLowerCase().contains(query) ||
          g.groupTitle.toLowerCase().contains(query) ||
          g.orderTitle.toLowerCase().contains(query) ||
          g.penerimaName.toLowerCase().contains(query) ||
          g.requesterName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            : const Text(
                'Pesan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
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
          // ── Filter & Sort Action Buttons Row (Matching Reference listChat.png) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.tune_rounded,
                  label: 'Filter',
                  onTap: () {
                    HapticFeedback.lightImpact();
                  },
                ),
                const SizedBox(width: 14),
                _buildActionButton(
                  icon: Icons.swap_vert_rounded,
                  label: 'Sort',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _chatGroups = _chatGroups.reversed.toList();
                    });
                  },
                ),
              ],
            ),
          ),

          // ── Chat List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 54, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada pesan chat pelayanan.',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChatGroups,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredGroups.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 70, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final group = _filteredGroups[index];
                            return _buildChatItem(group);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: const Color(0xFF1E5399)),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E5399),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: const BorderSide(color: Color(0xFF1E5399), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Line 2: Alert Icon + Judul Permintaan / Detail Misa • Tanggal
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 13, color: Color(0xFFEF4444)),
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

                  // Line 3: Checkmark + Last Message Preview
                  Row(
                    children: [
                      const Icon(Icons.done_all_rounded,
                          size: 14, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          group.lastMessageText ?? 'Isi Chat sebagian yang tampil',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
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
                  group.lastMessageAt ?? '23:59',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                if (group.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E5399),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '${group.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
