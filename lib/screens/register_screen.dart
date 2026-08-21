import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _startYearController = TextEditingController(text: DateTime.now().year.toString());
  final TextEditingController _endYearController = TextEditingController(text: (DateTime.now().year + 3).toString());

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  bool _isSubmitting = false;

  // Selected Role
  String _selectedRoleCode = 'UMAT';

  // Role list definitions
  final List<Map<String, String>> _roleList = [
    {
      'code': 'UMAT',
      'label': 'Umat Katolik',
      'desc': 'Umat beriman di lingkungan paroki',
    },
    {
      'code': 'PENGURUS_LINGKUNGAN',
      'label': 'Pengurus Lingkungan',
      'desc': 'Ketua / Pengurus Inti Lingkungan Gereja',
    },
    {
      'code': 'ROMO_PAROKI',
      'label': 'Romo Paroki',
      'desc': 'Pastor Kepala / Rekan Paroki',
    },
    {
      'code': 'ROMO_ORDO',
      'label': 'Romo Ordo',
      'desc': 'Imam Tarekat / Kongregasi Religius',
    },
  ];

  // Positions
  String? _selectedPengurusPosition = 'Ketua Lingkungan';
  final List<String> _pengurusPositions = [
    'Ketua Lingkungan',
    'Wakil Ketua Lingkungan',
    'Sekretaris Lingkungan',
    'Bendahara Lingkungan',
  ];

  String? _selectedRomoParokiPosition = 'Kepala Romo Paroki';
  final List<String> _romoParokiPositions = [
    'Kepala Romo Paroki',
    'Romo Paroki',
  ];

  String? _selectedRomoOrdoPosition = 'Romo Ordo';
  final List<String> _romoOrdoPositions = [
    'Ketua Romo Ordo',
    'Romo Ordo',
  ];

  // Cascading Dynamic DB Master Data Lists
  List<dynamic> _keuskupanList = [];
  List<dynamic> _parokiList = [];
  List<dynamic> _wilayahList = [];
  List<dynamic> _lingkunganList = [];
  List<dynamic> _ordoList = [];
  List<dynamic> _provinsiList = [];
  List<dynamic> _kabupatenKotaList = [];

  // Selected DB IDs
  String? _selectedKeuskupanId;
  String? _selectedParokiId;
  String? _selectedWilayahId;
  String? _selectedLingkunganId;
  String? _selectedOrdoId;
  String? _selectedProvinsiId;
  String? _selectedKabupatenKotaId;

  // Loading flags for cascading fetches
  bool _loadingKeuskupan = false;
  bool _loadingParoki = false;
  bool _loadingWilayah = false;
  bool _loadingLingkungan = false;
  bool _loadingOrdo = false;
  bool _loadingProvinsi = false;
  bool _loadingKabupaten = false;

  @override
  void initState() {
    super.initState();
    _loadInitialMasterData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Live Database Fetchers
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadInitialMasterData() async {
    await Future.wait([
      _fetchKeuskupan(),
      _fetchOrdo(),
      _fetchProvinsi(),
    ]);
  }

  Future<void> _fetchKeuskupan() async {
    setState(() => _loadingKeuskupan = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/keuskupan'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _keuskupanList = data;
            // Default to Jakarta if available
            final defaultK = data.firstWhere(
              (k) => k['id'].toString() == '1',
              orElse: () => data.isNotEmpty ? data.first : null,
            );
            if (defaultK != null) {
              _selectedKeuskupanId = defaultK['id'].toString();
              _fetchParoki(_selectedKeuskupanId!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Keuskupan: $e');
    } finally {
      if (mounted) setState(() => _loadingKeuskupan = false);
    }
  }

  Future<void> _fetchParoki(String keuskupanId) async {
    setState(() {
      _loadingParoki = true;
      _parokiList = [];
      _selectedParokiId = null;
      _wilayahList = [];
      _selectedWilayahId = null;
      _lingkunganList = [];
      _selectedLingkunganId = null;
    });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/paroki?keuskupanId=$keuskupanId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _parokiList = data;
            if (data.isNotEmpty) {
              _selectedParokiId = data.first['id'].toString();
              if (_selectedRoleCode != 'ROMO_PAROKI') {
                _fetchWilayah(_selectedParokiId!);
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Paroki: $e');
    } finally {
      if (mounted) setState(() => _loadingParoki = false);
    }
  }

  Future<void> _fetchWilayah(String parokiId) async {
    setState(() {
      _loadingWilayah = true;
      _wilayahList = [];
      _selectedWilayahId = null;
      _lingkunganList = [];
      _selectedLingkunganId = null;
    });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/wilayah?parokiId=$parokiId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _wilayahList = data;
            if (data.isNotEmpty) {
              _selectedWilayahId = data.first['id'].toString();
              _fetchLingkungan(_selectedWilayahId!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Wilayah: $e');
    } finally {
      if (mounted) setState(() => _loadingWilayah = false);
    }
  }

  Future<void> _fetchLingkungan(String wilayahId) async {
    setState(() {
      _loadingLingkungan = true;
      _lingkunganList = [];
      _selectedLingkunganId = null;
    });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/lingkungan?wilayahId=$wilayahId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _lingkunganList = data;
            if (data.isNotEmpty) {
              _selectedLingkunganId = data.first['id'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Lingkungan: $e');
    } finally {
      if (mounted) setState(() => _loadingLingkungan = false);
    }
  }

  Future<void> _fetchOrdo() async {
    setState(() => _loadingOrdo = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/ordo'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _ordoList = data;
            if (data.isNotEmpty) {
              _selectedOrdoId = data.first['id'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Ordo: $e');
    } finally {
      if (mounted) setState(() => _loadingOrdo = false);
    }
  }

  Future<void> _fetchProvinsi() async {
    setState(() => _loadingProvinsi = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/provinsi'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _provinsiList = data;
            if (data.isNotEmpty) {
              _selectedProvinsiId = data.first['id'].toString();
              _fetchKabupaten(_selectedProvinsiId!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Provinsi: $e');
    } finally {
      if (mounted) setState(() => _loadingProvinsi = false);
    }
  }

  Future<void> _fetchKabupaten(String provinsiId) async {
    setState(() {
      _loadingKabupaten = true;
      _kabupatenKotaList = [];
      _selectedKabupatenKotaId = null;
    });
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/auth/kabupaten-kota?provinsiId=$provinsiId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() {
            _kabupatenKotaList = data;
            if (data.isNotEmpty) {
              _selectedKabupatenKotaId = data.first['id'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching Kabupaten: $e');
    } finally {
      if (mounted) setState(() => _loadingKabupaten = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Submit Registration to Backend
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Normalize phone number to 62... format
    String phone = _phoneController.text.trim();
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    } else if (phone.startsWith('+62')) {
      phone = phone.substring(1);
    } else if (!phone.startsWith('62')) {
      phone = '62$phone';
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> payload = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': phone,
        'password': _passController.text,
        'roleCode': _selectedRoleCode,
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'birthDate': _birthDateController.text.trim().isNotEmpty ? _birthDateController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      };

      if (_selectedRoleCode == 'ROMO_ORDO') {
        if (_selectedOrdoId != null) {
          payload['ordoId'] = int.tryParse(_selectedOrdoId!);
        }
        payload['romoPosition'] = _selectedRomoOrdoPosition;
      } else {
        if (_selectedKeuskupanId != null) {
          payload['keuskupanId'] = int.tryParse(_selectedKeuskupanId!);
        }
        if (_selectedParokiId != null) {
          payload['parokiId'] = int.tryParse(_selectedParokiId!);
        }
        if (_selectedRoleCode == 'ROMO_PAROKI') {
          payload['romoPosition'] = _selectedRomoParokiPosition;
        } else {
          // UMAT or PENGURUS_LINGKUNGAN
          if (_selectedWilayahId != null) {
            payload['wilayahId'] = int.tryParse(_selectedWilayahId!);
          }
          if (_selectedLingkunganId != null) {
            payload['lingkunganId'] = int.tryParse(_selectedLingkunganId!);
          }
          if (_selectedRoleCode == 'PENGURUS_LINGKUNGAN') {
            payload['pengurusPosition'] = _selectedPengurusPosition;
            if (_startYearController.text.isNotEmpty) {
              payload['jabatanStartYear'] = int.tryParse(_startYearController.text);
            }
            if (_endYearController.text.isNotEmpty) {
              payload['jabatanEndYear'] = int.tryParse(_endYearController.text);
            }
          }
        }
      }

      if (_selectedProvinsiId != null) {
        payload['provinsiId'] = int.tryParse(_selectedProvinsiId!);
      }
      if (_selectedKabupatenKotaId != null) {
        payload['kabupatenKotaId'] = int.tryParse(_selectedKabupatenKotaId!);
      }

      final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.emerald, size: 28),
                SizedBox(width: 10),
                Text('Pendaftaran Berhasil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              body['message'] ?? 'Akun Anda berhasil didaftarkan dan berstatus Menunggu Persetujuan (PENDING APPROVAL). Silakan hubungi pengurus atau admin untuk verifikasi.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Ke Halaman Masuk'),
              ),
            ],
          ),
        );
      } else {
        final errorMsg = body['message'] is List
            ? (body['message'] as List).join('\n')
            : (body['message'] ?? 'Pendaftaran gagal.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(errorMsg, style: const TextStyle(color: Colors.white)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Terjadi kesalahan jaringan: $e', style: const TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.indigo, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daftar Akun Baru',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Logo Banner
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.indigo.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Image.asset('assets/images/catuv2_1.png', height: 75),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Registrasi Ekosistem CATU',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Data tersinkronisasi langsung dengan Database Gereja',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 1. PILIH JENIS AKUN / ROLE ──
                _buildSectionHeader(Icons.manage_accounts, 'Jenis Akun Pengguna'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedRoleCode,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: InputBorder.none,
                    ),
                    items: _roleList.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['code'],
                        child: Text(
                          r['label']!,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRoleCode = val;
                          if (val == 'ROMO_PAROKI') {
                            _wilayahList = [];
                            _lingkunganList = [];
                          } else if (val != 'ROMO_ORDO' && _selectedParokiId != null) {
                            _fetchWilayah(_selectedParokiId!);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. DATA PRIBADI & KONTAK ──
                _buildSectionHeader(Icons.person_outline, 'Informasi Kontak & Akun'),
                const SizedBox(height: 10),
                _buildCardContainer([
                  // Nama Lengkap
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Nama Lengkap',
                    hint: 'Contoh: Antonius Budi Raharjo',
                    icon: Icons.badge_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nama lengkap wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Nomor WhatsApp
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Nomor WhatsApp / HP',
                    hint: 'Contoh: 081234567890',
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nomor HP wajib diisi';
                      if (v.trim().length < 9) return 'Nomor HP minimal 9 digit';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Email
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email (Opsional)',
                    hint: 'Contoh: budi@gmail.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),

                  // Password
                  _buildTextField(
                    controller: _passController,
                    label: 'Kata Sandi',
                    hint: 'Minimal 6 karakter',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kata sandi wajib diisi';
                      if (v.length < 6) return 'Minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Confirm Password
                  _buildTextField(
                    controller: _confirmPassController,
                    label: 'Konfirmasi Kata Sandi',
                    hint: 'Ulangi kata sandi di atas',
                    icon: Icons.lock_reset,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Konfirmasi sandi wajib diisi';
                      if (v != _passController.text) return 'Kata sandi tidak sama';
                      return null;
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // ── 3. DATA STRUKTUR GEREJA (CASCADING DB) ──
                if (_selectedRoleCode == 'ROMO_ORDO') ...[
                  _buildSectionHeader(Icons.church_outlined, 'Struktur Ordo / Kongregasi Religius'),
                  const SizedBox(height: 10),
                  _buildCardContainer([
                    _buildDropdownField(
                      label: 'Ordo / Kongregasi',
                      isLoading: _loadingOrdo,
                      value: _selectedOrdoId,
                      items: _ordoList.map((o) {
                        return DropdownMenuItem<String>(
                          value: o['id'].toString(),
                          child: Text('${o['code']} - ${o['name']}', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedOrdoId = val),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField(
                      label: 'Jabatan di Ordo',
                      value: _selectedRomoOrdoPosition,
                      items: _romoOrdoPositions.map((p) {
                        return DropdownMenuItem<String>(
                          value: p,
                          child: Text(p),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRomoOrdoPosition = val),
                    ),
                  ]),
                ] else ...[
                  _buildSectionHeader(Icons.account_tree_outlined, 'Hierarki & Komunitas Gereja (Live DB)'),
                  const SizedBox(height: 10),
                  _buildCardContainer([
                    // Keuskupan
                    _buildDropdownField(
                      label: '1. Keuskupan',
                      isLoading: _loadingKeuskupan,
                      value: _selectedKeuskupanId,
                      items: _keuskupanList.map((k) {
                        return DropdownMenuItem<String>(
                          value: k['id'].toString(),
                          child: Text(k['name'], overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedKeuskupanId = val);
                          _fetchParoki(val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Paroki
                    _buildDropdownField(
                      label: '2. Paroki',
                      isLoading: _loadingParoki,
                      value: _selectedParokiId,
                      items: _parokiList.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(p['name'], overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedParokiId = val);
                          if (_selectedRoleCode != 'ROMO_PAROKI') {
                            _fetchWilayah(val);
                          }
                        }
                      },
                    ),

                    // Romo Paroki Position
                    if (_selectedRoleCode == 'ROMO_PAROKI') ...[
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: 'Posisi Pastoral Paroki',
                        value: _selectedRomoParokiPosition,
                        items: _romoParokiPositions.map((p) {
                          return DropdownMenuItem<String>(value: p, child: Text(p));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedRomoParokiPosition = val),
                      ),
                    ],

                    // Wilayah (Umat & Pengurus)
                    if (_selectedRoleCode != 'ROMO_PAROKI') ...[
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: '3. Wilayah Gereja',
                        isLoading: _loadingWilayah,
                        value: _selectedWilayahId,
                        items: _wilayahList.map((w) {
                          return DropdownMenuItem<String>(
                            value: w['id'].toString(),
                            child: Text(w['name'], overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWilayahId = val);
                            _fetchLingkungan(val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Lingkungan (Umat & Pengurus)
                      _buildDropdownField(
                        label: '4. Komunitas Lingkungan',
                        isLoading: _loadingLingkungan,
                        value: _selectedLingkunganId,
                        items: _lingkunganList.map((l) {
                          return DropdownMenuItem<String>(
                            value: l['id'].toString(),
                            child: Text(l['name'], overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedLingkunganId = val),
                      ),
                    ],

                    // Pengurus Lingkungan Specifics
                    if (_selectedRoleCode == 'PENGURUS_LINGKUNGAN') ...[
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: 'Jabatan Pengurus Lingkungan',
                        value: _selectedPengurusPosition,
                        items: _pengurusPositions.map((p) {
                          return DropdownMenuItem<String>(value: p, child: Text(p));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPengurusPosition = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _startYearController,
                              label: 'Tahun Mulai',
                              hint: '2024',
                              icon: Icons.calendar_today,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _endYearController,
                              label: 'Tahun Selesai',
                              hint: '2027',
                              icon: Icons.event,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ]),
                ],
                const SizedBox(height: 20),

                // ── 4. WILAYAH ADMINISTRATIF / DOMISILI ──
                _buildSectionHeader(Icons.location_on_outlined, 'Wilayah Administratif Domisili'),
                const SizedBox(height: 10),
                _buildCardContainer([
                  _buildDropdownField(
                    label: 'Provinsi',
                    isLoading: _loadingProvinsi,
                    value: _selectedProvinsiId,
                    items: _provinsiList.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(p['name'], overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedProvinsiId = val);
                        _fetchKabupaten(val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    label: 'Kabupaten / Kota',
                    isLoading: _loadingKabupaten,
                    value: _selectedKabupatenKotaId,
                    items: _kabupatenKotaList.map((k) {
                      return DropdownMenuItem<String>(
                        value: k['id'].toString(),
                        child: Text(k['name'], overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedKabupatenKotaId = val),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Alamat Tempat Tinggal (Opsional)',
                    hint: 'Jl. Melati No. 12',
                    icon: Icons.home_outlined,
                  ),
                ]),
                const SizedBox(height: 20),

                // Terms & Conditions Checkbox
                Row(
                  children: [
                    Checkbox(
                      activeColor: Colors.indigo.shade800,
                      value: _agree,
                      onChanged: (val) => setState(() => _agree = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Saya menyetujui Syarat & Ketentuan Penggunaan Aplikasi Pelayanan CATU.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade800,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.indigo.shade200,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (_agree && !_isSubmitting) ? _registerUser : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'DAFTAR SEKARANG',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Already have account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Sudah memiliki akun? ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Masuk Disini',
                        style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI Helper Widgets
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.indigo.shade800),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
        ),
      ],
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.slate.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 20, color: Colors.indigo.shade600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.indigo.shade700, width: 1.5)),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? value,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: items.any((it) => it.value == value) ? value : null,
            hint: Text(isLoading ? 'Memuat data dari server...' : '-- Pilih $label --', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
            items: items,
            onChanged: isLoading ? null : onChanged,
          ),
        ),
      ],
    );
  }
}
