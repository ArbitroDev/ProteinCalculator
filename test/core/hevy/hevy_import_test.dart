import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/hevy/hevy_csv.dart';
import 'package:protein_calculator/core/hevy/hevy_import.dart';

import '../database/test_database.dart';

/// A small Hevy export with one set of each of [workouts], given by title,
/// start and end.
String _export(List<(String, String, String)> workouts) => [
  'title,start_time,end_time,exercise_title,set_index,weight_kg,reps',
  for (final (title, start, end) in workouts)
    '"$title","$start","$end","Squat (Barbell)",0,80,5',
].join('\n');

void main() {
  late AppDatabase db;
  final importedAt = DateTime(2026, 10, 26, 9);

  setUp(() => db = openTestDatabase());
  tearDown(() => appDayStartHour = defaultAppDayStartHour);

  Future<void> importFile(String content) async => applyHevyImport(
    db,
    await prepareHevyImport(db, content),
    now: importedAt,
  );

  Future<List<String>> titles() async => [
    for (final session in await db.select(db.hevySessions).get()) session.title,
  ];

  test('a workout at 1 a.m. counts for the day before', () async {
    appDayStartHour = 3;
    await importFile(
      _export([
        ('Late', '24 oct. 2026, 01:00', '24 oct. 2026, 01:45'),
        ('Morning', '24 oct. 2026, 09:00', '24 oct. 2026, 10:00'),
      ]),
    );

    final sessions = await db.select(db.hevySessions).get();
    expect(sessions.map((session) => session.dayKey), [20261023, 20261024]);
    expect(sessions.first.startedAt, DateTime(2026, 10, 24, 1));
    expect(sessions.first.endedAt, DateTime(2026, 10, 24, 1, 45));
  });

  test('an import replaces all workouts', () async {
    await importFile(
      _export([
        ('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00'),
        ('Pull', '22 oct. 2026, 18:00', '22 oct. 2026, 19:00'),
      ]),
    );
    await importFile(
      _export([('Legs', '25 oct. 2026, 18:00', '25 oct. 2026, 19:00')]),
    );

    expect(await titles(), ['Legs']);
    expect(
      (await db.select(db.appSettings).getSingle()).hevyImportedAt,
      importedAt,
    );
  });

  test('a failed import keeps the previous workouts', () async {
    await importFile(
      _export([('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00')]),
    );

    await expectLater(
      prepareHevyImport(db, 'name,grams\nSkyr,15\n'),
      throwsA(isA<HevyFileException>()),
    );
    await expectLater(
      prepareHevyImport(
        db,
        _export([('Legs', 'last Sunday', '25 oct. 2026, 19:00')]),
      ),
      throwsA(
        isA<HevyFileException>().having(
          (e) => e.error,
          'error',
          HevyFileError.dates,
        ),
      ),
    );

    expect(await titles(), ['Push']);
    expect(
      (await db.select(db.appSettings).getSingle()).hevyImportedAt,
      importedAt,
    );
  });

  group('isOlder', () {
    test('is false at the first import', () async {
      final hevyImport = await prepareHevyImport(
        db,
        _export([('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00')]),
      );

      expect(hevyImport.currentLastStart, equals(null));
      expect(hevyImport.isOlder, isFalse);
    });

    test('when the file ends before the last import', () async {
      await importFile(
        _export([
          ('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00'),
          ('Pull', '25 oct. 2026, 18:00', '25 oct. 2026, 19:00'),
        ]),
      );

      final older = await prepareHevyImport(
        db,
        _export([('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00')]),
      );
      expect(older.fileLastStart, DateTime(2026, 10, 20, 18));
      expect(older.currentLastStart, DateTime(2026, 10, 25, 18));
      expect(older.isOlder, isTrue);

      final same = await prepareHevyImport(
        db,
        _export([('Pull', '25 oct. 2026, 18:00', '25 oct. 2026, 19:00')]),
      );
      expect(same.isOlder, isFalse);

      final newer = await prepareHevyImport(
        db,
        _export([('Legs', '26 oct. 2026, 08:00', '26 oct. 2026, 09:00')]),
      );
      expect(newer.isOlder, isFalse);
    });

    test('a file without any workout once workouts are imported', () async {
      final empty = _export([]);
      expect((await prepareHevyImport(db, empty)).isOlder, isFalse);

      await importFile(
        _export([('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00')]),
      );

      final hevyImport = await prepareHevyImport(db, empty);
      expect(hevyImport.fileLastStart, equals(null));
      expect(hevyImport.isOlder, isTrue);
    });
  });

  test('shownSessionCount counts from the first app day', () async {
    final hevyImport = await prepareHevyImport(
      db,
      _export([
        ('Before', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00'),
        ('First day', '22 oct. 2026, 18:00', '22 oct. 2026, 19:00'),
        ('Today', '24 oct. 2026, 18:00', '24 oct. 2026, 19:00'),
        ('Tomorrow', '25 oct. 2026, 18:00', '25 oct. 2026, 19:00'),
      ]),
    );

    expect(
      shownSessionCount(hevyImport, firstDayKey: 20261022, todayKey: 20261024),
      2,
    );
    expect(
      shownSessionCount(hevyImport, firstDayKey: null, todayKey: 20261024),
      0,
    );
  });
}
