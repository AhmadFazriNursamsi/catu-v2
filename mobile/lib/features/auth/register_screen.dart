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

  String _selectedKeuskupan = 'Keuskupan Agung Jakarta';
  String _selectedParoki = 'Paroki Santo Antonius Padua - Otista';
  String _selectedWilayah = 'Wilayah St. Agustinus';
  String _selectedLingkungan = 'Lingkungan St. Agnes 1';
  String _selectedOrdo = 'SJ - Serikat Yesus';

  final _startDateController = TextEditingController(text: '01/01/${DateTime.now().year}');
  final _endDateController = TextEditingController(text: '31/12/${DateTime.now().year + 3}');

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
    _startDateController.dispose();
    _endDateController.dispose();
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

  List<Map<String, dynamic>> _keuskupanList = [];
  List<Map<String, dynamic>> _parokiList = [];
  List<Map<String, dynamic>> _wilayahList = [];
  List<Map<String, dynamic>> _lingkunganList = [];
  List<Map<String, dynamic>> _ordoList = [];

  int? _selectedKeuskupanId;
  int? _selectedParokiId;
  int? _selectedWilayahId;
  int? _selectedLingkunganId;
  int? _selectedOrdoId;

  void _onKeuskupanChanged(int newKeuskupanId) async {
    setState(() {
      _selectedKeuskupanId = newKeuskupanId;
      _selectedParokiId = null;
      _selectedWilayahId = null;
      _selectedLingkunganId = null;
      _parokiList = [];
      _wilayahList = [];
      _lingkunganList = [];
    });
    final paroki = await ApiService.getParokiList(keuskupanId: newKeuskupanId);
    if (!mounted) return;
    setState(() {
      _parokiList = paroki;
      if (_parokiList.isNotEmpty) {
        _selectedParokiId = int.parse(_parokiList[0]['id'].toString());
        _onParokiChanged(_selectedParokiId!);
      }
    });
  }

  void _onParokiChanged(int newParokiId) async {
    setState(() {
      _selectedParokiId = newParokiId;
      _selectedWilayahId = null;
      _selectedLingkunganId = null;
      _wilayahList = [];
      _lingkunganList = [];
    });
    final wilayah = await ApiService.getWilayahList(parokiId: newParokiId);
    if (!mounted) return;
    setState(() {
      _wilayahList = wilayah;
      if (_wilayahList.isNotEmpty) {
        _selectedWilayahId = int.parse(_wilayahList[0]['id'].toString());
        _onWilayahChanged(_selectedWilayahId!);
      }
    });
  }

  void _onWilayahChanged(int newWilayahId) async {
    setState(() {
      _selectedWilayahId = newWilayahId;
      _selectedLingkunganId = null;
      _lingkunganList = [];
    });
    final lingkungan = await ApiService.getLingkunganList(wilayahId: newWilayahId);
    if (!mounted) return;
    setState(() {
      _lingkunganList = lingkungan;
      if (_lingkunganList.isNotEmpty) {
        _selectedLingkunganId = int.parse(_lingkunganList[0]['id'].toString());
      }
    });
  }

  void _loadMasterData() async {
    final keuskupan = await ApiService.getKeuskupanList();
    final ordo = await ApiService.getOrdoList();
    if (!mounted) return;
    setState(() {
      _keuskupanList = keuskupan;
      _ordoList = ordo;
      if (_keuskupanList.isNotEmpty) {
        _selectedKeuskupanId = int.parse(_keuskupanList[0]['id'].toString());
        _onKeuskupanChanged(_selectedKeuskupanId!);
      }
      if (_ordoList.isNotEmpty) {
        _selectedOrdoId = int.parse(_ordoList[0]['id'].toString());
      }
    });
  }

  void _loadRoles() async {
    final roles = await ApiService.getRoles();
    _loadMasterData();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text('Harap lengkapi semua kolom bertanda wajib dengan benar.')),
          ]),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        if (_selectedRole == 'UMAT') finalRoleCode = 'PENGURUS_LINGKUNGAN';
      }
    } else if (_selectedRole == 'ROMO_ORDO') {
      romoPosition = _selectedRomoOrdoPosition;
    } else if (_selectedRole == 'ROMO_PAROKI') {
      romoPosition = _selectedRomoParokiPosition;
    }

    String? jabatanStartDate;
    String? jabatanEndDate;
    int? jabatanStartYear;
    int? jabatanEndYear;

    if (_needsMasaJabatan) {
      jabatanStartDate = _startDateController.text.trim();
      jabatanEndDate = _endDateController.text.trim();
      if (jabatanStartDate.contains('/')) {
        final parts = jabatanStartDate.split('/');
        if (parts.length == 3) jabatanStartYear = int.tryParse(parts[2]);
      }
      if (jabatanEndDate.contains('/')) {
        final parts = jabatanEndDate.split('/');
        if (parts.length == 3) jabatanEndYear = int.tryParse(parts[2]);
      }
    }

    setState(() => _isLoading = true);
    final res = await ApiService.register(
      fullName: name,
      phoneNumber: fullPhone,
      password: password,
      roleCode: finalRoleCode,
      keuskupanId: _selectedKeuskupanId,
      parokiId: _selectedParokiId,
      wilayahId: _selectedWilayahId,
      lingkunganId: _selectedLingkunganId,
      ordoId: _selectedRole == 'ROMO_ORDO' ? _selectedOrdoId : null,
      pengurusPosition: pengurusPosition,
      romoPosition: romoPosition,
      jabatanStartYear: jabatanStartYear,
      jabatanEndYear: jabatanEndYear,
      jabatanStartDate: jabatanStartDate,
      jabatanEndDate: jabatanEndDate,
      isJabatanActive: false, // Flag Jabatan auto PENDING (Menunggu Persetujuan Admin)
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    String responseMsg = 'Registrasi berhasil! Silakan login.';
    if (res['message'] != null) {
      if (res['message'] is List) {
        responseMsg = (res['message'] as List).join(', ');
      } else {
        responseMsg = res['message'].toString();
      }
    }

    final isSuccess = res['statusCode'] == 201 || res['statusCode'] == 200 || res['user'] != null;

    if (isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(responseMsg)),
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
            Expanded(child: Text(responseMsg)),
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

  Widget _buildHierarchyDropdowns() {
    if (_selectedRole == 'UMAT' || _selectedRole == 'PENGURUS_LINGKUNGAN' || _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // 1. Keuskupan
          DropdownButtonFormField<int>(
            value: _selectedKeuskupanId,
            decoration: _fieldDeco(label: 'Keuskupan', icon: Icons.account_balance_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _keuskupanList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onKeuskupanChanged(val);
            },
          ),
          const SizedBox(height: 12),

          // 2. Paroki
          DropdownButtonFormField<int>(
            value: _selectedParokiId,
            decoration: _fieldDeco(label: 'Paroki', icon: Icons.church_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _parokiList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onParokiChanged(val);
            },
          ),
          const SizedBox(height: 12),

          // 3. Wilayah
          DropdownButtonFormField<int>(
            value: _selectedWilayahId,
            decoration: _fieldDeco(label: 'Wilayah', icon: Icons.map_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _wilayahList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onWilayahChanged(val);
            },
          ),
          const SizedBox(height: 12),

          // 4. Lingkungan
          DropdownButtonFormField<int>(
            value: _selectedLingkunganId,
            decoration: _fieldDeco(label: 'Lingkungan', icon: Icons.home_work_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _lingkunganList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedLingkunganId = val);
            },
          ),
          const SizedBox(height: 12),
        ],
      );
    } else if (_selectedRole == 'ROMO_PAROKI') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // 1. Keuskupan
          DropdownButtonFormField<int>(
            value: _selectedKeuskupanId,
            decoration: _fieldDeco(label: 'Keuskupan', icon: Icons.account_balance_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _keuskupanList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onKeuskupanChanged(val);
            },
          ),
          const SizedBox(height: 12),

          // 2. Paroki
          DropdownButtonFormField<int>(
            value: _selectedParokiId,
            decoration: _fieldDeco(label: 'Paroki', icon: Icons.church_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _parokiList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _onParokiChanged(val);
            },
          ),
          const SizedBox(height: 12),
        ],
      );
    } else if (_selectedRole == 'ROMO_ORDO') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // 1. Ordo
          DropdownButtonFormField<int>(
            value: _selectedOrdoId,
            decoration: _fieldDeco(label: 'Ordo / Kongregasi', icon: Icons.workspace_premium_outlined),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            items: _ordoList.map((item) {
              final id = int.parse(item['id'].toString());
              final name = item['name'].toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedOrdoId = val);
            },
          ),
          const SizedBox(height: 12),
        ],
      );
    }
    return const SizedBox.shrink();
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

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppConstants.primaryBlue,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        controller.text = '$day/$month/$year';
      });
    }
  }

  Widget _buildMasaJabatanAndFlagFields() {
    if (!_needsMasaJabatan) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, size: 18, color: AppConstants.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Periode Masa Jabatan',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Ketuk kolom untuk memilih tanggal mulai & selesai',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 2 Column Layout for Masa Jabatan (Mulai & Selesai)
              Row(
                children: [
                  // Kolom 1: Tanggal Mulai
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(_startDateController),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 13, color: AppConstants.primaryBlue),
                                SizedBox(width: 4),
                                Text(
                                  'TGL MULAI',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.primaryBlue, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startDateController.text.isEmpty ? 'DD/MM/YYYY' : _startDateController.text,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Kolom 2: Tanggal Selesai
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(_endDateController),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.event_available_outlined, size: 13, color: AppConstants.primaryBlue),
                                SizedBox(width: 4),
                                Text(
                                  'TGL SELESAI',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.primaryBlue, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endDateController.text.isEmpty ? 'DD/MM/YYYY' : _endDateController.text,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // User friendly Admin verification status card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.verified_user_outlined, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Jabatan: Menunggu Verifikasi Admin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Jabatan ini akan diverifikasi & diaktifkan oleh Admin setelah pendaftaran Anda disetujui.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD97706),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
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

                                            // Dropdown Hirarki Kondisional (Keuskupan/Paroki/Wilayah/Lingkungan atau Ordo)
                                            _buildHierarchyDropdowns(),

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
