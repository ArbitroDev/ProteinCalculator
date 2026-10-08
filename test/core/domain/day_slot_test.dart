import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';

void main() {
  DaySlot slotAt(int hour, [int minute = 0]) =>
      DaySlot.of(DateTime(2026, 9, 30, hour, minute));

  tearDown(() => appDayStartHour = defaultAppDayStartHour);

  test('morning runs from 3 a.m. to 11:30 a.m.', () {
    expect(slotAt(3), DaySlot.morning);
    expect(slotAt(11, 29), DaySlot.morning);
  });

  test('afternoon runs from 11:30 a.m. to 6 p.m.', () {
    expect(slotAt(11, 30), DaySlot.afternoon);
    expect(slotAt(17, 59), DaySlot.afternoon);
  });

  test('evening runs from 6 p.m. to 3 a.m.', () {
    expect(slotAt(18), DaySlot.evening);
    expect(slotAt(23, 59), DaySlot.evening);
    expect(slotAt(0), DaySlot.evening);
    expect(slotAt(2, 59), DaySlot.evening);
  });

  test('morning and evening follow the start hour chosen', () {
    appDayStartHour = 6;
    expect(slotAt(5, 59), DaySlot.evening);
    expect(slotAt(6), DaySlot.morning);

    appDayStartHour = 0;
    expect(slotAt(0), DaySlot.morning);
    expect(slotAt(23, 59), DaySlot.evening);
  });
}
