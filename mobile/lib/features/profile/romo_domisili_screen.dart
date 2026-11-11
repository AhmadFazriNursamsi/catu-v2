import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_http.dart' as http;
import 'profile_region_fields.dart';
import 'region_transfer_flow.dart' show backendMessage;

/// Romo yang didaftarkan Koordinator belum memilih Provinsi & Kota sendiri.
/// Kota ini menentukan wilayah tugas (Romo Ordo menerima pelayanan di kotanya), jadi wajib diisi sebelum melanjutkan.
bool romoNeedsDomisili(Map<String, dynamic> user) {
  final role = (user['roleCode'] ?? user['role_code'] ?? '').toString().toUpperCase();
  if (role != 'ROMO_PAROKI' && role != 'ROMO_ORDO') return false;
  return (user['kabupatenKotaId'] ?? user['kabupaten_kota_id']) == null;
}

class RomoDomisiliScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const RomoDomisiliScreen({super.key, required this.user});

  @override
  State<RomoDomisiliScreen> createState() => _RomoDomisiliScreenState();
}

class _RomoDomisiliScreenState extends State<RomoDomisiliScreen> {
  int? _provinsiId, _kotaId;
  bool _saving = false;

  bool get _isOrdo => (widget.user['roleCode'] ?? widget.user['role_code'] ?? '').toString().toUpperCase() == 'ROMO_ORDO';

  @override
  void initState() {
    super.initState();
    _provinsiId = int.tryParse('${widget.user['provinsiId'] ?? widget.user['provinsi_id'] ?? ''}');
    _kotaId = int.tryParse('${widget.user['kabupatenKotaId'] ?? widget.user['kabupaten_kota_id'] ?? ''}');
  }

  Future<void> _save() async {
    if (_provinsiId == null || _kotaId == null) {
      _snack('Pilih provinsi dan kota/kabupaten terlebih dahulu.');
      return;
    }
    setState(() => _saving = true);
    try {
      final userId = widget.user['id'] ?? widget.user['user_id'] ?? widget.user['userId'];
      final res = await http
          .put(Uri.parse('${ApiService.baseUrl}/auth/profile/$userId'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'kabupatenKotaId': _kotaId}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 400) {
        _snack(backendMessage(res.body, 'Gagal menyimpan provinsi dan kota.'));
        return;
      }
      final data = jsonDecode(res.body);
      if (data is Map && data['user'] is Map) widget.user.addAll(Map<String, dynamic>.from(data['user']));
      widget.user['kabupatenKotaId'] = _kotaId;
      widget.user['provinsiId'] = _provinsiId;
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _snack('Gagal terhubung ke server. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text('Provinsi & Kota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(),
                const SizedBox(height: 20),
                ProvinsiKotaFields(
                  provinsiId: _provinsiId,
                  kotaId: _kotaId,
                  onChanged: (p, k) => setState(() {
                    _provinsiId = p;
                    _kotaId = k;
                  }),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                        : const Text('Simpan & Lanjutkan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2)),
      child: Row(
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.location_on_rounded, color: Color(0xFF0066FF), size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lengkapi Domisili', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(
                  _isOrdo
                      ? 'Pilih provinsi dan kota tempat Romo bertugas. Pelayanan yang dapat Romo terima mengikuti kota ini.'
                      : 'Pilih provinsi dan kota tempat tinggal Romo sebelum melanjutkan.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
