import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import '../orders/order_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final int groupId;
  final String orderNumber;
  final String userName;
  final int? userId;
  final bool isRomo;
  final ChatGroupItem? groupItem;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.orderNumber,
    required this.userName,
    this.userId,
    this.isRomo = false,
    this.groupItem,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
    _loadMessages();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await ApiService.getGroupMessages(widget.groupId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  List<ChatMessage> _buildInitialDemoMessages() {
    return [
      ChatMessage(
        id: 1,
        chatGroupId: widget.groupId,
        senderName: null,
        messageType: 'SYSTEM_EVENT',
        message: 'Grup chat pelayanan telah otomatis dibentuk oleh sistem.',
        createdAt: '2026-08-13T10:00:00Z',
      ),
      ChatMessage(
        id: 2,
        chatGroupId: widget.groupId,
        senderName: 'Theresia (Pemohon)',
        messageType: 'TEXT',
        message: 'Selamat siang Romo, kami memohon bimbingan dan ketersediaan pelayanan.',
        createdAt: '2026-08-13T10:05:00Z',
      ),
      ChatMessage(
        id: 3,
        chatGroupId: widget.groupId,
        senderName: null,
        messageType: 'SYSTEM_EVENT',
        message: 'Romo Fajar Pr telah mengkonfirmasi kehadiran dan bergabung dalam grup chat.',
        createdAt: '2026-08-13T10:10:00Z',
      ),
      ChatMessage(
        id: 4,
        chatGroupId: widget.groupId,
        senderName: 'Romo Fajar Pr',
        messageType: 'TEXT',
        message: 'Berkah Dalem. Baik Ibu Theresia, saya siap mendampingi pelayanan ini sesuai jadwal.',
        createdAt: '2026-08-13T10:12:00Z',
      ),
    ];
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentSenderId = widget.userId ?? 1;

    _messageController.clear();
    final newMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      chatGroupId: widget.groupId,
      senderId: currentSenderId,
      senderName: widget.userName,
      messageType: 'TEXT',
      message: text,
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages.add(newMsg);
    });
    _scrollToBottom();

    await ApiService.sendChatMessage(
      widget.groupId,
      'TEXT',
      text,
      senderId: currentSenderId,
    );

    final backendMsgs = await ApiService.getGroupMessages(widget.groupId);
    if (mounted && backendMsgs.isNotEmpty) {
      setState(() {
        _messages = backendMsgs;
      });
      _scrollToBottom();
    }
  }

  void _simulateAttachment(String type) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(type == 'CAMERA'
            ? '📸 Membuka Kamera untuk lampiran foto...'
            : '📄 Membuka Dokumen untuk lampiran file...'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDayAndDate(String dateStr) {
    if (dateStr.isEmpty) return 'Kamis, 13/08/2026';
    try {
      final dt = DateTime.parse(dateStr);
      final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final dayName = days[dt.weekday - 1];
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dayName, $dd/$mm/$yyyy';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTimeOnly(String timeStr) {
    if (timeStr.isEmpty) return '13:30';
    if (timeStr.length >= 5 && timeStr.contains(':')) {
      return timeStr.substring(0, 5);
    }
    return timeStr;
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFFDCFCE7); // Soft Green
      case 'IN_PROGRESS':
        return const Color(0xFFDBEAFE); // Soft Blue
      case 'DONE':
        return const Color(0xFFEDE9FE); // Soft Purple
      case 'CLOSE':
        return const Color(0xFFF1F5F9); // Soft Slate
      case 'FAIL':
        return const Color(0xFFFEE2E2); // Soft Red
      case 'PENDING':
      default:
        return const Color(0xFFFEF3C7); // Soft Amber
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return const Color(0xFF15803D); // Dark Green
      case 'IN_PROGRESS':
        return const Color(0xFF1D4ED8); // Dark Blue
      case 'DONE':
        return const Color(0xFF6D28D9); // Dark Purple
      case 'CLOSE':
        return const Color(0xFF475569); // Dark Slate
      case 'FAIL':
        return const Color(0xFFB91C1C); // Dark Red
      case 'PENDING':
      default:
        return const Color(0xFFB45309); // Dark Amber
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'MENUNGGU KONFIRMASI';
      case 'CONFIRMED':
        return 'DIKONFIRMASI';
      case 'IN_PROGRESS':
        return 'SEDANG BERLANGSUNG';
      case 'DONE':
        return 'SELESAI';
      case 'CLOSE':
        return 'DITUTUP';
      case 'FAIL':
        return 'GAGAL / BATAL';
      default:
        return status.toUpperCase();
    }
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '15:30';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      if (raw.length >= 16 && raw.contains('T')) {
        return raw.substring(11, 16);
      }
      return '15:30';
    }
  }

  void _showGroupMembersModal() {
    HapticFeedback.selectionClick();
    final groupId = widget.groupItem?.groupId ?? widget.groupId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GroupMembersBottomSheet(
        groupId: groupId,
        groupTitle: widget.groupItem?.displayTitle ?? 'Group Pelayanan',
        penerimaName: widget.groupItem?.penerimaOrDeceasedName ?? widget.userName,
        requesterName: widget.groupItem?.requesterName ?? widget.userName,
        orderStatus: widget.groupItem?.orderStatus ?? 'PENDING',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.groupItem;
    final String mainTitle = group?.displayTitle ?? 'Group Pelayanan';
    final String rawStatus = group?.orderStatus ?? 'PENDING';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _showGroupMembersModal,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage('assets/images/church_1.jpg'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mainTitle,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E5399)),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sticky Header Card / Pinned Banner (Clickable -> Detail Pelayanan) ──
          InkWell(
            onTap: () async {
              HapticFeedback.selectionClick();
              final orderId = group?.orderId ?? widget.groupId;
              final order = await ApiService.getOrderById(orderId);
              if (context.mounted) {
                if (order != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        order: order,
                        userName: widget.userName,
                        isRomo: widget.isRomo,
                        romoId: widget.isRomo ? widget.userId : null,
                      ),
                    ),
                  );
                } else {
                  final fallbackOrder = Order(
                    id: orderId,
                    userId: widget.userId,
                    orderNumber: widget.orderNumber,
                    categoryName: group?.orderCategory ?? 'Pelayanan',
                    urgencyName: 'Biasa',
                    status: group?.orderStatus ?? 'PENDING',
                    scheduledDate: group?.scheduledDate ?? '',
                    scheduledTime: group?.scheduledTimeStart ?? '',
                    locationName: 'Gereja Paroki St. Laurensius',
                    pemohonName: group?.penerimaName ?? widget.userName,
                    notes: group?.notes ?? '',
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(
                        order: fallbackOrder,
                        userName: widget.userName,
                        isRomo: widget.isRomo,
                        romoId: widget.isRomo ? widget.userId : null,
                      ),
                    ),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF4FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0E1FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        group?.urgencyIcon ?? Icons.info_outline_rounded,
                        size: 16,
                        color: group?.urgencyColor ?? const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          mainTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: Color(0xFF1E5399)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_formatDayAndDate(group?.scheduledDate ?? '')} - ${_formatTimeOnly(group?.scheduledTimeStart ?? '')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(rawStatus),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getStatusTextColor(rawStatus).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getStatusLabel(rawStatus),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: _getStatusTextColor(rawStatus),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Messages Stream ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada pesan obrolan.\nKetik pesan di bawah untuk memulai diskusi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isSystem = msg.messageType == 'SYSTEM_EVENT';
                      final currentUserId = widget.userId;
                      final bool isMe = !isSystem && (
                          (msg.senderId != null && currentUserId != null && msg.senderId == currentUserId) ||
                          (msg.senderName != null && widget.userName.isNotEmpty && msg.senderName == widget.userName) ||
                          (msg.senderId == null && msg.senderName == null)
                      );

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              msg.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment:
                              isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.78,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  // Sent: Dark Blue (#1E5399), Received: White with Blue border (Matching DetailChat.png)
                                  color: isMe
                                      ? const Color(0xFF1E5399)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  border: isMe
                                      ? null
                                      : Border.all(
                                          color: const Color(0xFF1E5399),
                                          width: 1.5,
                                        ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe && msg.senderName != null) ...[
                                      Text(
                                        msg.senderName!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E5399),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      msg.message,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Timestamp & Double Checkmark (Matching DetailChat.png)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTimestamp(msg.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Bottom Input Field Container (Matching Reference DetailChat.png) ──
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1E5399),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Ketik disini',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        // Document / Attachment Icon (📄)
                        IconButton(
                          icon: const Icon(Icons.insert_drive_file_outlined,
                              color: Color(0xFF1E5399), size: 22),
                          onPressed: () => _simulateAttachment('FILE'),
                        ),
                        // Camera Icon (📷)
                        IconButton(
                          icon: const Icon(Icons.camera_alt_outlined,
                              color: Color(0xFF1E5399), size: 22),
                          onPressed: () => _simulateAttachment('CAMERA'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E5399),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMembersBottomSheet extends StatefulWidget {
  final int groupId;
  final String groupTitle;
  final String penerimaName;
  final String requesterName;
  final String orderStatus;

  const _GroupMembersBottomSheet({
    required this.groupId,
    required this.groupTitle,
    required this.penerimaName,
    required this.requesterName,
    required this.orderStatus,
  });

  @override
  State<_GroupMembersBottomSheet> createState() =>
      _GroupMembersBottomSheetState();
}

class _GroupMembersBottomSheetState extends State<_GroupMembersBottomSheet> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final res = await ApiService.getGroupMembers(widget.groupId);
    if (mounted) {
      setState(() {
        _members = res.isNotEmpty ? res : _getDefaultMembers();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getDefaultMembers() {
    final isRomoAccepted = widget.orderStatus.toUpperCase() != 'PENDING';

    final members = <Map<String, dynamic>>[
      {
        'user_id': 1,
        'role_in_group': 'PEMOHON',
        'full_name': widget.penerimaName.isNotEmpty ? widget.penerimaName : widget.requesterName,
        'phone_number': '+62 812-3456-7890',
        'lingkungan_name': 'Pemohon / Penerima Pelayanan',
      },
      {
        'user_id': 3,
        'role_in_group': 'SEKRETARIAT',
        'full_name': 'Sekretariat Paroki St. Laurensius',
        'phone_number': '+62 811-2233-4455',
        'lingkungan_name': 'Sekretariat Paroki',
      },
      {
        'user_id': 4,
        'role_in_group': 'PENGURUS_LINGKUNGAN',
        'full_name': 'Ketua Lingkungan',
        'phone_number': '+62 815-5667-7889',
        'lingkungan_name': 'Pengurus Lingkungan Pemohon',
      },
    ];

    if (isRomoAccepted) {
      members.insert(1, {
        'user_id': 2,
        'role_in_group': 'ROMO',
        'full_name': 'Romo Yohanes, Pr',
        'phone_number': '+62 819-8765-4321',
        'lingkungan_name': 'Romo Paroki St. Laurensius',
      });
    }

    return members;
  }

  Color _getRoleBadgeBg(String role) {
    final r = role.toUpperCase();
    if (r.contains('ROMO')) return const Color(0xFFF3E8FF);
    if (r.contains('PEMOHON') || r.contains('UMAT')) return const Color(0xFFDCFCE7);
    if (r.contains('SEKRETARIAT') || r.contains('ADMIN')) return const Color(0xFFDBEAFE);
    return const Color(0xFFFEF3C7);
  }

  Color _getRoleBadgeText(String role) {
    final r = role.toUpperCase();
    if (r.contains('ROMO')) return const Color(0xFF7C3AED);
    if (r.contains('PEMOHON') || r.contains('UMAT')) return const Color(0xFF15803D);
    if (r.contains('SEKRETARIAT') || r.contains('ADMIN')) return const Color(0xFF1D4ED8);
    return const Color(0xFFB45309);
  }

  String _getRoleLabel(String role) {
    final r = role.toUpperCase();
    if (r.contains('ROMO_ORDO')) return 'ROMO ORDO';
    if (r.contains('ROMO')) return 'ROMO';
    if (r.contains('PEMOHON') || r.contains('UMAT')) return 'PEMOHON';
    if (r.contains('SEKRETARIAT') || r.contains('ADMIN')) return 'SEKRETARIAT';
    if (r.contains('PENGURUS')) return 'PENGURUS LINGKUNGAN';
    return r;
  }

  IconData _getRoleIcon(String role) {
    final r = role.toUpperCase();
    if (r.contains('ROMO')) return Icons.star_rounded;
    if (r.contains('PEMOHON') || r.contains('UMAT')) return Icons.person_rounded;
    if (r.contains('SEKRETARIAT')) return Icons.admin_panel_settings_rounded;
    return Icons.house_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF1E5399),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_members.length} Anggota Grup Pelayanan',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (widget.orderStatus.toUpperCase() == 'PENDING')
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Romo Paroki akan otomatis bergabung ke grup ini setelah mengkonfirmasi dan menerima pelayanan.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Member List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _members.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final m = _members[index];
                      final name = m['full_name']?.toString() ?? 'Anggota';
                      final role = m['role_in_group']?.toString() ?? 'UMAT';
                      final phone = m['phone_number']?.toString() ?? '';
                      final subText = m['lingkungan_name']?.toString() ?? 'Paroki St. Laurensius';

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: _getRoleBadgeBg(role),
                          child: Icon(
                            _getRoleIcon(role),
                            color: _getRoleBadgeText(role),
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRoleBadgeBg(role),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getRoleLabel(role),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleBadgeText(role),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '$subText • $phone',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 20, color: Color(0xFF1E5399)),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Menghubungi $name ($phone)...'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
