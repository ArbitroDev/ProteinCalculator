import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';
import 'package:protein_calculator/core/stats/streaks.dart';

void main() {
  group('StatsPeriod', () {
    test('a week starts on the first day of the week of the language', () {
      // Sunday 25 October 2026.
      final sunday = DateTime(2026, 10, 25, 20);

      final monday = StatsPeriod.containing(
        StatsSpan.week,
        sunday,
        firstWeekday: 1,
      );
      final fromSunday = StatsPeriod.containing(
        StatsSpan.week,
        sunday,
        firstWeekday: 0,
      );

      expect(monday.firstKey, 20261019);
      expect(monday.lastKey, 20261025);
      expect(fromSunday.firstKey, 20261025);
      expect(fromSunday.lastKey, 20261031);
    });

    test('a week across two years', () {
      final week = StatsPeriod.containing(
        StatsSpan.week,
        DateTime(2027, 1, 1),
        firstWeekday: 1,
      );

      expect(week.dayKeys, [
        20261228,
        20261229,
        20261230,
        20261231,
        20270101,
        20270102,
        20270103,
      ]);
      expect(week.next.firstKey, 20270104);
      expect(week.previous.firstKey, 20261221);
    });

    test('a month keeps its days over the change of time', () {
      final october = StatsPeriod.containing(
        StatsSpan.month,
        DateTime(2026, 10, 25),
        firstWeekday: 1,
      );

      expect(october.dayKeys, hasLength(31));
      expect(october.dayKeys.toSet(), hasLength(31));
      expect(october.lastKey, 20261031);
      expect(october.previous.firstKey, 20260901);
      expect(october.next.lastKey, 20261130);
      expect(october.contains(20261031), isTrue);
      expect(october.contains(20261101), isFalse);
      expect(october.middle, DateTime(2026, 10, 16));
    });

    test('a year and its months', () {
      final year = StatsPeriod.containing(
        StatsSpan.year,
        DateTime(2028, 6, 1),
        firstWeekday: 1,
      );

      expect(year.dayKeys, hasLength(366));
      expect(year.months.map((month) => month.firstKey).take(2), [
        20280101,
        20280201,
      ]);
      expect(year.months[1].dayKeys, hasLength(29));
      expect(year.previous.lastKey, 20271231);
    });

    test('counts the days from the first app day to today', () {
      final october = StatsPeriod.containing(
        StatsSpan.month,
        DateTime(2026, 10, 1),
        firstWeekday: 1,
      );

      expect(
        countedDayKeys(october, firstAppDayKey: 20261020, todayKey: 20261025),
        [20261020, 20261021, 20261022, 20261023, 20261024, 20261025],
      );
      expect(
        countedDayKeys(october, firstAppDayKey: 20261101, todayKey: 20261105),
        isEmpty,
      );
    });

    test('moves from day to day over the end of a month', () {
      expect(nextDayKey(20261031), 20261101);
      expect(previousDayKey(20260301), 20260228);
    });
  });

  group('streaks', () {
    final days = {20261020, 20261021, 20261022, 20261024, 20261025};

    test('counts the days in a row ending on a day', () {
      expect(streakEnding(days, 20261022), 3);
      expect(streakEnding(days, 20261023), 0);
    });

    test('today does not break the streak before it is over', () {
      expect(currentStreak(days, 20261025), 2);
      expect(currentStreak(days, 20261026), 2);
      expect(currentStreak(days, 20261027), 0);
    });

    test('the best streak touching some days is counted whole', () {
      expect(bestStreakTouching(days, [20261022, 20261023]), 3);
      expect(bestStreakTouching(days, [20261025]), 2);
      expect(bestStreakTouching(days, [20261023]), 0);
    });

    test('a streak runs over the end of a month', () {
      final across = {20261030, 20261031, 20261101};

      expect(streakEnding(across, 20261101), 3);
    });
  });
}
