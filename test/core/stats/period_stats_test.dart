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
  int todayKey = _today,
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
  todayKey: todayKey,
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
      // Today is not over: 780 g over the 9 days before it.
      expect(stats.protein.averageGrams, closeTo(780 / 9, 1e-9));
      expect(stats.protein.averageGoal, 100);
      expect(stats.protein.goalDays, 7);
      expect(stats.protein.deltaGrams, isNull);
    });

    test('today counts in the averages once its goal is reached', () {
      final days = _input().days;
      final stats = computeStats(
        _month,
        _input(
          days: {...days, 20261010: _day(20261010, 120)},
          hevyImported: true,
          workoutDays: {20261002, 20261005, 20261009},
        ),
      );

      expect(stats.protein.averageGrams, 90);
      // The 3rd, 6th and today follow a workout.
      expect(stats.cross.proteinAfterWorkoutDay, closeTo(280 / 3, 1e-9));
    });

    test('today alone counts all the same, without a difference', () {
      final stats = computeStats(
        _month,
        _input(
          days: {20261001: _day(20261001, 30), 20260915: _day(20260915, 300)},
          firstAppDayKey: 20260901,
          todayKey: 20261001,
        ),
      );

      expect(stats.protein.averageGrams, 30);
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
      // 5 days at 100 g and 4 at 200 g; today is not over.
      expect(stats.protein.averageGoal, closeTo(1300 / 9, 1e-9));
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

      // 780 g over the 9 days before today, against 300 g over the 30 days
      // of September.
      expect(stats.protein.deltaGrams, 77);
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
      expect(bars[9].grams, closeTo(780 / 9, 1e-9));
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

    test('today counts once a dose is taken', () {
      final creatine = computeStats(
        _month,
        _input(
          days: {...days, _today: _day(_today, 30)},
          creatineTracked: true,
        ),
      ).creatine!;

      // From the 3rd to yesterday.
      expect(creatine.countedDays, 7);
      expect(creatine.takenDays, 4);
      expect(creatine.marks[9], isNull);
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
      // Over the 9 days to yesterday: today has no workout yet.
      expect(workouts.perWeek, closeTo(3 * 7 / 9, 1e-9));
      expect(workouts.totalDuration, const Duration(minutes: 150));
      expect(workouts.averageDuration, const Duration(minutes: 75));
      expect(workouts.marks[1], isTrue);
      expect(workouts.marks[2], isFalse);
    });

    test('today counts once it has a workout', () {
      WorkoutStats workouts(Set<int> days) => computeStats(
        _month,
        _input(hevyImported: true, workoutDays: days, sessions: sessions),
      ).workouts!;

      // Not yet: today is left out of the days counted.
      expect(workouts(workoutDays).marks[9], isNull);
      expect(workouts({...workoutDays, _today}).marks[9], isTrue);
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
        // Today is not over: the rest days are the 1st, 3rd, 4th, 6th, 7th
        // and 8th.
        expect(stats.proteinByWorkout!.second, closeTo(460 / 6, 1e-9));
        expect(stats.goalShareByWorkout!.first, 1);
        expect(stats.goalShareByWorkout!.second, closeTo(4 / 6, 1e-9));
        // Only the 3rd and 6th follow a workout, today not being over.
        expect(stats.proteinAfterWorkoutDay, isNull);
      });

      test('sums the protein taken in the hours after a workout', () {
        final after = cross().postWorkout!;

        expect(after.grams, closeTo(50 / 3, 1e-9));
        expect(after.followed, 1);
        expect(after.sessions, 3);
      });

      test('protein between two workouts close together counts once', () {
        final after = computeStats(
          _month,
          _input(
            hevyImported: true,
            workoutDays: {20261002, 20261005},
            sessions: [
              _session(DateTime(2026, 10, 2, 18), minutes: 60),
              _session(DateTime(2026, 10, 5, 17), minutes: 60),
              // An hour after the one before: what follows both counts
              // after this one only.
              _session(DateTime(2026, 10, 5, 19), minutes: 60),
            ],
            entries: [
              _entry(DateTime(2026, 10, 2, 19, 30), 30),
              _entry(DateTime(2026, 10, 5, 18, 30), 10),
              _entry(DateTime(2026, 10, 5, 20, 30), 30),
            ],
          ),
        ).cross.postWorkout!;

        expect(after.grams, closeTo(70 / 3, 1e-9));
        expect(after.followed, 2);
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

      test('tells when the workouts start', () {
        final time = cross().workoutTime!;

        // 18:00, 18:00 and 7:00, on average 14:20, to the quarter.
        expect(time.startMinutes, 14 * 60 + 15);
        expect(time.counts, {
          DaySlot.morning: 1,
          DaySlot.afternoon: 0,
          DaySlot.evening: 2,
        });
        expect(time.afterGrams, isEmpty);
      });

      test('sums the protein after the workouts of each part of the day', () {
        final time = computeStats(
          _month,
          _input(
            hevyImported: true,
            workoutDays: {...workoutDays, 20261007},
            sessions: [
              ...sessions,
              _session(DateTime(2026, 10, 7, 18), minutes: 60),
            ],
            entries: [
              ...entries,
              _entry(DateTime(2026, 10, 7, 19, 30), 40, name: 'Whey'),
            ],
          ),
        ).cross.workoutTime!;

        // The evening has 3 workouts, the morning only one.
        expect(time.afterGrams.keys, [DaySlot.evening]);
        expect(time.afterGrams[DaySlot.evening], closeTo(25, 1e-9));
      });

      test('no workout time without an import', () {
        expect(cross(hevy: false).workoutTime, isNull);
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
        expect(stats.workoutTime, isNull);
      });
    });
  });

  group('insights', () {
    test('averages each weekday counted on 2 days at least', () {
      final averages = computeStats(_month, _input()).cross.weekdayAverages!;

      // From Monday: only Thursday and Friday come twice, today, a Saturday,
      // not being over.
      expect(averages, [null, null, null, 100, 110, null, null]);
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

      // 4 entries over the 9 days before today.
      expect(rhythm.entriesPerDay, closeTo(4 / 9, 1e-9));
      expect(rhythm.gramsPerEntry, 25);
      // 8:00 and 9:20, on average 8:40, to the quarter.
      expect(rhythm.firstEntryMinutes, 8 * 60 + 45);
      expect(stats.cross.topProducts, [
        (name: 'Eggs', uses: 3, grams: 60.0),
        (name: 'Chicken', uses: 1, grams: 40.0),
      ]);
    });

    test('a shortfall needs 3 missed days', () {
      // Only the 3rd misses its goal: the 4th has no entry, today is not
      // over.
      expect(computeStats(_month, _input()).cross.shortfall, isNull);
    });

    test('averages what the missed days lack, without empty days', () {
      final stats = computeStats(
        _month,
        _input(goals: const [(dayKey: 20261001, grams: 115)]),
      );

      // All the days with entries but the 2nd and today.
      expect(stats.cross.shortfall!.days, 7);
      expect(stats.cross.shortfall!.grams, closeTo(145 / 7, 1e-9));
    });

    test('tells when the goal is reached, late after 21:00', () {
      final stats = computeStats(
        _month,
        _input(
          entries: [
            _entry(DateTime(2026, 10, 1, 8), 60),
            _entry(DateTime(2026, 10, 1, 12), 50),
            _entry(DateTime(2026, 10, 2, 9), 120),
            _entry(DateTime(2026, 10, 5, 20), 40),
            _entry(DateTime(2026, 10, 5, 22), 60),
            _entry(DateTime(2026, 10, 6, 23), 50),
            // After midnight, still the 6th.
            _entry(DateTime(2026, 10, 7, 1), 60),
          ],
        ),
      );

      // 12:00, 9:00, 22:00 and 25:00, on average 17:00.
      expect(stats.cross.goalTime, (minutes: 17 * 60, late: 2, days: 4));
    });

    test('a goal reached at 21:00 sharp is not late', () {
      final stats = computeStats(
        _month,
        _input(
          days: {
            for (var day = 1; day <= 3; day++)
              20261000 + day: _day(20261000 + day, 100),
          },
          entries: [
            for (var day = 1; day <= 3; day++)
              _entry(DateTime(2026, 10, day, 21), 100),
          ],
        ),
      );

      expect(stats.cross.goalTime, (minutes: 21 * 60, late: 0, days: 3));
    });

    test('no goal time with fewer than 3 days', () {
      final stats = computeStats(
        _month,
        _input(entries: [_entry(DateTime(2026, 10, 2, 9), 120)]),
      );

      expect(stats.cross.goalTime, isNull);
    });

    test('tells how regular the days are, without today and empty days', () {
      final regularity = computeStats(_month, _input()).cross.regularity!;

      expect(regularity.deviation, closeTo(19.2, 0.01));
      expect(regularity.lowest, (dayKey: 20261003, grams: 50.0));
      expect(regularity.highest, (dayKey: 20261002, grams: 120.0));
    });

    test('the earliest of tied days is shown', () {
      final regularity = computeStats(
        _month,
        _input(
          days: {
            for (final day in [1, 2, 3])
              20261000 + day: _day(20261000 + day, 80),
          },
        ),
      ).cross.regularity!;

      expect(regularity.deviation, 0);
      expect(regularity.lowest.dayKey, 20261001);
      expect(regularity.highest.dayKey, 20261001);
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
      // Today, without creatine yet, is not over.
      expect(stats.cross.completeDays, (days: 4, share: 4 / 9));
    });
  });
}
