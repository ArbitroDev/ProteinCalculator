import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';

/// Color of a bar of [grams] towards [goal], as the calendar colors the
/// days, on a card.
Color progressColor(double grams, double? goal, AppColors colors) =>
    switch (DayProgress.of(grams, goal ?? 0)) {
      DayProgress.none => colors.divider,
      DayProgress.low => Color.alphaBlend(
        AppColors.accent.withValues(alpha: 0.3),
        colors.surface,
      ),
      DayProgress.half => AppColors.progressHalf,
      DayProgress.reached => AppColors.accent,
    };

/// A card of the statistics tab, with its [title].
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.title,
    required this.children,
    this.titleColor,
    this.caption,
  });

  final String title;
  final Color? titleColor;

  /// Shown after the title, smaller.
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title),
                  if (caption case final caption?)
                    TextSpan(text: '  $caption', style: textTheme.bodySmall),
                ],
              ),
              style: textTheme.headlineSmall!.copyWith(
                fontSize: 20,
                color: titleColor ?? colors.text,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Title of a section of a card.
class StatsSectionTitle extends StatelessWidget {
  const StatsSectionTitle(this.text, {super.key, this.first = false});

  final String text;

  /// Whether it opens the card, without space above.
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? 0 : 16, bottom: 6),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall!
            .copyWith(color: AppColors.of(context).textSecondary),
      ),
    ),
  );
}

/// A value and what it is, on a raised surface.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleMedium!.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Tiles side by side, of the same height.
class StatTiles extends StatelessWidget {
  const StatTiles(this.tiles, {super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, tile) in tiles.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: tile),
        ],
      ],
    ),
  );
}

/// Protein of each day of a week or a month, or of each month of a year, in
/// bars colored by their goal, under a dashed line at [goal].
///
/// Tapping a bar tells its value; tapping it again opens its day, when
/// [canOpen].
class StatsBarChart extends StatefulWidget {
  const StatsBarChart({
    super.key,
    required this.bars,
    required this.span,
    required this.goal,
    required this.goalLabel,
    required this.describe,
    required this.canOpen,
    required this.onOpen,
  });

  final List<StatsBar> bars;
  final StatsSpan span;
  final double? goal;

  /// [goal] as written over its line: "140 g".
  final String goalLabel;

  /// Day or month of a bar and its value, as read: "Mar. 14 oct. · 132 g".
  final String Function(StatsBar bar) describe;
  final bool Function(StatsBar bar) canOpen;
  final ValueChanged<StatsBar> onOpen;

  @override
  State<StatsBarChart> createState() => _StatsBarChartState();
}

class _StatsBarChartState extends State<StatsBarChart> {
  static const _height = 110.0;
  int? _selected;

