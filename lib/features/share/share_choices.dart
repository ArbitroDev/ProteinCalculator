import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/stats/streaks.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/locale_name.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/features/share/share_tiles.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Shortest current streak offered as its own tile.
const shareMinStreak = 3;

/// Round share button of the top right of a page.
class ShareButton extends StatelessWidget {
  const ShareButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      tooltip: AppLocalizations.of(context).shareButton,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
      ),
      icon: const Icon(LucideIcons.share2, size: 20),
    );
  }
}

/// A day as its tiles show it: its entries, goal, workouts and the streak
/// it continues. Pages with a share button watch it, so it is ready.
final dayShareProvider = Provider.autoDispose.family<DayShare, int>((
  ref,
  dayKey,
) {
  final days = ref.watch(historyProvider).value ?? const [];
  final goals = ref.watch(goalChangesProvider).value ?? const [];
  final current = ref.watch(dailyGoalProvider).value;
  final reached = {
    for (final day in days)
      if ((goalOn(day.dayKey, goals) ?? current) case final goal?
          when goal > 0 && day.proteinGrams >= goal)
        day.dayKey,
  };
  final shown = ref.watch(shownHevyDaysProvider).contains(dayKey);
  return DayShare(
    dayKey: dayKey,
    entries: ref.watch(dayEntriesProvider(dayKey)).value ?? const [],
    goal: ref.watch(dayGoalProvider(dayKey)) ?? 0,
    sessions: shown
        ? ref.watch(daySessionsProvider(dayKey)).value ?? const []
        : const <HevySession>[],
    streak: currentStreak(reached, dayKey),
    isToday: dayKey == ref.watch(currentDayKeyProvider).value,
  );
});

/// Tiles of a day: its shaker and its timeline, [timelineFirst] or not.
List<ShareChoice> dayShareChoices(
  BuildContext context,
  DayShare day, {
  required bool timelineFirst,
}) {
  final l10n = AppLocalizations.of(context);
  final dayKey = day.dayKey;
  final shaker = ShareChoice(
    label: l10n.shareChoiceShaker,
    fileName: 'protein-$dayKey',
    build: (_) => DayShakerTile(day: day),
  );
  final timeline = ShareChoice(
    label: l10n.shareChoiceDay,
    fileName: 'protein-day-$dayKey',
    productsSwitch: true,
    build: (options) =>
        DayTimelineTile(day: day, showProducts: options.showProducts),
  );
  return timelineFirst ? [timeline, shaker] : [shaker, timeline];
}

/// Tiles of the statistics shown: the current streak when long enough,
/// then the period.
List<ShareChoice> statsShareChoices(
  BuildContext context,
  PeriodStats stats,
  DateTime today,
) {
  final l10n = AppLocalizations.of(context);
  final streak = stats.protein.currentStreak ?? 0;
  final period = stats.period;
  final span = period.span;
  return [
    if (streak >= shareMinStreak)
      ShareChoice(
        label: l10n.shareChoiceStreak,
        fileName: 'protein-streak-$streak',
        build: (_) => StreakTile(streak: streak),
      ),
    ShareChoice(
      label: switch (span) {
        StatsSpan.week => l10n.statsWeek,
        StatsSpan.month => l10n.statsMonth,
        StatsSpan.year => l10n.statsYear,
      },
      fileName: 'protein-${span.name}-${period.firstKey}',
      build: (_) => span == StatsSpan.year
          ? YearTile(stats: stats)
          : PeriodTile(stats: stats, today: today),
    ),
  ];
}

/// Tiles of the history: a month of the calendar, which the sheet browses,
/// and the last 7 days, the one of the [view] first.
List<ShareChoice> historyShareChoices(
  WidgetRef ref,
  BuildContext context,
  HistoryView view,
) {
  final l10n = AppLocalizations.of(context);
  final locale = context.localeName;
  final todayKey = ref.read(currentDayKeyProvider).value!;
  final firstKey = ref.read(firstAppDayKeyProvider) ?? todayKey;
  final days = ref.read(historyProvider).value ?? const [];
  final goals = ref.read(goalChangesProvider).value ?? const [];
  final current = ref.read(dailyGoalProvider).value;
  double? goalOf(int dayKey) => goalOn(dayKey, goals) ?? current;
  final grams = {for (final day in days) day.dayKey: day.proteinGrams};
  final today = dateOfDayKey(todayKey);
  final first = dateOfDayKey(firstKey);
  DateTime monthAt(int offset) => DateTime(today.year, today.month + offset);
  final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  final byKey = {for (final day in days) day.dayKey: day};

  final month = ShareChoice(
    label: l10n.statsMonth,
    fileName: 'protein-calendar',
    browse: (
      name: (offset) => formatMonth(monthAt(offset), locale),
      oldest: (first.year - today.year) * 12 + first.month - today.month,
    ),
    build: (options) => CalendarMonthTile(
      data: MonthShare(
        month: monthAt(options.offset),
        grams: grams,
        goalOf: goalOf,
        todayKey: todayKey,
        firstAppDayKey: firstKey,
        firstWeekday: firstWeekday,
      ),
    ),
  );
  final week = ShareChoice(
    label: l10n.shareChoiceLastDays,
    fileName: 'protein-week-$todayKey',
    build: (_) => WeekTile(
      today: today,
      days: [
        for (var back = 6; back >= 0; back--)
          () {
            final dayKey = dayKeyOfDate(
              DateTime(today.year, today.month, today.day - back),
            );
            return (
              dayKey: dayKey,
              bySlot: byKey[dayKey]?.bySlot ?? const {},
              goal: goalOf(dayKey) ?? 0,
            );
          }(),
      ],
    ),
  );
  return view == HistoryView.calendar ? [month, week] : [week, month];
}
