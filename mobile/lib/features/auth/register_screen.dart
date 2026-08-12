import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/fade_slide_route.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'UMAT';
  String? _selectedUmatPosition;
  String _selectedRomoOrdoPosition = 'ROMO_BIASA';
  String _selectedRomoParokiPosition = 'ROMO_BIASA';

  final _startYearController = TextEditingController(text: DateTime.now().year.toString());
  final _endYearController = TextEditingController(text: (DateTime.now().year + 3).toString());
  bool _isJabatanActive = true;

  bool _isLoading = false;
  bool _isLoadingRoles = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  List<Map<String, String>> _roleOptions = [];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _loadRoles();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  bool get _needsMasaJabatan {
    if (_selectedRole == 'ROMO_PAROKI' && _selectedRomoParokiPosition == 'KETUA_ROMO') return true;
    if (_selectedRole == 'ROMO_ORDO' && _selectedRomoOrdoPosition == 'KETUA_ROMO') return true;
    if (_selectedRole == 'UMAT' || _selectedRole == 'PENGURUS_LINGKUNGAN' || _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      if (_selectedUmatPosition == 'KETUA' || _selectedUmatPosition == 'WAKIL' || _selectedUmatPosition == 'SEKRETARIS') {
        return true;
      }
    }
    return false;
  }

  void _onPhoneChanged() {
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

  void _loadRoles() async {
    final roles = await ApiService.getRoles();
    if (!mounted) return;
    setState(() {
      _roleOptions = roles;
      _isLoadingRoles = false;
      if (_roleOptions.isNotEmpty) _selectedRole = _roleOptions[0]['code']!;
    });
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
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
        if (_selectedRole == 'UMAT') finalRoleCode = 'PENGURUS_LINGKUNGAN';
      }
    } else if (_selectedRole == 'ROMO_ORDO') {
      romoPosition = _selectedRomoOrdoPosition;
    } else if (_selectedRole == 'ROMO_PAROKI') {
      romoPosition = _selectedRomoParokiPosition;
    }

    int? jabatanStartYear;
    int? jabatanEndYear;
    bool? isJabatanActive;

    if (_needsMasaJabatan) {
      jabatanStartYear = int.tryParse(_startYearController.text.trim());
      jabatanEndYear = int.tryParse(_endYearController.text.trim());
      isJabatanActive = _isJabatanActive;
    }

    setState(() => _isLoading = true);
    final res = await ApiService.register(
      fullName: name,
      phoneNumber: fullPhone,
      password: password,
      roleCode: finalRoleCode,
      pengurusPosition: pengurusPosition,
      romoPosition: romoPosition,
      jabatanStartYear: jabatanStartYear,
      jabatanEndYear: jabatanEndYear,
      isJabatanActive: isJabatanActive,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['statusCode'] == 201 || res['user'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(res['message'] ?? 'Registrasi berhasil! Silakan login.')),
          ]),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(res['message'] ?? 'Registrasi Gagal')),
          ]),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  InputDecoration _fieldDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: AppConstants.primaryBlue, size: 20),
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

  Widget _buildSectionLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppConstants.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppConstants.primaryBlue,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildPositionDropdown() {
    if (_selectedRole == 'UMAT' || _selectedRole == 'PENGURUS_LINGKUNGAN' || _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      return DropdownButtonFormField<String?>(
        value: _selectedUmatPosition,
        decoration: _fieldDeco(label: 'Jabatan / Peran Umat', icon: Icons.badge_outlined),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        items: const [
          DropdownMenuItem<String?>(value: null, child: Text('Anggota Umat', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(value: 'KETUA', child: Text('Ketua Lingkungan', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(value: 'WAKIL', child: Text('Wakil Ketua Lingkungan', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(value: 'SEKRETARIS', child: Text('Sekretaris Lingkungan', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (val) => setState(() => _selectedUmatPosition = val),
      );
    } else if (_selectedRole == 'ROMO_ORDO') {
      return DropdownButtonFormField<String>(
        value: _selectedRomoOrdoPosition,
        decoration: _fieldDeco(label: 'Jabatan Romo Ordo', icon: Icons.military_tech_outlined),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: 'KETUA_ROMO',
            child: Text('Ketua Ordo', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          DropdownMenuItem(
            value: 'ROMO_BIASA',
            child: Text('Romo Ordo Biasa', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: (val) { if (val != null) setState(() => _selectedRomoOrdoPosition = val); },
      );
    } else if (_selectedRole == 'ROMO_PAROKI') {
      return DropdownButtonFormField<String>(
        value: _selectedRomoParokiPosition,
        decoration: _fieldDeco(label: 'Jabatan Romo Paroki', icon: Icons.church_outlined),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: 'KETUA_ROMO',
            child: Text('Pastor Kepala (Ketua Paroki)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          DropdownMenuItem(
            value: 'ROMO_BIASA',
            child: Text('Romo Paroki Biasa (Pastor Rekan)', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: (val) { if (val != null) setState(() => _selectedRomoParokiPosition = val); },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMasaJabatanAndFlagFields() {
    if (!_needsMasaJabatan) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.date_range_rounded, size: 18, color: AppConstants.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Masa Jabatan & Flag Status',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startYearController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDeco(label: 'Tahun Mulai', icon: Icons.calendar_today_outlined),
                      validator: (val) {
                        if (!_needsMasaJabatan) return null;
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _endYearController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDeco(label: 'Tahun Selesai', icon: Icons.event_outlined),
                      validator: (val) {
                        if (!_needsMasaJabatan) return null;
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isJabatanActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _isJabatanActive ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isJabatanActive ? 'Flag Jabatan: AKTIF' : 'Flag Jabatan: NON-AKTIF',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isJabatanActive ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isJabatanActive,
                      activeColor: AppConstants.primaryBlue,
                      onChanged: (val) => setState(() => _isJabatanActive = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Stack(
        children: [
          // Top decorative gradient header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 200,
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

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        // Title di atas gradient
                        const Text(
                          'Buat Akun CATU',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Isi data diri Anda untuk bergabung',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),

                        // Form Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 24,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [

                                  // ── Seksi: Data Diri ──
                                  _buildSectionLabel('DATA DIRI', Icons.person_outline_rounded),

                                  // Nama Lengkap
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                                    decoration: _fieldDeco(label: 'Nama Lengkap', icon: Icons.person_outline_rounded),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Nama lengkap wajib diisi';
                                      if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Nomor HP
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
                                            const Text('+62', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryBlue)),
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
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) return 'Nomor WhatsApp wajib diisi';
                                      var clean = value.trim();
                                      if (clean.startsWith('0')) clean = clean.substring(1);
                                      if (clean.startsWith('62')) clean = clean.substring(2);
                                      if (!clean.startsWith('8')) return 'Nomor HP harus diawali angka 8';
                                      if (clean.length < 9) return 'Nomor HP minimal 9 digit';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Seksi: Keamanan ──
                                  _buildSectionLabel('KEAMANAN AKUN', Icons.lock_outline_rounded),

                                  // Password
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500, size: 20),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Password wajib diisi';
                                      if (v.trim().length < 6) return 'Password minimal 6 karakter';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  // Konfirmasi Password
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(fontSize: 14, color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: 'Konfirmasi Password',
                                      icon: Icons.lock_reset_rounded,
                                      suffix: IconButton(
                                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade500, size: 20),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Konfirmasi password wajib diisi';
                                      if (v.trim() != _passwordController.text.trim()) return 'Password tidak cocok!';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // ── Seksi: Keanggotaan ──
                                  _buildSectionLabel('KEANGGOTAAN', Icons.church_outlined),

                                  // Role chips + Dropdown
                                  _isLoadingRoles
                                      ? const Center(child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryBlue),
                                        ))
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Role chips
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: _roleOptions.map((role) {
                                                final isSelected = _selectedRole == role['code'];
                                                return GestureDetector(
                                                  onTap: () => setState(() {
                                                    _selectedRole = role['code']!;
                                                    _selectedUmatPosition = null;
                                                    _selectedRomoOrdoPosition = 'ROMO_BIASA';
                                                    _selectedRomoParokiPosition = 'ROMO_BIASA';
                                                  }),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? AppConstants.primaryBlue : const Color(0xFFF7F9FC),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: isSelected ? AppConstants.primaryBlue : Colors.grey.shade200,
                                                        width: isSelected ? 2 : 1,
                                                      ),
                                                      boxShadow: isSelected ? [
                                                        BoxShadow(color: AppConstants.primaryBlue.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))
                                                      ] : [],
                                                    ),
                                                    child: Text(
                                                      role['label']!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: isSelected ? Colors.white : AppConstants.textMuted,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 14),

                                            // Jabatan kondisional
                                            _buildPositionDropdown(),
                                            _buildMasaJabatanAndFlagFields(),
                                          ],
                                        ),

                                  const SizedBox(height: 30),

                                  // Submit Button
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.primaryBlue,
                                        disabledBackgroundColor: AppConstants.primaryBlue.withOpacity(0.6),
                                        elevation: 4,
                                        shadowColor: AppConstants.primaryBlue.withOpacity(0.4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text('DAFTAR AKUN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Link kembali ke Login
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Sudah punya akun?', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                                        child: const Text(
                                          'Masuk di sini',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.primaryBlue),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
