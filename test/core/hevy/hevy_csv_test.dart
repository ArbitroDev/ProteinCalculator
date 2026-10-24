import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/hevy/hevy_csv.dart';

/// Header of a Hevy export in kilograms.
const _header =
    'title,start_time,end_time,description,exercise_title,superset_id,'
    'exercise_notes,set_index,set_type,weight_kg,reps,distance_km,'
    'duration_seconds,rpe';

/// Header of a Hevy export in pounds.
const _headerInPounds =
    'title,start_time,end_time,description,exercise_title,superset_id,'
    'exercise_notes,set_index,set_type,weight_lbs,reps,distance_miles,'
    'duration_seconds,rpe';

/// One set of a workout, as a row of an export.
String _set(String title, String start, String end, {int index = 0}) =>
    '"$title","$start","$end","","Bench Press (Barbell)","","",$index,'
    '"normal",60,10,"","",""';

/// A small export in French: two sets of "Push" then one of "Pull, legs".
final _frenchExport = [
  _header,
  _set('Push', '23 oct. 2026, 11:48', '23 oct. 2026, 12:12'),
  _set('Push', '23 oct. 2026, 11:48', '23 oct. 2026, 12:12', index: 1),
  _set('Pull, legs', '25 oct. 2026, 18:00', '25 oct. 2026, 19:05'),
].join('\n');

void _expectTheTwoWorkouts(List<HevyWorkout> workouts) {
  expect(workouts.map((workout) => workout.title), ['Push', 'Pull, legs']);
  expect(workouts.map((workout) => workout.start), [
    DateTime(2026, 10, 23, 11, 48),
    DateTime(2026, 10, 25, 18),
  ]);
  expect(workouts.first.duration, const Duration(minutes: 24));
  expect(workouts.last.duration, const Duration(minutes: 65));
}

Future<HevyFileError?> _errorOf(String content) async {
  try {
    await parseHevyCsv(content);
    return null;
  } on HevyFileException catch (e) {
    return e.error;
  }
}

void main() {
  test('reads a French export', () async {
    _expectTheTwoWorkouts(await parseHevyCsv(_frenchExport));
  });

  test('reads an English export in pounds with CRLF and a BOM', () async {
    final export = [
      _headerInPounds,
      _set('Push', '23 Oct 2026, 11:48', '23 Oct 2026, 12:12'),
      _set('Push', '23 Oct 2026, 11:48', '23 Oct 2026, 12:12', index: 1),
      _set('Pull, legs', '25 Oct 2026, 18:00', '25 Oct 2026, 19:05'),
    ].join('\r\n');

    _expectTheTwoWorkouts(await parseHevyCsv('\uFEFF$export\r\n'));
  });

  test('splits two workouts with the same title', () async {
    final workouts = await parseHevyCsv(
      [
        _header,
        _set('Push', '23 oct. 2026, 11:48', '23 oct. 2026, 12:12'),
        _set('Push', '23 oct. 2026, 18:00', '23 oct. 2026, 18:30'),
      ].join('\n'),
    );

    expect(workouts, hasLength(2));
    expect(workouts.map((workout) => workout.start), [
      DateTime(2026, 10, 23, 11, 48),
      DateTime(2026, 10, 23, 18),
    ]);
  });

  test('reads a header-only export as no workouts', () async {
    expect(await parseHevyCsv(_header), isEmpty);
    expect(await parseHevyCsv('$_header\n'), isEmpty);
  });

  test('reads tab-separated exports', () async {
    final export = [
      'title\tstart_time\tend_time\texercise_title',
      'Push\t23 oct. 2026, 11:48\t23 oct. 2026, 12:12\tBench Press',
      'Pull, legs\t25 oct. 2026, 18:00\t25 oct. 2026, 19:05\tRow',
    ].join('\n');

    _expectTheTwoWorkouts(await parseHevyCsv(export));
  });

  test('an empty end has no duration', () async {
    final workouts = await parseHevyCsv(
      [
        _header,
        _set('Push', '23 oct. 2026, 11:48', ''),
        _set('Pull', '25 oct. 2026, 18:00', '25 oct. 2026, 17:00'),
      ].join('\n'),
    );

    expect(workouts.map((workout) => workout.start), [
      DateTime(2026, 10, 23, 11, 48),
      DateTime(2026, 10, 25, 18),
    ]);
    expect(workouts.first.end, equals(null));
    expect(workouts.first.duration, equals(null));
    // An end before the start gives no duration either.
    expect(workouts.last.duration, equals(null));
  });

  test('reads a time skipped when the clocks go forward', () async {
    // 2:30 on the night of summer time does not exist in Europe: in that time
    // zone, the date moves on by an hour, and anywhere else it stays.
    final workouts = await parseHevyCsv(
      [
        _header,
        _set('Push', '29 mars 2026, 02:30', '29 mars 2026, 03:30'),
      ].join('\n'),
    );

    expect(workouts.single.start, DateTime(2026, 3, 29, 2, 30));
  });

  test('rejects a file without the Hevy columns', () async {
    expect(
      await _errorOf('{"format":"protein_calculator","version":9}'),
      HevyFileError.notHevy,
    );
    expect(
      await _errorOf('name,grams\nSkyr,15\nWhey,24\n'),
      HevyFileError.notHevy,
    );
    expect(
      await _errorOf('title,start_time\nPush,23 oct. 2026, 11:48\n'),
      HevyFileError.notHevy,
    );
  });

  test('rejects an empty file', () async {
    expect(await _errorOf(''), HevyFileError.unreadable);
    expect(await _errorOf(' \n '), HevyFileError.unreadable);
    expect(await _errorOf('\uFEFF'), HevyFileError.unreadable);
  });

  test('rejects unreadable dates', () async {
    expect(
      await _errorOf(
        [
          _header,
          _set('Push', '23 oct. 2026, 11:48', '23 oct. 2026, 12:12'),
          _set('Pull', 'yesterday evening', '25 oct. 2026, 19:05'),
        ].join('\n'),
      ),
      HevyFileError.dates,
    );
    expect(
      await _errorOf([_header, _set('Push', '', '')].join('\n')),
      HevyFileError.dates,
    );
  });
}
