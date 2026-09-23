import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launch(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) await launchUrl(uri);
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
              const SizedBox(height: 16),
              _buildCard(
                onTap: () => _launch('tel:+6285213499965'),
                leading: _circleIcon(const Color(0xFF007BFF), Icons.phone_rounded),
                label: 'Telepon',
                content: const Text('+62 852-1349-9965', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0A2540))),
              ),
              const SizedBox(height: 14),
              _buildCard(
                onTap: () => _launch('mailto:myemail@catu.id'),
                leading: _circleIcon(const Color(0xFFE52E2D), Icons.mail_rounded),
                label: 'Email',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(onTap: () => _launch('mailto:myemail@catu.id'), child: const Text('myemail@catu.id', style: TextStyle(fontSize: 14.5, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 3),
                    InkWell(onTap: () => _launch('mailto:2ndemail@catu.id'), child: const Text('2ndemail@catu.id', style: TextStyle(fontSize: 14.5, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildCard(
                onTap: () => _launch('https://maps.google.com/?q=Jakarta+14240'),
                leading: _circleIcon(const Color(0xFF0284C7), Icons.location_on_rounded),
                label: 'Lokasi',
                content: const Text('Jakarta 14240', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0A2540))),
              ),
              const SizedBox(height: 14),
              _buildCard(
                onTap: () => _launch('https://instagram.com'),
                leading: _instagramIcon(),
                label: 'Instagram',
                content: InkWell(onTap: () => _launch('https://instagram.com'), child: const Text('instagram', style: TextStyle(fontSize: 14.5, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
              ),
              const SizedBox(height: 26),
              _buildMottoRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Us', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                SizedBox(height: 8),
                Text('Kami siap membantu Anda.\nSilakan hubungi kami melalui\nkontak berikut.', style: TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Image.asset(
            'assets/images/catu_app_logo.png',
            width: 95,
            height: 95,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(width: 95, height: 95),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget leading, required String label, required Widget content, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F2B66).withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      content,
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0066FF), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(Color color, IconData icon) => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 26),
      );

  Widget _instagramIcon() => Container(
        width: 52, height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.bottomLeft, end: Alignment.topRight,
            colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
          ),
        ),
        child: Center(
          child: Container(
            width: 25, height: 25,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2.2), borderRadius: BorderRadius.circular(7.5)),
            child: Center(
              child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.0))),
            ),
          ),
        ),
      );

  Widget _buildMottoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 44, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
        const SizedBox(width: 14),
        Text(
          'Bersama dalam pelayanan',
          style: GoogleFonts.dancingScript(fontSize: 18, fontStyle: FontStyle.italic, color: const Color(0xFF0284C7), fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 14),
        Container(width: 44, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
      ],
    );
  }
}
