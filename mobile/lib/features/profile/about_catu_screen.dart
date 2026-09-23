import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';

class AboutCatuScreen extends StatelessWidget {
  const AboutCatuScreen({super.key});

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
          title: const Text(
            'Tentang CATU',
            style: TextStyle(
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(),
              const SizedBox(height: 18),
              _buildPillarCard(
                badgeText: 'VERSI 1 • LAYANAN KEDUKAAN',
                badgeColor: const Color(0xFF0284C7),
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBgColor: const Color(0xFFE0F2FE),
                title: 'Pelayanan Umat',
                description:
                    'Umat Katolik yang perlu diberi bantuan pada saat kedukaan adalah bentuk pelayanan yang konkrit.',
                features: const [
                  'Pendampingan doa arwah & misa requiem',
                  'Permohonan sakramen perminyakan orang sakit',
                  'Dukungan koordinasi lingkungan & paroki',
                ],
              ),
              const SizedBox(height: 14),
              _buildPillarCard(
                badgeText: 'VERSI 2 • LAYANAN KESEHATAN',
                badgeColor: const Color(0xFF4338CA),
                icon: Icons.medical_services_rounded,
                iconColor: const Color(0xFF4338CA),
                iconBgColor: const Color(0xFFEEF2FF),
                title: 'Pelayanan Medis',
                description:
                    'Para Romo membutuhkan layanan medis dari dokter untuk optimal dalam pelayanan.',
                features: const [
                  'Konsultasi medis & pemeriksaan berkala',
                  'Jaringan dokter & tenaga medis Katolik',
                  'Penjadwalan perawatan kesehatan terintegrasi',
                ],
              ),
              const SizedBox(height: 14),
              _buildPillarCard(
                badgeText: 'SINERGI KOMUNITAS',
                badgeColor: const Color(0xFF0D9488),
                icon: Icons.church_rounded,
                iconColor: const Color(0xFF0D9488),
                iconBgColor: const Color(0xFFCCFBF1),
                title: 'Pelayanan Gereja',
                description:
                    'Melengkapi kebutuhan Gereja secara menyeluruh dengan melibatkan semua pihak.',
                features: const [
                  'Kolaborasi keuskupan, paroki, & umat',
                  'Transparansi data & penjadwalan pastoral',
                  'Partisipasi aktif seluruh elemen Gereja',
                ],
              ),
              const SizedBox(height: 24),
              _buildAppInfoCard(),
              const SizedBox(height: 20),
              _buildMottoRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF0284C7)),
                SizedBox(width: 6),
                Text('TENTANG KAMI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF0284C7))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Misi & Pelayanan CATU', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.4)),
          const SizedBox(height: 8),
          const Text(
            'Kami berusaha membantu umat Katolik untuk mendapatkan layanan Romo untuk umat yang berduka (versi 1) dan memberikan layanan untuk Romo yang membutuhkan perawatan dan konsultasi medis (versi 2).',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarCard({
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
    required List<String> features,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badgeText, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: badgeColor)),
                    const SizedBox(height: 2),
                    Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          ...features.map((feat) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feat, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Text('CATU Platform Mobile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          SizedBox(height: 3),
          Text('Versi Aplikasi ${AppConstants.appVersion}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
          SizedBox(height: 3),
          Text('© 2026 CATU. All Rights Reserved.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildMottoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 40, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
        const SizedBox(width: 14),
        Text(
          'Bersama dalam pelayanan',
          style: GoogleFonts.dancingScript(fontSize: 18, fontStyle: FontStyle.italic, color: const Color(0xFF0284C7), fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 14),
        Container(width: 40, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
      ],
    );
  }
}