  @override
  void didUpdateWidget(StatsBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bars.firstOrNull?.date != widget.bars.firstOrNull?.date ||
        oldWidget.span != widget.span) {
      _selected = null;
    }
  }

  void _tap(int index) {
    final bar = widget.bars[index];
    if (_selected == index && widget.canOpen(bar)) {
      widget.onOpen(bar);
    } else {
      setState(() => _selected = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bars = widget.bars;
    final goal = widget.goal;
    final top = max(
      goal ?? 0,
      bars.map((bar) => bar.grams ?? 0).fold(0.0, max),
    );
    // Room above the bars, and above the goal for its label.
    final scale = top <= 0 ? 1.0 : max(top * 1.12, (goal ?? 0) * 1.25);
    final gap = switch (widget.span) {
      StatsSpan.week => 10.0,
      StatsSpan.month => 3.0,
      StatsSpan.year => 6.0,
    };
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: selected == null
              ? null
              : Text(
                  widget.describe(bars[selected]),
                  style: textTheme.bodySmall!.copyWith(color: colors.text),
                ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, bar) in bars.indexed)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: gap / 2),
                          child: _bar(
                            index,
                            bar,
                            scale,
                            colors,
                            dimmed: selected != null && selected != index,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (goal != null && goal > 0) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _height * goal / scale,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size.fromHeight(1.5),
                      painter: _DashedLine(colors.textSecondary),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: _height * goal / scale + 3,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Text(
                        widget.goalLabel,
                        style: textTheme.labelSmall,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(height: 1, color: colors.divider),
        const SizedBox(height: 4),
        SizedBox(height: 14, child: _axis(context)),
      ],
    );
  }

  Widget _bar(
    int index,
    StatsBar bar,
    double scale,
    AppColors colors, {
    required bool dimmed,
  }) {
    final grams = bar.grams;
    // Not counted: to come, or before the app was used.
    if (grams == null) return const SizedBox.shrink();
    final color = progressColor(grams, bar.goal ?? widget.goal, colors);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(index),
      child: Semantics(
        button: true,
        label: widget.describe(bar),
        excludeSemantics: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: dimmed ? 0.45 : 1,
            child: SizedBox(
              width: double.infinity,
              height: max(2, _height * grams / scale),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _axis(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    final bars = widget.bars;
    final material = MaterialLocalizations.of(context);
    switch (widget.span) {
      case StatsSpan.week:
        return Row(
          children: [
            for (final bar in bars)
              Expanded(
                child: Text(
                  material.narrowWeekdays[bar.date.weekday % 7],
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
          ],
        );
      case StatsSpan.year:
        final format = DateFormat('MMMMM', context.localeName);
        return Row(
          children: [
            for (final bar in bars)
              Expanded(
                child: Text(
                  format.format(bar.date),
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
          ],
        );
      case StatsSpan.month:
        final shown = {0, 7, 14, 21, bars.length - 1};
        return LayoutBuilder(
          builder: (context, constraints) {
            final step = constraints.maxWidth / bars.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final index in shown)
                  Positioned(
                    left: step * (index + 0.5) - 15,
                    width: 30,
                    top: 0,
                    child: Text(
                      '${bars[index].date.day}',
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
              ],
            );
          },
        );
    }
  }
}

class _DashedLine extends CustomPainter {
  const _DashedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(min(x + 4, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLine oldDelegate) => oldDelegate.color != color;
}

/// The days of a week or a month in a row of dots, filled in [color] for
/// those marked, outlined for those not counted; or for a year, the share
/// of each month in small bars. Read as [summary].
class DayMarksStrip extends StatelessWidget {
  const DayMarksStrip({
    super.key,
    required this.marks,
    required this.monthShares,
    required this.color,
    required this.summary,
  });

  final List<bool?> marks;
  final List<double?> monthShares;
  final Color color;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: marks.isNotEmpty ? _dots(colors) : _months(context, colors),
      ),
    );
  }

  Widget _dots(AppColors colors) => LayoutBuilder(
    builder: (context, constraints) {
      final size = min(14.0, constraints.maxWidth / marks.length - 3);
      return Row(
        children: [
          for (final mark in marks)
            Expanded(
              child: Center(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (mark) {
                      true => color,
                      false => colors.divider,
                      null => null,
                    },
                    border: mark == null
                        ? Border.all(color: colors.divider)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _months(BuildContext context, AppColors colors) {
    final format = DateFormat('MMMMM', context.localeName);
    final style = Theme.of(context).textTheme.labelSmall!;
    return Row(
      children: [
        for (final (index, share) in monthShares.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: 28,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: share == null ? null : colors.divider,
                      border: share == null
                          ? Border.all(color: colors.divider)
                          : null,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: share == null || share == 0
                        ? null
                        : FractionallySizedBox(
                            heightFactor: share,
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(format.format(DateTime(2026, index + 1)), style: style),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A label and its value, over a horizontal bar filled by [fraction].
class CompareBar extends StatelessWidget {
  const CompareBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: textTheme.bodyMedium)),
                Text(
                  value,
                  style: textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 9,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(5),
              ),
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0, 1),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label and its value on a line, with a [detail] under them.
class StatsValueRow extends StatelessWidget {
  const StatsValueRow({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(label, style: textTheme.bodyMedium)),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            if (detail case final detail?) ...[
              const SizedBox(height: 2),
              Text(detail, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
