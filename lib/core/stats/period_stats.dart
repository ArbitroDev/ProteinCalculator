import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/hevy/hevy_csv.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/stats/streaks.dart';

/// Fewest days on each side of a comparison (workout days against rest
/// days…) for it to show: fewer would tell more about chance than habits.
const minCompareDays = 3;

/// Fewest days of one weekday for its average to show.
const minWeekdayDays = 2;

/// Time after a workout whose protein counts as taken after it.
const postWorkoutWindow = Duration(hours: 3);

/// Protein grams after a workout, within [postWorkoutWindow], for it to count
/// as followed by protein.
const postWorkoutGrams = 20.0;

/// Length assumed for a workout without an end, to know when it was over.
const assumedWorkoutLength = Duration(hours: 1);

/// Time of day, in minutes after midnight, from which a goal reached counts
/// as reached late.
const lateGoalMinutes = 21 * 60;

/// Everything the statistics of a period are computed from.
@immutable
class StatsInput {
  const StatsInput({
    required this.days,
    required this.goals,
    required this.currentGoal,
    required this.firstAppDayKey,
    required this.todayKey,
    required this.firstWeekday,
    required this.creatineTracked,
    required this.hevyImported,
    required this.workoutDays,
    required this.entries,
    required this.sessions,
  });

  /// Days having entries, by key, all of them: streaks run past the period.
  final Map<int, DaySummary> days;

  /// Daily goals over time, oldest first, see `goalOn`.
  final List<({int dayKey, double grams})> goals;
  final double? currentGoal;
  final int firstAppDayKey;
  final int todayKey;

  /// First day of the week, 0 for Sunday as the localizations count.
  final int firstWeekday;

  /// Whether the user tracks creatine.
  final bool creatineTracked;

  /// Whether Hevy workouts were imported.
  final bool hevyImported;

  /// Days having a Hevy workout, all of them.
  final Set<int> workoutDays;

  /// Entries of the period and of the day after it, by their time: protein
  /// taken after a workout of the last day may fall on it.
  final List<Entry> entries;

  /// Hevy workouts of the period, in the order they started.
  final List<HevySession> sessions;
}

/// Statistics of one period, see [computeStats].
@immutable
class PeriodStats {
  const PeriodStats({
    required this.period,
    required this.countedDays,
    required this.hasEntries,
    required this.protein,
    required this.creatine,
    required this.workouts,
    required this.cross,
  });

  final StatsPeriod period;

  /// Days counted, see `countedDayKeys`.
  final int countedDays;

  /// Whether one of the counted days has entries.
  final bool hasEntries;
  final ProteinStats protein;

  /// Null when creatine is neither tracked nor taken in the period.
  final CreatineStats? creatine;

  /// Null without Hevy workouts imported.
  final WorkoutStats? workouts;
  final CrossStats cross;
}

/// A bar of the protein chart: a day, or a month of a year.
@immutable
class StatsBar {
  const StatsBar({required this.date, this.dayKey, this.grams, this.goal});

  /// The day, or the first day of the month.
  final DateTime date;

  /// Key of the day; null for a month.
  final int? dayKey;

  /// Protein grams of the day, or daily average of the month; null when it
  /// is not counted.
  final double? grams;

  /// Goal of the day, or average goal of the month.
  final double? goal;
}

@immutable
class ProteinStats {
  const ProteinStats({
    required this.averageGrams,
    required this.averageGoal,
    required this.goalDays,
    required this.currentStreak,
    required this.bestStreak,
    required this.bars,
    required this.deltaGrams,
  });

  /// Protein grams per counted day, days without entries counting for 0 g,
  /// today only once its goal is reached.
  final double averageGrams;

  /// Average goal of the counted days; null without a goal.
  final double? averageGoal;

  /// Counted days reaching their goal.
  final int goalDays;

  /// Days in a row reaching their goal, up to today; null when the period
  /// does not hold today.
  final int? currentStreak;

  /// Longest streak of days reaching their goal touching the period.
  final int bestStreak;
  final List<StatsBar> bars;

  /// [averageGrams] minus that of the previous period, rounded; null when
  /// the previous period has no counted day.
  final int? deltaGrams;
}

@immutable
class CreatineStats {
  const CreatineStats({
    required this.countedDays,
    required this.takenDays,
    required this.currentStreak,
    required this.doses,
    required this.marks,
    required this.monthShares,
  });

