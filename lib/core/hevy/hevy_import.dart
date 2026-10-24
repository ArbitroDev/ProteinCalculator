import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/hevy/hevy_csv.dart';

/// A Hevy export, read and ready to replace the workouts. The import is made
/// in two steps so that the user can be asked first when the file looks older
/// than the last import.
class HevyImport {
  const HevyImport({
    required this.sessions,
    required this.fileLastStart,
    required this.currentLastStart,
  });

  /// The workouts of the file, with the app day each one starts in.
  final List<HevySessionsCompanion> sessions;

  /// When the latest workout of the file starts; null for a file without any.
  final DateTime? fileLastStart;

  /// When the latest workout already imported starts; null without any.
  final DateTime? currentLastStart;

  /// Whether the file stops before the latest workout already imported. A
  /// file without any workout is older when workouts are already imported,
  /// so that it never removes them without asking.
  bool get isOlder {
    final current = currentLastStart;
    if (current == null) return false;
    final file = fileLastStart;
    return file == null || file.isBefore(current);
  }
}

/// Reads [content], a Hevy export, without changing the database. Throws
/// [HevyFileException] if the file is not a usable export.
Future<HevyImport> prepareHevyImport(AppDatabase db, String content) async {
  final workouts = await parseHevyCsv(content);
  return HevyImport(
    sessions: [
      for (final workout in workouts)
        HevySessionsCompanion.insert(
          title: workout.title,
          startedAt: workout.start,
          endedAt: Value(workout.end),
          dayKey: dayKeyOf(workout.start),
        ),
    ],
    fileLastStart: workouts.map((workout) => workout.start).maxOrNull,
    currentLastStart: await db.hevyDao.getLastSessionStart(),
  );
}

/// Replaces all the workouts with those of [hevyImport], imported at [now].
Future<void> applyHevyImport(
  AppDatabase db,
  HevyImport hevyImport, {
  required DateTime now,
}) => db.hevyDao.replaceSessions(hevyImport.sessions, importedAt: now);

/// How many workouts of [hevyImport] the history shows: those from
/// [firstDayKey], the first app day, to [todayKey]. None while the first day
/// is not known.
int shownSessionCount(
  HevyImport hevyImport, {
  required int? firstDayKey,
  required int todayKey,
}) {
  if (firstDayKey == null) return 0;
  return hevyImport.sessions.where((session) {
    final dayKey = session.dayKey.value;
    return dayKey >= firstDayKey && dayKey <= todayKey;
  }).length;
}
