import 'dart:math';

import 'package:protein_calculator/core/domain/grams.dart';

/// How far a day went towards its goal, shown by the calendar.
enum DayProgress {
  /// No protein at all.
  none,

  /// Less than half of the goal.
  low,

  /// Half of the goal or more, without reaching it.
  half,

  /// The goal is reached or exceeded.
  reached;

  /// Progress of a day of [total] grams towards [goal] grams, both as shown,
  /// rounded to the gram, see [isGoalReached].
  static DayProgress of(double total, double goal) {
    if (total <= 0) return none;
    if (isGoalReached(total, goal)) return reached;
    return roundGrams(total) * 2 >= roundGrams(goal) ? half : low;
  }
}

/// Whether a day of [total] protein grams reaches its [goal]: once the total
/// as shown, rounded to the gram (see [roundGrams]), reaches the goal as
/// shown. The one rule of every screen, the watch and the widget included,
/// so that "140 g / 140 g" always goes with the goal reached.
bool isGoalReached(double total, double goal) =>
    roundGrams(total) >= roundGrams(goal);

/// Whole grams left to reach [goal] from [total], as shown; 0 once reached.
int gramsLeft(double total, double goal) =>
    max(0, roundGrams(goal) - roundGrams(total));

/// Whole grams of [total] beyond [goal], as shown; 0 below it.
int gramsOver(double total, double goal) =>
    max(0, roundGrams(total) - roundGrams(goal));

/// Share of [goal] that [total] makes, in whole percent rounded down, so
/// that 100 % always goes with the goal reached; 0 without a goal.
int goalPercent(double total, double goal) {
  final shownGoal = roundGrams(goal);
  return shownGoal <= 0 ? 0 : roundGrams(total) * 100 ~/ shownGoal;
}

/// Goal of the app day [dayKey], from the goals set over time as
/// `(dayKey, grams)`, oldest first: the latest set on that day or before.
/// Days before the first goal take it, the earlier goals being unknown.
/// Null without any goal.
double? goalOn(int dayKey, List<({int dayKey, double grams})> goals) {
  if (goals.isEmpty) return null;
  var goal = goals.first.grams;
  for (final change in goals) {
    if (change.dayKey > dayKey) break;
    goal = change.grams;
  }
  return goal;
}

/// Goal of the app day [dayKey]: the one it had, see [goalOn], or else the
/// [current] goal, before any goal was kept over time. The one rule of the
/// history, the calendar, the statistics, the shared tiles and the watch.
double? goalOfDay(
  int dayKey,
  List<({int dayKey, double grams})> goals,
  double? current,
) => goalOn(dayKey, goals) ?? current;

/// App days of [totals] (protein grams by day) reaching their goal, see
/// [goalOfDay] and [isGoalReached]; none without a goal.
Set<int> reachedDayKeys(
  Map<int, double> totals,
  List<({int dayKey, double grams})> goals,
  double? current,
) => {
  for (final MapEntry(key: dayKey, value: total) in totals.entries)
    if (goalOfDay(dayKey, goals, current) case final goal?
        when goal > 0 && isGoalReached(total, goal))
      dayKey,
};
