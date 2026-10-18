import 'package:flutter/material.dart';

import '../app_config.dart';

class MapPainter extends CustomPainter {
  final bool dark;
  final List<Offset>? route; // fractions
  MapPainter({this.dark = false, this.route});
  static const xs = [0.15, 0.40, 0.70, 0.90];
  static const ys = [0.20, 0.45, 0.75];

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()..color = dark ? const Color(0xFF1E2A22) : const Color(0xFFEAF1E4),
    );
    // park
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * .45,
          s.height * .50,
          s.width * .22,
          s.height * .20,
        ),
        const Radius.circular(16),
      ),
      Paint()..color = dark ? const Color(0xFF244A33) : const Color(0xFFC9E6C0),
    );
    // river
    final river = Path()
      ..moveTo(0, s.height * .93)
      ..quadraticBezierTo(
        s.width * .4,
        s.height * .80,
        s.width,
        s.height * .97,
      );
    c.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * .04
        ..color = dark ? const Color(0xFF28506B) : const Color(0xFFB5D9F0),
    );
    final road = Paint()
      ..strokeWidth = s.width * .02
      ..color = dark ? const Color(0xFF3A463E) : Colors.white
      ..strokeCap = StrokeCap.round;
    for (final x in xs) {
      c.drawLine(Offset(x * s.width, 0), Offset(x * s.width, s.height), road);
    }
    for (final y in ys) {
      c.drawLine(Offset(0, y * s.height), Offset(s.width, y * s.height), road);
    }
    if (route != null) {
      final p = Path();
      for (var i = 0; i < route!.length; i++) {
        final o = Offset(route![i].dx * s.width, route![i].dy * s.height);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..color = kGreen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter old) =>
      old.dark != dark || old.route != route;
}
