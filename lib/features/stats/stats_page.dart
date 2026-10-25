import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/content_width.dart';
import 'package:protein_calculator/core/widgets/empty_state.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/core/widgets/pill_tabs.dart';
import 'package:protein_calculator/features/stats/stats_providers.dart';
import 'package:protein_calculator/features/stats/stats_widgets.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Statistics tab: protein, creatine and workouts over a week, a month or a
/// year, and what they tell together.
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  /// Statistics last shown, kept while those of another period are read.
  PeriodStats? _shown;

  void _show(StatsPeriod period, int todayKey) => ref
      .read(statsDateProvider.notifier)
      .show(period.contains(todayKey) ? null : period.start);

  void _selectSpan(StatsSpan span, StatsPeriod period, int todayKey) {
    // The current period stays current; another one gives its middle.
    ref
        .read(statsDateProvider.notifier)
        .show(period.contains(todayKey) ? null : period.middle);
    ref.read(statsSpanProvider.notifier).select(span);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayKey = ref.watch(currentDayKeyProvider).value;
    final firstKey = ref.watch(firstAppDayKeyProvider);
    final history = ref.watch(historyProvider).value;
    final span = ref.watch(statsSpanProvider);
    final date = ref.watch(statsDateProvider);
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;

    Widget body;
    if (todayKey == null || firstKey == null || history == null) {
      body = const SizedBox.shrink();
    } else if (history.isEmpty) {
      body = EmptyState(l10n.statsEmpty);
    } else {
      final today = dateOfDayKey(todayKey);
      var period = StatsPeriod.containing(
        span,
        date ?? today,
        firstWeekday: firstWeekday,
      );
      // A period of days to come, or before the app was used, has nothing to
      // tell: the current one instead.
      if (period.firstKey > todayKey || period.lastKey < firstKey) {
        period = StatsPeriod.containing(
          span,
          today,
          firstWeekday: firstWeekday,
        );
      }
      final stats =
          ref.watch(
            periodStatsProvider((period: period, firstWeekday: firstWeekday)),
          ) ??
          _shown;
      _shown = stats;
      final canGoBack = period.firstKey > firstKey;
      final canGoForward = period.lastKey < todayKey;

      final header = [
        PillTabs(
          labels: {
            StatsSpan.week: l10n.statsWeek,
            StatsSpan.month: l10n.statsMonth,
            StatsSpan.year: l10n.statsYear,
          },
          selected: span,
          onChanged: (value) => _selectSpan(value, period, todayKey),
        ),
        _PeriodBar(
          period: period,
          today: today,
          onPrevious: canGoBack ? () => _show(period.previous, todayKey) : null,
          onNext: canGoForward ? () => _show(period.next, todayKey) : null,
        ),
      ];
      body = stats == null
          ? const SizedBox.shrink()
          : GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 300 && canGoBack) {
                  _show(period.previous, todayKey);
                } else if (velocity < -300 && canGoForward) {
                  _show(period.next, todayKey);
                }
              },
              child: _StatsContent(
                stats: stats,
                header: header,
                todayKey: todayKey,
              ),
            );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStats)),
      // In landscape, the two columns take the width of the screen.
      body: ContentWidth(
        maxWidth: MediaQuery.orientationOf(context) == Orientation.landscape
            ? double.infinity
            : 640,
        child: body,
      ),
    );
  }
}

/// The period shown, between the buttons going to the previous and the next
/// one.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.period,
    required this.today,
    required this.onPrevious,
    required this.onNext,
  });

  final StatsPeriod period;
  final DateTime today;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    final label = switch (period.span) {
      StatsSpan.week => l10n.statsWeekOf(
        formatDayMonth(period.start, locale, now: today),
      ),
      StatsSpan.month => formatMonth(period.start, locale),
      StatsSpan.year => '${period.start.year}',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: l10n.statsPrevious,
            icon: const Icon(LucideIcons.chevronLeft),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: l10n.statsNext,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
      ),
    );
  }
}

