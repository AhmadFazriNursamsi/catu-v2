import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/services/language_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;

  const EditProfileScreen({
    Key? key,
    required this.user,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _birthDateController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  String? _avatarUrl;
  String _selectedRole = 'Umat';
  String _selectedKeuskupan = 'Keuskupan Agung Jakarta';
  String _selectedParoki = 'Paroki Alam Sutera - St. Laurensius';
  String _selectedWilayah = 'Wilayah 01 - St. Laurensius';
  String _selectedLingkungan = 'Lingkungan St. Angela Merici';

  List<Map<String, dynamic>> _dynamicProvinsiList = [];
  List<Map<String, dynamic>> _dynamicKotaList = [];
  int? _selectedProvinsiId;
  int? _selectedKabupatenKotaId;

  bool _notifyKetuaLingkungan = true;
  bool _isSaving = false;

  final List<String> _keuskupanList = [
    'Keuskupan Agung Jakarta',
    'Keuskupan Agung Bandung',
    'Keuskupan Agung Surabaya',
    'Keuskupan Agung Semarang',
    'Keuskupan Agung Medan',
  ];

  final List<String> _parokiList = [
    'Paroki Alam Sutera - St. Laurensius',
    'Paroki Pademangan - St. Alfonsus Rodriguez',
    'Paroki Serpong - St. Monika',
    'Paroki Bintaro Jaya - St. Maria Regina',
    'Paroki Curug - St. Helena',
  ];

  final List<String> _wilayahList = [
    'Wilayah 01 - St. Laurensius',
    'Wilayah St. Agustinus',
    'Wilayah 02 - St. Agnes',
    'Wilayah 03 - St. Gabriel',
  ];

  final List<String> _lingkunganList = [
    'Lingkungan St. Angela Merici',
    'Lingkungan St. Agnes 1',
    'Lingkungan St. Anastasia 2',
    'Lingkungan St. Franciscus',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _birthDateController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();

    _initDataFromUserMap(widget.user);
    _loadDynamicProvinsiKota();
    _fetchProfileFromBackend();
    LanguageService.currentLanguage.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLanguage.removeListener(_onLanguageChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicProvinsiKota() async {
    final provs = await ApiService.getProvinsiList();
    if (mounted) {
      setState(() {
        _dynamicProvinsiList = provs;
      });

      final currentProvId = _selectedProvinsiId ??
          (provs.isNotEmpty ? int.tryParse(provs.first['id'].toString()) : null);

      if (currentProvId != null) {
        _selectedProvinsiId = currentProvId;
        final kotas = await ApiService.getKabupatenKotaList(provinsiId: currentProvId);
        if (mounted) {
          setState(() {
            _dynamicKotaList = kotas;
            if (_selectedKabupatenKotaId == null && kotas.isNotEmpty) {
              _selectedKabupatenKotaId = int.tryParse(kotas.first['id'].toString());
            }
          });
        }
      }
    }
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

  void _initDataFromUserMap(Map<String, dynamic> data) {
    final fullName = data['fullName'] ?? data['full_name'] ?? '';
    final parts = fullName.toString().trim().split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    _firstNameController.text = first;
    _lastNameController.text = last;
    _birthDateController.text =
        data['birthDate'] ?? data['birth_date'] ?? '';
    _phoneController.text =
        data['phoneNumber'] ?? data['phone_number'] ?? '';
    _emailController.text = data['email'] ?? '';
    _addressController.text = data['address'] ?? '';

    final avatar = data['avatarUrl'] ?? data['avatar_url'];
    if (avatar != null && avatar.toString().isNotEmpty) {
      _avatarUrl = avatar.toString();
    }

    final rawProvId = data['provinsiId'] ?? data['provinsi_id'];
    if (rawProvId != null) {
      _selectedProvinsiId = int.tryParse(rawProvId.toString());
    }

    final rawKotaId = data['kabupatenKotaId'] ?? data['kabupaten_kota_id'];
    if (rawKotaId != null) {
      _selectedKabupatenKotaId = int.tryParse(rawKotaId.toString());
    }

    final keuskupan = data['keuskupanName'] ?? data['keuskupan_name'];
    if (keuskupan != null && keuskupan.toString().isNotEmpty) {
      if (!_keuskupanList.contains(keuskupan)) _keuskupanList.add(keuskupan);
      _selectedKeuskupan = keuskupan;
    }

    final paroki = data['parokiName'] ?? data['paroki_name'];
    if (paroki != null && paroki.toString().isNotEmpty) {
      if (!_parokiList.contains(paroki)) _parokiList.add(paroki);
      _selectedParoki = paroki;
    }

    final wilayah = data['wilayahName'] ?? data['wilayah_name'];
    if (wilayah != null && wilayah.toString().isNotEmpty) {
      if (!_wilayahList.contains(wilayah)) _wilayahList.add(wilayah);
      _selectedWilayah = wilayah;
    }

    final lingkungan = data['lingkunganName'] ?? data['lingkungan_name'];
    if (lingkungan != null && lingkungan.toString().isNotEmpty) {
      if (!_lingkunganList.contains(lingkungan)) _lingkunganList.add(lingkungan);
      _selectedLingkungan = lingkungan;
    }
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
            _loadDynamicProvinsiKota();
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D4ED8),
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
      final year = picked.year;
      setState(() {
        _birthDateController.text = '$day/$month/$year';
      });
    }
  }

  void _handleSave() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final userId = widget.user['id'] ?? widget.user['user_id'] ?? 1;
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();
      final url = Uri.parse('${ApiService.baseUrl}/auth/profile/$userId');

      final body = {
        'fullName': fullName,
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'birthDate': _birthDateController.text.trim(),
        'address': _addressController.text.trim(),
        'avatarUrl': _avatarUrl,
        'kabupatenKotaId': _selectedKabupatenKotaId,
        'notifyKetuaLingkungan': _notifyKetuaLingkungan,
      };

      await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('Error updating profile to backend: $e');
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('✅ Perubahan profil berhasil disimpan dan dikirim ke backend!'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );

    widget.onSaved();
    Navigator.pop(context);
  }

  ImageProvider _getAvatarImageProvider() {
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      return const AssetImage('assets/images/church_1.jpg');
    }
    if (_avatarUrl!.startsWith('data:image')) {
      try {
        final base64String = _avatarUrl!.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (_) {
        return const AssetImage('assets/images/church_1.jpg');
      }
    }
    if (_avatarUrl!.startsWith('http://') || _avatarUrl!.startsWith('https://')) {
      return NetworkImage(_avatarUrl!);
    }
    if (File(_avatarUrl!).existsSync()) {
      return FileImage(File(_avatarUrl!));
    }
    return const AssetImage('assets/images/church_1.jpg');
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
            LanguageService.tr('edit_profile'),
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

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: LanguageService.tr('first_name'),
                      hint: 'Kevin',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: LanguageService.tr('last_name'),
                      hint: 'Antaratama',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              GestureDetector(
                onTap: _pickBirthDate,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _birthDateController,
                    label: LanguageService.tr('birth_date'),
                    hint: 'DD/MM/YYYY',
                    icon: Icons.calendar_month_rounded,
                    suffixIcon: Icons.calendar_today_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _phoneController,
                label: LanguageService.tr('phone_number'),
                hint: '081234567890',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _emailController,
                label: LanguageService.tr('email'),
                hint: 'kevin@catu.id',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 24),

              _buildSectionTitle(LanguageService.tr('church_data'), Icons.church_rounded),
              const SizedBox(height: 12),

              _buildDropdownField(
                label: LanguageService.tr('role'),
                value: _selectedRole,
                items: ['Umat', 'Pengurus Lingkungan', 'Romo Paroki'],
                onChanged: (val) => setState(() => _selectedRole = val!),
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 14),

              _buildDropdownField(
                label: LanguageService.tr('keuskupan'),
                value: _selectedKeuskupan,
                items: _keuskupanList,
                onChanged: (val) => setState(() => _selectedKeuskupan = val!),
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 14),

              _buildDropdownField(
                label: LanguageService.tr('paroki'),
                value: _selectedParoki,
                items: _parokiList,
                onChanged: (val) => setState(() => _selectedParoki = val!),
                icon: Icons.location_city_rounded,
              ),
              const SizedBox(height: 14),

              _buildDropdownField(
                label: LanguageService.tr('wilayah'),
                value: _selectedWilayah,
                items: _wilayahList,
                onChanged: (val) => setState(() => _selectedWilayah = val!),
                icon: Icons.map_rounded,
              ),
              const SizedBox(height: 14),

              _buildDropdownField(
                label: LanguageService.tr('lingkungan'),
                value: _selectedLingkungan,
                items: _lingkunganList,
                onChanged: (val) => setState(() => _selectedLingkungan = val!),
                icon: Icons.groups_rounded,
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
              ),
              const SizedBox(height: 14),

              // Dynamic Backend Dropdowns for Provinsi & Kota
              Row(
                children: [
                  Expanded(
                    child: _buildDynamicProvinsiDropdown(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDynamicKotaDropdown(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildVerificationCheckboxCard(),
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
                        const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          LanguageService.tr('save_changes'),
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

  // ── Dynamic Backend Dropdown Builders ─────────────────────────────────────

  Widget _buildDynamicProvinsiDropdown() {
    final selectedVal = _selectedProvinsiId != null &&
            _dynamicProvinsiList.any((p) => int.tryParse(p['id'].toString()) == _selectedProvinsiId)
        ? _selectedProvinsiId
        : (_dynamicProvinsiList.isNotEmpty
            ? int.tryParse(_dynamicProvinsiList.first['id'].toString())
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Provinsi',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedVal,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B)),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              onChanged: (val) {
                if (val != null) _onProvinsiChanged(val);
              },
              items: _dynamicProvinsiList.map((p) {
                final id = int.parse(p['id'].toString());
                final name = p['name'].toString();
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicKotaDropdown() {
    final selectedVal = _selectedKabupatenKotaId != null &&
            _dynamicKotaList.any((k) => int.tryParse(k['id'].toString()) == _selectedKabupatenKotaId)
        ? _selectedKabupatenKotaId
        : (_dynamicKotaList.isNotEmpty
            ? int.tryParse(_dynamicKotaList.first['id'].toString())
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kota / Kabupaten',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedVal,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B)),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedKabupatenKotaId = val);
                }
              },
              items: _dynamicKotaList.map((k) {
                final id = int.parse(k['id'].toString());
                final name = k['name'].toString();
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: icon != null
                  ? Icon(icon, size: 18, color: const Color(0xFF64748B))
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
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    final validValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B)),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: const Color(0xFF64748B)),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          item,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCheckboxCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Checkbox.adaptive(
            value: _notifyKetuaLingkungan,
            activeColor: const Color(0xFF1D4ED8),
            onChanged: (val) {
              setState(() => _notifyKetuaLingkungan = val ?? true);
            },
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Kirim Perubahan Data ke Ketua Lingkungan untuk Verifikasi',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
