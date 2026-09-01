import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const PendingApprovalScreen({super.key, required this.user});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _currentUser;
  bool _isChecking = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _resolveOrdoNameIfNeeded();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _resolveOrdoNameIfNeeded() async {
    final role = _currentUser['roleCode'];
    final currentOrdo = _currentUser['ordoName'] ??
        _currentUser['ordo_name'] ??
        _currentUser['ordo'] ??
        _currentUser['ordoCode'] ??
        _currentUser['ordo_code'];

    if (role == 'ROMO_ORDO' && (currentOrdo == null || currentOrdo.toString().trim().isEmpty || currentOrdo == '-')) {
      final ordoId = _currentUser['ordoId'] ?? _currentUser['ordo_id'];
      try {
        final list = await ApiService.getOrdoList();
        if (list.isNotEmpty) {
          Map<String, dynamic>? matched;
          if (ordoId != null) {
            matched = list.firstWhere(
              (o) => o['id'].toString() == ordoId.toString(),
              orElse: () => list.first,
            );
          } else {
            matched = list.first;
          }
          final found = matched;
          if (found != null && mounted) {
            setState(() {
              _currentUser['ordoName'] = found['name'] ?? found['code'];
            });
          }
        }
      } catch (e) {
        debugPrint('Error resolving Ordo name: $e');
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getApproverTitle(String role, String? romoPos) {
    if (role == 'ROMO_ORDO') {
      return romoPos == 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Ketua Romo Ordo / Admin Aplikasi CATU';
    } else if (role == 'ROMO_PAROKI') {
      return romoPos == 'KETUA_ROMO' ? 'Admin Aplikasi CATU' : 'Kepala Romo Paroki / Admin Aplikasi CATU';
    } else if (role == 'PENGURUS_LINGKUNGAN') {
      return 'Admin Aplikasi CATU';
    } else if (role == 'UMAT') {
      return 'Pengurus Lingkungan';
    }
    return 'Admin / Pengurus';
  }

  String _getNoticeText(String role, String? romoPos) {
    if (role == 'ROMO_ORDO') {
      return romoPos == 'KETUA_ROMO'
          ? 'Pendaftaran Ketua Romo Ordo akan diverifikasi oleh Admin Aplikasi CATU sebelum akun aktif.'
          : 'Pendaftaran Romo Ordo akan diverifikasi oleh Ketua Romo Ordo atau Admin Aplikasi CATU sebelum akun aktif.';
    } else if (role == 'ROMO_PAROKI') {
      return romoPos == 'KETUA_ROMO'
          ? 'Pendaftaran Kepala Romo Paroki akan diverifikasi oleh Admin Aplikasi CATU sebelum akun aktif.'
          : 'Pendaftaran Romo Paroki akan diverifikasi oleh Kepala Romo Paroki atau Admin Aplikasi CATU sebelum akun aktif.';
    } else if (role == 'PENGURUS_LINGKUNGAN') {
      return 'Pendaftaran Pengurus Lingkungan akan diverifikasi oleh Admin Aplikasi CATU sebelum akun aktif.';
    }
    return 'Sesuai ketentuan Gereja Katolik, akun Umat harus diverifikasi oleh Pengurus Lingkungan setempat sebelum dapat mengajukan permohonan sakramen & misa.';
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'ROMO_ORDO':
        return 'Romo Ordo';
      case 'ROMO_PAROKI':
        return 'Romo Paroki';
      case 'PENGURUS_LINGKUNGAN':
        return 'Pengurus Lingkungan';
      case 'UMAT':
        return 'Umat Katolik';
      default:
        return role;
    }
  }

  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true);
    try {
      final phone = _currentUser['phoneNumber'] ?? '';
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/check-status?phone=$phone'),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final status = body['accountStatus'] ?? _currentUser['accountStatus'];
        final updatedUser = body['user'] != null
            ? Map<String, dynamic>.from(body['user'])
            : _currentUser;

        setState(() {
          _currentUser = updatedUser;
        });

        final role = updatedUser['roleCode'] ?? _currentUser['roleCode'] ?? 'UMAT';
        final romoPos = updatedUser['romoPosition'] ?? _currentUser['romoPosition'];
        final approverTitle = _getApproverTitle(role, romoPos);

        if (status == 'APPROVED') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF059669),
              content: Text('🎉 Selamat! Akun Anda telah disetujui oleh $approverTitle!'),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pushReplacement(
            context,
            FadeSlideRoute(page: HomeScreen(user: updatedUser)),
          );
          return;
        } else if (status == 'REJECTED') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text('Akun Anda ditolak oleh $approverTitle. Silakan hubungi admin.'),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFD97706),
              content: Text('Status akun masih MENUNGGU PERSETUJUAN (PENDING) dari $approverTitle.'),
            ),
          );
        }
      } else {
        // Fallback: Show informative toast
        final role = _currentUser['roleCode'] ?? 'UMAT';
        final romoPos = _currentUser['romoPosition'];
        final approverTitle = _getApproverTitle(role, romoPos);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD97706),
            content: Text('Status akun masih MENUNGGU PERSETUJUAN (PENDING) dari $approverTitle.'),
          ),
        );
      }
    } catch (e) {
      final role = _currentUser['roleCode'] ?? 'UMAT';
      final romoPos = _currentUser['romoPosition'];
      final approverTitle = _getApproverTitle(role, romoPos);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD97706),
          content: Text('Status saat ini masih Menunggu Persetujuan dari $approverTitle.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _currentUser['fullName'] ?? 'Terdaftar';
    final phone = _currentUser['phoneNumber'] ?? '-';
    final email = _currentUser['email'];
    final role = _currentUser['roleCode'] ?? 'UMAT';
    final romoPos = _currentUser['romoPosition'];
    final pengurusPos = _currentUser['pengurusPosition'];
    final keuskupan = _currentUser['keuskupanName'];
    final paroki = _currentUser['parokiName'];
    final wilayah = _currentUser['wilayahName'];
    final lingkungan = _currentUser['lingkunganName'];
    final ordo = _currentUser['ordoName'] ??
        _currentUser['ordo_name'] ??
        _currentUser['ordo'] ??
        _currentUser['ordoCode'] ??
        _currentUser['ordo_code'];

    String? positionDisplay;
    if (role == 'ROMO_ORDO' || role == 'ROMO_PAROKI') {
      if (romoPos == 'KETUA_ROMO') {
        positionDisplay = role == 'ROMO_ORDO' ? 'Ketua / Superior Ordo' : 'Kepala Romo Paroki';
      } else if (romoPos == 'ROMO_BIASA') {
        positionDisplay = 'Romo Rekan / Anggota';
      }
    } else if (pengurusPos != null && pengurusPos.toString().isNotEmpty) {
      positionDisplay = pengurusPos.toString();
    }

    final approverTitle = _getApproverTitle(role, romoPos);
    final noticeText = _getNoticeText(role, romoPos);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          'Status Verifikasi Pendaftaran',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
            tooltip: 'Keluar',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 6),

              // Prominent Rebuild Version Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified_outlined, size: 14, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text(
                      'BUILD REVISED: ${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Animated Glowing Hourglass Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      size: 46,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Status Badge Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'STATUS: MENUNGGU PERSETUJUAN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF92400E),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Akun Anda Sedang Ditinjau',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Pendaftaran Anda telah berhasil dicatat di sistem database CATU dan sedang menunggu persetujuan (approval) dari $approverTitle.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // ── Summary Data Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.badge_outlined, color: AppConstants.primaryBlue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Data Pendaftaran Anda',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),

                    _buildInfoRow('Nama Lengkap', fullName),
                    const SizedBox(height: 10),
                    _buildInfoRow('Nomor WhatsApp', phone),
                    if (email != null && email.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow('Email', email.toString()),
                    ],
                    const SizedBox(height: 10),
                    _buildInfoRow('Jenis Pengguna', _formatRoleName(role)),
                    if (positionDisplay != null && positionDisplay.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildInfoRow('Jabatan / Posisi', positionDisplay),
                    ],
                    if (role == 'ROMO_ORDO') ...[
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        'Ordo',
                        (ordo != null && ordo.toString().trim().isNotEmpty && ordo.toString() != '-')
                            ? ordo.toString()
                            : 'Memuat data Ordo...',
                      ),
                    ] else ...[
                      if (keuskupan != null && keuskupan.toString().trim().isNotEmpty && keuskupan.toString() != '-') ...[
                        const SizedBox(height: 10),
                        _buildInfoRow('Keuskupan', keuskupan.toString()),
                      ],
                      if (paroki != null && paroki.toString().trim().isNotEmpty && paroki.toString() != '-') ...[
                        const SizedBox(height: 10),
                        _buildInfoRow('Paroki', paroki.toString()),
                      ],
                      if (role != 'ROMO_PAROKI') ...[
                        if (wilayah != null && wilayah.toString().trim().isNotEmpty && wilayah.toString() != '-') ...[
                          const SizedBox(height: 10),
                          _buildInfoRow('Wilayah', wilayah.toString()),
                        ],
                        if (lingkungan != null && lingkungan.toString().trim().isNotEmpty && lingkungan.toString() != '-') ...[
                          const SizedBox(height: 10),
                          _buildInfoRow('Lingkungan', lingkungan.toString()),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Informative Notice Box ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        noticeText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // Action Button 1: Check Live Status
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isChecking ? null : _checkApprovalStatus,
                  child: _isChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.refresh_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cek Status Persetujuan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Action Button 2: Back to Login
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Kembali ke Halaman Masuk',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Versioning Badge
              Center(
                child: Text(
                  AppConstants.appVersion,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