/// The cards of a period, under [header]: in one column, or in landscape in
/// two of the same width, the protein beside the rest.
class _StatsContent extends ConsumerWidget {
  const _StatsContent({
    required this.stats,
    required this.header,
    required this.todayKey,
  });

  final PeriodStats stats;
  final List<Widget> header;
  final int todayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final goal = ref.watch(dailyGoalProvider).value;
    final entryDays = {
      for (final day
          in ref.watch(historyProvider).value ?? const <DaySummary>[])
        day.dayKey,
    };
    final workoutDays = ref.watch(hevySessionDaysProvider).value ?? const {};

    final main = <Widget>[
      if (stats.hasEntries)
        _ProteinCard(
          stats: stats,
          goal: goal,
          // A day opens on its entries, or on its workouts when it has none.
          canOpen: (dayKey) =>
              entryDays.contains(dayKey) || workoutDays.contains(dayKey),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Text(
            l10n.statsNoEntry,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: colors.textSecondary),
          ),
        ),
    ];
    final others = <Widget>[
      if (stats.creatine case final creatine?)
        _CreatineCard(stats: creatine, period: stats.period),
      if (stats.workouts case final workouts?)
        _WorkoutsCard(stats: workouts, period: stats.period),
      if (stats.hasEntries && !stats.cross.isEmpty)
        _InsightsCard(stats: stats.cross, goal: stats.protein.averageGoal),
    ];

    const padding = EdgeInsets.fromLTRB(18, 0, 18, 24);
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: padding.copyWith(right: 8),
              children: [...header, ...main],
            ),
          ),
          Expanded(
            child: ListView(
              padding: padding.copyWith(left: 8, top: 8),
              children: others,
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: padding,
      children: [...header, ...main, ...others],
    );
  }
}

/// Grams rounded to the unit, for averages: "136 g".
String _grams(double grams, String locale, AppLocalizations l10n) =>
    l10n.grams(NumberFormat.decimalPattern(locale).format(grams.round()));

String _percent(double share, String locale) =>
    NumberFormat.percentPattern(locale).format(share);

/// [count] of [total], as tiles show them: "17 / 25".
String _outOf(int count, int total) => '$count / $total';

class _ProteinCard extends StatelessWidget {
  const _ProteinCard({
    required this.stats,
    required this.goal,
    required this.canOpen,
  });

  final PeriodStats stats;

