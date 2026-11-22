import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';

/// Gold of the caps of the baubles and of the star.
const _gold = Color(0xFFE0B44C);
const _goldDark = Color(0xFFA47A1C);

/// Colors of the lit bulbs of the garland, in turn.
const _bulbs = [
  Color(0xFFFFD34D),
  Color(0xFFFF5A6A),
  Color(0xFF6BD69A),
  Color(0xFFFFFFFF),
];

/// A day of December up to the 25th in the Christmas theme, in the square
/// the bubble of a day takes: a bauble hanging from the garland of its
/// week, whose bulbs light up above the days reaching their goal. The 25th
/// is the star at the top of the tree.
class ChristmasDay extends StatelessWidget {
  const ChristmasDay({
    super.key,
    required this.day,
    required this.fill,
    required this.textColor,
    required this.bold,
    required this.isToday,
    required this.lit,
    required this.gap,
    required this.onTap,
  });

  /// Day of December, from 1 to 25.
  final int day;

  /// Colors of the day, as its bubble would have them; [fill] transparent
  /// for a day to come.
  final Color fill;
  final Color textColor;
  final bool bold;
  final bool isToday;

  /// Whether the goal of the day is reached: the garland above it lights up,
  /// or the star shines.
  final bool lit;

  /// Space between two days, which the garland crosses.
  final double gap;
  final VoidCallback? onTap;

  bool get _star => day == 25;

