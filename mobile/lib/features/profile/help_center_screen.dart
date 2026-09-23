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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 290,
            child: CustomPaint(painter: _TopWaveBackgroundPainter()),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0, height: 75,
            child: IgnorePointer(child: CustomPaint(painter: _BottomWavesPainter())),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSection(),
                        const SizedBox(height: 14),
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
                                content: const Text('Jakarta 14240', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A2540))),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 20, 4),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
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
          CustomPaint(size: const Size(125, 125), painter: _CrossHandsWatermarkPainter()),
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

class _TopWaveBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFE3F0FF), Color(0xFFEEF6FF), Color(0xFFF8FBFF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.72)
      ..quadraticBezierTo(w * 0.65, h * 0.95, w * 0.25, h * 0.88)
      ..quadraticBezierTo(w * 0.08, h * 0.84, 0, h)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrossHandsWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final crossPaint = Paint()..color = const Color(0xFFF7D5D8)..style = PaintingStyle.fill;
    const r = Radius.circular(22);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 44, height: 120), r), crossPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 44), r), crossPaint);

    final handPaint = Paint()..color = Colors.white.withValues(alpha: 0.90)..style = PaintingStyle.fill;
    final fingerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    // Left forearm / palm
    final leftArm = Path()
      ..moveTo(cx - 42, cy - 24)..lineTo(cx - 24, cy - 16)..lineTo(cx - 8, cy - 8)..lineTo(cx - 12, cy + 6)..lineTo(cx - 36, cy - 8)..close();
    canvas.drawPath(leftArm, handPaint);

    // Left fingers
    canvas.drawLine(Offset(cx - 18, cy - 18), Offset(cx - 4, cy - 22), fingerPaint);
    canvas.drawLine(Offset(cx - 8, cy - 11), Offset(cx + 18, cy - 3), fingerPaint);
    canvas.drawLine(Offset(cx - 7, cy - 6), Offset(cx + 20, cy + 2), fingerPaint);
    canvas.drawLine(Offset(cx - 6, cy - 1), Offset(cx + 18, cy + 7), fingerPaint);
    canvas.drawLine(Offset(cx - 5, cy + 4), Offset(cx + 14, cy + 12), fingerPaint);

    // Right forearm / palm
    final rightArm = Path()
      ..moveTo(cx + 42, cy + 24)..lineTo(cx + 24, cy + 16)..lineTo(cx + 8, cy + 8)..lineTo(cx + 12, cy - 6)..lineTo(cx + 36, cy + 8)..close();
    canvas.drawPath(rightArm, handPaint);

    // Right fingers
    canvas.drawLine(Offset(cx + 18, cy + 18), Offset(cx + 4, cy + 22), fingerPaint);
    canvas.drawLine(Offset(cx + 8, cy + 11), Offset(cx - 18, cy + 3), fingerPaint);
    canvas.drawLine(Offset(cx + 7, cy + 6), Offset(cx - 20, cy - 2), fingerPaint);
    canvas.drawLine(Offset(cx + 6, cy + 1), Offset(cx - 18, cy - 7), fingerPaint);
    canvas.drawLine(Offset(cx + 5, cy - 4), Offset(cx - 14, cy - 12), fingerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final lightBlue = Paint()..color = const Color(0xFF90CAF9).withValues(alpha: 0.3)..style = PaintingStyle.fill;
    final pLight = Path()..moveTo(0, h * 0.15)..quadraticBezierTo(w * 0.32, h * 0.35, w * 0.85, h)..lineTo(0, h)..close();
    canvas.drawPath(pLight, lightBlue);

    final bluePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft, end: Alignment.topRight,
        colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF1E88E5)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final bluePath = Path()..moveTo(0, h * 0.28)..quadraticBezierTo(w * 0.28, h * 0.50, w * 0.68, h * 0.92)..lineTo(w * 0.76, h)..lineTo(0, h)..close();
    canvas.drawPath(bluePath, bluePaint);

    final redPaint = Paint()..color = const Color(0xFFE52E2D)..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    final redPath = Path()..moveTo(w * 0.44, h * 0.95)..quadraticBezierTo(w * 0.72, h * 0.82, w, h * 0.38);
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
