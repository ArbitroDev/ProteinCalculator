import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protein_calculator/core/theme.dart';

/// White of the snow of the Christmas theme, outlined with the structure
/// color so it shows on the light background too.
const snowWhite = Color(0xFFFFFFFF);
const _snow = snowWhite;

Paint _outline(AppColors colors, double width) => Paint()
  ..color = colors.structure.withValues(alpha: 0.4)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// A few flakes falling slowly over the pages, from December 1 to 25. They
/// never take a touch, and stay still where animations are reduced.
class Snowfall extends StatefulWidget {
  const Snowfall({super.key});

  /// Flakes on the screen at once: few enough to leave the pages readable.
  static const flakeCount = 20;

  @override
  State<Snowfall> createState() => _SnowfallState();
}

class _SnowfallState extends State<Snowfall>
    with SingleTickerProviderStateMixin {
  /// Time of the fall, in seconds; every flake falls in 9 to 17 seconds.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3600),
  );

  static final List<_Flake> _flakes = () {
    // Always the same flakes, so the screen does not jump on a rebuild.
    final random = Random(25);
    return [
      for (var i = 0; i < Snowfall.flakeCount; i++)
        _Flake(
          x: random.nextDouble(),
          radius: 1.5 + random.nextDouble() * 2,
          fallSeconds: 9 + random.nextDouble() * 8,
          phase: random.nextDouble(),
          drift: 8 + random.nextDouble() * 22,
        ),
    ];
  }();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SnowfallPainter(
          flakes: _flakes,
          clock: _clock,
          colors: AppColors.of(context),
        ),
      ),
    ),
  );
}

class _Flake {
  const _Flake({
    required this.x,
    required this.radius,
    required this.fallSeconds,
    required this.phase,
    required this.drift,
  });

  /// Across the screen, from 0 to 1.
  final double x;
  final double radius;
  final double fallSeconds;

  /// Where the flake is in its fall at the start, from 0 to 1.
  final double phase;

  /// Swing from side to side, in pixels.
  final double drift;
}

class _SnowfallPainter extends CustomPainter {
  _SnowfallPainter({
    required this.flakes,
    required this.clock,
    required this.colors,
  }) : super(repaint: clock);

  final List<_Flake> flakes;
  final Animation<double> clock;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value * 3600;
    final fill = Paint()..color = _snow;
    final outline = _outline(colors, 0.8);
    for (final flake in flakes) {
      final fall = (seconds / flake.fallSeconds + flake.phase) % 1;
      final center = Offset(
        flake.x * size.width + sin(fall * 2 * pi) * flake.drift / 2,
        -10 + fall * (size.height + 20),
      );
      canvas
        ..drawCircle(center, flake.radius, fill)
        ..drawCircle(center, flake.radius, outline);
    }
  }

  @override
  bool shouldRepaint(_SnowfallPainter old) =>
      old.flakes != flakes || old.colors != colors;
}

/// A low bank of snow along the bottom of the pages, just above the tab bar.
class SnowBank extends StatelessWidget {
  const SnowBank({super.key});

  static const height = 18.0;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: const Size(double.infinity, height),
      painter: _SnowBankPainter(AppColors.of(context)),
    ),
  );
}

class _SnowBankPainter extends CustomPainter {
  _SnowBankPainter(this.colors);

  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Gentle hills, the same on any width.
    final top = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.08, h * 0.1, w * 0.2, h * 0.4)
      ..quadraticBezierTo(w * 0.32, h * 0.7, w * 0.44, h * 0.3)
      ..quadraticBezierTo(w * 0.58, 0, w * 0.68, h * 0.42)
      ..quadraticBezierTo(w * 0.8, h * 0.8, w * 0.9, h * 0.3)
      ..quadraticBezierTo(w * 0.96, h * 0.1, w, h * 0.25);
    // A pixel past the bottom, under the snow of the tab bar: the two meet
    // between two pixels, which would leave a line otherwise.
    final bank = Path.from(top)
      ..lineTo(w, h + 1)
      ..lineTo(0, h + 1)
      ..close();
    canvas
      ..drawPath(bank, Paint()..color = _snow)
      ..drawPath(top, _outline(colors, 1));
  }

  @override
  bool shouldRepaint(_SnowBankPainter old) => old.colors != colors;
}

