import 'package:protein_calculator/core/domain/app_day.dart';

/// Part of the app day an entry belongs to, based on the time it was added.
enum DaySlot {
  /// 3 a.m. to noon.
  morning,

  /// Noon to 6 p.m.
  afternoon,

  /// 6 p.m. to 3 a.m.
  evening;

  static DaySlot of(DateTime time) {
    final hour = time.hour;
    if (hour >= appDayStartHour && hour < 12) return DaySlot.morning;
    if (hour >= 12 && hour < 18) return DaySlot.afternoon;
    return DaySlot.evening;
  }
}
