/// An app day runs from 3 a.m. to 3 a.m. the next calendar day, so that a
/// late-night snack still counts for the evening it belongs to.
const appDayStartHour = 3;

/// Identifies the app day of [time] as a `yyyymmdd` integer.
///
/// Uses calendar fields rather than duration arithmetic, so daylight saving
/// changes never move an entry to the wrong day.
int dayKeyOf(DateTime time) {
  final day = time.hour < appDayStartHour
      ? DateTime(time.year, time.month, time.day - 1)
      : time;
  return day.year * 10000 + day.month * 100 + day.day;
}

/// Calendar date (at midnight) of the app day identified by [dayKey].
DateTime dateOfDayKey(int dayKey) =>
    DateTime(dayKey ~/ 10000, dayKey ~/ 100 % 100, dayKey % 100);

/// Moment the app day following the one containing [time] starts.
DateTime nextDayStart(DateTime time) {
  final date = dateOfDayKey(dayKeyOf(time));
  return DateTime(date.year, date.month, date.day + 1, appDayStartHour);
}