/// Snow settled on the shaker, in its 110 x 290 drawing box, as it lies
/// after falling for a while: piled higher on the left of the dome of the
/// lid and thinner on the right, with drips of uneven lengths over its edge,
/// a mound leaning on the cap and a line on the left of the handle.
///
/// [amount] is how much has settled, from 0 to 1: it piles up from the lid.
/// While [fall] is set, the seconds since the shaker was shaken, the snow
/// that lay there, [fallen], falls off in clumps, see [snowFallSeconds].
void paintSnowOnLid(
  Canvas canvas,
  AppColors colors, {
  double amount = 1,
  double? fall,
  double fallen = 0,
}) {
  if (amount > 0) {
    // Each part grows from the top of what it lies on: a small heap in the
    // middle first, then wider and thicker.
    for (final (path, top, depth) in [
      (_dome, const Offset(52, 38), 4.0),
      (_cap, const Offset(37, 26), 2.5),
      (_handle, const Offset(74, 7), 1.5),
    ]) {
      _paintLying(canvas, colors, path, top, depth, amount);
    }
  }
  if (fall != null && fall < snowFallSeconds) {
    _paintFalling(canvas, colors, fall, fallen);
  }
}

/// Time the snow takes to fall off the shaker when it is shaken.
const snowFallSeconds = 0.9;

void _paintLying(
  Canvas canvas,
  AppColors colors,
  Path full,
  Offset top,
  double depth,
  double amount,
) {
  // Faint at first; the shape gathered towards [top], its outline kept as
  // thin.
  final opacity = min(1.0, amount * 3);
  final path = full.transform(
    (Matrix4.identity()
          ..translateByDouble(top.dx, top.dy, 0, 1)
          ..scaleByDouble(0.45 + 0.55 * amount, amount, 1, 1)
          ..translateByDouble(-top.dx, -top.dy, 0, 1))
        .storage,
  );
  final shade = Paint()
    ..color = colors.structure.withValues(alpha: 0.14 * opacity);
  canvas
    ..drawPath(path, Paint()..color = _snow.withValues(alpha: opacity))
    // The shade: the snow shifted up, cut out of it, leaves its bottom.
    ..save()
    ..clipPath(path)
    ..drawPath(
      Path.combine(
        PathOperation.difference,
        path,
        path.shift(Offset(0, -depth)),
      ),
      shade,
    )
    ..restore()
    ..drawPath(
      path,
      _outline(colors, 1.2)
        ..color = colors.structure.withValues(alpha: 0.4 * opacity),
    );
}

/// Clumps of snow coming off the lid: where they lay, their size and how
/// fast they leave it, sideways and up.
const _clumps = [
  (x: 22.0, y: 42.0, r: 5.0, vx: -26.0, vy: -40.0),
  (x: 33.0, y: 31.0, r: 5.5, vx: -14.0, vy: -70.0),
  (x: 45.0, y: 28.0, r: 6.0, vx: -4.0, vy: -85.0),
  (x: 56.0, y: 32.0, r: 5.0, vx: 9.0, vy: -60.0),
  (x: 70.0, y: 34.0, r: 4.5, vx: 18.0, vy: -50.0),
  (x: 86.0, y: 42.0, r: 3.8, vx: 30.0, vy: -30.0),
  (x: 34.0, y: 22.0, r: 3.6, vx: -10.0, vy: -90.0),
  (x: 42.0, y: 20.0, r: 3.0, vx: 4.0, vy: -100.0),
  (x: 68.0, y: 8.0, r: 2.8, vx: 6.0, vy: -60.0),
];

