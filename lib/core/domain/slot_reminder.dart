import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';

/// Number of app days, from the current one, whose reminders are planned
/// ahead: Android shows them even if the app is not opened in between.
const slotReminderDays = 14;

/// Reminder to add entries in a part of an app day, shown at the time of
/// the part (see [slotReminderHour]) only if nothing was added in it, in
/// case the user forgot.
@immutable
class SlotReminder {
  const SlotReminder(this.dayKey, this.slot);

  /// App day of the reminder, see `dayKeyOf`.
  final int dayKey;
  final DaySlot slot;

  /// Moment the reminder shows, near the end of its part of the day.
  DateTime get time {
    final date = dateOfDayKey(dayKey);
    return DateTime(date.year, date.month, date.day, slotReminderHour(slot));
  }

  /// Id of its notification: negative, apart from those of the routines of
  /// the products, which are their positive ids.
  int get id => -(dayKey * DaySlot.values.length + slot.index);

  @override
  bool operator ==(Object other) =>
      other is SlotReminder && other.dayKey == dayKey && other.slot == slot;

  @override
  int get hashCode => Object.hash(dayKey, slot);

  @override
  String toString() => 'SlotReminder($dayKey, ${slot.name})';
}

/// Hour the reminder of [slot] shows.
int slotReminderHour(DaySlot slot) => switch (slot) {
  DaySlot.morning => 11,
  DaySlot.afternoon => 16,
  DaySlot.evening => 22,
};

/// Whether [id] is the id of the notification of a [SlotReminder].
bool isSlotReminderId(int id) => id < 0;

/// A product added on its own every day at [minutes], see
/// [DailyRoutine.autoAdd], whose additions were made up to [checkedAt].
typedef AutoAddRoutine = ({int minutes, DateTime? checkedAt});

/// The app days whose reminders are looked after at [now], oldest first:
/// the previous one, whose reminders may still show, then the
/// [slotReminderDays] from the current one, planned ahead.
List<int> slotReminderDayKeys(DateTime now) {
  final today = dateOfDayKey(dayKeyOf(now));
  return [
    for (var day = -1; day < slotReminderDays; day++)
      dayKeyOfDate(DateTime(today.year, today.month, today.day + day)),
  ];
}

/// The reminders of the app days of [slotReminderDayKeys]: those to plan
/// ([planned]), after [now], and those that may show but must not
/// ([outdated]), to remove: their part of the day is no longer empty, or
/// the reminders are turned off ([enabled]).
///
/// A part of the day is empty without entries in [filledSlots] (as
/// `(dayKey, slot)`) and without a product of [autoAdds] adding itself in it
/// by the time of the reminder.
({List<SlotReminder> planned, List<SlotReminder> outdated}) planSlotReminders({
  required DateTime now,
  required bool enabled,
  required Set<(int, DaySlot)> filledSlots,
  required List<AutoAddRoutine> autoAdds,
}) {
  final planned = <SlotReminder>[];
  final outdated = <SlotReminder>[];
  for (final dayKey in slotReminderDayKeys(now)) {
    for (final slot in DaySlot.values) {
      final reminder = SlotReminder(dayKey, slot);
      final remind =
          enabled &&
          !filledSlots.contains((dayKey, slot)) &&
          !autoAdds.any((routine) => _addsBefore(routine, reminder, now));
      if (reminder.time.isAfter(now)) {
        if (remind) planned.add(reminder);
      } else if (!remind) {
        outdated.add(reminder);
      }
    }
  }
  return (planned: planned, outdated: outdated);
}

/// Whether [routine] adds its product in the part of the day of [reminder]
/// by its time, and has not done it yet: once made, the entry counts.
bool _addsBefore(AutoAddRoutine routine, SlotReminder reminder, DateTime now) {
  final time = routineTimeOn(dateOfDayKey(reminder.dayKey), routine.minutes);
  return dayKeyOf(time) == reminder.dayKey &&
      DaySlot.of(time) == reminder.slot &&
      !time.isAfter(reminder.time) &&
      time.isAfter(routine.checkedAt ?? now);
}
