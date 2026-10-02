import 'dart:math';

import 'package:flutter/material.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/theme.dart';

/// One entry shown as a layer in the shaker.
@immutable
class ShakerLayer {
  const ShakerLayer({required this.grams, required this.slot});

  final double grams;
  final DaySlot slot;

  @override
  bool operator ==(Object other) =>
      other is ShakerLayer && other.grams == grams && other.slot == slot;

  @override
  int get hashCode => Object.hash(grams, slot);
}

/// Live state of the liquid, driven by the phone motion: only the drawing
/// repaints when it changes, the widget tree does not rebuild.
class ShakerMotion extends ChangeNotifier {
  /// Angle of the liquid surface, in radians: it stays level while the
  /// phone tilts.
  double tilt = 0;

  /// How mixed the layers are, from 0 (separate) to 1 (fully mixed).
  double mix = 0;

  /// Advances while mixing, to animate the swirl and the bubbles.
  double phase = 0;

  void update({
    required double tilt,
    required double mix,
    required double phase,
  }) {
    this.tilt = tilt;
    this.mix = mix;
    this.phase = phase;
    notifyListeners();
  }
}

/// Protein shaker filled with one layer per entry, graduated up to [goal].
///
/// The fill level animates when entries are added or removed, unless the
/// device asks to reduce animations. An optional [motion] tilts and mixes
/// the liquid.
class Shaker extends StatelessWidget {
  const Shaker({
    super.key,
    required this.layers,
    required this.goal,
    required this.semanticLabel,
    this.motion,
  });

  final List<ShakerLayer> layers;
  final double goal;
  final String semanticLabel;
  final ShakerMotion? motion;

  /// Width / height ratio of the drawing.
  static const aspectRatio = 110 / 290;

  /// Empty space under the bottom of the drawing, as a fraction of its
  /// height, to align other widgets with the visible bottom of the shaker.
  static const bottomInset = (290 - 283.5) / 290;

