import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroSection(),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                _buildCard(
                                  onTap: () => _launch('tel:+6285213499965'),
                                  leading: _circleIcon(const Color(0xFF007BFF), Icons.phone_rounded),
                                  label: 'Telepon',
                                  content: const Text('+62 852-1349-9965', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A2540))),
                                ),
                                const SizedBox(height: 16),
                                _buildCard(
                                  onTap: () => _launch('mailto:myemail@catu.id'),
                                  leading: _circleIcon(const Color(0xFFE52E2D), Icons.mail_rounded),
                                  label: 'Email',
                                  content: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(onTap: () => _launch('mailto:myemail@catu.id'), child: const Text('myemail@catu.id', style: TextStyle(fontSize: 15, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                                      const SizedBox(height: 2),
                                      InkWell(onTap: () => _launch('mailto:2ndemail@catu.id'), child: const Text('2ndemail@catu.id', style: TextStyle(fontSize: 15, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildCard(
                                  onTap: () => _launch('https://maps.google.com/?q=Jakarta+14240'),
                                  leading: _circleIcon(const Color(0xFF0284C7), Icons.location_on_rounded),
                                  label: 'Lokasi',
                                  content: const Text('Jakarta 14240', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A2540))),
                                ),
                                const SizedBox(height: 16),
                                _buildCard(
                                  onTap: () => _launch('https://instagram.com'),
                                  leading: _instagramIcon(),
                                  label: 'Instagram',
                                  content: InkWell(onTap: () => _launch('https://instagram.com'), child: const Text('instagram', style: TextStyle(fontSize: 15, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                                ),
                                const SizedBox(height: 28),
                                _buildMottoRow(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0, right: 0, bottom: 0, height: 80,
                    child: IgnorePointer(child: CustomPaint(painter: _BottomWavesPainter())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0066FF), size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text('Pusat Bantuan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0A2540))),
          const Spacer(),
          Image.asset('assets/images/logoCatu.png', height: 42, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('CATU', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE52E2D), fontSize: 18))),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF3FD), Color(0xFFF1F7FE), Color(0xFFF7FAFD)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Us', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0A2540), letterSpacing: -0.5)),
                SizedBox(height: 10),
                Text('Kami siap membantu Anda.\nSilakan hubungi kami melalui\nkontak berikut.', style: TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF5B708B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          CustomPaint(size: const Size(120, 120), painter: _CrossHandsWatermarkPainter()),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget leading, required String label, required Widget content, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F2B66).withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      content,
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF0066FF), size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(Color color, IconData icon) => Container(
        width: 54, height: 54,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 26),
      );

  Widget _instagramIcon() => Container(
        width: 54, height: 54,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.bottomLeft, end: Alignment.topRight,
            colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
          ),
        ),
        child: Center(
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2.2), borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Container(width: 11, height: 11, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.0))),
            ),
          ),
        ),
      );

  Widget _buildMottoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 34, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
        const SizedBox(width: 12),
        Text(
          'Bersama dalam pelayanan',
          style: GoogleFonts.merriweather(fontSize: 14, fontStyle: FontStyle.italic, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Container(width: 34, height: 1.2, color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
      ],
    );
  }
}

class _CrossHandsWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final crossPaint = Paint()..color = const Color(0xFFF4CCD0)..style = PaintingStyle.fill;
    const r = Radius.circular(20);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 40, height: 114), r), crossPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 114, height: 40), r), crossPaint);

    final handPaint = Paint()..color = Colors.white.withValues(alpha: 0.95)..style = PaintingStyle.fill;
    final handStroke = Paint()..color = Colors.white.withValues(alpha: 0.95)..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;

    final pLeft = Path()..moveTo(cx - 36, cy - 20)..quadraticBezierTo(cx - 18, cy - 14, cx - 4, cy - 6)..lineTo(cx + 8, cy - 2)..quadraticBezierTo(cx - 2, cy + 2, cx - 14, cy + 1)..lineTo(cx - 36, cy - 8)..close();
    canvas.drawPath(pLeft, handPaint);

    final pRight = Path()..moveTo(cx + 36, cy + 20)..quadraticBezierTo(cx + 18, cy + 14, cx + 4, cy + 6)..lineTo(cx - 8, cy + 2)..quadraticBezierTo(cx + 2, cy - 2, cx + 14, cy - 1)..lineTo(cx + 36, cy + 8)..close();
    canvas.drawPath(pRight, handPaint);

    canvas.drawLine(Offset(cx - 16, cy - 6), Offset(cx + 4, cy - 2), handStroke);
    canvas.drawLine(Offset(cx + 16, cy + 6), Offset(cx - 4, cy + 2), handStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bluePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft, end: Alignment.topRight,
        colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF2196F3)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final bluePath = Path()
      ..moveTo(0, h * 0.22)
      ..quadraticBezierTo(w * 0.25, h * 0.45, w * 0.65, h * 0.88)
      ..lineTo(w * 0.75, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final cyanPaint = Paint()..color = const Color(0xFF64B5F6).withValues(alpha: 0.35)..style = PaintingStyle.fill;
    final cyanPath = Path()..moveTo(0, h * 0.12)..quadraticBezierTo(w * 0.30, h * 0.35, w * 0.82, h)..lineTo(0, h)..close();
    canvas.drawPath(cyanPath, cyanPaint);

    final redPaint = Paint()..color = const Color(0xFFE52E2D)..style = PaintingStyle.fill;
    final redPath = Path()..moveTo(w * 0.48, h * 0.94)..quadraticBezierTo(w * 0.70, h * 0.82, w, h * 0.38)..lineTo(w, h * 0.48)..quadraticBezierTo(w * 0.72, h * 0.88, w * 0.52, h)..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
