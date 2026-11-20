import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
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
        leading: const IconTheme(
          data: IconThemeData(color: Colors.white),
          child: HevyMark(size: 13),
        ),
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
          Text(
            formatLongDate(dateOfDayKey(day.dayKey), locale),
            style: _body(14.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
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
                  child: Column(
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
                        l10n.shareOfGoal(formatGrams(goal, locale), percent),
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
              child: Text(
                formatTime(entry.createdAt, locale),
                style: _body(12.5),
                maxLines: 1,
                overflow: TextOverflow.clip,
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
    final goal = this.goal;
    final top = max(values.nonNulls.maxOrNull ?? 0, goal ?? 0) * 1.12;
    final labels = this.labels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final (index, value) in values.indexed)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: gap / 2),
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
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                  if (goal != null && goal > 0 && top > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: height * goal / top,
                      child: CustomPaint(
                        size: const Size.fromHeight(1.5),
                        painter: _Dashes(_colors.textSecondary),
                      ),
                    ),
                  if (goal != null && goal > 0 && top > 0)
                    Positioned(
                      right: 0,
                      bottom: height * goal / top + 3,
                      child: Text(
                        l10n.grams(formatGrams(goal, locale)),
                        style: _body(10.5, weight: FontWeight.w600),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Container(height: 1, color: _colors.divider),
        if (labels != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: _body(10.5, weight: FontWeight.w600),
                  ),
                ),
            ],
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
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Column(
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
    ),
  );
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
              _Grams(protein.averageGrams, size: 70),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    [l10n.statsDailyAverage, ?compared].join('\n'),
                    style: _body(13),
                    maxLines: 2,
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
                    l10n.shareYearGoalDays(stats.countedDays),
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
}

/// A month of the calendar, each day colored by its progress.
class CalendarMonthTile extends StatelessWidget {
  const CalendarMonthTile({super.key, required this.data});

  final MonthShare data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final material = MaterialLocalizations.of(context);
    final month = data.month;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (month.weekday % 7 - data.firstWeekday + 7) % 7;
    var reached = 0;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
    ];
    for (var day = 1; day <= days; day++) {
      final dayKey = dayKeyOfDate(DateTime(month.year, month.month, day));
      final counted = dayKey >= data.firstAppDayKey && dayKey <= data.todayKey;
      final grams = data.grams[dayKey] ?? 0;
      final goal = data.goalOf(dayKey);
      final full = counted && goal != null && goal > 0 && grams >= goal;
      final half = counted && !full && goal != null && grams >= goal / 2;
      if (full) reached++;
      cells.add(
        Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: !counted
                ? null
                : full
                ? AppColors.accent
                : half
                ? AppColors.progressHalf
                : _colors.surface,
            borderRadius: BorderRadius.circular(7),
            border: dayKey > data.todayKey
                ? Border.all(color: _colors.divider, width: 1.2)
                : dayKey == data.todayKey
                ? Border.all(color: _colors.text, width: 2)
                : null,
          ),
          child: Text(
            '$day',
            style: _body(
              12.5,
              weight: FontWeight.w600,
              color: !counted
                  ? _colors.divider
                  : full || half
                  ? AppColors.onAccent
                  : _colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return ShareTileFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  toBeginningOfSentenceCase(
                    DateFormat.MMMM(locale).format(month),
                  ),
                  style: _display(38),
                ),
              ),
              Text(l10n.shareMonthReached(reached), style: _body(13.5)),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rows = ((lead + days) / 7).ceil();
                const gap = 5.0;
                final width = (constraints.maxWidth - gap * 6) / 7;
                final height = min(
                  width,
                  (constraints.maxHeight - gap * (rows - 1)) / rows,
                );
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
          const SizedBox(height: 6),
          Row(
            children: [
              _Dot(AppColors.accent),
              Text(l10n.shareGoalReached, style: _body(11)),
              const SizedBox(width: 14),
              _Dot(AppColors.progressHalf),
              Text(l10n.shareHalfGoal, style: _body(11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    margin: const EdgeInsets.only(right: 5),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A day of the week tile.
typedef WeekDayShare = ({int dayKey, Map<DaySlot, double> bySlot, double goal});

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
          const Spacer(),
          Row(
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
                        DateFormat.E(locale).format(dateOfDayKey(day.dayKey)),
                        style: _body(11, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
