import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';

/// Length of the periods shown by the statistics tab, a month at first.
/// Kept while the app runs, not in the settings.
final statsSpanProvider = NotifierProvider<StatsSpanNotifier, StatsSpan>(
  StatsSpanNotifier.new,
);

class StatsSpanNotifier extends Notifier<StatsSpan> {
  @override
  StatsSpan build() => StatsSpan.month;

  void select(StatsSpan span) => state = span;
}

/// A date in the period shown by the statistics tab; null for the current
/// one, which then follows the days.
final statsDateProvider = NotifierProvider<StatsDateNotifier, DateTime?>(
  StatsDateNotifier.new,
);

class StatsDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void show(DateTime? date) => state = date;
}

/// Entries of the app days from the first key to the second, included.
final _entriesBetweenProvider = StreamProvider.autoDispose
    .family<List<Entry>, (int, int)>(
      (ref, range) => ref
          .watch(databaseProvider)
          .entriesDao
          .watchEntriesBetween(range.$1, range.$2),
    );

/// Hevy workouts of the app days from the first key to the second, included.
final _sessionsBetweenProvider = StreamProvider.autoDispose
    .family<List<HevySession>, (int, int)>(
      (ref, range) => ref
          .watch(databaseProvider)
          .hevyDao
          .watchSessionsBetween(range.$1, range.$2),
    );

/// Period whose statistics to compute, and the first day of the week, 0 for
/// Sunday as the localizations count.
typedef StatsRequest = ({StatsPeriod period, int firstWeekday});

/// Statistics of a period; null until the data they come from is read.
final periodStatsProvider = Provider.autoDispose
    .family<PeriodStats?, StatsRequest>((ref, request) {
      final period = request.period;
      final days = ref.watch(historyProvider).value;
      final goals = ref.watch(goalChangesProvider).value;
      final goal = ref.watch(dailyGoalProvider);
      final first = ref.watch(firstAppDayKeyProvider);
      final todayKey = ref.watch(currentDayKeyProvider).value;
      final creatine = ref.watch(creatineSettingsProvider).value;
      final importedAt = ref.watch(hevyImportedAtProvider);
      final workoutDays = ref.watch(hevySessionDaysProvider).value;
      // The day after the period too: protein taken after a workout of its
      // last day may fall on it.
      final entries = ref
          .watch(
            _entriesBetweenProvider((
              period.firstKey,
              nextDayKey(period.lastKey),
            )),
          )
          .value;
      final sessions = ref
          .watch(_sessionsBetweenProvider((period.firstKey, period.lastKey)))
          .value;
      if (days == null ||
          goals == null ||
          !goal.hasValue ||
          first == null ||
          todayKey == null ||
          creatine == null ||
          !importedAt.hasValue ||
          workoutDays == null ||
          entries == null ||
          sessions == null) {
        return null;
      }
      return computeStats(
        period,
        StatsInput(
          days: {for (final day in days) day.dayKey: day},
          goals: goals,
          currentGoal: goal.value,
          firstAppDayKey: first,
          todayKey: todayKey,
          firstWeekday: request.firstWeekday,
          creatineTracked: creatine.enabled,
          hevyImported: importedAt.value != null,
          workoutDays: workoutDays,
          entries: entries,
          sessions: sessions,
        ),
      );
    });