  /// Current goal, drawn over the bars.
  final double? goal;
  final bool Function(int dayKey) canOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final protein = stats.protein;
    final period = stats.period;
    final unitStyle = textTheme.headlineSmall!.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
    );

    final delta = protein.deltaGrams;
    String? compared;
    String? deltaText;
    if (delta != null) {
      final sign = delta > 0
          ? '+'
          : delta < 0
          ? '−'
          : '±';
      deltaText =
          '$sign${l10n.grams(NumberFormat.decimalPattern(locale).format(delta.abs()))}';
      final previous = period.previous.start;
      compared = switch (period.span) {
        StatsSpan.week => l10n.statsComparedToPreviousWeek(deltaText),
        StatsSpan.month => l10n.statsComparedTo(
          deltaText,
          DateFormat.MMMM(locale).format(previous),
        ),
        StatsSpan.year => l10n.statsComparedTo(deltaText, '${previous.year}'),
      };
    }

    String describe(StatsBar bar) {
      final when = bar.dayKey == null
          ? formatMonth(bar.date, locale)
          : formatShortDate(bar.date, locale);
      final grams = bar.dayKey == null
          ? _grams(bar.grams ?? 0, locale, l10n)
          : l10n.grams(formatGrams(bar.grams ?? 0, locale));
      return '$when · $grams';
    }

    final averageGoal = protein.averageGoal;
    return StatsCard(
      title: l10n.statsProtein,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: NumberFormat.decimalPattern(locale)
                    .format(protein.averageGrams.round()),
                style: textTheme.displayMedium,
              ),
              TextSpan(text: ' ${l10n.gramsUnit}', style: unitStyle),
              if (averageGoal != null)
                TextSpan(
                  text: '  / ${_grams(averageGoal, locale, l10n)}',
                  style: unitStyle.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
            children: [
              TextSpan(text: l10n.statsDailyAverage),
              if (compared != null && deltaText != null) ...[
                const TextSpan(text: ' · '),
                ..._highlighted(
                  compared,
                  deltaText,
                  TextStyle(
                    color: colors.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        StatTiles([
          StatTile(
            value: _outOf(protein.goalDays, stats.countedDays),
            label: l10n.statsGoalReached(
              _percent(protein.goalDays / stats.countedDays, locale),
            ),
          ),
          if (protein.currentStreak case final streak?)
            StatTile(
              value: l10n.statsDayCount(streak),
              label: l10n.statsCurrentStreak,
            ),
          StatTile(
            value: l10n.statsDayCount(protein.bestStreak),
            label: l10n.statsBestStreak,
          ),
        ]),
        const SizedBox(height: 10),
        StatsBarChart(
          bars: protein.bars,
          span: period.span,
          goal: goal,
          goalLabel: l10n.grams(formatGrams(goal ?? 0, locale)),
          describe: describe,
          canOpen: (bar) => bar.dayKey != null && canOpen(bar.dayKey!),
          onOpen: (bar) => context.go(AppRoutes.historyDay(bar.dayKey!)),
        ),
      ],
    );
  }
}

/// [text] in spans, [part] of it in [style].
List<TextSpan> _highlighted(String text, String part, TextStyle style) {
  final index = text.indexOf(part);
  if (index < 0) return [TextSpan(text: text)];
  return [
    TextSpan(text: text.substring(0, index)),
    TextSpan(text: part, style: style),
    TextSpan(text: text.substring(index + part.length)),
  ];
}

class _CreatineCard extends StatelessWidget {
  const _CreatineCard({required this.stats, required this.period});

  final CreatineStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final locale = context.localeName;
    return StatsCard(
      title: l10n.creatine,
      titleColor: colors.creatineText,
      children: [
        if (stats.countedDays == 0)
          Text(
            l10n.statsNoCreatine,
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: colors.textSecondary),
          )
        else ...[
          StatTiles([
            StatTile(
              value: _outOf(stats.takenDays, stats.countedDays),
              label: l10n.statsCreatineDays(
                _percent(stats.takenDays / stats.countedDays, locale),
              ),
            ),
            if (stats.currentStreak case final streak?)
              StatTile(
                value: l10n.statsDayCount(streak),
                label: l10n.statsCurrentStreak,
              ),
            StatTile(
              value: '${stats.doses}',
              label: l10n.statsDosesLabel(stats.doses),
            ),
          ]),
          DayMarksStrip(
            marks: stats.marks,
            monthShares: stats.monthShares,
            color: AppColors.creatine,
            summary: l10n.statsMarks(stats.takenDays, stats.countedDays),
          ),
        ],
      ],
    );
  }
}

class _WorkoutsCard extends StatelessWidget {
  const _WorkoutsCard({required this.stats, required this.period});

  final WorkoutStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final week = period.span == StatsSpan.week;
    final total = stats.totalDuration;
    final average = stats.averageDuration;
    final counted = stats.marks.isNotEmpty ? stats.marks.nonNulls.length : null;