  /// Counted days from the first dose ever taken.
  final int countedDays;
  final int takenDays;

  /// Days in a row with creatine, up to today; null when the period does not
  /// hold today.
  final int? currentStreak;
  final int doses;

  /// Each day of a week or a month: whether creatine was taken, null when
  /// the day is not counted. Empty for a year.
  final List<bool?> marks;

  /// Each month of a year: the share of its counted days with creatine, null
  /// without counted day. Empty for a week or a month.
  final List<double?> monthShares;
}

@immutable
class WorkoutStats {
  const WorkoutStats({
    required this.sessions,
    required this.days,
    required this.perWeek,
    required this.totalDuration,
    required this.averageDuration,
    required this.marks,
    required this.monthShares,
  });

  /// Workouts of the counted days.
  final int sessions;

  /// Counted days with a workout.
  final int days;

  /// Workouts per week of counted days.
  final double perWeek;

  /// Of the workouts having a length; null without any.
  final Duration? totalDuration;
  final Duration? averageDuration;

  /// As [CreatineStats.marks], for the days with a workout.
  final List<bool?> marks;

  /// As [CreatineStats.monthShares], for the days with a workout.
  final List<double?> monthShares;
}

/// Two averages compared, such as the protein of the workout days and that
/// of the rest days.
typedef StatsComparison = ({double first, double second});

/// What the protein, the creatine and the workouts tell together. Each
/// field is null when its data is missing or too thin to show.
@immutable
class CrossStats {
  const CrossStats({
    this.proteinByWorkout,
    this.goalShareByWorkout,
    this.proteinAfterWorkoutDay,
    this.postWorkout,
    this.creatineByWorkout,
    this.completeDays,
    this.weekdayAverages,
    this.slotShares,
    this.rhythm,
    this.topProducts = const [],
    this.shortfall,
    this.goalTime,
    this.regularity,
    this.workoutTime,
  });

  /// Protein grams per day: workout days, then rest days.
  final StatsComparison? proteinByWorkout;

  /// Share of the days reaching their goal: workout days, then rest days.
  final StatsComparison? goalShareByWorkout;

  /// Protein grams per day of the rest days following a workout day; null
  /// with fewer than [minCompareDays] of them.
  final double? proteinAfterWorkoutDay;

  /// Protein grams taken within [postWorkoutWindow] after a workout, on
  /// average, and how many of the [sessions] were followed by
  /// [postWorkoutGrams] at least.
  final ({double grams, int followed, int sessions})? postWorkout;

  /// Share of the days with creatine: workout days, then rest days.
  final StatsComparison? creatineByWorkout;

  /// Days reaching their goal with creatine taken, and their share of the
  /// days counted for creatine.
  final ({int days, double share})? completeDays;

  /// Protein grams per day of each weekday, from the first day of the week;
  /// null for a weekday counted on too few days. Null for a week.
  final List<double?>? weekdayAverages;

  /// Share of the protein taken in each part of the day.
  final Map<DaySlot, double>? slotShares;

  /// Entries of protein per counted day, their average grams, and the
  /// average time of the first one of a day, in minutes after midnight.
  final ({double entriesPerDay, double gramsPerEntry, int firstEntryMinutes})?
  rhythm;

  /// Names entered most often, with their uses and protein grams, the most
  /// used first; three at most.
  final List<({String name, int uses, double grams})> topProducts;

  /// Protein grams missing on average on the past days with entries missing
  /// their goal, and how many of them; null with fewer than
  /// [minCompareDays] of them.
  final ({double grams, int days})? shortfall;

  /// Average time the goal was reached, in minutes after midnight, of the
  /// days whose entries reach it; how many of them reached it after
  /// [lateGoalMinutes]; and how many there are. Null with fewer than
  /// [minCompareDays] of them.
  final ({int minutes, int late, int days})? goalTime;

  /// Standard deviation of the protein grams of the past days with entries,
  /// with the lowest and the highest of them, the earliest when tied; null
  /// with fewer than [minCompareDays] of them.
  final ({
    double deviation,
    ({int dayKey, double grams}) lowest,
    ({int dayKey, double grams}) highest,
  })?
  regularity;

