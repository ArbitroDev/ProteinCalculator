import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';

void main() {
  DaySlot slotAt(int hour, [int minute = 0]) =>
      DaySlot.of(DateTime(2026, 9, 30, hour, minute));

  test('morning runs from 3 a.m. to noon', () {
    expect(slotAt(3), DaySlot.morning);
    expect(slotAt(11, 59), DaySlot.morning);
  });

  test('afternoon runs from noon to 6 p.m.', () {
    expect(slotAt(12), DaySlot.afternoon);
    expect(slotAt(17, 59), DaySlot.afternoon);
  });

  test('evening runs from 6 p.m. to 3 a.m.', () {
    expect(slotAt(18), DaySlot.evening);
    expect(slotAt(23, 59), DaySlot.evening);
    expect(slotAt(0), DaySlot.evening);
    expect(slotAt(2, 59), DaySlot.evening);
  });
}