  @override
  Widget build(BuildContext context) {
    final total = layers.fold(0.0, (sum, layer) => sum + layer.grams);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: semanticLabel,
      image: true,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: total),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, level, _) => RepaintBoundary(
            child: CustomPaint(
              painter: _ShakerPainter(
                layers: layers,
                goal: goal,
                level: level,
                colors: AppColors.of(context),
                motion: motion,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShakerPainter extends CustomPainter {
  _ShakerPainter({
    required this.layers,
    required this.goal,
    required this.level,
    required this.colors,
    required this.motion,
  }) : super(repaint: motion);

  final List<ShakerLayer> layers;
  final double goal;
  final double level;
  final AppColors colors;
  final ShakerMotion? motion;

  // Drawing coordinates, in a 110 x 290 box.
  static const _width = 110.0;
  static const _bottom = 280.0;
  static const _fillHeight = 184.0;
  static const _left = 10.0;
  static const _right = 100.0;
  static const _center = 55.0;

  static final _body = Path()
    ..moveTo(17, 76)
    ..lineTo(23, 270)
    ..quadraticBezierTo(24, 282, 36, 282)
    ..lineTo(74, 282)
    ..quadraticBezierTo(86, 282, 87, 270)
    ..lineTo(93, 76)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _width);

    final total = layers.fold(0.0, (sum, layer) => sum + layer.grams);
    final range = max(goal, total);
    double y(double grams) => _bottom - grams / range * _fillHeight;

    _paintContent(canvas, y, total);
    _paintGraduations(canvas, range, y);
    _paintLid(canvas);
  }

  void _paintContent(Canvas canvas, double Function(double) y, double total) {
    canvas
      ..save()
      ..clipPath(_body)
      ..drawRect(
        const Rect.fromLTWH(0, 0, _width, 290),
        Paint()..color = colors.shakerInside,
      );

    final tilt = motion?.tilt ?? 0;
    final mix = motion?.mix ?? 0;
    final phase = motion?.phase ?? 0;
    final slope = tan(tilt);

    // Height of the boundary between two layers, or of the surface, at x:
    // tilted with the phone, waving while the layers mix.
    double boundary(double grams, int index, double x, {bool surface = false}) {
      var value = y(grams) - (x - _center) * slope;
      if (surface) value -= 3 * sin((x - _left) / (_right - _left) * 2 * pi);
      if (mix > 0) value += sin(x * 0.12 + phase + index * 1.7) * 6 * mix;
      return value;
    }

    List<Offset> line(double grams, int index, {bool surface = false}) => [
      for (var x = _left; x <= _right; x += 5)
        Offset(x, boundary(grams, index, x, surface: surface)),
    ];

    final mixed = _averageColor(total);
    final separator = Paint()
      ..color = AppColors.onAccent.withValues(alpha: 0.25 * (1 - mix))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    var start = 0.0;
    for (var i = 0; i < layers.length && start < level; i++) {
      final layer = layers[i];
      final fullEnd = start + layer.grams;
      final end = min(fullEnd, level);
      final isTop = end >= level;

      final upper = line(end, i + 1, surface: isTop);
      final lower = i == 0
          ? [const Offset(_right, 290), const Offset(_left, 290)]
          : line(start, i).reversed.toList();
      final color = Color.lerp(AppColors.slot(layer.slot), mixed, mix)!;
      canvas.drawPath(
        Path()..addPolygon([...upper, ...lower], true),
        Paint()..color = color,
      );
      if (i > 0 && mix < 1) {
        canvas.drawPath(Path()..addPolygon(line(start, i), false), separator);
      }
      start = fullEnd;
    }

    if (mix > 0 && level > 0) _paintBubbles(canvas, y(level), mix, phase);
    canvas.restore();
  }

  /// Color of the whole content, each layer weighted by its grams.
  Color _averageColor(double total) {
    if (total == 0) return AppColors.slot(DaySlot.afternoon);
    var r = 0.0, g = 0.0, b = 0.0;
    for (final layer in layers) {
      final color = AppColors.slot(layer.slot);
      final weight = layer.grams / total;
      r += color.r * weight;
      g += color.g * weight;
      b += color.b * weight;
    }
    return Color.from(alpha: 1, red: r, green: g, blue: b);
  }

  /// Bubbles rising through the liquid while it is shaken.
  void _paintBubbles(Canvas canvas, double surface, double mix, double phase) {
    final height = _bottom - surface;
    if (height < 8) return;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35 * mix);
    for (var i = 0; i < 12; i++) {
      final x = 20 + (i * 37 % 70).toDouble();
      final rise = (phase * 14 + i * 29) % height;
      canvas.drawCircle(Offset(x, _bottom - rise), 1.5 + i % 3, paint);
    }
  }

  void _paintGraduations(
    Canvas canvas,
    double range,
    double Function(double) y,
  ) {
    canvas.drawPath(
      _body,
      Paint()
        ..color = colors.structure
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      const Offset(83, 96),
      const Offset(80, 250),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final tick = Paint()
      ..color = colors.structure.withValues(alpha: 0.75)
      ..strokeWidth = 1.5;
    final step = range <= 200 ? 10.0 : 50.0;
    for (var grams = step; grams <= range; grams += step) {
      final major = grams % 50 == 0 || grams == goal;
      canvas.drawLine(
        Offset(27, y(grams)),
        Offset(major ? 39 : 33, y(grams)),
        tick,
      );
    }

    final goalLine = Paint()
      ..color = colors.structure
      ..strokeWidth = 1.5;
    for (var x = 20.0; x < 90; x += 8) {
      canvas.drawLine(Offset(x, y(goal)), Offset(x + 4, y(goal)), goalLine);
    }
  }

  void _paintLid(Canvas canvas) {
    final lid = Paint()..color = colors.structure;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 54, 84, 24),
        const Radius.circular(5),
      ),
      lid,
    );
    final ridge = Paint()
      ..color = colors.background.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (var x = 19.0; x < 94; x += 6) {
      canvas.drawLine(Offset(x, 58), Offset(x, 74), ridge);
    }
    canvas
      ..drawPath(
        Path()
          ..moveTo(19, 54)
          ..quadraticBezierTo(19, 38, 34, 38)
          ..lineTo(76, 38)
          ..quadraticBezierTo(91, 38, 91, 54)
          ..close(),
        lid,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(25, 26, 24, 14),
          const Radius.circular(4),
        ),
        lid,
      )
      ..drawPath(
        Path()
          ..moveTo(64, 41)
          ..lineTo(64, 24)
          ..quadraticBezierTo(64, 12, 75, 12)
          ..quadraticBezierTo(86, 12, 86, 24)
          ..lineTo(86, 37),
        Paint()
          ..color = colors.structure
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
  }

  @override
  bool shouldRepaint(_ShakerPainter old) =>
      old.level != level ||
      old.goal != goal ||
      old.colors != colors ||
      old.motion != motion ||
      !_sameLayers(old.layers, layers);

  static bool _sameLayers(List<ShakerLayer> a, List<ShakerLayer> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
