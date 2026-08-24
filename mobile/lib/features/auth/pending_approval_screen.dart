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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
        
        if (status == 'APPROVED') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF059669),
              content: Text('🎉 Selamat! Akun Anda telah disetujui oleh Pengurus Lingkungan!'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pushReplacement(
            context,
            FadeSlideRoute(page: HomeScreen(user: body['user'] ?? _currentUser)),
          );
          return;
        } else if (status == 'REJECTED') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: const Text('Akun Anda ditolak oleh Pengurus Lingkungan / Admin. Silakan hubungi admin.'),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFD97706),
              content: Text('Status akun masih MENUNGGU PERSETUJUAN (PENDING) dari Pengurus Lingkungan.'),
            ),
          );
        }
      } else {
        // Fallback: Show informative toast
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD97706),
            content: Text('Status akun masih MENUNGGU PERSETUJUAN (PENDING).'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD97706),
          content: Text('Status saat ini masih Menunggu Persetujuan Pengurus Lingkungan.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _currentUser['fullName'] ?? 'Umat Terdaftar';
    final phone = _currentUser['phoneNumber'] ?? '-';
    final role = _currentUser['roleCode'] ?? 'UMAT';
    final keuskupan = _currentUser['keuskupanName'] ?? '-';
    final paroki = _currentUser['parokiName'] ?? '-';
    final wilayah = _currentUser['wilayahName'] ?? '-';
    final lingkungan = _currentUser['lingkunganName'] ?? '-';

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
              const SizedBox(height: 10),

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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Pendaftaran Anda telah berhasil dicatat di sistem database CATU dan sedang menunggu persetujuan (approval) dari Pengurus Lingkungan Anda.',
                  style: TextStyle(
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
                    const SizedBox(height: 10),
                    _buildInfoRow('Jenis Pengguna', role == 'UMAT' ? 'Umat Katolik' : role),
                    const SizedBox(height: 10),
                    _buildInfoRow('Keuskupan', keuskupan),
                    const SizedBox(height: 10),
                    _buildInfoRow('Paroki', paroki),
                    if (wilayah != '-') ...[
                      const SizedBox(height: 10),
                      _buildInfoRow('Wilayah', wilayah),
                    ],
                    if (lingkungan != '-') ...[
                      const SizedBox(height: 10),
                      _buildInfoRow('Lingkungan', lingkungan),
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
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sesuai ketentuan Gereja Katolik, akun Umat harus diverifikasi oleh Pengurus Lingkungan setempat sebelum dapat mengajukan permohonan sakramen & misa.',
                        style: TextStyle(
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
