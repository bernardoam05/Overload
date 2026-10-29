import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/ranks.dart';

/// Hexagonal emblem for a rank tier, with pips for the division.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.standing, this.size = 56});

  final RankStanding standing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BadgePainter(
          tier: standing.tier,
          tierIndex: standing.tierIndex,
          pips: standing.isMaxTier ? 0 : standing.division + 1,
          empty: standing.score <= 0,
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.tier,
    required this.tierIndex,
    required this.pips,
    required this.empty,
  });

  final Tier tier;
  final int tierIndex;
  final int pips;
  final bool empty;

  Path _hexagon(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final color = Brand.tierColor(tier);
    final glow = Brand.tierGlow(tier);
    final opacity = empty ? 0.35 : 1.0;

    if (!empty) {
      canvas.drawPath(
        _hexagon(c, r * 0.92),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
      );
    }

    final outer = _hexagon(c, r * 0.92);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: opacity),
            glow.withValues(alpha: opacity),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final inner = _hexagon(c, r * 0.68);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: opacity),
            Color.lerp(glow, Colors.black, 0.55)!.withValues(alpha: opacity),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.7)),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = Color.lerp(
          color,
          Colors.white,
          0.5,
        )!.withValues(alpha: 0.7 * opacity),
    );

    // Central mark: a stylised flame / chevron that grows with the tier.
    final mark = Path();
    final h = r * (0.32 + 0.025 * tierIndex);
    final w = r * 0.30;
    mark
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + w, c.dy + h * 0.15)
      ..lineTo(c.dx + w * 0.35, c.dy + h * 0.05)
      ..lineTo(c.dx + w * 0.5, c.dy + h * 0.7)
      ..lineTo(c.dx, c.dy + h * 0.35)
      ..lineTo(c.dx - w * 0.5, c.dy + h * 0.7)
      ..lineTo(c.dx - w * 0.35, c.dy + h * 0.05)
      ..lineTo(c.dx - w, c.dy + h * 0.15)
      ..close();
    canvas.drawPath(
      mark,
      Paint()
        ..color = Color.lerp(
          color,
          Colors.white,
          0.6,
        )!.withValues(alpha: opacity),
    );

    // Division pips along the bottom edge.
    if (pips > 0 && !empty) {
      final pipR = r * 0.07;
      final spacing = pipR * 2.8;
      final y = c.dy + r * 0.80;
      final start = c.dx - spacing * (pips - 1) / 2;
      for (var i = 0; i < pips; i++) {
        final p = Offset(start + i * spacing, y);
        canvas.drawCircle(p, pipR * 1.35, Paint()..color = glow);
        canvas.drawCircle(p, pipR, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.tier != tier ||
      old.pips != pips ||
      old.empty != empty ||
      old.tierIndex != tierIndex;
}
