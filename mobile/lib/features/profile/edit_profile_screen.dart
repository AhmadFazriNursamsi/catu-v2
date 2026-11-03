import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';
import '../auth/widgets/gender_form_field.dart';
import '../home/widgets/home_greeting.dart' show homeRoleTitle;
import 'profile_region_fields.dart';
import 'region_transfer_flow.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  final bool resubmit;

  const EditProfileScreen({super.key, required this.user, required this.onSaved, this.resubmit = false});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  String? _gender;

  String? _avatarUrl;
  String _selectedRole = 'Umat';
  int? _keuskupanId, _parokiId, _wilayahId, _lingkunganId, _selectedProvinsiId, _selectedKabupatenKotaId;
  bool _regionDirty = false;

  List<Map<String, dynamic>> _ordoList = [];
  int? _selectedOrdoId;
  String _selectedOrdoName = 'SJ — Serikat Yesus';

  final bool _notifyKetuaLingkungan = true;
  bool _isSaving = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();

    _initDataFromUserMap(widget.user);
    _loadOrdoList();
    _fetchProfileFromBackend();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
  }

  static String _ordoLabel(Map<String, dynamic> o) => [o['code'], o['name']].where((v) => (v ?? '').toString().trim().isNotEmpty).join(' — ');

  void _syncSelectedOrdo() {
    if (_ordoList.isEmpty) return;

    if (_selectedOrdoId != null) {
      final match = _ordoList.firstWhere((e) => e['id'].toString() == _selectedOrdoId.toString(), orElse: () => _ordoList.first);
      _selectedOrdoId = int.tryParse(match['id'].toString());
      _selectedOrdoName = _ordoLabel(match);
    } else if (_selectedOrdoName.isNotEmpty) {
      final wanted = _selectedOrdoName.toLowerCase();
      final match = _ordoList.firstWhere((e) => e['name'].toString().toLowerCase().contains(wanted) || _ordoLabel(e).toLowerCase() == wanted, orElse: () => _ordoList.first);
      _selectedOrdoId = int.tryParse(match['id'].toString());
      _selectedOrdoName = _ordoLabel(match);
    } else {
      _selectedOrdoId = int.tryParse(_ordoList.first['id'].toString());
      _selectedOrdoName = _ordoLabel(_ordoList.first);
    }
  }

  Future<void> _loadOrdoList() async {
    try {
      final ordos = await ApiService.getOrdo();
      if (mounted && ordos.isNotEmpty) {
        setState(() {
          _ordoList = ordos;
          _syncSelectedOrdo();
        });
      }
    } catch (e) {
      debugPrint('Error loading Ordo list: $e');
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _isRomo {
    final code = (widget.user['roleCode'] ?? widget.user['role_code'] ?? widget.user['role'] ?? '').toString().toUpperCase();
    return code.startsWith('ROMO') || _selectedRole.contains('Romo');
  }

  bool get _isUmatRole => _selectedRole.startsWith('Umat') || _selectedRole == 'Pengurus Lingkungan';

  bool get _isRomoOrdo {
    final code = (widget.user['roleCode'] ?? widget.user['role_code'] ?? widget.user['role'] ?? '').toString().toUpperCase();
    return code == 'ROMO_ORDO' || _selectedRole == 'Romo Ordo';
  }

  void _initDataFromUserMap(Map<String, dynamic> data) {
    final fullName = data['fullName'] ?? data['full_name'] ?? '';
    final parts = fullName.toString().trim().split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    _firstNameController.text = first;
    _lastNameController.text = last;
    _phoneController.text =
        data['phoneNumber'] ?? data['phone_number'] ?? '';
    _emailController.text = data['email'] ?? '';
    _addressController.text = data['address'] ?? '';
    final g = (data['gender'] ?? '').toString().toUpperCase();
    _gender = (g == 'L' || g == 'P') ? g : null;

    final avatar = data['avatarUrl'] ?? data['avatar_url'];
    if (avatar != null && avatar.toString().isNotEmpty) {
      _avatarUrl = avatar.toString();
    }

    final rawRoleCode = (data['roleCode'] ?? data['role_code'] ?? data['role'] ?? '').toString().toUpperCase();
    if (rawRoleCode == 'ROMO_PAROKI') {
      _selectedRole = 'Romo Paroki';
    } else if (rawRoleCode == 'ROMO_ORDO') {
      _selectedRole = 'Romo Ordo';
    } else if (rawRoleCode == 'PENGURUS_LINGKUNGAN') {
      _selectedRole = 'Pengurus Lingkungan';
    } else if (rawRoleCode == 'UMAT') {
      _selectedRole = 'Umat';
    } else {
      final roleStr = (data['roleName'] ?? data['role_name'] ?? data['role'] ?? '').toString();
      if (roleStr.isNotEmpty) {
        _selectedRole = roleStr;
      }
    }

    final rawOrdoId = data['ordoId'] ?? data['ordo_id'];
    if (rawOrdoId != null) {
      _selectedOrdoId = int.tryParse(rawOrdoId.toString());
    }

    final rawOrdoName = data['ordoName'] ?? data['ordo_name'];
    if (rawOrdoName != null && rawOrdoName.toString().isNotEmpty) {
      _selectedOrdoName = rawOrdoName.toString();
    }

    _syncSelectedOrdo();

    final rawProvId = data['provinsiId'] ?? data['provinsi_id'];
    if (rawProvId != null) {
      _selectedProvinsiId = int.tryParse(rawProvId.toString());
    }

    final rawKotaId = data['kabupatenKotaId'] ?? data['kabupaten_kota_id'];
    if (rawKotaId != null) {
      _selectedKabupatenKotaId = int.tryParse(rawKotaId.toString());
    }

    int? idOf(String camel, String snake) => int.tryParse((data[camel] ?? data[snake] ?? '').toString());
    _keuskupanId = idOf('keuskupanId', 'keuskupan_id') ?? _keuskupanId;
    _parokiId = idOf('parokiId', 'paroki_id') ?? _parokiId;
    _wilayahId = idOf('wilayahId', 'wilayah_id') ?? _wilayahId;
    _lingkunganId = idOf('lingkunganId', 'lingkungan_id') ?? _lingkunganId;
  }

  Future<void> _fetchProfileFromBackend() async {
    try {
      final userId = widget.user['id'] ?? widget.user['user_id'] ?? 1;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/profile/$userId'),
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['user'] != null) {
          final u = resData['user'];
          if (mounted) {
            setState(() {
              _initDataFromUserMap(u);
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching fresh profile: $e');
    }
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      HapticFeedback.selectionClick();
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final base64Str = base64Encode(bytes);
          final finalUrl = 'data:image/png;base64,$base64Str';
          setState(() {
            _avatarUrl = finalUrl;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        source == ImageSource.camera
                            ? '📸 Foto dari Kamera berhasil dipilih! Tekan "Simpan Perubahan".'
                            : '🖼️ Foto dari Galeri berhasil dipilih! Tekan "Simpan Perubahan".',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } on PlatformException catch (pe) {
      debugPrint('PlatformException camera/gallery: $pe');
      if (source == ImageSource.camera && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 Kamera fisik tidak tersedia di Simulator. Membuka Galeri / File...'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _pickImageWithFilePicker();
    } catch (e) {
      debugPrint('Error picking image from $source: $e');
      _pickImageWithFilePicker();
    }
  }

  Future<void> _pickImageWithFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? fileBytes = file.bytes;
        if ((fileBytes == null || fileBytes.isEmpty) &&
            file.path != null &&
            file.path!.isNotEmpty) {
          final f = File(file.path!);
          if (f.existsSync()) {
            fileBytes = f.readAsBytesSync();
          }
        }

        if (fileBytes != null && fileBytes.isNotEmpty) {
          final base64Str = base64Encode(fileBytes);
          final finalUrl = 'data:image/png;base64,$base64Str';

          setState(() {
            _avatarUrl = finalUrl;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Foto profil "${file.name}" dipilih! Tekan "Simpan Perubahan".'),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error with FilePicker: $e');
    }
  }

  void _showAvatarPickerModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Ganti Foto Profil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih metode pengambilan foto profil Anda',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              _buildModalOptionTile(
                icon: Icons.camera_alt_rounded,
                iconBgColor: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF1D4ED8),
                title: 'Ambil Foto dari Kamera',
                subtitle: 'Potret langsung menggunakan kamera HP',
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
              ),

              const SizedBox(height: 12),

              _buildModalOptionTile(
                icon: Icons.photo_library_rounded,
                iconBgColor: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF059669),
                title: 'Pilih dari Galeri / File',
                subtitle: 'Gunakan foto yang sudah ada di galeri',
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
              ),

              if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildModalOptionTile(
                  icon: Icons.delete_outline_rounded,
                  iconBgColor: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFDC2626),
                  title: 'Hapus Foto Profil',
                  subtitle: 'Kembalikan foto ke tampilan awal',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _avatarUrl = '';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Foto profil telah dihapus.'),
                        backgroundColor: Color(0xFF475569),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalOptionTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }


  String _roleToCode(String role) {
    if (role == 'Romo Ordo') return 'ROMO_ORDO';
    if (role == 'Romo Paroki') return 'ROMO_PAROKI';
    if (role == 'Pengurus Lingkungan') return 'PENGURUS_LINGKUNGAN';
    return 'UMAT';
  }

  void _handleSave() async {
    HapticFeedback.mediumImpact();
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Format email tidak valid. Contoh: nama@perusahaan.com');
      return;
    }
    if (_regionDirty && _isUmatRole) {
      if (_lingkunganId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih lingkungan tujuan terlebih dahulu.')));
        return;
      }
      if (!widget.resubmit && !await confirmRegionTransfer(context)) return;
    }
    setState(() => _isSaving = true);

    try {
      final userId = widget.user['id'] ?? widget.user['user_id'] ?? 1;
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      _syncSelectedOrdo();
      final roleCode = _roleToCode(_selectedRole);
      final body = <String, dynamic>{
        'fullName': fullName,
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        if (_gender != null && !_isRomo) 'gender': _gender,
        'avatarUrl': _avatarUrl,
        'roleCode': roleCode,
        'kabupatenKotaId': _selectedKabupatenKotaId,
        if (_regionDirty) ...{
          'keuskupanId': _keuskupanId,
          'parokiId': _parokiId,
          if (!_isRomo) ...{'wilayahId': _wilayahId, 'lingkunganId': _lingkunganId},
        },
        'notifyKetuaLingkungan': _notifyKetuaLingkungan,
      };

      if (_isRomoOrdo && _selectedOrdoId != null) {
        body['ordoId'] = _selectedOrdoId;
      }

      final headers = {'Content-Type': 'application/json'};
      final base = ApiService.baseUrl;
      final response = widget.resubmit
          ? await http.post(Uri.parse('$base/auth/resubmit-registration'), headers: headers, body: jsonEncode(body))
          : await http.put(Uri.parse('$base/auth/profile/$userId'), headers: headers, body: jsonEncode(body));

      if (response.statusCode >= 400) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(backendMessage(response.body, 'Gagal menyimpan profil.')), backgroundColor: const Color(0xFFDC2626), behavior: SnackBarBehavior.floating));
        }
        return;
      }
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (widget.resubmit || resData['regionTransfer'] == 'PENDING') {
          if (mounted) await openPendingAfterTransfer(context, widget.user..addAll({'fullName': fullName, ...Map<String, dynamic>.from(resData['user'] ?? {})}));
          return;
        }
        if (resData['user'] != null && resData['user'] is Map) {
          final Map<String, dynamic> updated = Map<String, dynamic>.from(resData['user']);
          widget.user.addAll(updated);
          widget.user['roleCode'] = roleCode;
          widget.user['role_code'] = roleCode;
          if (_selectedOrdoId != null) widget.user['ordoId'] = _selectedOrdoId;
        }
      }
    } catch (e) {
      debugPrint('Error updating profile to backend: $e');
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Perubahan profil berhasil disimpan!'), backgroundColor: Color(0xFF059669), behavior: SnackBarBehavior.floating));

    widget.onSaved();
    Navigator.pop(context);
  }

  static final Map<String, MemoryImage> _avatarMemoryCache = {};

  ImageProvider _getAvatarImageProvider() {
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return const AssetImage('assets/images/katedral_jakarta.jpg');
    }
    if (_avatarUrl!.startsWith('data:image')) {
      if (_avatarMemoryCache.containsKey(_avatarUrl!)) {
        return _avatarMemoryCache[_avatarUrl!]!;
      }
      try {
        final commaIdx = _avatarUrl!.indexOf(',');
        final base64String = commaIdx != -1 ? _avatarUrl!.substring(commaIdx + 1) : _avatarUrl!;
        final bytes = base64Decode(base64String);
        final provider = MemoryImage(bytes);
        _avatarMemoryCache[_avatarUrl!] = provider;
        return provider;
      } catch (_) {
        return const AssetImage('assets/images/katedral_jakarta.jpg');
      }
    }
    if (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) {
      return NetworkImage(_avatarUrl!);
    }
    if (File(_avatarUrl!).existsSync()) {
      return FileImage(File(_avatarUrl!));
    }
    return const AssetImage('assets/images/katedral_jakarta.jpg');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.resubmit ? 'Perbaiki Data Pendaftaran' : LanguageService.tr('edit_profile'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildAvatarSection()),

              const SizedBox(height: 24),

              _buildSectionTitle(LanguageService.tr('personal_info'), Icons.person_outline_rounded),
              const SizedBox(height: 12),

              _buildTextField(controller: _firstNameController, label: LanguageService.tr('first_name'), hint: 'Kevin', icon: Icons.person_rounded),
              const SizedBox(height: 14),
              _buildTextField(controller: _lastNameController, label: LanguageService.tr('last_name'), hint: 'Antaratama'),
              const SizedBox(height: 14),
              if (!_isRomo) ...[
                GenderFormField(value: _gender, onChanged: (g) => setState(() => _gender = g)),
                const SizedBox(height: 14),
              ],
              _buildTextField(
                controller: _phoneController,
                label: LanguageService.tr('phone_number'),
                hint: '081234567890',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                readOnly: true,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _emailController,
                label: LanguageService.tr('email'),
                hint: 'nama@perusahaan.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),

              const SizedBox(height: 24),

              _buildSectionTitle(LanguageService.tr('church_data'), Icons.church_rounded),
              const SizedBox(height: 12),
              _buildReadOnlyField(
                label: LanguageService.tr('role'),
                value: homeRoleTitle(widget.user),
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 14),

              if (_isRomoOrdo)
                _buildReadOnlyField(label: 'Ordo / Tarekat', value: _selectedOrdoName, icon: Icons.auto_stories_rounded)
              else
                ChurchRegionFields(
                  keuskupanId: _keuskupanId,
                  parokiId: _parokiId,
                  wilayahId: _wilayahId,
                  lingkunganId: _lingkunganId,
                  showArea: !_isRomo,
                  enabled: _isUmatRole,
                  onChanged: (k, p, w, l) => setState(() {
                    _keuskupanId = k;
                    _parokiId = p;
                    _wilayahId = w;
                    _lingkunganId = l;
                    _regionDirty = true;
                  }),
                ),

              const SizedBox(height: 24),

              _buildSectionTitle(LanguageService.tr('address_info'), Icons.home_rounded),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _addressController,
                label: LanguageService.tr('address'),
                hint: 'Jl. Sutera Utama No. 18',
                icon: Icons.place_rounded,
                maxLines: 2,
                readOnly: false,
              ),
              const SizedBox(height: 14),

              ProvinsiKotaFields(
                provinsiId: _selectedProvinsiId,
                kotaId: _selectedKabupatenKotaId,
                onChanged: (p, k) => setState(() {
                  _selectedProvinsiId = p;
                  _selectedKabupatenKotaId = k;
                }),
              ),
            ],
          ),
        ),

        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.resubmit ? Icons.send_rounded : Icons.save_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.resubmit ? 'Ajukan Ulang Pendaftaran' : LanguageService.tr('save_changes'),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final avatarProvider = _getAvatarImageProvider();

    return Column(
      children: [
        GestureDetector(
          onTap: _showAvatarPickerModal,
          child: Stack(
            children: [
              Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                  border: Border.all(color: const Color(0xFF1D4ED8), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: DecorationImage(
                    image: avatarProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showAvatarPickerModal,
          child: const Text(
            'Ubah Foto Profil',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1D4ED8)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    IconData? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: readOnly ? const Color(0xFF64748B) : const Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (readOnly) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: Color(0xFF64748B)),
                    SizedBox(width: 3),
                    Text(
                      'Terkunci',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: readOnly ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onChanged: onChanged,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: icon != null
                  ? Icon(icon, size: 18, color: readOnly ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                  : null,
              suffixIcon: suffixIcon != null
                  ? Icon(suffixIcon, size: 18, color: const Color(0xFF1D4ED8))
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        if (errorText != null) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(errorText, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    IconData? icon,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 10, color: Color(0xFF64748B)),
                  SizedBox(width: 3),
                  Text('Terkunci', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : (hint ?? '-'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
