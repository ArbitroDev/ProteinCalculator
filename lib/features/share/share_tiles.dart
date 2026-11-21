import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/hevy/hevy_csv.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/creatine_mark.dart';
import 'package:protein_calculator/core/widgets/hevy_mark.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/shaker_icon.dart';
import 'package:protein_calculator/core/widgets/slot_name.dart';
import 'package:protein_calculator/features/history/calendar_view.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/features/stats/stats_widgets.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

part 'tiles/day_tiles.dart';
part 'tiles/period_tiles.dart';
part 'tiles/history_tiles.dart';

const _colors = AppColors.light;

TextStyle _display(double size, {Color? color, FontWeight? weight}) =>
    TextStyle(
      fontFamily: 'Saira Semi Condensed',
      fontSize: size,
      fontWeight: weight ?? FontWeight.w800,
      height: 1,
      color: color ?? _colors.text,
    );

TextStyle _body(double size, {Color? color, FontWeight? weight}) => TextStyle(
  fontFamily: 'Outfit',
  fontSize: size,
  fontWeight: weight ?? FontWeight.w500,
  height: 1.25,
  color: color ?? _colors.textSecondary,
);

/// A day as its tiles show it.
@immutable
class DayShare {
  const DayShare({
    required this.dayKey,
    required this.entries,
    required this.goal,
    this.sessions = const [],
    this.streak = 0,
    this.isToday = false,
  });

  final int dayKey;

  /// Entries of the day, by their time.
  final List<Entry> entries;
  final double goal;
  final List<HevySession> sessions;

  /// Days in a row reaching their goal, up to this day.
  final int streak;

  /// Whether the day is not over.
  final bool isToday;

  double get total => entries.proteinGrams;
  int get creatineDoses => entries.creatineDoses;
  bool get reached => goal > 0 && isGoalReached(total, goal);

  /// When the entries reached the goal; null when they did not.
  DateTime? get reachedAt {
    if (goal <= 0) return null;
    var sum = 0.0;
    for (final entry in entries) {
      sum += entry.proteinGrams;
      if (isGoalReached(sum, goal)) return entry.createdAt;
    }
    return null;
  }

  List<ShakerLayer> get layers => [
    for (final entry in entries)
      if (entry.proteinGrams > 0)
        ShakerLayer(grams: entry.proteinGrams, slot: entry.slot),
  ];
}

/// "96 g", the number large and the unit smaller.
class _Grams extends StatelessWidget {
  const _Grams(this.grams, {required this.size});

  final double grams;
  final double size;

