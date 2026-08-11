import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    if (_backendError != null) {
      setState(() => _backendError = null);
    }
    String text = _phoneController.text;
    if (text.startsWith('0')) {
      text = text.substring(1);
      _updatePhoneText(text);
    } else if (text.startsWith('62')) {
      text = text.substring(2);
      _updatePhoneText(text);
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
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
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
        MaterialPageRoute(
          builder: (context) => HomeScreen(user: res['user']),
        ),
      );
    } else {
      if (!mounted) return;
      setState(() {
        _backendError = res['message'] ?? 'Nomor HP atau Password salah';
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
    }
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required Widget prefix,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefix,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppConstants.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade800, width: 2),
      ),
      errorStyle: TextStyle(
        color: Colors.red.shade700,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidateMode,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/logoCatu.png',
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Silakan masuk dengan nomor HP terdaftar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Inline Backend Error Container (Bukan Alert SnackBar)
                        if (_backendError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _backendError!,
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Input Nomor HP dengan Bendera & Prefix Readonly +62
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDecoration(
                            labelText: 'Nomor WhatsApp / HP',
                            hintText: '81234567890',
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 14, right: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇮🇩', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '+62',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppConstants.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 22,
                                    width: 1,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor WhatsApp / HP wajib diisi';
                            }
                            var clean = value.trim();
                            if (clean.startsWith('0')) clean = clean.substring(1);
                            if (clean.startsWith('62')) clean = clean.substring(2);

                            if (!RegExp(r'^\d+$').hasMatch(clean)) {
                              return 'Nomor HP hanya boleh berisi angka (0-9)';
                            }
                            if (!clean.startsWith('8')) {
                              return 'Nomor HP harus diawali angka 8 (contoh: 81234567890)';
                            }
                            if (clean.length < 9) {
                              return 'Nomor HP minimal 9 digit (contoh: 81234567890)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            labelText: 'Password',
                            prefix: const Icon(Icons.lock_outline_rounded, color: AppConstants.primaryBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
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
                        const SizedBox(height: 24),

                        // Submit Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'MASUK SEKARANG',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                        const SizedBox(height: 20),

                        // Register Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Belum punya akun?',
                              style: TextStyle(fontSize: 13, color: AppConstants.textMuted),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              child: const Text(
                                'Daftar Sekarang',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.primaryBlue,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
