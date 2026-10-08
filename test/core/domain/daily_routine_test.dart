import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';

void main() {
  const eight = 8 * 60;

  test('isValidRoutineMinutes accepts the minutes of a day', () {
    expect(isValidRoutineMinutes(0), isTrue);
    expect(isValidRoutineMinutes(minutesPerDay - 1), isTrue);
    expect(isValidRoutineMinutes(minutesPerDay), isFalse);
    expect(isValidRoutineMinutes(-1), isFalse);
  });

  group('latestRoutineTime', () {
    test('is today once the time has passed', () {
      expect(
        latestRoutineTime(eight, DateTime(2026, 10, 8, 9)),
        DateTime(2026, 10, 8, 8),
      );
      expect(
        latestRoutineTime(eight, DateTime(2026, 10, 8, 8)),
        DateTime(2026, 10, 8, 8),
      );
    });

    test('is yesterday before the time', () {
      expect(
        latestRoutineTime(eight, DateTime(2026, 10, 8, 7, 59)),
        DateTime(2026, 10, 7, 8),
      );
    });
  });

  group('routineTimesBetween', () {
    test('lists the times after the start, up to the end included', () {
      expect(
        routineTimesBetween(
          eight,
          DateTime(2026, 10, 6, 9),
          DateTime(2026, 10, 8, 8),
        ),
        [DateTime(2026, 10, 7, 8), DateTime(2026, 10, 8, 8)],
      );
    });

    test('leaves out a time equal to the start', () {
      expect(
        routineTimesBetween(
          eight,
          DateTime(2026, 10, 8, 8),
          DateTime(2026, 10, 8, 12),
        ),
        isEmpty,
      );
    });

    test('is empty when the end comes before the start', () {
      expect(
        routineTimesBetween(
          eight,
          DateTime(2026, 10, 8, 12),
          DateTime(2026, 10, 8, 9),
        ),
        isEmpty,
      );
    });
  });
}
