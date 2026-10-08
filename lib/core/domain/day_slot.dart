import 'package:protein_calculator/core/domain/app_day.dart';

/// Part of the app day an entry belongs to, based on the time it was added.
enum DaySlot {
  /// Start of the app day (3 a.m. by default, see `appDayStartHour`) to
  /// 11:30 a.m.
  morning,

  /// 11:30 a.m. to 6 p.m.
  afternoon,

  /// 6 p.m. to the start of the next app day.
  evening;

  /// End of the morning, in minutes since midnight.
  static const morningEnd = 11 * 60 + 30;

  /// Start of the evening, in minutes since midnight.
  static const eveningStart = 18 * 60;

  static DaySlot of(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (time.hour < appDayStartHour) return DaySlot.evening;
    if (minutes < morningEnd) return DaySlot.morning;
    if (minutes < eveningStart) return DaySlot.afternoon;
    return DaySlot.evening;
  }
}
