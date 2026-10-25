import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/stats/period_stats.dart';
import 'package:protein_calculator/core/stats/stats_period.dart';

/// Saturday 10 October 2026, the app used since the 1st.
const _today = 20261010;

/// Protein of the days of October 2026: the 4th has no entry.
const _october = {
  1: 100.0,
  2: 120.0,
  3: 50.0,
  5: 100.0,
  6: 110.0,
  7: 100.0,
  8: 100.0,
  9: 100.0,
  10: 30.0,
};

DaySummary _day(
  int dayKey,
  double grams, {
  int doses = 0,
  DaySlot slot = DaySlot.morning,
}) => DaySummary(
  dayKey: dayKey,
  bySlot: grams > 0 ? {slot: grams} : const {},
  creatineDoses: doses,
);

Entry _entry(DateTime at, double grams, {String? name, int doses = 0}) => Entry(
  id: 0,
  name: name,
  nameKey: name?.toLowerCase(),
  mode: EntryMode.direct,
  proteinGrams: grams,
  createdAt: at,
  dayKey: dayKeyOf(at),
  slot: DaySlot.of(at),
  fromWatch: false,
  unit: QuantityUnit.grams,
  creatineDoses: doses,
);

HevySession _session(DateTime start, {int? minutes}) => HevySession(
  id: 0,
  title: 'Push',
  startedAt: start,
  endedAt: minutes == null ? null : start.add(Duration(minutes: minutes)),
  dayKey: dayKeyOf(start),
);

StatsInput _input({
  Map<int, DaySummary>? days,
  List<({int dayKey, double grams})> goals = const [
    (dayKey: 20261001, grams: 100),
  ],
  int firstAppDayKey = 20261001,
  bool creatineTracked = false,
  bool hevyImported = false,
  Set<int> workoutDays = const {},
  List<Entry> entries = const [],
  List<HevySession> sessions = const [],
}) => StatsInput(
  days:
      days ??
      {
        for (final MapEntry(key: day, value: grams) in _october.entries)
          20261000 + day: _day(20261000 + day, grams),
      },
  goals: goals,
  currentGoal: goals.last.grams,
  firstAppDayKey: firstAppDayKey,
  todayKey: _today,
  firstWeekday: 1,
  creatineTracked: creatineTracked,
  hevyImported: hevyImported,
  workoutDays: workoutDays,
  entries: entries,
  sessions: sessions,
);

StatsPeriod _period(StatsSpan span) =>
    StatsPeriod.containing(span, DateTime(2026, 10, 10), firstWeekday: 1);

final _month = _period(StatsSpan.month);

