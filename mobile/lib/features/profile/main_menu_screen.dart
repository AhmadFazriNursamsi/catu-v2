// CATU — Halaman Menu Utama & Akun (Main Menu Screen)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import 'edit_profile_screen.dart';
import '../admin/pengurus_approval_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const MainMenuScreen({
    Key? key,
    required this.user,
    required this.onRefresh,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _userData;
  bool _isAkunExpanded = true;
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  String _selectedLanguage = 'Bahasa Indonesia';
  String _selectedTheme = 'Terang (Otomatis)';
  bool _notifyPelayanan = true;
  bool _notifyChatRomo = true;

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.user);
    if (LanguageService.currentLanguage.value == 'en') {
      _selectedLanguage = 'English (US)';
    } else if (LanguageService.currentLanguage.value == 'la') {
      _selectedLanguage = 'Lingua Latina';
    } else {
      _selectedLanguage = 'Bahasa Indonesia';
    }
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);

    _fetchFreshUser();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchFreshUser() async {
    try {
      final userId = _userData['id'] ?? _userData['user_id'] ?? 1;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/profile/$userId'),
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['user'] != null && mounted) {
          setState(() {
            _userData = Map<String, dynamic>.from(resData['user']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching fresh user in MainMenuScreen: $e');
    }
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _animController.dispose();
    super.dispose();
  }

  // ── User Data Extractors ──────────────────────────────────────────────────
  String get _userName =>
      _userData['fullName'] ?? _userData['full_name'] ?? 'Umat';

  String get _phoneNumber =>
      _userData['phoneNumber'] ?? _userData['phone_number'] ?? '-';

  String get _email => _userData['email'] ?? 'umat@catu.id';

  String get _pengurusPos =>
      _userData['pengurusPosition'] ?? _userData['pengurus_position'] ?? '';

  String get _accountStatus =>
      _userData['accountStatus'] ?? _userData['account_status'] ?? 'APPROVED';

  bool get _isApproved => _accountStatus == 'APPROVED';

  String get _keuskupan =>
      _userData['keuskupanName'] ?? _userData['keuskupan_name'] ?? 'Keuskupan Agung Jakarta';

  String get _paroki =>
      _userData['parokiName'] ?? _userData['paroki_name'] ?? 'Paroki Alam Sutera - St. Laurensius';

  String get _lingkungan =>
      _userData['lingkunganName'] ?? _userData['lingkungan_name'] ?? 'Lingkungan St. Angela Merici';

  String get _roleCode =>
      _userData['roleCode'] ?? _userData['role_code'] ?? _userData['role'] ?? 'UMAT';

  String get _ordoName {
    final name = _userData['ordoName'] ?? _userData['ordo_name'];
    if (name != null && name.toString().isNotEmpty) return name.toString();
    return 'Serikat Yesus (SJ)';
  }

  String get _romoPos =>
      _userData['romoPosition'] ?? _userData['romo_position'] ?? '';

  String get _positionTitle {
    final code = _roleCode.toUpperCase();
    if (code == 'ROMO_ORDO') {
      return 'Romo Ordo — $_ordoName';
    }
    if (code == 'ROMO_PAROKI' || code.startsWith('ROMO')) {
      if (_romoPos == 'KETUA_ROMO') return 'Romo Paroki — Pastor Kepala';
      return 'Romo Paroki — Pastor Rekan';
    }
    if (_pengurusPos == 'KETUA') return 'Umat — Ketua Lingkungan';
    if (_pengurusPos == 'WAKIL') return 'Umat — Wakil Ketua';
    if (_pengurusPos == 'SEKRETARIS') return 'Umat — Sekretaris';
    return 'Umat (Anggota Lingkungan)';
  }

  String get _periodeText {
    final start = _userData['jabatanStartDate'] ?? _userData['jabatan_start_date'];
    final end = _userData['jabatanEndDate'] ?? _userData['jabatan_end_date'];
    if (start != null && end != null && start.toString().isNotEmpty) {
      return '$start - $end';
    }
    return '2024 - 2027';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: FadeTransition(
          opacity: _fadeIn,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header Bar ──
              SliverToBoxAdapter(child: _buildHeaderBar()),

              // ── User Profile Header Card ──
              SliverToBoxAdapter(child: _buildProfileCard()),

              // ── Menu List Container ──
              SliverToBoxAdapter(child: _buildMenuList()),

              // ── Footer Copyright ──
              SliverToBoxAdapter(child: _buildFooterInfo()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Bar ────────────────────────────────────────────────────────────

  Widget _buildHeaderBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LanguageService.tr('menu_title'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onRefresh();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 19, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Header Card ────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar with Camera Edit Badge
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                  border: Border.all(color: const Color(0xFF1D4ED8), width: 2.5),
                  image: DecorationImage(
                    image: _getAvatarImageProvider(),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _navigateToEditProfile,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // User Name
          Text(
            _userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Position Badge
          Text(
            _positionTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          // Status & Parish Info Pills Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // Verification Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _isApproved
                      ? const Color(0xFF059669).withValues(alpha: 0.1)
                      : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isApproved
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      size: 12,
                      color: _isApproved
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isApproved ? LanguageService.tr('account_approved') : LanguageService.tr('pending_verification'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isApproved
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),

              // Paroki Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _roleCode.toUpperCase() == 'ROMO_ORDO' ? _ordoName : _paroki,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Ubah Profil Pill Button
          GestureDetector(
            onTap: _navigateToEditProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 6),
                  Text(
                    LanguageService.tr('edit_profile'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: _userData,
          onSaved: widget.onRefresh,
        ),
      ),
    );
    _fetchFreshUser();
  }

  ImageProvider _getAvatarImageProvider() {
    final avatar = _userData['avatarUrl'] ?? _userData['avatar_url'];
    if (avatar == null || avatar.toString().isEmpty) {
      return const AssetImage('assets/images/church_1.jpg');
    }
    final urlStr = avatar.toString();
    if (urlStr.startsWith('data:image')) {
      try {
        final base64String = urlStr.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (_) {
        return const AssetImage('assets/images/church_1.jpg');
      }
    }
    if (urlStr.startsWith('http://') || urlStr.startsWith('https://')) {
      return NetworkImage(urlStr);
    }
    if (File(urlStr).existsSync()) {
      return FileImage(File(urlStr));
    }
    return const AssetImage('assets/images/church_1.jpg');
  }

  // ── Menu List Section ──────────────────────────────────────────────────────

  Widget _buildMenuList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_userData['roleCode'] == 'PENGURUS_LINGKUNGAN' ||
              _userData['role_code'] == 'PENGURUS_LINGKUNGAN' ||
              (_userData['pengurusPosition'] != null &&
                  _userData['pengurusPosition'].toString().trim().isNotEmpty) ||
              (_userData['pengurus_position'] != null &&
                  _userData['pengurus_position'].toString().trim().isNotEmpty)) ...[
            _buildMenuItem(
              icon: Icons.how_to_reg_rounded,
              title: 'Persetujuan Umat Lingkungan',
              subtitle: 'Verifikasi pendaftaran umat baru di lingkungan Anda',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PengurusApprovalScreen(user: _userData),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],

          // ── Section 1: 👤 AKUN (Expandable Accordion) ──
          _buildAccordionHeader(
            icon: Icons.account_circle_rounded,
            title: LanguageService.tr('account'),
            isExpanded: _isAkunExpanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isAkunExpanded = !_isAkunExpanded);
            },
          ),

          if (_isAkunExpanded) ...[
            _buildSubMenuItem(
              title: LanguageService.tr('my_profile'),
              subtitle: LanguageService.tr('my_profile_sub'),
              onTap: _navigateToEditProfile,
            ),
            _buildSubMenuItem(
              title: LanguageService.tr('verification'),
              subtitle: LanguageService.tr('verification_sub'),
              onTap: _showVerificationModal,
            ),
            _buildSubMenuItem(
              title: LanguageService.tr('privacy_security'),
              subtitle: LanguageService.tr('privacy_security_sub'),
              onTap: () => _showToast('Fitur Pengaturan Keamanan Aktif'),
            ),
            _buildSubMenuItem(
              title: LanguageService.tr('linked_accounts'),
              subtitle: LanguageService.tr('linked_accounts_sub'),
              onTap: () => _showToast('Nomor WhatsApp aktif dan terhubung'),
            ),
            const SizedBox(height: 6),
          ],

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Section 2: ⚙️ SETELAN ──
          _buildMenuItem(
            icon: Icons.settings_rounded,
            title: LanguageService.tr('app_settings'),
            subtitle: LanguageService.tr('settings_sub'),
            onTap: _showSettingsModal,
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Section 3: 🎧 PUSAT BANTUAN ──
          _buildMenuItem(
            icon: Icons.headset_mic_rounded,
            title: LanguageService.tr('help_center'),
            subtitle: LanguageService.tr('help_center_sub'),
            onTap: _showHelpModal,
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Section 4: ℹ️ TENTANG CATU ──
          _buildMenuItem(
            icon: Icons.info_outline_rounded,
            title: LanguageService.tr('about_app'),
            subtitle: LanguageService.tr('about_app_sub'),
            onTap: _showAboutModal,
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Section 5: 🚪 KELUAR ──
          _buildMenuItem(
            icon: Icons.logout_rounded,
            title: LanguageService.tr('logout'),
            subtitle: LanguageService.tr('logout_sub'),
            titleColor: const Color(0xFFDC2626),
            iconColor: const Color(0xFFDC2626),
            iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.08),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  // ── Accordion Header ──────────────────────────────────────────────────────

  Widget _buildAccordionHeader({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: const Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Menu Item ─────────────────────────────────────────────────────────

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color titleColor = const Color(0xFF0F172A),
    Color iconColor = const Color(0xFF1D4ED8),
    Color? iconBgColor,
  }) {
    final bg = iconBgColor ?? const Color(0xFF1D4ED8).withValues(alpha: 0.1);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // ── Sub Menu Item (Indented under Akun) ───────────────────────────────────

  Widget _buildSubMenuItem({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(72, 10, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // ── Modals & Dialogs ──────────────────────────────────────────────────────

  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
              const Text(
                'Profil Saya',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Nama Lengkap', _userName),
              _buildDetailRow('Nomor HP', _phoneNumber),
              _buildDetailRow('Email', _email),
              _buildDetailRow('Keuskupan', _keuskupan),
              _buildDetailRow('Paroki', _paroki),
              _buildDetailRow('Lingkungan', _lingkungan),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerificationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
              const Text(
                'Verifikasi Data & Jabatan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Status Akun', _isApproved ? 'Disetujui' : 'Menunggu Verifikasi'),
              _buildDetailRow('Jabatan Pengurus', _positionTitle),
              _buildDetailRow('Masa Jabatan', _periodeText),
              _buildDetailRow('Verifikator', 'Sekretariat Paroki / Dewan Paroki'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsModal() {
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
                  Text(
                    LanguageService.tr('app_settings'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchRow(
                    LanguageService.tr('notification_pelayanan'),
                    _notifyPelayanan,
                    (val) {
                      setState(() => _notifyPelayanan = val);
                      setModalState(() {});
                    },
                  ),
                  _buildSwitchRow(
                    LanguageService.tr('notification_chat'),
                    _notifyChatRomo,
                    (val) {
                      setState(() => _notifyChatRomo = val);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    LanguageService.tr('language'),
                    _selectedLanguage,
                    onTap: () => _showLanguagePickerModal(setModalState),
                  ),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    LanguageService.tr('theme'),
                    _selectedTheme,
                    onTap: () => _showThemePickerModal(setModalState),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showToast('✅ Setelan berhasil disimpan');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(LanguageService.tr('close_save'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
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

  void _showLanguagePickerModal(StateSetter parentSetModalState) {
    HapticFeedback.mediumImpact();
    final languages = [
      {'name': 'Bahasa Indonesia', 'code': 'id', 'flag': '🇮🇩', 'subtitle': 'Bahasa utama'},
      {'name': 'English (US)', 'code': 'en', 'flag': '🇺🇸', 'subtitle': 'International English'},
      {'name': 'Lingua Latina', 'code': 'la', 'flag': '🇻🇦', 'subtitle': 'Vatican Latin'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
              Text(
                LanguageService.tr('language'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih bahasa tampilan yang ingin Anda gunakan',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ...languages.map((lang) {
                final isSelected = _selectedLanguage == lang['name'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Text(
                      lang['flag']!,
                      style: const TextStyle(fontSize: 26),
                    ),
                    title: Text(
                      lang['name']!,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      lang['subtitle']!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF1D4ED8), size: 22)
                        : const Icon(Icons.radio_button_unchecked_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final code = lang['code']!;
                      LanguageService.setLanguage(code);
                      setState(() {
                        _selectedLanguage = lang['name']!;
                      });
                      parentSetModalState(() {});
                      Navigator.pop(ctx);
                      _showToast('🌐 ${LanguageService.tr("language")} -> ${lang["name"]}');
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showThemePickerModal(StateSetter parentSetModalState) {
    HapticFeedback.mediumImpact();
    final themes = [
      {
        'name': 'Terang (Otomatis)',
        'icon': Icons.wb_sunny_rounded,
        'subtitle': 'Tampilan terang default'
      },
      {
        'name': 'Gelap (Dark Mode)',
        'icon': Icons.dark_mode_rounded,
        'subtitle': 'Mode malam nyaman di mata'
      },
      {
        'name': 'Ikuti Sistem HP',
        'icon': Icons.settings_suggest_rounded,
        'subtitle': 'Menyesuaikan tema perangkat'
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
              const Text(
                'Pilih Tema Tampilan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sesuaikan skema warna tampilan aplikasi CATU',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ...themes.map((theme) {
                final isSelected = _selectedTheme == theme['name'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1D4ED8).withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(theme['icon'] as IconData,
                          color: isSelected
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF64748B),
                          size: 20),
                    ),
                    title: Text(
                      theme['name'] as String,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      theme['subtitle'] as String,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF1D4ED8), size: 22)
                        : const Icon(Icons.radio_button_unchecked_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedTheme = theme['name'] as String;
                      });
                      parentSetModalState(() {});
                      Navigator.pop(ctx);
                      _showToast('🎨 Tema diubah ke ${theme['name']}');
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showHelpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
              const Text(
                'Pusat Bantuan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.phone_rounded, color: Color(0xFF1D4ED8)),
                title: const Text('Sekretariat Paroki'),
                subtitle: const Text('Hubungi via Telepon / WhatsApp'),
                onTap: () => _showToast('Menghubungi Sekretariat Paroki...'),
              ),
              ListTile(
                leading: const Icon(Icons.help_center_rounded, color: Color(0xFF1D4ED8)),
                title: const Text('Panduan Pengajuan Pelayanan'),
                subtitle: const Text('Langkah pengajuan Perminyakan & Kedukaan'),
                onTap: () => _showToast('Membuka Panduan CATU...'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Icon(Icons.church_rounded, size: 48, color: Color(0xFF1D4ED8)),
              const SizedBox(height: 10),
              const Text(
                'CATU Mobile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sistem Pelayanan Sakramen Gereja Katolik',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Versi Aplikasi', 'v2.4.0 (Build 108)'),
              _buildDetailRow('Pengembang', 'Tim Antigravity / CATU Tech'),
              _buildDetailRow('Hak Cipta', '© 2026 CATU. All Rights Reserved.'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 10),
              Text('Konfirmasi Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun CATU?',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ya, Keluar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildDetailRow(String label, String value, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF94A3B8)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
      String label, bool value, ValueChanged<bool>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF1D4ED8),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'CATU Mobile v2.4.0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 Gereja Katolik. All Rights Reserved.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
