import 'package:protein_calculator/core/stats/stats_period.dart';

/// Number of days in a row of [days] ending on [dayKey]; 0 if [dayKey] is not
/// one of them.
int streakEnding(Set<int> days, int dayKey) {
  var count = 0;
  for (var day = dayKey; days.contains(day); day = previousDayKey(day)) {
    count++;
  }
  return count;
}

/// Streak going on at [todayKey]: the one ending yesterday, and today once
/// it is one of [days]. Today never breaks it before it is over.
int currentStreak(Set<int> days, int todayKey) => days.contains(todayKey)
    ? streakEnding(days, todayKey)
    : streakEnding(days, previousDayKey(todayKey));

/// Longest streak of [days] having at least one day among [dayKeys], counted
/// whole, beyond them too; 0 without any.
int bestStreakTouching(Set<int> days, Iterable<int> dayKeys) {
  var best = 0;
  final seen = <int>{};
  for (final dayKey in dayKeys) {
    if (!days.contains(dayKey) || seen.contains(dayKey)) continue;
    var first = dayKey;
    while (days.contains(previousDayKey(first))) {
      first = previousDayKey(first);
    }
    var length = 0;
    for (var day = first; days.contains(day); day = nextDayKey(day)) {
      seen.add(day);
      length++;
    }
    if (length > best) best = length;
  }
  return best;
}