  /// Average start time of the workouts, in minutes after midnight; how many
  /// started in each part of the day; and the protein grams taken after
  /// them, within [postWorkoutWindow], for the parts of the day with
  /// [minCompareDays] workouts at least. Null with fewer workouts.
  final ({
    int startMinutes,
    Map<DaySlot, int> counts,
    Map<DaySlot, double> afterGrams,
  })?
  workoutTime;

  bool get isEmpty =>
      proteinByWorkout == null &&
      goalShareByWorkout == null &&
      proteinAfterWorkoutDay == null &&
      postWorkout == null &&
      creatineByWorkout == null &&
      completeDays == null &&
      weekdayAverages == null &&
      slotShares == null &&
      rhythm == null &&
      topProducts.isEmpty &&
      shortfall == null &&
      goalTime == null &&
      regularity == null &&
      workoutTime == null;
}

/// Statistics of [period] from [input].
PeriodStats computeStats(StatsPeriod period, StatsInput input) {
  final counted = countedDayKeys(
    period,
    firstAppDayKey: input.firstAppDayKey,
    todayKey: input.todayKey,
  );
  final countedSet = counted.toSet();
  final holdsToday = period.contains(input.todayKey);

  double gramsOf(int dayKey) => input.days[dayKey]?.proteinGrams ?? 0;
  double? goalOf(int dayKey) =>
      goalOn(dayKey, input.goals) ?? input.currentGoal;
  bool reached(int dayKey) {
    final goal = goalOf(dayKey);
    return goal != null &&
        DayProgress.of(gramsOf(dayKey), goal) == DayProgress.reached;
  }

  final reachedDays = {
    for (final dayKey in input.days.keys)
      if (reached(dayKey)) dayKey,
  };
  final takenDays = {
    for (final MapEntry(key: dayKey, value: day) in input.days.entries)
      if (day.creatineDoses > 0) dayKey,
  };

  // Today counts in the averages once its goal is reached: before, it is
  // not over and would pull them down. Alone in the period, it counts all the
  // same, there being nothing else to show.
  final finished = [
    for (final dayKey in counted)
      if (dayKey != input.todayKey || reachedDays.contains(dayKey)) dayKey,
  ];
  final onlyToday = finished.isEmpty && counted.isNotEmpty;
  final averaged = onlyToday ? counted : finished;

  double average(Iterable<int> dayKeys) =>
      dayKeys.isEmpty ? 0 : dayKeys.map(gramsOf).sum / dayKeys.length;
  double? averageGoal(Iterable<int> dayKeys) {
    final goals = dayKeys.map(goalOf).nonNulls;
    return goals.isEmpty ? null : goals.sum / goals.length;
  }

  // Protein.
  final previous = countedDayKeys(
    period.previous,
    firstAppDayKey: input.firstAppDayKey,
    todayKey: input.todayKey,
  );
  final averageGrams = average(averaged);
  final protein = ProteinStats(
    averageGrams: averageGrams,
    averageGoal: averageGoal(averaged),
    goalDays: counted.where(reachedDays.contains).length,
    currentStreak: holdsToday
        ? currentStreak(reachedDays, input.todayKey)
        : null,
    bestStreak: bestStreakTouching(reachedDays, counted),
    bars: period.span == StatsSpan.year
        ? [
            for (final month in period.months)
              () {
                final days = averaged.where(month.contains).toList();
                return StatsBar(
                  date: month.start,
                  grams: days.isEmpty ? null : average(days),
                  goal: averageGoal(days),
                );
              }(),
          ]
        : [
            for (final dayKey in period.dayKeys)
              StatsBar(
                date: dateOfDayKey(dayKey),
                dayKey: dayKey,
                grams: countedSet.contains(dayKey) ? gramsOf(dayKey) : null,
                goal: goalOf(dayKey),
              ),
          ],
    deltaGrams: previous.isEmpty || onlyToday
        ? null
        : (averageGrams - average(previous)).round(),
  );

  // Creatine: counted from the first dose, it may have been turned on long
  // after the app was first used.
  final firstDose = takenDays.isEmpty ? null : takenDays.min;
  final creatineCounted = firstDose == null
      ? const <int>[]
      : counted.where((dayKey) => dayKey >= firstDose).toList();
  final creatineSet = creatineCounted.toSet();
  final doses = counted.map((k) => input.days[k]?.creatineDoses ?? 0).sum;
  final creatine = input.creatineTracked || doses > 0
      ? CreatineStats(
          countedDays: creatineCounted.length,
          takenDays: creatineCounted.where(takenDays.contains).length,
          currentStreak: holdsToday
              ? currentStreak(takenDays, input.todayKey)
              : null,
          doses: doses,
          marks: _marks(period, creatineSet, takenDays),
          monthShares: _monthShares(period, creatineCounted, takenDays),
        )
      : null;

  // Workouts.
  final workoutDays = input.workoutDays;
  final sessions = [
    for (final session in input.sessions)
      if (countedSet.contains(session.dayKey)) session,
  ];
  final durations = [
    for (final session in sessions)
      ?workoutDuration(session.startedAt, session.endedAt),
  ];
  final total = durations.fold(Duration.zero, (sum, d) => sum + d);
  final workouts = input.hevyImported
      ? WorkoutStats(
          sessions: sessions.length,
          days: counted.where(workoutDays.contains).length,
          perWeek: counted.isEmpty ? 0 : sessions.length * 7 / counted.length,
          totalDuration: durations.isEmpty ? null : total,
          averageDuration: durations.isEmpty ? null : total ~/ durations.length,
          marks: _marks(period, countedSet, workoutDays),
          monthShares: _monthShares(period, counted, workoutDays),
        )
      : null;

  return PeriodStats(
    period: period,
    countedDays: counted.length,
    hasEntries: counted.any(input.days.containsKey),
    protein: protein,
    creatine: creatine,
    workouts: workouts,
    cross: _cross(
      period: period,
      input: input,
      counted: counted,
      averaged: averaged,
      countedSet: countedSet,
      creatineCounted: creatine == null ? const [] : creatineCounted,
      sessions: sessions,
      gramsOf: gramsOf,
      goalOf: goalOf,
      reachedDays: reachedDays,
      takenDays: takenDays,
      average: average,
    ),
  );
}