  /// The bauble hangs a little lower or higher from one day to the next.
  double get _drop => const [0.0, 0.07, 0.02, 0.09, 0.0, 0.05, 0.03][day % 7];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final number = Text(
          '$day',
          style: textTheme.bodyLarge!.copyWith(
            fontSize: _star ? 12 : 13,
            height: 1,
            color: textColor,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        );
        final ball = _ballRect(w);
        return CustomPaint(
          painter: _GarlandPainter(
            colors: colors,
            day: day,
            lit: lit,
            gap: gap,
            hangTo: _star ? _starRect(w).top + w * 0.06 : ball.top - w * 0.07,
            last: _star,
          ),
          foregroundPainter: _star
              ? null
              : _CapPainter(ball: ball, empty: fill.a == 0),
          child: _star
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StarPainter(
                          rect: _starRect(w),
                          fill: fill,
                          lit: lit,
                          isToday: isToday,
                          ring: colors.structure,
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: _starRect(w),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onTap,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: w * 0.05),
                              child: number,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Positioned.fromRect(
                      rect: ball,
                      child: Material(
                        color: fill,
                        // A day to come: a bauble still clear, in outline.
                        shape: CircleBorder(
                          side: isToday
                              ? BorderSide(color: colors.structure, width: 2)
                              : fill.a == 0
                              ? BorderSide(
                                  color: colors.structure.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1.2,
                                )
                              : BorderSide.none,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onTap,
                          child: Center(child: number),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// The bauble, low in the square, the string above it.
  Rect _ballRect(double w) {
    final r = w * 0.34;
    final center = Offset(w / 2, w - r - w * 0.02 - _drop * w);
    return Rect.fromCircle(center: center, radius: r);
  }

  Rect _starRect(double w) =>
      Rect.fromCircle(center: Offset(w / 2, w * 0.58), radius: w * 0.42);
}

/// The piece of garland above a day, the bulbs on it and the string down to
/// its bauble or star.
class _GarlandPainter extends CustomPainter {
  _GarlandPainter({
    required this.colors,
    required this.day,
    required this.lit,
    required this.gap,
    required this.hangTo,
    required this.last,
  });

  final AppColors colors;
  final int day;
  final bool lit;
  final double gap;

  /// Where the string ends, at the top of the bauble or star.
  final double hangTo;

  /// Whether the garland ends on this day, at the star.
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final y = w * 0.05;
    final sag = w * 0.06;
    // From the middle of the gap on the left to the middle of the gap on the
    // right, to meet the pieces of the next days; the first day of December
    // starts it, the star ends it.
    final left = day == 1 ? w / 2 : -gap / 2;
    final right = last ? w / 2 : w + gap / 2;
    Offset at(double t) {
      // A quadratic sag between the two ends, lowest in the middle.
      final x = left + (right - left) * t;
      return Offset(x, y + sag * 4 * t * (1 - t));
    }

    final rope = Paint()
      ..color = colors.structure.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()..moveTo(left, y);
    for (var i = 1; i <= 12; i++) {
      final p = at(i / 12);
      path.lineTo(p.dx, p.dy);
    }
    // The string the bauble hangs from, from the middle of the day.
    final middle = at((w / 2 - left) / (right - left));
    canvas
      ..drawPath(path, rope)
      ..drawLine(middle, Offset(w / 2, hangTo), rope..strokeWidth = 1);

    // Two bulbs above each day, lit when its goal is reached.
    for (final (k, t) in [(0, 0.25), (1, 0.75)]) {
      final x = t * w;
      if (x < left || x > right) continue;
      final p = at((x - left) / (right - left)) + Offset(0, w * 0.035);
      final bulb = Rect.fromCenter(center: p, width: w * 0.07, height: w * 0.1);
      if (lit) {
        final color = _bulbs[(day * 2 + k) % _bulbs.length];
        canvas
          ..drawCircle(
            p,
            w * 0.11,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  color.withValues(alpha: 0.55),
                  color.withValues(alpha: 0),
                ],
              ).createShader(Rect.fromCircle(center: p, radius: w * 0.11)),
          )
          ..drawOval(bulb, Paint()..color = color);
      } else {
        canvas.drawOval(
          bulb,
          Paint()..color = colors.structure.withValues(alpha: 0.3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GarlandPainter old) =>
      old.lit != lit ||
      old.colors != colors ||
      old.hangTo != hangTo ||
      old.gap != gap;
}

/// The gold cap of a bauble and its shine, over it.
class _CapPainter extends CustomPainter {
  _CapPainter({required this.ball, required this.empty});

  final Rect ball;

  /// A bauble of a day to come, without color: no shine on it.
  final bool empty;

  @override
  void paint(Canvas canvas, Size size) {
    final r = ball.width / 2;
    final cap = Rect.fromCenter(
      center: Offset(ball.center.dx, ball.top - r * 0.06),
      width: r * 0.62,
      height: r * 0.3,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(r * 0.08)),
        Paint()..color = _gold,
      )
      ..drawLine(
        cap.centerLeft,
        cap.centerRight,
        Paint()
          ..color = _goldDark
          ..strokeWidth = 0.8,
      );
    if (empty) return;
    // The shine, on the upper left.
    final shine = Path()
      ..addArc(
        Rect.fromCircle(center: ball.center, radius: r * 0.7),
        pi * 1.05,
        pi * 0.35,
      );
    canvas.drawPath(
      shine,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CapPainter old) => old.ball != ball || old.empty != empty;
}

/// The star of the 25th, at the top of the tree: colored like a day, in a
/// gold frame, shining once the goal is reached.
class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.rect,
    required this.fill,
    required this.lit,
    required this.isToday,
    required this.ring,
  });

  final Rect rect;
  final Color fill;
  final bool lit;
  final bool isToday;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = rect.center;
    final outer = rect.width / 2;
    final inner = outer * 0.5;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(angle), sin(angle)) * radius;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    if (lit) {
      canvas.drawCircle(
        c,
        outer * 1.25,
        Paint()
          ..shader = RadialGradient(
            colors: [_gold.withValues(alpha: 0.55), _gold.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: outer * 1.25)),
      );
    }
    canvas
      ..drawPath(star, Paint()..color = fill)
      ..drawPath(
        star,
        Paint()
          ..color = isToday ? ring : _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.rect != rect ||
      old.fill != fill ||
      old.lit != lit ||
      old.isToday != isToday ||
      old.ring != ring;
}
