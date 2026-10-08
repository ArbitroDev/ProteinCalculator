/// What a product does every day at the time chosen by the user.
enum DailyRoutine {
  /// Nothing: the product is only added by hand.
  none,

  /// A notification reminds the user to take the product, with a button
  /// adding it.
  reminder,

  /// The product is added on its own, and a notification says so, with a
  /// button removing it.
  autoAdd,
}

/// Minutes in a day: a routine time is a number of minutes since midnight,
/// from 0 to 1439.
const minutesPerDay = 24 * 60;

/// Whether [minutes] is a time of day.
bool isValidRoutineMinutes(int minutes) =>
    minutes >= 0 && minutes < minutesPerDay;

/// The local time of day [minutes] on the calendar date of [day].
DateTime routineTimeOn(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// Latest moment at the time of day [minutes] that is not after [now]:
/// today's if it has passed, otherwise yesterday's.
DateTime latestRoutineTime(int minutes, DateTime now) {
  final today = routineTimeOn(now, minutes);
  return today.isAfter(now)
      ? routineTimeOn(DateTime(now.year, now.month, now.day - 1), minutes)
      : today;
}

/// Moments at the time of day [minutes] strictly after [after] and up to
/// [until] included, oldest first.
List<DateTime> routineTimesBetween(
  int minutes,
  DateTime after,
  DateTime until,
) {
  final times = <DateTime>[];
  var day = DateTime(after.year, after.month, after.day);
  while (true) {
    final time = routineTimeOn(day, minutes);
    if (time.isAfter(until)) return times;
    if (time.isAfter(after)) times.add(time);
    day = DateTime(day.year, day.month, day.day + 1);
  }
}