/// Each day of a week or a month: whether it is one of [days], null when it
/// is not [counted]. Empty for a year.
List<bool?> _marks(StatsPeriod period, Set<int> counted, Set<int> days) =>
    period.span == StatsSpan.year
    ? const []
    : [
        for (final dayKey in period.dayKeys)
          counted.contains(dayKey) ? days.contains(dayKey) : null,
      ];

/// Each month of a year: the share of its [counted] days that are [days].
/// Empty for a week or a month.
List<double?> _monthShares(
  StatsPeriod period,
  List<int> counted,
  Set<int> days,
) => period.span != StatsSpan.year
    ? const []
    : [
        for (final month in period.months)
          () {
            final inMonth = counted.where(month.contains).toList();
            return inMonth.isEmpty
                ? null
                : inMonth.where(days.contains).length / inMonth.length;
          }(),
      ];

/// Two averages of [value] over the days of [first] and of [second]; null
/// when one of them has fewer than [minCompareDays] days.
StatsComparison? _compare(
  List<int> first,
  List<int> second,
  double Function(int dayKey) value,
) {
  if (first.length < minCompareDays || second.length < minCompareDays) {
    return null;
  }
  double average(List<int> days) => days.map(value).sum / days.length;
  return (first: average(first), second: average(second));
}

