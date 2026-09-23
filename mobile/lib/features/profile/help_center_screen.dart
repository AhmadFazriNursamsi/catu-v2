import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const String instagramUrl =
      'https://www.instagram.com/catu.caribantu?stkn=endiN2czYmF5YjBt';

  Future<void> _launch(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (_) {}
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
          title: const Text(
            'Pusat Bantuan',
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
              _buildCard(
                onTap: () => _launch('tel:+6285213499965'),
                leading: _circleIcon(const Color(0xFF0284C7), Icons.phone_rounded),
                badgeText: 'TELEPON & WHATSAPP',
                badgeColor: const Color(0xFF0284C7),
                content: const Text(
                  '+62 852-1349-9965',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 14),
              _buildCard(
                onTap: () => _launch('mailto:myemail@catu.id'),
                leading: _circleIcon(const Color(0xFFDC2626), Icons.mail_rounded),
                badgeText: 'EMAIL DUKUNGAN',
                badgeColor: const Color(0xFFDC2626),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _launch('mailto:myemail@catu.id'),
                      child: const Text(
                        'myemail@catu.id',
                        style: TextStyle(fontSize: 14.5, color: Color(0xFF0284C7), decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _launch('mailto:2ndemail@catu.id'),
                      child: const Text(
                        '2ndemail@catu.id',
                        style: TextStyle(fontSize: 14.5, color: Color(0xFF0284C7), decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildCard(
                onTap: () => _launch('https://maps.google.com/?q=Jakarta+14240'),
                leading: _circleIcon(const Color(0xFF0D9488), Icons.location_on_rounded),
                badgeText: 'LOKASI KANTOR',
                badgeColor: const Color(0xFF0D9488),
                content: const Text(
                  'Jakarta 14240, Indonesia',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 14),
              _buildCard(
                onTap: () => _launch(instagramUrl),
                leading: _instagramIcon(),
                badgeText: 'INSTAGRAM RESMI',
                badgeColor: const Color(0xFFC026D3),
                content: InkWell(
                  onTap: () => _launch(instagramUrl),
                  child: const Text(
                    '@catu.caribantu',
                    style: TextStyle(
                      fontSize: 15.5,
                      color: Color(0xFF0284C7),
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headset_mic_rounded, size: 14, color: Color(0xFF0284C7)),
                SizedBox(width: 6),
                Text(
                  'LAYANAN BANTUAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Contact Us',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kami siap melayani dan mendampingi Anda. Silakan hubungi tim kami melalui kontak di bawah ini.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Widget leading,
    required String badgeText,
    required Color badgeColor,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      content,
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF94A3B8),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(Color color, IconData icon) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color, size: 24),
      );

  Widget _instagramIcon() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [
              Color(0xFFFEDA75),
              Color(0xFFFA7E1E),
              Color(0xFFD62976),
              Color(0xFF962FBF),
              Color(0xFF4F5BD5),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.0),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.8),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildMottoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 40, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
        const SizedBox(width: 14),
        Text(
          'Bersama dalam pelayanan',
          style: GoogleFonts.dancingScript(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF0284C7),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 14),
        Container(width: 40, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
      ],
    );
  }
}
