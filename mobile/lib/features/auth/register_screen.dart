import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/fade_slide_route.dart';
import '../../widgets/searchable_select_field.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'UMAT';
  String? _selectedUmatPosition;
  String _selectedRomoOrdoPosition = 'ROMO_BIASA';
  String _selectedRomoParokiPosition = 'ROMO_BIASA';

  List<Map<String, dynamic>> _dynamicProvinsiList = [];
  List<Map<String, dynamic>> _dynamicKotaList = [];
  int? _selectedProvinsiId;
  int? _selectedKabupatenKotaId;

  final _startDateController =
      TextEditingController(text: '01/01/${DateTime.now().year}');
  final _endDateController =
      TextEditingController(text: '31/12/${DateTime.now().year + 3}');

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
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  bool get _needsMasaJabatan {
    if (_selectedRole == 'ROMO_PAROKI' &&
        _selectedRomoParokiPosition == 'KETUA_ROMO') return true;
    if (_selectedRole == 'ROMO_ORDO' &&
        _selectedRomoOrdoPosition == 'KETUA_ROMO') return true;
    if (_selectedRole == 'UMAT' ||
        _selectedRole == 'PENGURUS_LINGKUNGAN' ||
        _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      if (_selectedUmatPosition == 'KETUA' ||
          _selectedUmatPosition == 'WAKIL' ||
          _selectedUmatPosition == 'SEKRETARIS' ||
          _selectedUmatPosition == 'BENDAHARA') {
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
    final parokis = await ApiService.getParoki(keuskupanId: newKeuskupanId);
    setState(() {
      _parokiList = parokis;
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
    final wilayahs = await ApiService.getWilayah(parokiId: newParokiId);
    setState(() {
      _wilayahList = wilayahs;
    });
  }

  void _onWilayahChanged(int newWilayahId) async {
    setState(() {
      _selectedWilayahId = newWilayahId;
      _selectedLingkunganId = null;
      _lingkunganList = [];
    });
    final lingkungans =
        await ApiService.getLingkungan(wilayahId: newWilayahId);
    setState(() {
      _lingkunganList = lingkungans;
    });
  }

  void _onProvinsiChanged(int newProvId) async {
    setState(() {
      _selectedProvinsiId = newProvId;
      _selectedKabupatenKotaId = null;
      _dynamicKotaList = [];
    });
    final kotas = await ApiService.getKabupatenKotaList(provinsiId: newProvId);
    if (mounted) {
      setState(() {
        _dynamicKotaList = kotas;
        if (kotas.isNotEmpty) {
          _selectedKabupatenKotaId = int.tryParse(kotas.first['id'].toString());
        }
      });
    }
  }

  Future<void> _loadRoles() async {
    final roles = await ApiService.getRoles();
    final keuskupans = await ApiService.getKeuskupan();
    final ordos = await ApiService.getOrdo();
    final provs = await ApiService.getProvinsiList();

    if (mounted) {
      setState(() {
        _roleOptions = roles;
        _keuskupanList = keuskupans;
        _ordoList = ordos;
        _dynamicProvinsiList = provs;
        _isLoadingRoles = false;

        if (_keuskupanList.isNotEmpty) {
          _selectedKeuskupanId =
              int.tryParse(_keuskupanList.first['id'].toString());
          if (_selectedKeuskupanId != null) {
            _onKeuskupanChanged(_selectedKeuskupanId!);
          }
        }

        if (_ordoList.isNotEmpty) {
          _selectedOrdoId = int.tryParse(_ordoList.first['id'].toString());
        }

        if (_dynamicProvinsiList.isNotEmpty) {
          _selectedProvinsiId =
              int.tryParse(_dynamicProvinsiList.first['id'].toString());
          if (_selectedProvinsiId != null) {
            _onProvinsiChanged(_selectedProvinsiId!);
          }
        }
      });
    }
  }

  void _onRoleChanged(String roleCode) {
    setState(() {
      _selectedRole = roleCode;
      _selectedUmatPosition = null;
    });
  }

  void _handleRegister() async {
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    var phone = _phoneController.text.trim();
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (phone.startsWith('62')) phone = phone.substring(2);
    final fullPhone = '62$phone';
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    final birthDate = _birthDateController.text.trim();
    final address = _addressController.text.trim();

    String finalRoleCode = _selectedRole;
    String? pengurusPosition;
    String? romoPosition;

    if (_selectedRole == 'UMAT' ||
        _selectedRole == 'PENGURUS_LINGKUNGAN' ||
        _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      if (_selectedUmatPosition != null &&
          _selectedUmatPosition!.isNotEmpty) {
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
      fullName: fullName,
      phoneNumber: fullPhone,
      password: password,
      roleCode: finalRoleCode,
      email: email.isNotEmpty ? email : null,
      birthDate: birthDate.isNotEmpty ? birthDate : null,
      address: address.isNotEmpty ? address : null,
      keuskupanId: _selectedKeuskupanId,
      parokiId: _selectedParokiId,
      wilayahId: _selectedWilayahId,
      lingkunganId: _selectedLingkunganId,
      kabupatenKotaId: _selectedKabupatenKotaId,
      ordoId: _selectedRole == 'ROMO_ORDO' ? _selectedOrdoId : null,
      pengurusPosition: pengurusPosition,
      romoPosition: romoPosition,
      jabatanStartYear: jabatanStartYear,
      jabatanEndYear: jabatanEndYear,
      jabatanStartDate: jabatanStartDate,
      jabatanEndDate: jabatanEndDate,
      isJabatanActive: false,
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

    final isSuccess = res['statusCode'] == 201 ||
        res['statusCode'] == 200 ||
        res['user'] != null;

    if (isSuccess) {
      final registeredUser = res['user'] ?? {
        'fullName': fullName,
        'phoneNumber': fullPhone,
        'roleCode': finalRoleCode,
        'accountStatus': 'PENDING_APPROVAL',
      };
      Navigator.pushReplacement(
        context,
        FadeSlideRoute(page: PendingApprovalScreen(user: registeredUser)),
      );
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.only(bottom: 12, top: 12),
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
    if (_selectedRole == 'UMAT' ||
        _selectedRole == 'PENGURUS_LINGKUNGAN' ||
        _selectedRole == 'KOORDINATOR_KEUSKUPAN' ||
        _selectedRole == 'ROMO_PAROKI') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // 1. Keuskupan
          SearchableSelectField<int>(
            label: 'Keuskupan',
            icon: Icons.account_balance_outlined,
            value: _selectedKeuskupanId,
            items: _keuskupanList
                .map((item) => SearchableSelectItem<int>(
                      value: int.parse(item['id'].toString()),
                      label: item['name'].toString(),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) _onKeuskupanChanged(val);
            },
            emptyMessage: 'Keuskupan tidak ditemukan',
          ),

          // 2. Paroki
          SearchableSelectField<int>(
            label: 'Paroki',
            icon: Icons.church_outlined,
            value: _selectedParokiId,
            items: _parokiList
                .map((item) => SearchableSelectItem<int>(
                      value: int.parse(item['id'].toString()),
                      label: item['name'].toString(),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) _onParokiChanged(val);
            },
            emptyMessage: 'Paroki tidak ditemukan pada keuskupan ini',
          ),

          // 3. Wilayah (Hanya untuk Umat & Pengurus Lingkungan)
          if (_selectedRole != 'ROMO_PAROKI') ...[
            SearchableSelectField<int>(
              label: 'Wilayah',
              icon: Icons.map_outlined,
              value: _selectedWilayahId,
              items: _wilayahList
                  .map((item) => SearchableSelectItem<int>(
                        value: int.parse(item['id'].toString()),
                        label: item['name'].toString(),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) _onWilayahChanged(val);
              },
              emptyMessage: 'Wilayah tidak ditemukan pada paroki ini',
            ),

            // 4. Lingkungan
            SearchableSelectField<int>(
              label: 'Lingkungan',
              icon: Icons.groups_outlined,
              value: _selectedLingkunganId,
              items: _lingkunganList
                  .map((item) => SearchableSelectItem<int>(
                        value: int.parse(item['id'].toString()),
                        label: item['name'].toString(),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLingkunganId = val);
              },
              emptyMessage: 'Lingkungan tidak ditemukan pada wilayah ini',
            ),
          ],
        ],
      );
    } else if (_selectedRole == 'ROMO_ORDO') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // 1. Ordo
          SearchableSelectField<int>(
            label: 'Ordo / Kongregasi',
            icon: Icons.workspace_premium_outlined,
            value: _selectedOrdoId,
            items: _ordoList
                .map((item) => SearchableSelectItem<int>(
                      value: int.parse(item['id'].toString()),
                      label: item['name'].toString(),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedOrdoId = val);
            },
            emptyMessage: 'Ordo tidak ditemukan',
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPositionDropdown() {
    if (_selectedRole == 'UMAT' ||
        _selectedRole == 'PENGURUS_LINGKUNGAN' ||
        _selectedRole == 'KOORDINATOR_KEUSKUPAN') {
      return DropdownButtonFormField<String?>(
        value: _selectedUmatPosition,
        decoration: _fieldDeco(
            label: 'Jabatan / Peran Umat', icon: Icons.badge_outlined),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        items: const [
          DropdownMenuItem<String?>(
              value: null,
              child: Text('Anggota Umat',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(
              value: 'KETUA',
              child: Text('Ketua Lingkungan',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(
              value: 'WAKIL',
              child: Text('Wakil Ketua Lingkungan',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(
              value: 'SEKRETARIS',
              child: Text('Sekretaris Lingkungan',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(
              value: 'BENDAHARA',
              child: Text('Bendahara Lingkungan',
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (val) => setState(() => _selectedUmatPosition = val),
      );
    } else if (_selectedRole == 'ROMO_ORDO') {
      return DropdownButtonFormField<String>(
        value: _selectedRomoOrdoPosition,
        decoration: _fieldDeco(
            label: 'Jabatan Romo Ordo', icon: Icons.military_tech_outlined),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: 'KETUA_ROMO',
            child: Text('Ketua Ordo',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          DropdownMenuItem(
            value: 'ROMO_BIASA',
            child: Text('Romo Ordo Biasa',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedRomoOrdoPosition = val);
        },
      );
    } else if (_selectedRole == 'ROMO_PAROKI') {
      return DropdownButtonFormField<String>(
        value: _selectedRomoParokiPosition,
        decoration: _fieldDeco(
            label: 'Jabatan Romo Paroki', icon: Icons.church_outlined),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true,
        items: const [
          DropdownMenuItem(
            value: 'KETUA_ROMO',
            child: Text('Pastor Kepala (Ketua Paroki)',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          DropdownMenuItem(
            value: 'ROMO_BIASA',
            child: Text('Romo Paroki Biasa (Pastor Rekan)',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _selectedRomoParokiPosition = val);
        },
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1920),
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
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        size: 18, color: AppConstants.primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periode Masa Jabatan',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Ketuk kolom untuk memilih tanggal mulai & selesai',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(_startDateController),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TANGGAL MULAI',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 3),
                            Text(
                              _startDateController.text,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(_endDateController),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TANGGAL SELESAI',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 3),
                            Text(
                              _endDateController.text,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
                          'Isi data akun Anda untuk bergabung',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
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
                                  // ── 1. AKUN & KEAMANAN ──
                                  _buildSectionLabel(
                                      'AKUN & KEAMANAN', Icons.lock_outline_rounded),

                                  TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.textDark),
                                    decoration: InputDecoration(
                                      labelText: 'Nomor WhatsApp / HP (Username)',
                                      hintText: '81234567890',
                                      hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14),
                                      labelStyle: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F9FC),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 18),
                                      prefixIcon: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('🇮🇩',
                                                style: TextStyle(fontSize: 18)),
                                            const SizedBox(width: 6),
                                            const Text('+62',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppConstants
                                                        .primaryBlue)),
                                            const SizedBox(width: 10),
                                            Container(
                                                height: 22,
                                                width: 1,
                                                color: Colors.grey.shade300),
                                          ],
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade200)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade200)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color: AppConstants.primaryBlue,
                                              width: 2)),
                                      errorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                              color: Colors.red.shade400,
                                              width: 1.5)),
                                      focusedErrorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                              color: Colors.red.shade600,
                                              width: 2)),
                                      errorStyle: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 11.5),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Nomor WhatsApp wajib diisi';
                                      }
                                      var clean = value.trim();
                                      if (clean.startsWith('0')) {
                                        clean = clean.substring(1);
                                      }
                                      if (clean.startsWith('62')) {
                                        clean = clean.substring(2);
                                      }
                                      if (!clean.startsWith('8')) {
                                        return 'Nomor HP harus diawali angka 8';
                                      }
                                      if (clean.length < 9) {
                                        return 'Nomor HP minimal 9 digit';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: Colors.grey.shade500,
                                            size: 20),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Password wajib diisi';
                                      }
                                      if (v.trim().length < 6) {
                                        return 'Password minimal 6 karakter';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: 'Konfirmasi Password',
                                      icon: Icons.lock_reset_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: Colors.grey.shade500,
                                            size: 20),
                                        onPressed: () => setState(() =>
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Konfirmasi password wajib diisi';
                                      }
                                      if (v.trim() !=
                                          _passwordController.text.trim()) {
                                        return 'Password tidak cocok!';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  const Text(
                                    'Pilih Role Akun',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  _isLoadingRoles
                                      ? const Center(
                                          child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppConstants.primaryBlue),
                                        ))
                                      : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _roleOptions.map((role) {
                                            final isSelected =
                                                _selectedRole == role['code'];
                                            return GestureDetector(
                                              onTap: () =>
                                                  _onRoleChanged(role['code']!),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AppConstants.primaryBlue
                                                      : const Color(0xFFF7F9FC),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AppConstants
                                                            .primaryBlue
                                                        : Colors.grey.shade200,
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                              color: AppConstants
                                                                  .primaryBlue
                                                                  .withValues(
                                                                      alpha:
                                                                          0.25),
                                                              blurRadius: 8,
                                                              offset:
                                                                  const Offset(
                                                                      0, 3))
                                                        ]
                                                      : [],
                                                ),
                                                child: Text(
                                                  role['label']!,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : AppConstants.textMuted,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),

                                  const SizedBox(height: 24),

                                  // ── 2. INFORMASI PRIBADI ──
                                  _buildSectionLabel('INFORMASI PRIBADI',
                                      Icons.person_outline_rounded),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _firstNameController,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppConstants.textDark),
                                          decoration: _fieldDeco(
                                              label: 'Nama Depan',
                                              icon: Icons.person_rounded),
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Wajib diisi';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _lastNameController,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppConstants.textDark),
                                          decoration: _fieldDeco(
                                              label: 'Nama Belakang',
                                              icon: Icons.person_outline_rounded),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  GestureDetector(
                                    onTap: () =>
                                        _selectDate(_birthDateController),
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        controller: _birthDateController,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppConstants.textDark),
                                        decoration: _fieldDeco(
                                          label: 'Tanggal Lahir',
                                          icon: Icons.calendar_month_rounded,
                                          hint: 'DD/MM/YYYY',
                                          suffix: const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 18,
                                              color: AppConstants.primaryBlue),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: 'Email (Opsional)',
                                      icon: Icons.email_rounded,
                                      hint: 'umat@catu.id',
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // ── 3. DATA KEUMATAN & GEREJA ──
                                  _buildSectionLabel(
                                      'DATA KEUMATAN & GEREJA',
                                      Icons.church_rounded),

                                  _buildHierarchyDropdowns(),
                                  _buildPositionDropdown(),
                                  _buildMasaJabatanAndFlagFields(),

                                  const SizedBox(height: 24),

                                  // ── 4. ALAMAT TEMPAT TINGGAL ──
                                  _buildSectionLabel('ALAMAT TEMPAT TINGGAL',
                                      Icons.home_rounded),

                                  TextFormField(
                                    controller: _addressController,
                                    maxLines: 2,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.textDark),
                                    decoration: _fieldDeco(
                                      label: 'Alamat Jalan / Rumah',
                                      icon: Icons.place_rounded,
                                      hint: 'Jl. Sutera Utama No. 18',
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Dynamic Backend Dropdowns for Provinsi & Kota
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SearchableSelectField<int>(
                                          label: 'Provinsi',
                                          icon: Icons.map_rounded,
                                          value: _selectedProvinsiId,
                                          items: _dynamicProvinsiList
                                              .map((item) => SearchableSelectItem<int>(
                                                    value: int.parse(item['id'].toString()),
                                                    label: item['name'].toString(),
                                                  ))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) _onProvinsiChanged(val);
                                          },
                                          emptyMessage: 'Provinsi tidak ditemukan',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SearchableSelectField<int>(
                                          label: 'Kota / Kabupaten',
                                          icon: Icons.location_city_rounded,
                                          value: _selectedKabupatenKotaId,
                                          items: _dynamicKotaList
                                              .map((item) => SearchableSelectItem<int>(
                                                    value: int.parse(item['id'].toString()),
                                                    label: item['name'].toString(),
                                                  ))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _selectedKabupatenKotaId = val);
                                            }
                                          },
                                          emptyMessage: 'Kota tidak ditemukan pada provinsi ini',
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 30),

                                  // Submit Button
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppConstants.primaryBlue,
                                        disabledBackgroundColor: AppConstants
                                            .primaryBlue
                                            .withValues(alpha: 0.6),
                                        elevation: 4,
                                        shadowColor: AppConstants.primaryBlue
                                            .withValues(alpha: 0.4),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5))
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.how_to_reg_rounded,
                                                    color: Colors.white,
                                                    size: 20),
                                                SizedBox(width: 8),
                                                Text('DAFTAR AKUN',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: 0.8)),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Link kembali ke Login
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Sudah punya akun?',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade500)),
                                      TextButton(
                                        onPressed: () {
                                          if (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          } else {
                                            Navigator.pushReplacement(
                                              context,
                                              FadeSlideRoute(
                                                  page: const LoginScreen()),
                                            );
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6)),
                                        child: const Text(
                                          'Masuk di sini',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppConstants.primaryBlue),
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