  @override
  Widget build(BuildContext context) {
    final locale = context.localeName;
    final l10n = AppLocalizations.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: NumberFormat.decimalPattern(locale).format(roundGrams(grams)),
            style: _display(size),
          ),
          TextSpan(
            text: ' ${l10n.gramsUnit}',
            style: _display(
              size * 0.38,
              color: _colors.textSecondary,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
    this.leading,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(12.5, color: foreground, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Creatine and workouts of a day, as chips; nothing without them.
List<Widget> _dayChips(DayShare day, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final session = day.sessions.firstOrNull;
  final length = session == null
      ? null
      : workoutDuration(session.startedAt, session.endedAt);
  return [
    if (day.creatineDoses > 0)
      _Chip(
        label: l10n.creatine,
        background: AppColors.creatine,
        foreground: const Color(0xFF06263F),
        leading: CreatineMark(
          doses: day.creatineDoses,
          size: 12,
          color: const Color(0xFF06263F),
        ),
      ),
    if (session != null)
      _Chip(
        label: [
          session.title,
          if (length != null) formatDuration(length, l10n),
          if (day.sessions.length > 1) '+${day.sessions.length - 1}',
        ].join(' · '),
        background: _colors.hevy,
        foreground: _colors.onHevy,
        // The dumbbell of the Hevy days, in the color of the text of the
        // chip: in its own color, it would not show on it.
        leading: Icon(hevyIcon, size: 13, color: _colors.onHevy),
      ),
  ];
}

/// Width on the right of the bars holding the value of the goal.
const _goalGutter = 40.0;

/// Bars of grams with the goal as a dashed line; null values leave a gap.
class _TileBars extends StatelessWidget {
  const _TileBars({
    required this.values,
    required this.goals,
    required this.goal,
    this.labels,
    this.gap = 2.5,
  });

  final List<double?> values;

  /// Goal of each value, coloring its bar.
  final List<double?> goals;

  /// Goal drawn across.
  final double? goal;
  final List<String>? labels;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final goal = this.goal ?? 0;
    final shown = goal > 0;
    final top = max(values.nonNulls.maxOrNull ?? 0, goal) * 1.12;
    final labels = this.labels;
    // The goal is written on the right of the bars, in a gutter of its own,
    // where it hides none of them.
    final gutter = shown ? _goalGutter : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final line = shown && top > 0 ? height * goal / top : null;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // The bars stand on the bottom of the chart.
                  Positioned.fill(
                    right: gutter,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final (index, value) in values.indexed)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: gap / 2,
                              ),
                              child: value == null
                                  ? const SizedBox.shrink()
                                  : Container(
                                      height: top <= 0
                                          ? 2
                                          : max(2, height * value / top),
                                      decoration: BoxDecoration(
                                        color: progressColor(
                                          value,
                                          goals[index],
                                          _colors,
                                        ),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (line != null) ...[
                    Positioned(
                      left: 0,
                      right: gutter - 4,
                      bottom: line - 0.75,
                      child: CustomPaint(
                        size: const Size.fromHeight(1.5),
                        painter: _Dashes(_colors.textSecondary),
                      ),
                    ),
                    // Centered on the line.
                    Positioned(
                      right: 0,
                      width: gutter - 6,
                      bottom: line - 7,
                      height: 14,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          l10n.grams(formatGrams(goal, locale)),
                          style: _body(
                            10.5,
                            color: _colors.text,
                            weight: FontWeight.w700,
                          ).copyWith(height: 1),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: gutter),
          child: Container(height: 1, color: _colors.divider),
        ),
        if (labels != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(right: gutter),
            child: Row(
              children: [
                for (final label in labels)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: _body(10.5, weight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Dashes extends CustomPainter {
  const _Dashes(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + 4, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes oldDelegate) => oldDelegate.color != color;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.flexible = true});

  final String value;
  final String label;

  /// Whether it shares the width of a row with others.
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final stat = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: _display(26, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: _body(12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return flexible ? Flexible(child: stat) : stat;
  }
}

/// Name of a week or a month of statistics.
String sharePeriodName(
  StatsPeriod period,
  AppLocalizations l10n,
  String locale,
  DateTime today,
) => switch (period.span) {
  StatsSpan.week => l10n.statsWeekOf(
    formatDayMonth(period.start, locale, now: today),
  ),
  StatsSpan.month => formatMonth(period.start, locale),
  StatsSpan.year => '${period.start.year}',
};

/// What a tile tells, and over which period: "Creatine · November 2026".
class _PeriodKicker extends StatelessWidget {
  const _PeriodKicker({
    required this.title,
    required this.period,
    required this.today,
  });

  final String title;
  final StatsPeriod period;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = period.span == StatsSpan.year
        ? '${period.start.year}'
        : sharePeriodName(period, l10n, context.localeName, today);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: _display(26, weight: FontWeight.w700),
          ),
          TextSpan(text: '  $name', style: _body(14.5)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A label and its value on one line.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(
        child: Text(
          label,
          style: _body(12.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 10),
      Text(value, style: _display(20, weight: FontWeight.w700)),
    ],
  );
}

/// A label over a bar filled by [fraction], its value on the right.
class _TileCompareBar extends StatelessWidget {
  const _TileCompareBar({
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
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 118,
        child: Text(
          label,
          style: _body(12.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 12,
            child: ColoredBox(
              color: _colors.surface,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0, 1),
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(value, style: _display(18, weight: FontWeight.w700)),
    ],
  );
}

/// The days of a week or a month as a thin row of dots, filled in [color]
/// when marked; for a year, the share of each month in small bars.
class _MarksStrip extends StatelessWidget {
  const _MarksStrip({
    required this.marks,
    required this.monthShares,
    required this.color,
  });

  final List<bool?> marks;
  final List<double?> monthShares;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (marks.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = min(14.0, constraints.maxWidth / marks.length - 2.5);
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
                          false => _colors.surface,
                          null => null,
                        },
                        border: mark == true
                            ? null
                            : Border.all(color: _colors.divider),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final share in monthShares)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: share == null ? null : _colors.surface,
                    border: share == null
                        ? Border.all(color: _colors.divider)
                        : null,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: share == null || share == 0
                      ? null
                      : Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A ring filled by [share], from the top, clockwise.
class _Ring extends CustomPainter {
  const _Ring({required this.share, required this.color, required this.track});

  final double share;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, paint..color = track);
    if (share > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * share.clamp(0, 1),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_Ring oldDelegate) =>
      oldDelegate.share != share ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
