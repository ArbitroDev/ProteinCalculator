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

  /// Progress of a day of [total] grams towards [goal] grams.
  static DayProgress of(double total, double goal) {
    if (total <= 0) return none;
    if (total >= goal) return reached;
    return total * 2 >= goal ? half : low;
  }
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
