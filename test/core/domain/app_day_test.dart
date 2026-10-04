import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/app_day.dart';

void main() {
  group('dayKeyOf', () {
    test('belongs to the same calendar day from 3 a.m.', () {
      expect(dayKeyOf(DateTime(2026, 9, 30, 3)), 20260930);
      expect(dayKeyOf(DateTime(2026, 9, 30, 23, 59)), 20260930);
    });

    test('belongs to the previous calendar day before 3 a.m.', () {
      expect(dayKeyOf(DateTime(2026, 10, 1)), 20260930);
      expect(dayKeyOf(DateTime(2026, 10, 1, 1, 10)), 20260930);
      expect(dayKeyOf(DateTime(2026, 10, 1, 2, 59, 59)), 20260930);
    });

    test('handles month and year boundaries', () {
      expect(dayKeyOf(DateTime(2027, 1, 1, 2)), 20261231);
      expect(dayKeyOf(DateTime(2028, 3, 1, 1)), 20280229);
      expect(dayKeyOf(DateTime(2027, 3, 1, 1)), 20270228);
    });

    test('is not shifted by daylight saving changes', () {
      // Last Sunday of March and October: clocks change in Europe.
      expect(dayKeyOf(DateTime(2026, 3, 29, 3, 30)), 20260329);
      expect(dayKeyOf(DateTime(2026, 10, 25, 2, 30)), 20261024);
      expect(dayKeyOf(DateTime(2026, 10, 25, 3, 30)), 20261025);
    });
  });

  test('dateOfDayKey returns the calendar date of a day key', () {
    expect(dateOfDayKey(20260930), DateTime(2026, 9, 30));
    expect(dateOfDayKey(20261231), DateTime(2026, 12, 31));
  });

  test('isValidDayKey accepts real calendar dates only', () {
    expect(isValidDayKey(20260930), isTrue);
    expect(isValidDayKey(20280229), isTrue);
    expect(isValidDayKey(20260931), isFalse);
    expect(isValidDayKey(20270229), isFalse);
    expect(isValidDayKey(20261300), isFalse);
    expect(isValidDayKey(0), isFalse);
    expect(isValidDayKey(-20260930), isFalse);
    expect(isValidDayKey(999999999), isFalse);
  });

  group('nextDayStart', () {
    test('is 3 a.m. the next calendar day during the day', () {
      expect(nextDayStart(DateTime(2026, 9, 30, 14)), DateTime(2026, 10, 1, 3));
    });

    test('is 3 a.m. the same calendar day after midnight', () {
      expect(nextDayStart(DateTime(2026, 10, 1, 1)), DateTime(2026, 10, 1, 3));
    });

    test('handles the end of the year', () {
      expect(nextDayStart(DateTime(2026, 12, 31, 22)), DateTime(2027, 1, 1, 3));
    });
  });
}