    return StatsCard(
      title: l10n.statsWorkouts,
      caption: 'Hevy',
      children: [
        if (stats.sessions == 0)
          Text(
            l10n.statsNoWorkout,
            style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
          )
        else ...[
          StatTiles([
            StatTile(
              value: '${stats.sessions}',
              label: l10n.statsSessionsLabel(stats.sessions),
            ),
            if (week)
              StatTile(
                value: '${stats.days}',
                label: l10n.statsWorkoutDaysLabel(stats.days),
              )
            else
              StatTile(
                value: NumberFormat('#,##0.0', locale).format(stats.perWeek),
                label: l10n.statsPerWeek,
              ),
            StatTile(
              value: average == null ? '—' : formatDuration(average, l10n),
              label: l10n.statsAverageLength,
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            [
              if (!week) l10n.statsWorkoutDays(stats.days),
              if (total != null)
                l10n.statsTotalLength(formatDuration(total, l10n)),
            ].join(' · '),
            style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
          ),
          DayMarksStrip(
            marks: stats.marks,
            monthShares: stats.monthShares,
            color: colors.hevy,
            summary: counted == null
                ? l10n.statsWorkoutDays(stats.days)
                : l10n.statsMarks(stats.days, counted),
          ),
        ],
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.stats, required this.goal});

  final CrossStats stats;

  /// Average goal of the period, coloring the weekdays.
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.localeName;
    String grams(double value) => _grams(value, locale, l10n);
    String percent(double value) => _percent(value, locale);

    final sections = <(String, List<Widget>)>[];

    // Protein and workouts.
    final byWorkout = stats.proteinByWorkout;
    final afterDay = stats.proteinAfterWorkoutDay;
    final top = [
      ?byWorkout?.first,
      ?byWorkout?.second,
      ?afterDay?.first,
      ?afterDay?.second,
    ].fold(0.0, (a, b) => a > b ? a : b);
    double fraction(double value) => top <= 0 ? 0 : value / top;
    final workoutRows = <Widget>[
      if (byWorkout != null) ...[
        CompareBar(
          label: l10n.statsOnWorkoutDays,
          value: grams(byWorkout.first),
          fraction: fraction(byWorkout.first),
          color: AppColors.accent,
        ),
        CompareBar(
          label: l10n.statsOnRestDays,
          value: grams(byWorkout.second),
          fraction: fraction(byWorkout.second),
          color: AppColors.progressHalf,
        ),
      ],
      if (afterDay != null) ...[
        CompareBar(
          label: l10n.statsDaysAfterWorkout,
          value: grams(afterDay.first),
          fraction: fraction(afterDay.first),
          color: AppColors.accent,
        ),
        CompareBar(
          label: l10n.statsOtherRestDays,
          value: grams(afterDay.second),
          fraction: fraction(afterDay.second),
          color: AppColors.progressHalf,
        ),
      ],
      if (stats.goalShareByWorkout case final shares?)
        StatsValueRow(
          label: l10n.statsGoalByWorkout,
          value: '${percent(shares.first)} · ${percent(shares.second)}',
        ),
      if (stats.postWorkout case final after?)
        StatsValueRow(
          label: l10n.statsAfterWorkout(postWorkoutWindow.inHours),
          value: grams(after.grams),
          detail: l10n.statsAfterWorkoutFollowed(
            after.followed,
            after.sessions,
            l10n.grams(formatGrams(postWorkoutGrams, locale)),
          ),
        ),
    ];
    if (workoutRows.isNotEmpty) {
      sections.add((l10n.statsProteinAndWorkouts, workoutRows));
    }

    // Creatine.
    final creatineRows = <Widget>[
      if (stats.creatineByWorkout case final shares?)
        StatsValueRow(
          label: l10n.statsCreatineByWorkout,
          value: '${percent(shares.first)} · ${percent(shares.second)}',
        ),
      if (stats.completeDays case final complete?)
        StatsValueRow(
          label: l10n.statsCompleteDays,
          value: '${complete.days} · ${percent(complete.share)}',
        ),
    ];
    if (creatineRows.isNotEmpty) {
      sections.add((l10n.creatine, creatineRows));
    }

    if (stats.weekdayAverages case final averages?) {
      sections.add((
        l10n.statsWeekdays,
        [_Weekdays(averages: averages, goal: goal)],
      ));
    }

    if (stats.slotShares case final shares?) {
      sections.add((l10n.statsDayParts, [_DayParts(shares: shares)]));
    }

    if (stats.rhythm case final rhythm?) {
      final minutes = rhythm.firstEntryMinutes;
      sections.add((
        l10n.statsRhythm,
        [
          StatTiles([
            StatTile(
              value: NumberFormat(
                '#,##0.0',
                locale,
              ).format(rhythm.entriesPerDay),
              label: l10n.statsEntriesPerDay,
            ),
            StatTile(
              value: grams(rhythm.gramsPerEntry),
              label: l10n.statsPerEntry,
            ),
            StatTile(
              value: formatTime(
                DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
                locale,
              ),
              label: l10n.statsFirstEntry,
            ),
          ]),
        ],
      ));
    }

    if (stats.topProducts.isNotEmpty) {
      sections.add((
        l10n.statsTopProducts,
        [
          for (final product in stats.topProducts)
            StatsValueRow(
              label: product.name,
              value: l10n.statsProductUses(
                product.uses,
                l10n.grams(formatGrams(product.grams, locale)),
              ),
            ),
        ],
      ));
    }

    return StatsCard(
      title: l10n.statsInsights,
      children: [
        for (final (index, (title, rows)) in sections.indexed) ...[
          StatsSectionTitle(title, first: index == 0),
          ...rows,
        ],
      ],
    );
  }
}

/// Average protein of each weekday in small bars, with the best and the
/// lowest one.
class _Weekdays extends StatelessWidget {
  const _Weekdays({required this.averages, required this.goal});