void main() {
  group('protein', () {
    test('averages the counted days, those without entries for 0 g', () {
      final stats = computeStats(_month, _input());

      expect(stats.countedDays, 10);
      expect(stats.hasEntries, isTrue);
      expect(stats.protein.averageGrams, 81);
      expect(stats.protein.averageGoal, 100);
      expect(stats.protein.goalDays, 7);
      expect(stats.protein.deltaGrams, isNull);
    });

    test('today does not break the current streak', () {
      final stats = computeStats(_month, _input());

      expect(stats.protein.currentStreak, 5);
      expect(stats.protein.bestStreak, 5);
    });

    test('a past period has no current streak', () {
      final days = {
        20260930: _day(20260930, 100),
        20260929: _day(20260929, 100),
      };
      final stats = computeStats(
        _month.previous,
        _input(days: days, firstAppDayKey: 20260901),
      );

      expect(stats.protein.currentStreak, isNull);
      expect(stats.protein.bestStreak, 2);
    });

    test('compares each day with the goal it had', () {
      final stats = computeStats(
        _month,
        _input(
          goals: const [
            (dayKey: 20261001, grams: 100),
            (dayKey: 20261006, grams: 200),
          ],
        ),
      );

      expect(stats.protein.goalDays, 3);
      expect(stats.protein.averageGoal, 150);
    });

    test('tells the difference with the previous period', () {
      final days = _input().days;
      final stats = computeStats(
        _month,
        _input(
          days: {...days, 20260915: _day(20260915, 300)},
          firstAppDayKey: 20260901,
        ),
      );

      // 810 g over 10 days, against 300 g over the 30 days of September.
      expect(stats.protein.deltaGrams, 71);
    });

    test('draws a bar per day, none for the days not counted', () {
      final bars = computeStats(_month, _input()).protein.bars;

      expect(bars, hasLength(31));
      expect(bars[3].grams, 0);
      expect(bars[3].dayKey, 20261004);
      expect(bars[9].grams, 30);
      expect(bars[10].grams, isNull);
    });

    test('draws a bar per month for a year', () {
      final bars = computeStats(_period(StatsSpan.year), _input()).protein.bars;

      expect(bars, hasLength(12));
      expect(bars[9].grams, 81);
      expect(bars[9].dayKey, isNull);
      expect(bars[8].grams, isNull);
    });

    test('a period without entries says so', () {
      final stats = computeStats(_month, _input(days: const {}));

      expect(stats.hasEntries, isFalse);
      expect(stats.protein.averageGrams, 0);
    });
  });

  group('creatine', () {
    final days = {
      for (final MapEntry(key: day, value: grams) in _october.entries)
        20261000 + day: _day(
          20261000 + day,
          grams,
          doses: const {3, 5, 9, 10}.contains(day) ? 1 : 0,
        ),
      20261004: _day(20261004, 0, doses: 2),
    };

    test('counts the days from the first dose', () {
      final creatine = computeStats(
        _month,
        _input(days: days, creatineTracked: true),
      ).creatine!;

      expect(creatine.countedDays, 8);
      expect(creatine.takenDays, 5);
      expect(creatine.doses, 6);
      expect(creatine.currentStreak, 2);
      expect(creatine.marks[0], isNull);
      expect(creatine.marks[3], isTrue);
      expect(creatine.marks[5], isFalse);
      expect(creatine.marks[10], isNull);
      expect(creatine.monthShares, isEmpty);
    });

    test('shares by month for a year', () {
      final creatine = computeStats(
        _period(StatsSpan.year),
        _input(days: days, creatineTracked: true),
      ).creatine!;

      expect(creatine.marks, isEmpty);
      expect(creatine.monthShares[9], 5 / 8);
      expect(creatine.monthShares[8], isNull);
    });

    test('shows when doses were taken, even if no longer tracked', () {
      expect(computeStats(_month, _input(days: days)).creatine, isNotNull);
      expect(computeStats(_month, _input()).creatine, isNull);
    });
  });

  group('workouts', () {
    final sessions = [
      _session(DateTime(2026, 10, 2, 18), minutes: 60),
      _session(DateTime(2026, 10, 5, 18)),
      _session(DateTime(2026, 10, 9, 7), minutes: 90),
    ];
    final workoutDays = {20261002, 20261005, 20261009};

    test('counts the workouts and their length', () {
      final workouts = computeStats(
        _month,
        _input(
          hevyImported: true,
          workoutDays: workoutDays,
          sessions: sessions,
        ),
      ).workouts!;

      expect(workouts.sessions, 3);
      expect(workouts.days, 3);
      expect(workouts.perWeek, closeTo(2.1, 1e-9));
      expect(workouts.totalDuration, const Duration(minutes: 150));
      expect(workouts.averageDuration, const Duration(minutes: 75));
      expect(workouts.marks[1], isTrue);
      expect(workouts.marks[2], isFalse);
    });

    test('nothing without an import', () {
      expect(computeStats(_month, _input()).workouts, isNull);
    });

    group('insights', () {
      final entries = [
        _entry(DateTime(2026, 10, 2, 20), 25, name: 'Whey'),
        _entry(DateTime(2026, 10, 5, 21, 30), 10, name: 'Skyr'),
        _entry(DateTime(2026, 10, 9, 9), 15, name: 'Whey'),
        // Out of the 3 hours after the workout of the 9th.
        _entry(DateTime(2026, 10, 9, 11, 30), 40, name: 'Eggs'),
      ];

      CrossStats cross({bool hevy = true}) => computeStats(
        _month,
        _input(
          hevyImported: hevy,
          workoutDays: workoutDays,
          sessions: sessions,
          entries: entries,
        ),
      ).cross;

      test('compares the workout days with the rest days', () {
        final stats = cross();

        expect(stats.proteinByWorkout!.first, closeTo(320 / 3, 1e-9));
        expect(stats.proteinByWorkout!.second, closeTo(490 / 7, 1e-9));
        expect(stats.goalShareByWorkout!.first, 1);
        expect(stats.goalShareByWorkout!.second, closeTo(4 / 7, 1e-9));
        // The 3rd, 6th and 10th follow a workout; the 1st, 4th, 7th and 8th
        // do not.
        expect(stats.proteinAfterWorkoutDay!.first, closeTo(190 / 3, 1e-9));
        expect(stats.proteinAfterWorkoutDay!.second, 75);
      });

      test('sums the protein taken in the hours after a workout', () {
        final after = cross().postWorkout!;

        expect(after.grams, closeTo(50 / 3, 1e-9));
        expect(after.followed, 1);
        expect(after.sessions, 3);
      });

      test('no workout insight without an import', () {
        final stats = cross(hevy: false);

        expect(stats.proteinByWorkout, isNull);
        expect(stats.goalShareByWorkout, isNull);
        expect(stats.proteinAfterWorkoutDay, isNull);
        expect(stats.postWorkout, isNull);
        expect(stats.creatineByWorkout, isNull);
      });

      test('a comparison needs 3 days on each side', () {
        final stats = computeStats(
          _month,
          _input(
            hevyImported: true,
            workoutDays: {20261002, 20261005},
            sessions: sessions.take(2).toList(),
          ),
        ).cross;

        expect(stats.proteinByWorkout, isNull);
        expect(stats.postWorkout, isNull);
      });
    });
  });

  group('insights', () {
    test('averages each weekday counted on 2 days at least', () {
      final averages = computeStats(_month, _input()).cross.weekdayAverages!;

      // From Monday: only Thursday, Friday and Saturday come twice.
      expect(averages, [null, null, null, 100, 110, 40, null]);
    });

    test('no weekdays for a week', () {
      final stats = computeStats(_period(StatsSpan.week), _input());

      expect(stats.cross.weekdayAverages, isNull);
    });

    test('shares the protein between the parts of the day', () {
      final stats = computeStats(
        _month,
        _input(
          days: {
            20261001: DaySummary(
              dayKey: 20261001,
              bySlot: const {DaySlot.morning: 30, DaySlot.evening: 90},
            ),
          },
        ),
      );

      expect(stats.cross.slotShares, {
        DaySlot.morning: 0.25,
        DaySlot.afternoon: 0,
        DaySlot.evening: 0.75,
      });
    });

    test('tells the rhythm of the entries, without creatine alone', () {
      final stats = computeStats(
        _month,
        _input(
          entries: [
            _entry(DateTime(2026, 10, 1, 8), 20, name: 'Eggs'),
            _entry(DateTime(2026, 10, 1, 12), 40, name: 'Chicken'),
            _entry(DateTime(2026, 10, 2, 7), 0, doses: 1),
            _entry(DateTime(2026, 10, 2, 9, 20), 30, name: 'eggs'),
            // After midnight, still the 2nd.
            _entry(DateTime(2026, 10, 3, 1), 10, name: 'Eggs'),
          ],
        ),
      );
      final rhythm = stats.cross.rhythm!;

      expect(rhythm.entriesPerDay, 0.4);
      expect(rhythm.gramsPerEntry, 25);
      // 8:00 and 9:20, on average 8:40, to the quarter.
      expect(rhythm.firstEntryMinutes, 8 * 60 + 45);
      expect(stats.cross.topProducts, [
        (name: 'Eggs', uses: 3, grams: 60.0),
        (name: 'Chicken', uses: 1, grams: 40.0),
      ]);
    });

    test('full days need the goal and creatine', () {
      final stats = computeStats(
        _month,
        _input(
          creatineTracked: true,
          days: {
            for (final MapEntry(key: day, value: grams) in _october.entries)
              20261000 + day: _day(
                20261000 + day,
                grams,
                doses: day.isOdd ? 1 : 0,
              ),
          },
        ),
      );

      // Creatine on the 1st, 3rd, 5th, 7th and 9th; the 3rd misses its goal.
      expect(stats.cross.completeDays, (days: 4, share: 0.4));
    });
  });
}
