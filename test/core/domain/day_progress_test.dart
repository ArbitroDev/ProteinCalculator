import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';

void main() {
  group('DayProgress.of', () {
    test('is none without protein', () {
      expect(DayProgress.of(0, 120), DayProgress.none);
    });

    test('is low under half of the goal', () {
      expect(DayProgress.of(1, 120), DayProgress.low);
      expect(DayProgress.of(59.9, 120), DayProgress.low);
    });

    test('is half from half of the goal, until it is reached', () {
      expect(DayProgress.of(60, 120), DayProgress.half);
      expect(DayProgress.of(119.9, 120), DayProgress.half);
    });

    test('is reached at the goal and above', () {
      expect(DayProgress.of(120, 120), DayProgress.reached);
      expect(DayProgress.of(200, 120), DayProgress.reached);
    });
  });

  group('goalOn', () {
    const goals = [
      (dayKey: 20260901, grams: 100.0),
      (dayKey: 20260915, grams: 140.0),
    ];

    test('is the latest goal set on the day or before', () {
      expect(goalOn(20260901, goals), 100);
      expect(goalOn(20260914, goals), 100);
      expect(goalOn(20260915, goals), 140);
      expect(goalOn(20261001, goals), 140);
    });

    test('takes the first goal for the days before it', () {
      expect(goalOn(20260801, goals), 100);
    });

    test('is null without any goal', () {
      expect(goalOn(20260901, const []), isNull);
    });
  });
}
