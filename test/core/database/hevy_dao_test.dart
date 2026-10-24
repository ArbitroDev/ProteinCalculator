import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/hevy_dao.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late HevyDao dao;
  final importedAt = DateTime(2026, 10, 26, 9);

  setUp(() {
    db = openTestDatabase();
    dao = db.hevyDao;
  });

  HevySessionsCompanion session(String title, DateTime start, {int? minutes}) =>
      HevySessionsCompanion.insert(
        title: title,
        startedAt: start,
        endedAt: Value(
          minutes == null ? null : start.add(Duration(minutes: minutes)),
        ),
        dayKey: start.year * 10000 + start.month * 100 + start.day,
      );

  test('an import replaces all workouts', () async {
    await dao.replaceSessions([
      session('Push', DateTime(2026, 10, 20, 18), minutes: 60),
      session('Pull', DateTime(2026, 10, 22, 18), minutes: 60),
    ], importedAt: DateTime(2026, 10, 23, 9));
    await dao.replaceSessions([
      session('Legs', DateTime(2026, 10, 25, 18)),
    ], importedAt: importedAt);

    expect(await dao.watchSessionDays().first, {20261025});
    expect(await dao.watchImportedAt().first, importedAt);
    expect(await dao.getLastSessionStart(), DateTime(2026, 10, 25, 18));
  });

  test('lists the workouts of a day in the order they started', () async {
    await dao.replaceSessions([
      session('Evening', DateTime(2026, 10, 25, 18), minutes: 30),
      session('Morning', DateTime(2026, 10, 25, 8), minutes: 45),
      session('Other day', DateTime(2026, 10, 24, 8)),
    ], importedAt: importedAt);

    final sessions = await dao.watchDaySessions(20261025).first;
    expect(sessions.map((s) => s.title), ['Morning', 'Evening']);
    expect(sessions.first.endedAt, DateTime(2026, 10, 25, 8, 45));
    expect(await dao.watchSessionDays().first, {20261024, 20261025});
  });

  test('clear removes the workouts and the import date', () async {
    await dao.replaceSessions([
      session('Push', DateTime(2026, 10, 20, 18), minutes: 60),
    ], importedAt: importedAt);

    await dao.clear();

    expect(await db.select(db.hevySessions).get(), isEmpty);
    expect(await dao.watchImportedAt().first, equals(null));
    expect(await dao.getLastSessionStart(), equals(null));
  });
}
