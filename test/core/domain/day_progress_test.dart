import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';

void main() {
  group('DayProgress.of', () {
    test('is none without protein', () {
      expect(DayProgress.of(0, 120), DayProgress.none);
    });

    test('is low under half of the goal', () {
      expect(DayProgress.of(1, 120), DayProgress.low);
      expect(DayProgress.of(59.4, 120), DayProgress.low);
    });

    test('is half from half of the goal as shown, until it is reached', () {
      expect(DayProgress.of(59.5, 120), DayProgress.half);
      expect(DayProgress.of(119.4, 120), DayProgress.half);
    });

    test('is reached once the total as shown reaches the goal', () {
      expect(DayProgress.of(119.5, 120), DayProgress.reached);
      expect(DayProgress.of(120, 120), DayProgress.reached);
      expect(DayProgress.of(200, 120), DayProgress.reached);
    });
  });

  group('isGoalReached', () {
    test('rounds the total to the gram, a half up', () {
      expect(isGoalReached(139.4, 140), isFalse);
      expect(isGoalReached(139.5, 140), isTrue);
      expect(isGoalReached(139.6, 140), isTrue);
    });

    test('is not fooled by floating point sums', () {
      // 49.99999999999999 summed in this order.
      expect(isGoalReached(0.8 + 37.8 + 11.4, 50), isTrue);
      expect(isGoalReached(140 - 0.5 - 1e-12, 140), isTrue);
    });
  });

  test('what is left, beyond, and the percent follow the shown values', () {
    expect(gramsLeft(139.4, 140), 1);
    expect(gramsLeft(139.6, 140), 0);
    expect(gramsLeft(150, 140), 0);
    expect(gramsOver(150.4, 140), 10);
    expect(gramsOver(139, 140), 0);
    expect(goalPercent(139.4, 140), 99);
    expect(goalPercent(139.6, 140), 100);
    // 995 of 1000 is 99.5 %: shown 99 % until the goal is reached.
    expect(goalPercent(995, 1000), 99);
    expect(goalPercent(10, 0), 0);
  });

  group('goalOfDay', () {
    test('falls back on the current goal without goals kept', () {
      expect(goalOfDay(20260901, const [], 120), 120);
      expect(goalOfDay(20260901, const [], null), isNull);
      expect(
        goalOfDay(20260901, const [(dayKey: 20260801, grams: 100.0)], 120),
        100,
      );
    });

    test('reachedDayKeys judges each day against its goal', () {
      expect(
        reachedDayKeys(
          {20260901: 99.6, 20260902: 99.4, 20260915: 120},
          const [
            (dayKey: 20260901, grams: 100.0),
            (dayKey: 20260915, grams: 140.0),
          ],
          140,
        ),
        {20260901},
      );
      expect(reachedDayKeys({20260901: 99.6}, const [], null), isEmpty);
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
