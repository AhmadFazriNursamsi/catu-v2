import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../core/services/language_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _backendError;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _animCtrl.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _onPhoneChanged() {
    if (_backendError != null) setState(() => _backendError = null);
    String text = _phoneController.text;
    if (text.startsWith('0')) {
      _updatePhoneText(text.substring(1));
    } else if (text.startsWith('62')) {
      _updatePhoneText(text.substring(2));
    }
  }

  void _updatePhoneText(String newText) {
    _phoneController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    String phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    final fullPhone = '62$phone';

    setState(() {
      _isLoading = true;
      _backendError = null;
    });

    final res = await ApiService.login(fullPhone, password);
    setState(() => _isLoading = false);

    if (res['statusCode'] == 200 && res['user'] != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        FadeSlideRoute(page: HomeScreen(user: res['user'])),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _backendError = res['message'] ?? 'Nomor HP atau Password salah';
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }
  }

  InputDecoration _fieldDeco({
    required String label,
    Widget? prefix,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppConstants.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      errorStyle: TextStyle(color: Colors.red.shade600, fontSize: 11.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 840;

    if (isDesktop) {
      return _buildDesktopWebLayout(context);
    }

    return _buildMobileLayout(context);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 💻 DESKTOP WEB LOGIN (SPLIT SCREEN LUXURY PORTAL)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // ── Sisi Kiri: Hero Branding & Feature Highlights (52% width) ──
          Expanded(
            flex: 52,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/church_1.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Color(0xE60A1128),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & System Pill
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD97706), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'assets/images/logoCatu.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'CATU WEB PORTAL',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'CARI & BANTU PELAYANAN GEREJA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Text(
                          '🔐 Admin & Staff Portal',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Big Headline
                  const Text(
                    'Sistem Informasi & Manajemen\nPelayanan Umat Katolik',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Platform terpadu untuk monitoring pelayanan Misa Kedukaan, Sakramen Perminyakan, serta tata kelola persetujuan umat dan koordinasi lintas paroki.',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 3 Feature Cards
                  _buildWebFeatureItem(
                    icon: Icons.church_rounded,
                    title: 'Integrasi Lintas Paroki & Ordo',
                    subtitle: 'Pengelolaan permintaan pelayanan sakramental secara real-time dan transparan.',
                  ),
                  const SizedBox(height: 16),
                  _buildWebFeatureItem(
                    icon: Icons.verified_user_rounded,
                    title: 'Manajemen Pengguna & Approval Berjenjang',
                    subtitle: 'Verifikasi pendaftaran Umat, Romo, dan Pengurus Lingkungan dengan satu klik.',
                  ),
                  const SizedBox(height: 16),
                  _buildWebFeatureItem(
                    icon: Icons.mark_chat_read_rounded,
                    title: 'Monitoring Group Chat Koordinasi',
                    subtitle: 'Pemantauan grup koordinasi pelayanan WhatsApp-style untuk kelancaran misa.',
                  ),
                  const Spacer(),

                  // Bottom Version Footer
                  Row(
                    children: const [
                      Icon(Icons.shield_rounded, size: 14, color: Color(0xFF94A3B8)),
                      SizedBox(width: 8),
                      Text(
                        'CATU Platform ${AppConstants.appVersion} • PostgreSQL 16 & NestJS v10 Secure Backend',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Sisi Kanan: Clean Admin Login Form Card (48% width) ──
          Expanded(
            flex: 48,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                image: DecorationImage(
                  image: AssetImage('assets/images/cross_banner.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Color(0xF5F8FAFC),
                    BlendMode.srcOver,
                  ),
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: _autovalidateMode,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Official CATU Logo
                            Center(
                              child: Image.asset(
                                'assets/images/logoCatu.png',
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 18),

                            const Center(
                              child: Text(
                                'Masuk Portal Admin',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                'Masukkan nomor WhatsApp / HP dan kata sandi Anda untuk mengakses dashboard manajemen.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error Banner
                            if (_backendError != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _backendError!,
                                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],

                            // Nomor WhatsApp Field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppConstants.textDark),
                              decoration: InputDecoration(
                                labelText: 'Nomor WhatsApp / HP',
                                hintText: '89999999999',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                prefixIcon: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🇮🇩', style: TextStyle(fontSize: 18)),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '+62',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(height: 22, width: 1, color: Colors.grey.shade300),
                                    ],
                                  ),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2)),
                              ),
                              autofillHints: const [AutofillHints.telephoneNumberNational],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nomor WhatsApp wajib diisi';
                                }
                                var clean = value.trim();
                                if (clean.startsWith('0')) clean = clean.substring(1);
                                if (clean.startsWith('62')) clean = clean.substring(2);
                                if (!clean.startsWith('8')) return 'Nomor HP harus diawali angka 8';
                                if (clean.length < 9) return 'Nomor HP minimal 9 digit';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                              decoration: InputDecoration(
                                labelText: 'Kata Sandi',
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1E3A8A), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey.shade500,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2)),
                              ),
                              autofillHints: const [AutofillHints.password],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Kata sandi wajib diisi';
                                }
                                if (value.trim().length < 6) {
                                  return 'Kata sandi minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Lupa Kata Sandi Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    FadeSlideRoute(page: const ForgotPasswordScreen()),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Lupa kata sandi?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Tombol Masuk Portal
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.login_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'MASUK KE PORTAL',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Info Box: Hanya Bisa Login (Tidak Ada Registrasi Web)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Pendaftaran akun umat baru hanya dapat dilakukan melalui Aplikasi Mobile CATU.',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.35),
                                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFeatureItem({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Icon(icon, color: const Color(0xFFD97706), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 📱 MOBILE LAYOUT (APP PHONE)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Stack(
        children: [
          // ── Gradient header background ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: screenH * 0.42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // ── Decorative circle blobs ──
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 60, left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── Hero section ──
                      SizedBox(height: screenH * 0.06),
                      Image.asset(
                        'assets/images/logoCatu.png',
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LanguageService.tr('welcome'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        LanguageService.tr('login_title'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                      SizedBox(height: screenH * 0.05),

                      // ── Form Card ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: AutofillGroup(
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [

                                  // Error banner
                                  if (_backendError != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded,
                                              color: Colors.red.shade700, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _backendError!,
                                              style: TextStyle(
                                                color: Colors.red.shade800,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                  ],

                                  // Nomor HP field
                                  TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                                    decoration: InputDecoration(
                                      labelText: 'Nomor WhatsApp / HP',
                                      hintText: '81234567890',
                                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F9FC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      prefixIcon: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('🇮🇩', style: TextStyle(fontSize: 18)),
                                            const SizedBox(width: 6),
                                            const Text(
                                              '+62',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppConstants.primaryBlue,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(height: 22, width: 1, color: Colors.grey.shade300),
                                          ],
                                        ),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppConstants.primaryBlue, width: 2)),
                                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
                                      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade600, width: 2)),
                                      errorStyle: TextStyle(color: Colors.red.shade600, fontSize: 11.5),
                                    ),
                                    autofillHints: const [AutofillHints.telephoneNumberNational],
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Nomor WhatsApp wajib diisi';
                                      }
                                      var clean = value.trim();
                                      if (clean.startsWith('0')) clean = clean.substring(1);
                                      if (clean.startsWith('62')) clean = clean.substring(2);
                                      if (!clean.startsWith('8')) return 'Nomor HP harus diawali angka 8';
                                      if (clean.length < 9) return 'Nomor HP minimal 9 digit';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Password field
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: LanguageService.tr('password'),
                                      hint: '••••••••',
                                      prefix: const Icon(Icons.lock_outline_rounded,
                                          color: AppConstants.primaryBlue, size: 20),
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.grey.shade500,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    autofillHints: const [AutofillHints.password],
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Password wajib diisi';
                                      }
                                      if (value.trim().length < 6) {
                                        return 'Password minimal 6 karakter';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),

                                  // Lupa Kata Sandi Link
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          FadeSlideRoute(page: const ForgotPasswordScreen()),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Lupa kata sandi?',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppConstants.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Tombol Masuk
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.primaryBlue,
                                        disabledBackgroundColor:
                                            AppConstants.primaryBlue.withOpacity(0.6),
                                        elevation: 4,
                                        shadowColor:
                                            AppConstants.primaryBlue.withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white, strokeWidth: 2.5),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.login_rounded,
                                                    color: Colors.white, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  LanguageService.tr('login_button'),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Divider & Daftar Button (Only shown on Mobile Native App)
                                  if (!kIsWeb) ...[
                                    Row(
                                      children: [
                                        Expanded(child: Divider(color: Colors.grey.shade200)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Text('atau',
                                              style: TextStyle(
                                                  fontSize: 12, color: Colors.grey.shade400)),
                                        ),
                                        Expanded(child: Divider(color: Colors.grey.shade200)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Daftar button
                                    OutlinedButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        FadeSlideRoute(
                                          page: const RegisterScreen(),
                                          beginOffset: const Offset(0, 0.04),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: Text(
                                        LanguageService.tr('register_here'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppConstants.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                 ],
                                ), // Column
                              ), // AutofillGroup
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ── App Version Badge ──
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.build_circle_outlined, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                AppConstants.appVersion,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
