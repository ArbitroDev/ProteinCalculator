import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/database/tables.dart';

part 'hevy_dao.g.dart';

/// Workouts imported from a Hevy export, and when they were imported.
@DriftAccessor(tables: [HevySessions, AppSettings])
class HevyDao extends DatabaseAccessor<AppDatabase> with _$HevyDaoMixin {
  HevyDao(super.attachedDatabase);

  Future<void> _writeImportedAt(DateTime? importedAt) =>
      (update(appSettings)..where((s) => s.id.equals(SettingsDao.rowId))).write(
        AppSettingsCompanion(hevyImportedAt: Value(importedAt)),
      );

  /// When the workouts were last imported; null while there are none.
  Stream<DateTime?> watchImportedAt() =>
      (select(appSettings)..where((s) => s.id.equals(SettingsDao.rowId)))
          .watchSingle()
          .map((settings) => settings.hevyImportedAt);

  /// App days having at least one workout, whatever the day.
  Stream<Set<int>> watchSessionDays() {
    final query = selectOnly(hevySessions, distinct: true)
      ..addColumns([hevySessions.dayKey]);
    return query.watch().map(
      (rows) => {for (final row in rows) row.read(hevySessions.dayKey)!},
    );
  }

  /// Workouts of one app day, in the order they started.
  Stream<List<HevySession>> watchDaySessions(int dayKey) =>
      (select(hevySessions)
            ..where((s) => s.dayKey.equals(dayKey))
            ..orderBy([
              (s) => OrderingTerm.asc(s.startedAt),
              (s) => OrderingTerm.asc(s.id),
            ]))
          .watch();

  /// When the latest workout started; null without workouts.
  Future<DateTime?> getLastSessionStart() async {
    final last =
        await (select(hevySessions)
              ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    return last?.startedAt;
  }

  /// Replaces all the workouts with [sessions] and records the import at
  /// [importedAt]. All or nothing: on an error, the workouts stay as they were.
  Future<void> replaceSessions(
    List<HevySessionsCompanion> sessions, {
    required DateTime importedAt,
  }) => transaction(() async {
    await delete(hevySessions).go();
    await batch((b) => b.insertAll(hevySessions, sessions));
    await _writeImportedAt(importedAt);
  });

  /// Deletes all the workouts and forgets the import.
  Future<void> clear() => transaction(() async {
    await delete(hevySessions).go();
    await _writeImportedAt(null);
  });
}
