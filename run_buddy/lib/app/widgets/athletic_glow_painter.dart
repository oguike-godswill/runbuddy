import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AthleticGlowPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  AthleticGlowPainter({
    this.primaryColor = AppColors.electricLime,
    this.accentColor = AppColors.buddyBlue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.7),
        radius: 0.9,
        colors: [
          primaryColor.withValues(alpha: 0.16),
          primaryColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, 0.5),
        radius: 0.8,
        colors: [
          accentColor.withValues(alpha: 0.14),
          accentColor.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);

    // Subtle dynamic topography speed lines
    final linePaint = Paint()
      ..color = AppColors.borderNavy.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double i = -size.height * 0.2; i < size.height * 1.2; i += 70) {
      path.moveTo(0, i);
      path.cubicTo(
        size.width * 0.3,
        i + 30,
        size.width * 0.7,
        i - 30,
        size.width,
        i + 15,
      );
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

