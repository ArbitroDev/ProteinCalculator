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

/// Protein shaker filled with one layer per entry, graduated up to [goal].
///
/// The fill level animates when entries are added or removed, unless the
/// device asks to reduce animations.
class Shaker extends StatelessWidget {
  const Shaker({
    super.key,
    required this.layers,
    required this.goal,
    required this.semanticLabel,
    required this.formatGrams,
  });

  final List<ShakerLayer> layers;
  final double goal;
  final String semanticLabel;
  final String Function(double grams) formatGrams;

  /// Width / height ratio of the drawing.
  static const aspectRatio = 110 / 290;

  /// Empty space under the bottom of the drawing, as a fraction of its
  /// height, to align other widgets with the visible bottom of the shaker.
  static const bottomInset = (290 - 283.5) / 290;

  @override
  Widget build(BuildContext context) {
    final total = layers.fold(0.0, (sum, layer) => sum + layer.grams);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labelStyle = Theme.of(context).textTheme.labelLarge!
        .copyWith(fontSize: 12, color: AppColors.onAccent);

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
          builder: (context, level, _) => CustomPaint(
            painter: _ShakerPainter(
              layers: layers,
              goal: goal,
              level: level,
              colors: AppColors.of(context),
              labelStyle: labelStyle,
              formatGrams: formatGrams,
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
    required this.labelStyle,
    required this.formatGrams,
  });

  final List<ShakerLayer> layers;
  final double goal;
  final double level;
  final AppColors colors;
  final TextStyle labelStyle;
  final String Function(double grams) formatGrams;

  // Drawing coordinates, in a 110 x 290 box.
  static const _width = 110.0;
  static const _bottom = 280.0;
  static const _fillHeight = 184.0;
  static const _minLabelHeight = 22.0;

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

    _paintContent(canvas, y);
    _paintGraduations(canvas, range, y);
    _paintLid(canvas);
  }

  void _paintContent(Canvas canvas, double Function(double) y) {
    canvas
      ..save()
      ..clipPath(_body)
      ..drawRect(
        const Rect.fromLTWH(0, 0, _width, 290),
        Paint()..color = colors.shakerInside,
      );

    final separator = Paint()
      ..color = AppColors.onAccent.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    var start = 0.0;
    for (var i = 0; i < layers.length && start < level; i++) {
      final layer = layers[i];
      final fullEnd = start + layer.grams;
      final end = min(fullEnd, level);
      final top = y(end);
      final base = y(start);
      final paint = Paint()..color = AppColors.slot(layer.slot);

      if (end >= level) {
        // The surface ripples on the visible top layer.
        canvas.drawPath(
          Path()
            ..moveTo(10, top)
            ..quadraticBezierTo(32, top - 6, 55, top)
            ..quadraticBezierTo(78, top + 6, 100, top)
            ..lineTo(100, base + 1)
            ..lineTo(10, base + 1)
            ..close(),
          paint,
        );
      } else {
        canvas.drawRect(Rect.fromLTRB(10, top, 100, base + 1), paint);
      }
      if (i > 0) {
        canvas.drawLine(Offset(10, base), Offset(100, base), separator);
      }

      if (end == fullEnd && base - top >= _minLabelHeight) {
        final label = TextPainter(
          text: TextSpan(text: formatGrams(layer.grams), style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(
          canvas,
          Offset(55 - label.width / 2, (top + base) / 2 - label.height / 2),
        );
      }
      start = fullEnd;
    }
    canvas.restore();
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
          ..moveTo(64, 40)
          ..lineTo(64, 24)
          ..quadraticBezierTo(64, 12, 75, 12)
          ..quadraticBezierTo(86, 12, 86, 24)
          ..lineTo(86, 40),
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
      old.labelStyle != labelStyle ||
      !_sameLayers(old.layers, layers);

  static bool _sameLayers(List<ShakerLayer> a, List<ShakerLayer> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
