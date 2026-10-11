import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/slot_reminder.dart';

void main() {
  /// Thursday 1 October 2026 at [hour]:[minute].
  DateTime october1(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 1, hour, minute);

  group('SlotReminder', () {
    test('shows at the hour of its part, on the date of its day', () {
      expect(
        const SlotReminder(20261001, DaySlot.morning).time,
        DateTime(2026, 10, 1, 11),
      );
      expect(
        const SlotReminder(20261001, DaySlot.afternoon).time,
        DateTime(2026, 10, 1, 16),
      );
      expect(
        const SlotReminder(20261001, DaySlot.evening).time,
        DateTime(2026, 10, 1, 22),
      );
    });

    test('has a negative id of its own, apart from the products', () {
      final ids = {
        for (final dayKey in [20260930, 20261001, 20261002])
          for (final slot in DaySlot.values) SlotReminder(dayKey, slot).id,
      };
      expect(ids, hasLength(9));
      expect(ids.every(isSlotReminderId), isTrue);
      expect(isSlotReminderId(42), isFalse);
    });
  });

  group('slotReminderDayKeys', () {
    test('starts the day before and plans the next days ahead', () {
      final keys = slotReminderDayKeys(october1(9));
      expect(keys.first, 20260930);
      expect(keys[1], 20261001);
      expect(keys.last, 20261014);
      expect(keys, hasLength(slotReminderDays + 1));
    });

    test('follows the app day, not the calendar date', () {
      // At 1 a.m., the app day is still 30 September.
      expect(slotReminderDayKeys(october1(1)).take(2), [20260929, 20260930]);
    });

    test('crosses the end of a month', () {
      expect(slotReminderDayKeys(DateTime(2026, 10, 31, 9)).take(3), [
        20261030,
        20261031,
        20261101,
      ]);
    });
  });

  group('planSlotReminders', () {
    ({List<SlotReminder> planned, List<SlotReminder> outdated}) plan(
      DateTime now, {
      bool enabled = true,
      Set<(int, DaySlot)> filledSlots = const {},
      List<AutoAddRoutine> autoAdds = const [],
    }) => planSlotReminders(
      now: now,
      enabled: enabled,
      filledSlots: filledSlots,
      autoAdds: autoAdds,
    );

    test('plans the parts of the days to come, from now', () {
      final result = plan(october1(9));

      expect(result.planned, hasLength(3 * slotReminderDays));
      expect(
        result.planned.first,
        const SlotReminder(20261001, DaySlot.morning),
      );
      expect(result.planned.every((r) => r.time.isAfter(october1(9))), isTrue);
      expect(result.outdated, isEmpty);
    });

    test('skips the reminders whose time has passed', () {
      final result = plan(october1(12));

      expect(
        result.planned,
        isNot(contains(const SlotReminder(20261001, DaySlot.morning))),
      );
      expect(
        result.planned.first,
        const SlotReminder(20261001, DaySlot.afternoon),
      );
      // Empty, the morning keeps the reminder it may show.
      expect(result.outdated, isEmpty);
    });

    test('does not plan a part of the day that has an entry', () {
      final result = plan(
        october1(9),
        filledSlots: {(20261001, DaySlot.afternoon)},
      );

      expect(
        result.planned,
        isNot(contains(const SlotReminder(20261001, DaySlot.afternoon))),
      );
      expect(
        result.planned,
        contains(const SlotReminder(20261001, DaySlot.morning)),
      );
    });

    test('removes a reminder shown once its part of the day has an entry', () {
      final result = plan(
        october1(12),
        filledSlots: {(20261001, DaySlot.morning)},
      );

      expect(result.outdated, [const SlotReminder(20261001, DaySlot.morning)]);
    });

    test('removes the reminder of the day before once filled afterwards', () {
      // "Yesterday at 8 p.m." added the next morning.
      final result = plan(
        october1(9),
        filledSlots: {(20260930, DaySlot.evening)},
      );

      expect(result.outdated, [const SlotReminder(20260930, DaySlot.evening)]);
    });

    test('turned off, plans nothing and removes those that may show', () {
      final result = plan(october1(12), enabled: false);

      expect(result.planned, isEmpty);
      expect(result.outdated, [
        const SlotReminder(20260930, DaySlot.morning),
        const SlotReminder(20260930, DaySlot.afternoon),
        const SlotReminder(20260930, DaySlot.evening),
        const SlotReminder(20261001, DaySlot.morning),
      ]);
    });

    test('counts a product adding itself before the reminder', () {
      final result = plan(
        october1(9),
        autoAdds: [(minutes: 9 * 60 + 30, checkedAt: october1(9))],
      );

      // The product adds itself at 9:30 every morning: no morning reminder.
      expect(result.planned.where((r) => r.slot == DaySlot.morning), isEmpty);
      expect(
        result.planned,
        contains(const SlotReminder(20261001, DaySlot.afternoon)),
      );
    });

    test('ignores a product adding itself after the reminder', () {
      final result = plan(
        october1(9),
        autoAdds: [(minutes: 11 * 60 + 15, checkedAt: october1(9))],
      );

      expect(
        result.planned,
        contains(const SlotReminder(20261001, DaySlot.morning)),
      );
    });

    test('counts an addition already made only through its entry', () {
      // Added at 9:30 and removed since: the morning is empty again.
      final result = plan(
        october1(10),
        autoAdds: [(minutes: 9 * 60 + 30, checkedAt: october1(10))],
      );

      expect(
        result.planned,
        contains(const SlotReminder(20261001, DaySlot.morning)),
      );
      expect(
        result.planned,
        isNot(contains(const SlotReminder(20261002, DaySlot.morning))),
      );
    });
  });
}