void _paintFalling(Canvas canvas, AppColors colors, double t, double fallen) {
  // Falls under gravity, in units of the drawing per second², and fades
  // out on the way down.
  const gravity = 420.0;
  final opacity = (1 - t / snowFallSeconds).clamp(0.0, 1.0);
  final fill = Paint()..color = _snow.withValues(alpha: opacity);
  final outline = _outline(colors, 1)
    ..color = colors.structure.withValues(alpha: 0.4 * opacity);
  final scale = sqrt(fallen);
  for (final c in _clumps) {
    final center = Offset(c.x + c.vx * t, c.y + c.vy * t + gravity * t * t / 2);
    final r = c.r * scale;
    // A clump: two lumps of snow stuck together.
    final shape = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: center, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: center + Offset(r * 0.7, -r * 0.3),
          radius: r * 0.7,
        ),
      ),
    );
    canvas
      ..drawPath(shape, fill)
      ..drawPath(shape, outline);
  }
}

// The dome of the lid runs from (19, 54) up to y = 38 and back down to
// (91, 54): the snow is piled higher on its left, with drips of uneven
// lengths.
final _dome = Path()
  ..moveTo(15, 53)
  ..cubicTo(13, 44, 15, 35, 24, 33)
  ..quadraticBezierTo(31, 27, 40, 27.5)
  ..quadraticBezierTo(46, 23.5, 52, 26.5)
  ..quadraticBezierTo(60, 28.5, 68, 30.5)
  ..quadraticBezierTo(74, 31, 79, 32.5)
  ..cubicTo(88, 33.5, 92, 38, 92.5, 46)
  ..quadraticBezierTo(93, 51, 92, 52)
  // Back along the bottom, from the right.
  ..quadraticBezierTo(92, 56, 90, 56)
  ..quadraticBezierTo(88, 56.5, 87.5, 50)
  ..quadraticBezierTo(82, 46.5, 76, 47.5)
  ..quadraticBezierTo(75.5, 53, 73.5, 53.5)
  ..quadraticBezierTo(71, 54, 70.5, 48.5)
  ..quadraticBezierTo(62, 46.5, 53, 48.5)
  ..quadraticBezierTo(52, 63, 48.5, 63)
  ..quadraticBezierTo(45.5, 63, 45, 52)
  ..quadraticBezierTo(41, 49.5, 36, 50.5)
  ..quadraticBezierTo(34, 57.5, 31, 57.5)
  ..quadraticBezierTo(28, 57.5, 27.5, 51.5)
  ..quadraticBezierTo(22, 51, 19.5, 53.5)
  ..quadraticBezierTo(18, 57, 16.5, 56)
  ..quadraticBezierTo(15, 55, 15, 53)
  ..close();

// The cap, from (25, 26) to (49, 40): a mound leaning on its left, with a
// drip in the middle.
final _cap = Path()
  ..moveTo(23.5, 30)
  ..cubicTo(22, 23, 27, 18.5, 33, 19)
  ..quadraticBezierTo(39, 18, 44, 21.5)
  ..cubicTo(49, 22.5, 51, 25.5, 50.5, 29)
  ..quadraticBezierTo(49.5, 31.5, 46, 30.5)
  ..quadraticBezierTo(41, 29.5, 37.5, 31)
  ..quadraticBezierTo(36, 36.5, 33.5, 36)
  ..quadraticBezierTo(31, 35.5, 30.5, 31)
  ..quadraticBezierTo(27, 32.5, 23.5, 30)
  ..close();

// The handle, an arc from (64, 24) over (75, 12) to (86, 24): snow on its
// left and its top only.
final _handle = Path()
  ..moveTo(60.8, 19)
  ..quadraticBezierTo(61, 6.5, 74, 5.8)
  ..quadraticBezierTo(83, 5.5, 86.5, 11)
  ..quadraticBezierTo(87, 13.5, 85, 13)
  ..quadraticBezierTo(81, 9.5, 75, 10)
  ..quadraticBezierTo(66, 10.5, 64, 18)
  ..quadraticBezierTo(62.5, 21, 60.8, 19)
  ..close();
