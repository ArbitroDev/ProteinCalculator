import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
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
import 'package:protein_calculator/features/history/calendar_view.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/features/stats/stats_widgets.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

const _colors = AppColors.light;

/// Secondary text on the orange background.
const _onOrangeSecondary = Color(0xFF5A2A08);

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
  bool get reached => goal > 0 && total >= goal;

  /// When the entries reached the goal; null when they did not.
  DateTime? get reachedAt {
    if (goal <= 0) return null;
    var sum = 0.0;
    for (final entry in entries) {
      sum += entry.proteinGrams;
      if (sum >= goal) return entry.createdAt;
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
            text: NumberFormat.decimalPattern(locale).format(grams.round()),
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

/// The shaker of a day, filled as it is, with the total and the goal.
class DayShakerTile extends StatelessWidget {
  const DayShakerTile({super.key, required this.day});

  final DayShare day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final total = day.total;
    final goal = day.goal;
    final percent = goal <= 0 ? 0 : (total / goal * 100).round();
    final chips = _dayChips(day, context);

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatLongDate(dateOfDayKey(day.dayKey), locale),
              style: _display(26, weight: FontWeight.w700),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  height: 226,
                  width: 226 * Shaker.aspectRatio,
                  child: Shaker(
                    layers: day.layers,
                    goal: goal,
                    creatineDoses: day.creatineDoses,
                    semanticLabel: l10n.shakerDescription(
                      formatGrams(total, locale),
                      formatGrams(goal, locale),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  // A full day may be taller than the shaker: it then shrinks to
                  // fit, its width kept.
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _Grams(total, size: 88),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.shareOfGoal(
                                formatGrams(goal, locale),
                                percent,
                              ),
                              style: _body(14.5),
                            ),
                            if (day.reached) ...[
                              if (total > goal)
                                Text(
                                  l10n.shareOverGoal(
                                    formatGrams(total - goal, locale),
                                  ),
                                  style: _body(14.5),
                                ),
                              const SizedBox(height: 10),
                              _Chip(
                                label: l10n.shareGoalReached,
                                background: AppColors.accent,
                                foreground: AppColors.onAccent,
                              ),
                              if (day.streak >= 3) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.shareStreak(day.streak),
                                  style: _body(14.5),
                                ),
                              ],
                            ] else if (day.isToday)
                              Text(
                                l10n.todayRemaining(
                                  formatGrams(max(0, goal - total), locale),
                                ),
                                style: _body(14.5),
                              )
                            else
                              Text(
                                l10n.shareShort(
                                  formatGrams(max(0, goal - total), locale),
                                ),
                                style: _body(14.5),
                              ),
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(spacing: 6, runSpacing: 6, children: chips),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Most entries listed on the timeline of a day.
const timelineMaxEntries = 6;

/// The entries of a day hour by hour, then the share of each part of the
/// day.
class DayTimelineTile extends StatelessWidget {
  const DayTimelineTile({
    super.key,
    required this.day,
    required this.showProducts,
  });

  final DayShare day;

  /// Whether the names of the products show.
  final bool showProducts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final protein = [
      for (final entry in day.entries)
        if (entry.proteinGrams > 0) entry,
    ];
    final most = protein.map((e) => e.proteinGrams).maxOrNull ?? 1;
    final reachedAt = day.reachedAt;
    final goal = formatGrams(day.goal, locale);

    final bySlot = {for (final slot in DaySlot.values) slot: 0.0};
    for (final entry in protein) {
      bySlot[entry.slot] = bySlot[entry.slot]! + entry.proteinGrams;
    }
    final total = day.total;
    String slotName(DaySlot slot) => switch (slot) {
      DaySlot.morning => l10n.slotMorning,
      DaySlot.afternoon => l10n.slotAfternoon,
      DaySlot.evening => l10n.slotEvening,
    };

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _Grams(total, size: 60),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatShortDate(dateOfDayKey(day.dayKey), locale),
                style: _body(14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reachedAt != null
                ? l10n.shareReachedAt(goal, formatTime(reachedAt, locale))
                : day.isToday
                ? l10n.shareGoalOnly(goal)
                : l10n.shareGoalMissed(
                    goal,
                    formatGrams(max(0, day.goal - total), locale),
                  ),
            style: _body(13.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: protein.isEmpty
                ? Center(child: Text(l10n.todayEntryCount(0), style: _body(15)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // As many lines as fit, 6 at most, keeping a line for
                      // the entries left out.
                      const line = _timelineLine + 7;
                      var count = min(
                        timelineMaxEntries,
                        (constraints.maxHeight / line).floor(),
                      );
                      if (count < protein.length) {
                        count = min(
                          count,
                          ((constraints.maxHeight - 18) / line).floor(),
                        );
                      }
                      final shown = protein.take(max(0, count)).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in shown)
                            _TimelineLine(
                              entry: entry,
                              most: most,
                              showProducts: showProducts,
                            ),
                          if (protein.length > shown.length)
                            Text(
                              l10n.shareMoreEntries(
                                protein.length - shown.length,
                              ),
                              style: _body(12.5),
                              maxLines: 1,
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final slot in DaySlot.values)
                      if (bySlot[slot]! > 0)
                        Expanded(
                          flex: (bySlot[slot]! / total * 1000).round().clamp(
                            1,
                            1000,
                          ),
                          child: ColoredBox(color: AppColors.slot(slot)),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 12,
              children: [
                for (final slot in DaySlot.values)
                  if (bySlot[slot]! > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.slot(slot),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${slotName(slot)} '
                          '${NumberFormat.percentPattern(locale).format(bySlot[slot]! / total)}',
                          style: _body(11.5),
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Height of a line of the timeline, without the space under it.
const _timelineLine = 20.0;

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({
    required this.entry,
    required this.most,
    required this.showProducts,
  });

  final Entry entry;

  /// Grams of the largest entry, filling the width.
  final double most;
  final bool showProducts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final named = showProducts && entry.name != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: SizedBox(
        height: _timelineLine,
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatTime(entry.createdAt, locale),
                  style: _body(12.5),
                  maxLines: 1,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // With its name, the bar keeps to the first half.
                  final room = constraints.maxWidth * (named ? 0.45 : 1);
                  return Row(
                    children: [
                      Container(
                        width: max(6, room * entry.proteinGrams / most),
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.slot(entry.slot),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (named) ...[
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            entry.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _body(12.5, color: _colors.text),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.grams(formatGrams(entry.proteinGrams, locale)),
              style: _display(16, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
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

/// A week or a month of statistics: the daily average, a bar per day and
/// the days at the goal.
class PeriodTile extends StatelessWidget {
  const PeriodTile({super.key, required this.stats, required this.today});

  final PeriodStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final protein = stats.protein;
    final delta = protein.deltaGrams;
    String? compared;
    if (delta != null) {
      final sign = delta > 0
          ? '+'
          : delta < 0
          ? '−'
          : '±';
      final text =
          '$sign${l10n.grams(NumberFormat.decimalPattern(locale).format(delta.abs()))}';
      compared = stats.period.span == StatsSpan.week
          ? l10n.statsComparedToPreviousWeek(text)
          : l10n.statsComparedTo(
              text,
              DateFormat.MMMM(locale).format(stats.period.previous.start),
            );
    }
    final week = stats.period.span == StatsSpan.week;

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sharePeriodName(stats.period, l10n, locale, today),
            style: _body(14.5),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // A large average shrinks rather than crowd out its label.
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: _Grams(protein.averageGrams, size: 70),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.statsDailyAverage,
                    style: _body(13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          // Long in French: on a line of its own, the whole width.
          if (compared != null) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(compared, style: _body(13), maxLines: 1),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: _TileBars(
              values: [for (final bar in protein.bars) bar.grams],
              goals: [for (final bar in protein.bars) bar.goal],
              goal: protein.averageGoal?.roundToDouble(),
              gap: week ? 8 : 2.5,
              labels: week
                  ? [
                      for (final bar in protein.bars)
                        DateFormat.E(locale).format(bar.date),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                value: '${protein.goalDays} / ${stats.countedDays}',
                label: l10n.shareGoalDays,
              ),
              const SizedBox(width: 28),
              _Stat(
                value: l10n.statsDayCount(protein.bestStreak),
                label: l10n.statsBestStreak,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A year: the days at the goal, the average of each month and the
/// workouts.
class YearTile extends StatelessWidget {
  const YearTile({super.key, required this.stats});

  final PeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final protein = stats.protein;
    final workouts = stats.workouts;

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shareYear(stats.period.start.year), style: _body(14.5)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.decimalPattern(locale).format(protein.goalDays),
                style: _display(70),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.shareYearGoalDays(protein.goalDays, stats.countedDays),
                    style: _body(13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _TileBars(
              values: [for (final bar in protein.bars) bar.grams],
              goals: [for (final bar in protein.bars) bar.goal],
              goal: protein.averageGoal?.roundToDouble(),
              gap: 5,
              labels: [
                for (final bar in protein.bars)
                  DateFormat('MMMMM', locale).format(bar.date),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                value: l10n.grams(formatGrams(protein.averageGrams, locale)),
                label: l10n.statsDailyAverage,
              ),
              const SizedBox(width: 28),
              if (workouts != null && workouts.sessions > 0)
                _Stat(
                  value: '${workouts.sessions}',
                  label: l10n.shareHevyWorkouts(workouts.sessions),
                )
              else
                _Stat(
                  value: l10n.statsDayCount(protein.bestStreak),
                  label: l10n.statsBestStreak,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Most shakers drawn on the streak tile.
const streakMaxShakers = 30;

/// The current streak: one number, one shaker per day.
class StreakTile extends StatelessWidget {
  const StreakTile({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    const ink = AppColors.onAccent;
    final drawn = min(streak, streakMaxShakers);

    return ShareTileFrame(
      orange: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shareCurrentStreak,
            style: _body(14.5, color: _onOrangeSecondary),
          ),
          // The number takes the room the shakers leave.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                NumberFormat.decimalPattern(locale).format(streak),
                style: _display(170, color: ink),
              ),
            ),
          ),
          Text(
            l10n.shareStreakDays(streak),
            style: _display(26, color: ink, weight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          IconTheme(
            data: const IconThemeData(color: ink, size: 24),
            child: Wrap(
              spacing: 3,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < drawn; i++) const ShakerIcon(),
                if (streak > drawn)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+${streak - drawn}',
                      style: _body(13, color: ink, weight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A month of the calendar as its tile shows it.
@immutable
class MonthShare {
  const MonthShare({
    required this.month,
    required this.grams,
    required this.goalOf,
    required this.todayKey,
    required this.firstAppDayKey,
    required this.firstWeekday,
    this.creatineDays = const {},
    this.hevyDays = const {},
    this.mode = CalendarMode.protein,
  });

  /// First day of the month.
  final DateTime month;

  /// Protein grams of the days with entries, by key.
  final Map<int, double> grams;
  final double? Function(int dayKey) goalOf;
  final int todayKey;
  final int firstAppDayKey;

  /// First day of the week, 0 for Sunday.
  final int firstWeekday;

  /// Days creatine was taken.
  final Set<int> creatineDays;

  /// Days with a Hevy workout.
  final Set<int> hevyDays;

  /// What colors the days, as in the calendar.
  final CalendarMode mode;
}

/// A month of the calendar, each day colored as the calendar colors it: by
/// its progress, by the creatine taken or by the Hevy workouts.
class CalendarMonthTile extends StatelessWidget {
  const CalendarMonthTile({super.key, required this.data});

  final MonthShare data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final material = MaterialLocalizations.of(context);
    final month = data.month;
    final mode = data.mode;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (month.weekday % 7 - data.firstWeekday + 7) % 7;
    var marked = 0;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    ];
    for (var day = 1; day <= days; day++) {
      final dayKey = dayKeyOfDate(DateTime(month.year, month.month, day));
      final goal = data.goalOf(dayKey);
      // As in the calendar: the days from the first one of the app to
      // today, those without entries as days of 0 g.
      final tracked =
          goal != null &&
          dayKey >= data.firstAppDayKey &&
          dayKey <= data.todayKey;
      final progress = tracked
          ? DayProgress.of(data.grams[dayKey] ?? 0, goal)
          : null;
      final creatine = data.creatineDays.contains(dayKey);
      final hevy = data.hevyDays.contains(dayKey);
      final highlighted = switch (mode) {
        CalendarMode.protein => progress == DayProgress.reached,
        CalendarMode.creatine => progress != null && creatine,
        CalendarMode.hevy => progress != null && hevy,
      };
      if (highlighted) marked++;
      // As in the calendar: days to come lighter.
      final style = progress == null
          ? (
              fill: Colors.transparent,
              text: _colors.textSecondary.withValues(
                alpha: dayKey > data.todayKey ? 0.5 : 1,
              ),
            )
          : switch (mode) {
              CalendarMode.protein => calendarProgressColors(progress, _colors),
              CalendarMode.creatine => calendarCreatineColors(
                creatine,
                _colors,
              ),
              CalendarMode.hevy => calendarHevyColors(hevy, _colors),
            };
      final isToday = dayKey == data.todayKey;
      cells.add(
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: style.fill,
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: _colors.structure, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: _body(
                    12.5,
                    color: style.text,
                    weight: highlighted || isToday
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ).copyWith(height: 1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final none = calendarProgressColors(DayProgress.none, _colors);
    final legend = switch (mode) {
      CalendarMode.protein => [
        for (final progress in DayProgress.values)
          _LegendItem(
            label: calendarProgressLabel(l10n, progress),
            fill: calendarProgressColors(progress, _colors).fill,
            bordered: progress == DayProgress.none,
          ),
      ],
      CalendarMode.creatine => [
        _LegendItem(label: l10n.calendarNone, fill: none.fill, bordered: true),
        _LegendItem(
          label: l10n.calendarCreatine,
          fill: calendarCreatineColors(true, _colors).fill,
        ),
      ],
      CalendarMode.hevy => [
        _LegendItem(
          label: l10n.calendarNoHevy,
          fill: none.fill,
          bordered: true,
        ),
        _LegendItem(
          label: l10n.calendarHevy,
          fill: calendarHevyColors(true, _colors).fill,
        ),
      ],
    };

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    toBeginningOfSentenceCase(
                      DateFormat.MMMM(locale).format(month),
                    ),
                    style: _display(38),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(switch (mode) {
                CalendarMode.protein => l10n.shareMonthReached(marked),
                CalendarMode.creatine => l10n.shareMonthCreatine(marked),
                CalendarMode.hevy => l10n.shareMonthHevy(marked),
              }, style: _body(13.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    material.narrowWeekdays[(data.firstWeekday + i) % 7],
                    textAlign: TextAlign.center,
                    style: _body(11, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rows = ((lead + days) / 7).ceil();
                const gap = 4.0;
                final width = (constraints.maxWidth - gap * 6) / 7;
                final height =
                    (constraints.maxHeight - gap * (rows - 1)) / rows;
                return GridView.count(
                  crossAxisCount: 7,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: width / height,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: cells,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Two by two, as in the calendar.
          for (final (index, row) in legend.slices(2).indexed) ...[
            if (index > 0) const SizedBox(height: 4),
            Row(
              children: [
                for (final item in row) Expanded(child: item),
                if (row.length == 1) const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A color of the calendar tile and what it tells.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.fill,
    this.bordered = false,
  });

  final String label;
  final Color fill;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: bordered ? Border.all(color: _colors.divider) : null,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(11.5),
        ),
      ),
    ],
  );
}

/// A day of the week tile: its protein by part of the day, its goal, and
/// whether creatine was taken and a Hevy workout done.
typedef WeekDayShare = ({
  int dayKey,
  Map<DaySlot, double> bySlot,
  double goal,
  bool creatine,
  bool hevy,
});

/// The last 7 days, each as a shaker filled to its level.
class WeekTile extends StatelessWidget {
  const WeekTile({super.key, required this.days, required this.today});

  /// Oldest first.
  final List<WeekDayShare> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    double total(WeekDayShare day) => day.bySlot.values.sum;
    final reached = days
        .where((day) => day.goal > 0 && total(day) >= day.goal)
        .length;
    final first = dateOfDayKey(days.first.dayKey);
    final last = dateOfDayKey(days.last.dayKey);
    final marked = days.any((day) => day.creatine || day.hevy);

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shareMyWeek, style: _display(38)),
          const SizedBox(height: 6),
          Text(
            l10n.shareWeekRange(
              formatDayMonth(first, locale, now: today),
              formatDayMonth(last, locale, now: today),
              reached,
              days.length,
            ),
            style: _body(13.5),
          ),
          // The shakers shrink to the room the title leaves them.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final day in days)
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 118,
                                  width: 118 * Shaker.aspectRatio,
                                  child: Shaker(
                                    layers: [
                                      for (final slot in DaySlot.values)
                                        if ((day.bySlot[slot] ?? 0) > 0)
                                          ShakerLayer(
                                            grams: day.bySlot[slot]!,
                                            slot: slot,
                                          ),
                                    ],
                                    goal: day.goal,
                                    showGoalLine: false,
                                    semanticLabel: l10n.shakerDescription(
                                      formatGrams(total(day), locale),
                                      formatGrams(day.goal, locale),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  NumberFormat.decimalPattern(locale)
                                      .format(total(day).round()),
                                  style: _display(18, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat.E(locale)
                                      .format(dateOfDayKey(day.dayKey)),
                                  style: _body(11, weight: FontWeight.w600),
                                ),
                                // The marks of the calendar, the same height for all.
                                if (marked) ...[
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    height: 12,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      spacing: 2,
                                      children: [
                                        if (day.creatine)
                                          const CreatineCheck(size: 12),
                                        if (day.hevy) const HevyMark(size: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
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

/// The creatine of a period: how regularly it was taken, as a ring, with
/// its streak and doses, and its days in a thin strip.
class CreatineTile extends StatelessWidget {
  const CreatineTile({super.key, required this.stats, required this.today});

  final PeriodStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final creatine = stats.creatine!;
    final streak = creatine.currentStreak;
    final share = creatine.countedDays == 0
        ? 0.0
        : creatine.takenDays / creatine.countedDays;
    final complete = stats.cross.completeDays;

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodKicker(
            title: l10n.creatine,
            period: stats.period,
            today: today,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _Ring(
                      share: share,
                      color: AppColors.creatine,
                      track: _colors.surface,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(26),
                          child: Text(
                            NumberFormat.percentPattern(locale).format(share),
                            style: _display(44),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  // Long words shrink the column rather than overflow it,
                  // its width kept.
                  child: LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${creatine.takenDays} / ${creatine.countedDays}',
                                style: _display(34, weight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.shareCreatineDaysLabel(creatine.takenDays),
                              style: _body(12.5),
                            ),
                            const SizedBox(height: 12),
                            _Stat(
                              value: '${creatine.doses}',
                              label: l10n.statsDosesLabel(creatine.doses),
                              flexible: false,
                            ),
                            if (streak != null && streak > 0) ...[
                              const SizedBox(height: 10),
                              _Stat(
                                value: l10n.statsDayCount(streak),
                                label: l10n.statsCurrentStreak,
                                flexible: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (complete != null) ...[
            const SizedBox(height: 14),
            _TileRow(label: l10n.statsCompleteDays, value: '${complete.days}'),
          ],
          const SizedBox(height: 12),
          _MarksStrip(
            marks: creatine.marks,
            monthShares: creatine.monthShares,
            color: AppColors.creatine,
          ),
        ],
      ),
    );
  }
}

/// The Hevy workouts of a period: their number and length, then the
/// protein of the workout days against the rest days, and after a workout.
class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.stats, required this.today});

  final PeriodStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final workouts = stats.workouts!;
    final week = stats.period.span == StatsSpan.week;
    final average = workouts.averageDuration;
    final cross = stats.cross;
    final byWorkout = cross.proteinByWorkout;
    final after = cross.postWorkout;
    String grams(double value) => l10n.grams(formatGrams(value, locale));
    final top = max(byWorkout?.first ?? 0, byWorkout?.second ?? 0);

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodKicker(
            title: l10n.statsWorkouts,
            period: stats.period,
            today: today,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.decimalPattern(locale).format(workouts.sessions),
                style: _display(70),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    [
                      l10n.shareHevyWorkouts(workouts.sessions),
                      if (week)
                        l10n.statsWorkoutDays(workouts.days)
                      else
                        '${NumberFormat('#,##0.0', locale).format(workouts.perWeek)} ${l10n.statsPerWeek}',
                      if (average != null)
                        '${formatDuration(average, l10n)} · ${l10n.statsAverageLength}',
                    ].join('\n'),
                    style: _body(12.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (cross.workoutTime case final workoutTime?) ...[
            _TileRow(
              label: l10n.statsWorkoutStart,
              value: formatTime(
                DateTime(
                  2000,
                  1,
                  1,
                  workoutTime.startMinutes ~/ 60,
                  workoutTime.startMinutes % 60,
                ),
                locale,
              ),
            ),
            const Spacer(),
          ],
          if (byWorkout != null) ...[
            Text(
              l10n.formProtein,
              style: _body(12.5, color: _colors.text, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _TileCompareBar(
              label: l10n.statsOnWorkoutDays,
              value: grams(byWorkout.first),
              fraction: top <= 0 ? 0 : byWorkout.first / top,
              color: AppColors.accent,
            ),
            const SizedBox(height: 8),
            _TileCompareBar(
              label: l10n.statsOnRestDays,
              value: grams(byWorkout.second),
              fraction: top <= 0 ? 0 : byWorkout.second / top,
              color: AppColors.progressHalf,
            ),
          ],
          if (after != null) ...[
            const SizedBox(height: 12),
            _TileRow(
              label: l10n.statsAfterWorkout(postWorkoutWindow.inHours),
              value: grams(after.grams),
            ),
          ],
          const Spacer(),
          _MarksStrip(
            marks: workouts.marks,
            monthShares: workouts.monthShares,
            color: _colors.hevy,
          ),
        ],
      ),
    );
  }
}

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
