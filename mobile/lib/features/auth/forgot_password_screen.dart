import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  // Step 0: Phone Input | Step 1: OTP Verification | Step 2: New Password | Step 3: Success
  int _currentStep = 0;

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKeyPhone = GlobalKey<FormState>();
  final _formKeyOtp = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Data from backend OTP request
  String _targetPhone = '';
  String _maskedPhone = '';
  String _fullName = '';
  String _demoOtp = '';

  // Password visibility
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  // Countdown timer for Resend OTP
  int _resendCountdown = 60;
  Timer? _timer;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  // ── Step 1: Request OTP ──
  Future<void> _handleRequestOtp() async {
    if (!_formKeyPhone.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    String rawPhone = _phoneController.text.trim();
    if (rawPhone.startsWith('0')) rawPhone = rawPhone.substring(1);
    if (rawPhone.startsWith('62')) rawPhone = rawPhone.substring(2);
    final fullPhone = '62$rawPhone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.requestForgotPasswordOtp(fullPhone);

    setState(() => _isLoading = false);

    if (res['statusCode'] == 200) {
      setState(() {
        _targetPhone = fullPhone;
        _maskedPhone = res['maskedPhone'] ?? fullPhone;
        _fullName = res['fullName'] ?? 'Pengguna';
        _demoOtp = res['demoOtp'] ?? '123456';
        _currentStep = 1;
        _errorMessage = null;
      });
      _startCountdown();
      _animController.reset();
      _animController.forward();
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Nomor WhatsApp tidak terdaftar di sistem CATU.';
      });
    }
  }

  // ── Step 2: Verify OTP ──
  Future<void> _handleVerifyOtp() async {
    if (!_formKeyOtp.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final otp = _otpController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.verifyForgotPasswordOtp(_targetPhone, otp);

    setState(() => _isLoading = false);

    if (res['statusCode'] == 200 && res['verified'] == true) {
      setState(() {
        _currentStep = 2;
        _errorMessage = null;
      });
      _animController.reset();
      _animController.forward();
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Kode OTP tidak valid atau salah.';
      });
    }
  }

  // ── Step 3: Reset Password ──
  Future<void> _handleResetPassword() async {
    if (!_formKeyPassword.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    final newPass = _newPasswordController.text.trim();
    final otp = _otpController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.resetPassword(
      phoneNumber: _targetPhone,
      otpCode: otp,
      newPassword: newPass,
    );

    setState(() => _isLoading = false);

    if (res['statusCode'] == 200) {
      setState(() {
        _currentStep = 3;
        _successMessage = res['message'] ?? 'Kata sandi berhasil diperbarui!';
      });
      _animController.reset();
      _animController.forward();
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Gagal memperbarui kata sandi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Stack(
        children: [
          // ── Header Background ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: screenH * 0.32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
            ),
          ),

          // ── App Bar & Back Button ──
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          if (_currentStep > 0 && _currentStep < 3) {
                            setState(() => _currentStep--);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Lupa Kata Sandi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Step Indicator Bar ──
                if (_currentStep < 3) _buildStepIndicator(),

                // ── Main Card Content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        child: _buildCurrentStepContent(),
                      ),
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

  // ── Step Indicator ──
  Widget _buildStepIndicator() {
    final steps = ['Nomor HP', 'Kode OTP', 'Sandi Baru'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIdx = index ~/ 2;
            final isDone = _currentStep > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: isDone ? const Color(0xFFD97706) : Colors.white.withOpacity(0.2),
              ),
            );
          }
          final stepIdx = index ~/ 2;
          final isActive = _currentStep == stepIdx;
          final isDone = _currentStep > stepIdx;

          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFFD97706)
                  : (isActive ? Colors.white : Colors.white.withOpacity(0.2)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text(
                      '${stepIdx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFF0F172A) : Colors.white70,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Phone();
      case 1:
        return _buildStep2Otp();
      case 2:
        return _buildStep3NewPassword();
      case 3:
      default:
        return _buildStep4Success();
    }
  }

  // ── STEP 1: Phone Input ──
  Widget _buildStep1Phone() {
    return Form(
      key: _formKeyPhone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Avatar
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppConstants.primaryBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppConstants.primaryBlue),
            ),
          ),
          const SizedBox(height: 18),

          const Center(
            child: Text(
              'Reset Kata Sandi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Masukkan nomor WhatsApp terdaftar untuk menerima kode verifikasi OTP.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Error Alert
          if (_errorMessage != null) _buildErrorBanner(_errorMessage!),

          // Input Phone
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppConstants.textDark),
            decoration: InputDecoration(
              labelText: 'Nomor WhatsApp',
              hintText: '8123456789',
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 22, width: 1, color: Colors.grey.shade300),
                  ],
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            ),
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
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRequestOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Kirim Kode OTP',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: OTP Verification ──
  Widget _buildStep2Otp() {
    return Form(
      key: _formKeyOtp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, size: 36, color: Color(0xFFD97706)),
            ),
          ),
          const SizedBox(height: 18),

          const Center(
            child: Text(
              'Verifikasi Kode OTP',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: Text(
              'Kode verifikasi 6-digit telah dikirimkan ke nomor WhatsApp $_maskedPhone atas nama $_fullName.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Demo OTP Quick Fill Banner
          if (_demoOtp.isNotEmpty)
            GestureDetector(
              onTap: () {
                _otpController.text = _demoOtp;
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                          children: [
                            const TextSpan(text: 'Kode OTP Demo: '),
                            TextSpan(
                              text: _demoOtp,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' (Klik untuk isi otomatis)'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Error Alert
          if (_errorMessage != null) _buildErrorBanner(_errorMessage!),

          // Input OTP Field
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 8),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 6) {
                return 'Masukkan 6-digit kode OTP';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Resend Timer
          Center(
            child: _resendCountdown > 0
                ? Text(
                    'Kirim ulang kode dalam ${_resendCountdown}s',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  )
                : TextButton(
                    onPressed: _handleRequestOtp,
                    child: const Text(
                      'Kirim Ulang Kode OTP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryBlue,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Verifikasi Kode OTP',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Create New Password ──
  Widget _buildStep3NewPassword() {
    return Form(
      key: _formKeyPassword,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 36, color: Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 18),

          const Center(
            child: Text(
              'Buat Kata Sandi Baru',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Center(
            child: Text(
              'Masukkan kata sandi baru untuk akun Anda (minimal 6 karakter).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Error Alert
          if (_errorMessage != null) _buildErrorBanner(_errorMessage!),

          // New Password Field
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPass,
            style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
            decoration: InputDecoration(
              labelText: 'Kata Sandi Baru',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppConstants.primaryBlue, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Kata sandi baru wajib diisi';
              }
              if (value.trim().length < 6) {
                return 'Kata sandi minimal 6 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPass,
            style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
            decoration: InputDecoration(
              labelText: 'Konfirmasi Kata Sandi',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppConstants.primaryBlue, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Konfirmasi kata sandi wajib diisi';
              }
              if (value.trim() != _newPasswordController.text.trim()) {
                return 'Konfirmasi kata sandi tidak cocok';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Reset Password Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Simpan Kata Sandi Baru',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 4: Success Screen ──
  Widget _buildStep4Success() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 52, color: Color(0xFF059669)),
        ),
        const SizedBox(height: 20),

        const Text(
          'Kata Sandi Diperbarui!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        Text(
          _successMessage ?? 'Kata sandi Anda telah berhasil diubah. Silakan masuk kembali ke akun Anda.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            child: const Text(
              'Masuk Sekarang',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
