import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'UMAT';

  // Jabatan Kondisional
  String? _selectedUmatPosition; // null (Anggota Umat), 'KETUA', 'WAKIL', 'SEKRETARIS'
  String _selectedRomoOrdoPosition = 'ROMO_BIASA'; // 'KETUA_ROMO', 'ROMO_BIASA'
  String _selectedRomoParokiPosition = 'ROMO_BIASA'; // 'KETUA_ROMO', 'ROMO_BIASA'

  bool _isLoading = false;
  bool _isLoadingRoles = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  List<Map<String, String>> _roleOptions = [];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _loadRoles();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
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

  void _loadRoles() async {
    final roles = await ApiService.getRoles();
    if (!mounted) return;
    setState(() {
      _roleOptions = roles;
      _isLoadingRoles = false;
      if (_roleOptions.isNotEmpty) {
        _selectedRole = _roleOptions[0]['code']!;
      }
    });
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon periksa kembali inputan form yang belum sesuai!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    var phone = _phoneController.text.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    final fullPhone = '62$phone';

    final password = _passwordController.text.trim();

    String finalRoleCode = _selectedRole;
    String? pengurusPosition;
    String? romoPosition;

    if (_selectedRole == 'UMAT' || _selectedRole == 'PENGURUS_LINGKUNGAN' || _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      if (_selectedUmatPosition != null && _selectedUmatPosition!.isNotEmpty) {
        pengurusPosition = _selectedUmatPosition;
        if (_selectedRole == 'UMAT') {
          finalRoleCode = 'PENGURUS_LINGKUNGAN';
        }
      }
    } else if (_selectedRole == 'ROMO_ORDO') {
      romoPosition = _selectedRomoOrdoPosition;
    } else if (_selectedRole == 'ROMO_PAROKI') {
      romoPosition = _selectedRomoParokiPosition;
    }

    setState(() => _isLoading = true);
    final res = await ApiService.register(
      fullName: name,
      phoneNumber: fullPhone,
      password: password,
      roleCode: finalRoleCode,
      pengurusPosition: pengurusPosition,
      romoPosition: romoPosition,
    );
    setState(() => _isLoading = false);

    if (res['statusCode'] == 201 || res['user'] != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Registrasi berhasil! Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Kembali ke Login
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Registrasi Gagal'),
          backgroundColor: Colors.red,
        ),
      );
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

  Widget _buildPositionDropdown() {
    if (_selectedRole == 'UMAT' || _selectedRole == 'PENGURUS_LINGKUNGAN' || _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      return DropdownButtonFormField<String?>(
        value: _selectedUmatPosition,
        decoration: _inputDecoration(
          labelText: 'Jabatan / Peran Umat',
          prefix: const Icon(Icons.badge_outlined, color: AppConstants.primaryBlue),
        ),
        items: const [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Anggota Umat', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
          DropdownMenuItem<String?>(
            value: 'KETUA',
            child: Text('Ketua Lingkungan', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
          DropdownMenuItem<String?>(
            value: 'WAKIL',
            child: Text('Wakil Ketua Lingkungan', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
          DropdownMenuItem<String?>(
            value: 'SEKRETARIS',
            child: Text('Sekretaris Lingkungan', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
        ],
        onChanged: (val) {
          setState(() => _selectedUmatPosition = val);
        },
      );
    } else if (_selectedRole == 'ROMO_ORDO') {
      return DropdownButtonFormField<String>(
        value: _selectedRomoOrdoPosition,
        decoration: _inputDecoration(
          labelText: 'Jabatan Romo Ordo',
          prefix: const Icon(Icons.military_tech_outlined, color: AppConstants.primaryBlue),
        ),
        items: const [
          DropdownMenuItem<String>(
            value: 'KETUA_ROMO',
            child: Text('Ketua Ordo', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
          DropdownMenuItem<String>(
            value: 'ROMO_BIASA',
            child: Text('Romo Ordo Biasa', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedRomoOrdoPosition = val);
        },
      );
    } else if (_selectedRole == 'ROMO_PAROKI') {
      return DropdownButtonFormField<String>(
        value: _selectedRomoParokiPosition,
        decoration: _inputDecoration(
          labelText: 'Jabatan Romo Paroki',
          prefix: const Icon(Icons.church_outlined, color: AppConstants.primaryBlue),
        ),
        items: const [
          DropdownMenuItem<String>(
            value: 'KETUA_ROMO',
            child: Text('Pastor Kepala (Ketua Paroki)', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
          DropdownMenuItem<String>(
            value: 'ROMO_BIASA',
            child: Text('Romo Paroki Biasa (Pastor Rekan)', style: TextStyle(fontSize: 14, color: AppConstants.textDark)),
          ),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedRomoParokiPosition = val);
        },
      );
    }
    return const SizedBox.shrink();
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
              constraints: const BoxConstraints(maxWidth: 440),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/logoCatu.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Silakan isi data registrasi di bawah ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppConstants.textMuted,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 1. Nama Lengkap / Username
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            labelText: 'Nama Lengkap / Username',
                            prefix: const Icon(Icons.person_outline_rounded, color: AppConstants.primaryBlue),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            if (value.trim().length < 3) {
                              return 'Nama minimal 3 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Nomor WhatsApp / HP dengan Bendera Indonesia 🇮🇩 +62 Readonly
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

                        // 3. Password
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
                        const SizedBox(height: 16),

                        // 4. Konfirmasi Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: _inputDecoration(
                            labelText: 'Konfirmasi Password',
                            prefix: const Icon(Icons.lock_reset_rounded, color: AppConstants.primaryBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Konfirmasi Password wajib diisi';
                            }
                            if (value.trim() != _passwordController.text.trim()) {
                              return 'Password dan Konfirmasi Password tidak cocok!';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 5. Pilih Role Utama (Kategori Umat / Romo)
                        _isLoadingRoles
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : DropdownButtonFormField<String>(
                                value: _roleOptions.any((r) => r['code'] == _selectedRole)
                                    ? _selectedRole
                                    : (_roleOptions.isNotEmpty ? _roleOptions[0]['code'] : null),
                                decoration: _inputDecoration(
                                  labelText: 'Pilih Role Utama',
                                  prefix: const Icon(Icons.assignment_ind_outlined, color: AppConstants.primaryBlue),
                                ),
                                items: _roleOptions.map((role) {
                                  return DropdownMenuItem<String>(
                                    value: role['code'],
                                    child: Text(
                                      role['label']!,
                                      style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                                    ),
                                  );
                                }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Silakan pilih role akun';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedRole = val;
                                      _selectedUmatPosition = null;
                                      _selectedRomoOrdoPosition = 'ROMO_BIASA';
                                      _selectedRomoParokiPosition = 'ROMO_BIASA';
                                    });
                                  }
                                },
                              ),
                        const SizedBox(height: 16),

                        // 6. Jabatan Kondisional berdasarkan Role Pilihan
                        _buildPositionDropdown(),

                        const SizedBox(height: 28),

                        // Submit Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
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
                                  'DAFTAR AKUN',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                        const SizedBox(height: 18),

                        // Back to Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Sudah punya akun?',
                              style: TextStyle(fontSize: 13, color: AppConstants.textMuted),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Masuk di sini',
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