CrossStats _cross({
  required StatsPeriod period,
  required StatsInput input,
  required List<int> counted,
  required List<int> averaged,
  required Set<int> countedSet,
  required List<int> creatineCounted,
  required List<HevySession> sessions,
  required double Function(int) gramsOf,
  required double? Function(int) goalOf,
  required Set<int> reachedDays,
  required Set<int> takenDays,
  required double Function(Iterable<int>) average,
}) {
  final workoutDays = input.workoutDays;
  final hevy = input.hevyImported;

  // Protein and workouts.
  final trainingDays = averaged.where(workoutDays.contains).toList();
  final restDays = averaged.whereNot(workoutDays.contains).toList();
  final afterWorkout = restDays
      .where((dayKey) => workoutDays.contains(previousDayKey(dayKey)))
      .toList();
  double reachedShare(int dayKey) => reachedDays.contains(dayKey) ? 1 : 0;
  double takenShare(int dayKey) => takenDays.contains(dayKey) ? 1 : 0;

  // Protein entries, without the creatine taken on its own.
  final proteinEntries = [
    for (final entry in input.entries)
      if (entry.proteinGrams > 0) entry,
  ];

  // Protein grams taken within [postWorkoutWindow] after a workout.
  double takenAfter(HevySession session) {
    final over = workoutDuration(session.startedAt, session.endedAt) == null
        ? session.startedAt.add(assumedWorkoutLength)
        : session.endedAt!;
    final until = over.add(postWorkoutWindow);
    return proteinEntries
        .where(
          (entry) =>
              !entry.createdAt.isBefore(over) &&
              entry.createdAt.isBefore(until),
        )
        .map((entry) => entry.proteinGrams)
        .sum;
  }

  ({double grams, int followed, int sessions})? postWorkout;
  ({
    int startMinutes,
    Map<DaySlot, int> counts,
    Map<DaySlot, double> afterGrams,
  })?
  workoutTime;
  if (hevy && sessions.length >= minCompareDays) {
    final taken = [for (final session in sessions) takenAfter(session)];
    postWorkout = (
      grams: taken.sum / sessions.length,
      followed: taken.where((grams) => grams >= postWorkoutGrams).length,
      sessions: sessions.length,
    );

    final bySlot = {for (final slot in DaySlot.values) slot: <double>[]};
    for (final (index, session) in sessions.indexed) {
      bySlot[DaySlot.of(session.startedAt)]!.add(taken[index]);
    }
    workoutTime = (
      startMinutes: _averageQuarter([
        for (final session in sessions)
          _minutesOfDay(session.startedAt, session.dayKey),
      ]),
      counts: {
        for (final MapEntry(key: slot, value: grams) in bySlot.entries)
          slot: grams.length,
      },
      afterGrams: {
        for (final MapEntry(key: slot, value: grams) in bySlot.entries)
          if (grams.length >= minCompareDays) slot: grams.sum / grams.length,
      },
    );
  }

  // The goal: past days with protein, today is not over.
  final pastDays = [
    for (final dayKey in counted)
      if (dayKey != input.todayKey && gramsOf(dayKey) > 0) dayKey,
  ];
  final missing = [
    for (final dayKey in pastDays)
      if (goalOf(dayKey) case final goal? when !reachedDays.contains(dayKey))
        goal - gramsOf(dayKey),
  ];

  // When the entries of each day reaching its goal reach it.
  final entriesOf = <int, List<Entry>>{};
  for (final entry in input.entries) {
    if (countedSet.contains(entry.dayKey)) {
      (entriesOf[entry.dayKey] ??= []).add(entry);
    }
  }
  final reachedAt = <int>[];
  for (final MapEntry(key: dayKey, value: entries) in entriesOf.entries) {
    final goal = goalOf(dayKey);
    if (goal == null || !reachedDays.contains(dayKey)) continue;
    var total = 0.0;
    for (final entry in entries) {
      total += entry.proteinGrams;
      if (total >= goal) {
        reachedAt.add(_minutesOfDay(entry.createdAt, dayKey));
        break;
      }
    }
  }

  // Regularity.
  ({
    double deviation,
    ({int dayKey, double grams}) lowest,
    ({int dayKey, double grams}) highest,
  })?
  regularity;
  if (pastDays.length >= minCompareDays) {
    final mean = average(pastDays);
    final variance =
        pastDays.map((k) => math.pow(gramsOf(k) - mean, 2)).sum /
        pastDays.length;
    // [pastDays] runs in order: the first of tied days stays.
    final lowest = pastDays.reduce((a, b) => gramsOf(b) < gramsOf(a) ? b : a);
    final highest = pastDays.reduce((a, b) => gramsOf(b) > gramsOf(a) ? b : a);
    regularity = (
      deviation: math.sqrt(variance),
      lowest: (dayKey: lowest, grams: gramsOf(lowest)),
      highest: (dayKey: highest, grams: gramsOf(highest)),
    );
  }

  // Creatine.
  final complete = creatineCounted
      .where((k) => reachedDays.contains(k) && takenDays.contains(k))
      .length;

  // Weekdays, for a month or a year only.
  List<double?>? weekdayAverages;
  if (period.span != StatsSpan.week) {
    final averages = [
      for (var i = 0; i < 7; i++)
        () {
          final weekday = (input.firstWeekday + i) % 7;
          final days = averaged
              .where((k) => dateOfDayKey(k).weekday % 7 == weekday)
              .toList();
          return days.length < minWeekdayDays ? null : average(days);
        }(),
    ];
    if (averages.nonNulls.length >= 2) weekdayAverages = averages;
  }

  // Parts of the day.
  final bySlot = {for (final slot in DaySlot.values) slot: 0.0};
  for (final dayKey in counted) {
    input.days[dayKey]?.bySlot.forEach(
      (slot, grams) => bySlot[slot] = bySlot[slot]! + grams,
    );
  }
  final slotTotal = bySlot.values.sum;

  // Rhythm and products, on the entries of the counted days.
  final periodEntries = [
    for (final entry in proteinEntries)
      if (countedSet.contains(entry.dayKey)) entry,
  ];
  ({double entriesPerDay, double gramsPerEntry, int firstEntryMinutes})? rhythm;
  if (periodEntries.isNotEmpty) {
    final firstOfDay = <int, DateTime>{};
    for (final entry in periodEntries) {
      firstOfDay.putIfAbsent(entry.dayKey, () => entry.createdAt);
    }
    final minutes = [
      for (final MapEntry(key: dayKey, value: time) in firstOfDay.entries)
        _minutesOfDay(time, dayKey),
    ];
    final averagedSet = averaged.toSet();
    // Today, not over, would lower the entries per day, as it lowers the
    // average: left out until its goal is reached. Its entries and its
    // first one are what they are.
    rhythm = (
      entriesPerDay:
          periodEntries.where((e) => averagedSet.contains(e.dayKey)).length /
          averaged.length,
      gramsPerEntry:
          periodEntries.map((entry) => entry.proteinGrams).sum /
          periodEntries.length,
      firstEntryMinutes: _averageQuarter(minutes),
    );
  }

  final products = <String, ({String name, int uses, double grams})>{};
  for (final entry in periodEntries) {
    final key = entry.nameKey;
    final name = entry.name;
    if (key == null || name == null) continue;
    final known = products[key];
    // The name as last entered.
    products[key] = (
      name: name,
      uses: (known?.uses ?? 0) + 1,
      grams: (known?.grams ?? 0) + entry.proteinGrams,
    );
  }
  final topProducts = products.values.sorted(
    (a, b) => b.uses != a.uses
        ? b.uses.compareTo(a.uses)
        : b.grams != a.grams
        ? b.grams.compareTo(a.grams)
        : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  final creatineTraining = creatineCounted.where(workoutDays.contains).toList();
  final creatineRest = creatineCounted.whereNot(workoutDays.contains).toList();

  return CrossStats(
    proteinByWorkout: hevy ? _compare(trainingDays, restDays, gramsOf) : null,
    goalShareByWorkout: hevy
        ? _compare(trainingDays, restDays, reachedShare)
        : null,
    proteinAfterWorkoutDay: hevy && afterWorkout.length >= minCompareDays
        ? average(afterWorkout)
        : null,
    postWorkout: postWorkout,
    creatineByWorkout: hevy
        ? _compare(creatineTraining, creatineRest, takenShare)
        : null,
    completeDays: creatineCounted.length < minCompareDays
        ? null
        : (days: complete, share: complete / creatineCounted.length),
    weekdayAverages: weekdayAverages,
    slotShares: slotTotal <= 0
        ? null
        : {
            for (final MapEntry(key: slot, value: grams) in bySlot.entries)
              slot: grams / slotTotal,
          },
    rhythm: rhythm,
    topProducts: topProducts.take(3).toList(),
    shortfall: missing.length < minCompareDays
        ? null
        : (grams: missing.sum / missing.length, days: missing.length),
    goalTime: reachedAt.length < minCompareDays
        ? null
        : (
            minutes: _averageQuarter(reachedAt),
            late: reachedAt.where((m) => m > lateGoalMinutes).length,
            days: reachedAt.length,
          ),
    regularity: regularity,
    workoutTime: workoutTime,
  );
}

/// Minutes after midnight of [time] in the day of [dayKey]: past 24 hours
/// after midnight, for a time still belonging to the day before.
int _minutesOfDay(DateTime time, int dayKey) =>
    time.hour * 60 + time.minute + (dayKeyOfDate(time) == dayKey ? 0 : 24 * 60);

/// Average of [minutes], rounded to the quarter, as a time of day.
int _averageQuarter(List<int> minutes) =>
    (minutes.sum / minutes.length / 15).round() * 15 % (24 * 60);