  /// From the first day of the week; null for a weekday not counted enough.
  final List<double?> averages;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    final material = MaterialLocalizations.of(context);
    final firstWeekday = material.firstDayOfWeekIndex;
    final top = averages.nonNulls.max;
    // A date of each weekday, 0 for Sunday, to name it.
    DateTime dateOf(int weekday) => DateTime(2026, 10, 25 + weekday);
    String name(int index) =>
        DateFormat.EEEE(locale).format(dateOf((firstWeekday + index) % 7));

    final indexed = averages.indexed.where((e) => e.$2 != null).toList();
    final best = indexed.reduce((a, b) => b.$2! > a.$2! ? b : a);
    final lowest = indexed.reduce((a, b) => b.$2! < a.$2! ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, average) in averages.indexed)
                Expanded(
                  child: Semantics(
                    label: average == null
                        ? name(index)
                        : '${name(index)} · ${_grams(average, locale, l10n)}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: average == null
                                  ? null
                                  : FractionallySizedBox(
                                      heightFactor: top <= 0
                                          ? 0
                                          : (average / top).clamp(0.03, 1),
                                      widthFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: progressColor(
                                            average,
                                            goal,
                                            colors,
                                          ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(3),
                                              ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            material.narrowWeekdays[(firstWeekday + index) % 7],
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.statsBestWeekday(name(best.$1), _grams(best.$2!, locale, l10n)),
          style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
        ),
        Text(
          l10n.statsLowestWeekday(
            name(lowest.$1),
            _grams(lowest.$2!, locale, l10n),
          ),
          style: textTheme.bodyMedium!.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Share of the protein of each part of the day, in a stacked bar.
class _DayParts extends StatelessWidget {
  const _DayParts({required this.shares});

  final Map<DaySlot, double> shares;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.localeName;
    String name(DaySlot slot) => switch (slot) {
      DaySlot.morning => l10n.slotMorning,
      DaySlot.afternoon => l10n.slotAfternoon,
      DaySlot.evening => l10n.slotEvening,
    };
    final shown = [
      for (final slot in DaySlot.values)
        if ((shares[slot] ?? 0) > 0) slot,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final slot in shown)
                    Expanded(
                      flex: (shares[slot]! * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: AppColors.slot(slot)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final slot in shown)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.slot(slot),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${name(slot)} ${_percent(shares[slot]!, locale)}',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
