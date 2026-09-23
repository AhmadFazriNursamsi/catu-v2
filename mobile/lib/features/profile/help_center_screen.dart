import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.white,
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
                      padding: const EdgeInsets.only(bottom: 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroSection(),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                _buildContactCard(
                                  onTap: () => _launch('tel:+6285213499965'),
                                  leading: _circleIcon(const Color(0xFF007BFF), Icons.phone_rounded),
                                  label: 'Telepon',
                                  content: const Text('+62 852-1349-9965', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2B66))),
                                ),
                                _buildContactCard(
                                  onTap: () => _launch('mailto:myemail@catu.id'),
                                  leading: _circleIcon(const Color(0xFFE52E2D), Icons.mail_rounded),
                                  label: 'Email',
                                  content: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(onTap: () => _launch('mailto:myemail@catu.id'), child: const Text('myemail@catu.id', style: TextStyle(fontSize: 14.5, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                                      const SizedBox(height: 2),
                                      InkWell(onTap: () => _launch('mailto:2ndemail@catu.id'), child: const Text('2ndemail@catu.id', style: TextStyle(fontSize: 14.5, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                ),
                                _buildContactCard(
                                  onTap: () => _launch('https://maps.google.com/?q=Jakarta+14240'),
                                  leading: _circleIcon(const Color(0xFF0284C7), Icons.location_on_rounded),
                                  label: 'Lokasi',
                                  content: const Text('Jakarta 14240', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F2B66))),
                                ),
                                _buildContactCard(
                                  onTap: () => _launch('https://instagram.com'),
                                  leading: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomLeft,
                                        end: Alignment.topRight,
                                        colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
                                      ),
                                    ),
                                    child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 26),
                                  ),
                                  label: 'Instagram',
                                  content: InkWell(onTap: () => _launch('https://instagram.com'), child: const Text('instagram', style: TextStyle(fontSize: 14.5, color: Color(0xFF0066FF), decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                                ),
                                const SizedBox(height: 20),
                                _buildMottoRow(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 70,
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

  Widget _circleIcon(Color color, IconData icon) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 26),
      );

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0066FF), size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text('Pusat Bantuan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F2B66))),
          const Spacer(),
          Image.asset(
            'assets/images/logoCatu.png',
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('CATU', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE52E2D), fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF4FF), Color(0xFFF8FBFF), Colors.white],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contact Us', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F2B66), letterSpacing: -0.5)),
                SizedBox(height: 10),
                Text('Kami siap membantu Anda.\nSilakan hubungi kami melalui\nkontak berikut.', style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF5B708B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          CustomPaint(size: const Size(110, 110), painter: _CrossHandsWatermarkPainter()),
        ],
      ),
    );
  }

  Widget _buildContactCard({required Widget leading, required String label, required Widget content, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F2B66).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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

  Widget _buildMottoRow() {
    return Row(
      children: [
        const SizedBox(width: 32),
        Expanded(child: Container(height: 1, color: const Color(0xFF0284C7).withValues(alpha: 0.35))),
        const SizedBox(width: 12),
        const Text('Bersama dalam pelayanan', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: const Color(0xFF0EA5E9).withValues(alpha: 0.35))),
        const SizedBox(width: 32),
      ],
    );
  }
}

class _CrossHandsWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF8D7DA)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final vBar = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 34, height: 96), const Radius.circular(17));
    final hBar = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 96, height: 34), const Radius.circular(17));
    canvas.drawRRect(vBar, paint);
    canvas.drawRRect(hBar, paint);

    final handPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final p1 = Path()
      ..moveTo(cx - 28, cy - 12)
      ..quadraticBezierTo(cx - 10, cy - 8, cx, cy)
      ..lineTo(cx + 8, cy - 4);
    final p2 = Path()
      ..moveTo(cx + 28, cy + 12)
      ..quadraticBezierTo(cx + 10, cy + 8, cx, cy)
      ..lineTo(cx - 8, cy + 4);

    canvas.drawPath(p1, handPaint);
    canvas.drawPath(p2, handPaint);
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
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF0052CC), Color(0xFF1677FF), Color(0xFF60A5FA)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final bluePath = Path()
      ..moveTo(0, h * 0.25)
      ..quadraticBezierTo(w * 0.35, h * 0.5, w * 0.75, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final redPaint = Paint()
      ..color = const Color(0xFFE52E2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final redPath = Path()
      ..moveTo(w * 0.45, h * 0.94)
      ..quadraticBezierTo(w * 0.72, h * 0.88, w, h * 0.5);
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
