import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/backup.dart';
import 'package:protein_calculator/core/crash_reporting.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/database_file.dart';
import 'package:protein_calculator/core/notifications.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/features/startup/startup_error_app.dart';

/// Opens the data, then runs the app. Completes with whether it started.
///
/// If the data cannot be read, because the file is damaged or a migration
/// failed, runs the startup error screen instead, from which the user can
/// try again or start over from a backup.
Future<bool> startApp({
  AppDatabase Function() openDatabase = AppDatabase.open,
}) async {
  final database = openDatabase();
  final double? goal;
  final bool crashReports;
  try {
    // The database opens, and migrates, on its first query. Reading the goal
    // before the first frame also avoids flashing the today screen before
    // the first launch screen.
    goal = await database.settingsDao.getDailyGoal();
    crashReports = await database.settingsDao.getCrashReports();
  } on Object catch (error, stack) {
    // The choice about crash reports is stored with the unreadable data: the
    // error is only reported on the device.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'database',
        context: ErrorDescription('while opening the data at launch'),
      ),
    );
    await _closeQuietly(database);
    runApp(
      StartupErrorApp(
        onRetry: () => startApp(openDatabase: openDatabase),
        onRestore: (backup) => _restoreAndStart(backup, openDatabase),
      ),
    );
    return false;
  }

  // Until the first launch screen is done, the user has not seen the
  // choice: nothing is sent.
  if (goal != null) await setCrashReporting(crashReports);

  // The products added automatically while the app was closed.
  await _reportFailure(
    'daily routines',
    () => database.entriesDao.addRoutineEntries(DateTime.now()),
  );
  var notifications = const RoutineNotifications.none();
  await _reportFailure('notifications', () async {
    notifications = await openRoutineNotifications();
  });

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        routineNotificationsProvider.overrideWithValue(notifications),
        initialLocationProvider.overrideWithValue(
          goal == null ? AppRoutes.onboarding : AppRoutes.today,
        ),
      ],
      child: const ProteinCalculatorApp(),
    ),
  );
  return true;
}

/// Sets the unreadable data aside, restores [backup] in a new database, then
/// starts the app.
Future<bool> _restoreAndStart(
  Backup backup,
  AppDatabase Function() openDatabase,
) async {
  await setAsideDatabase(DateTime.now());
  final database = openDatabase();
  try {
    await restoreBackup(database, backup);
  } finally {
    await database.close();
  }
  return startApp(openDatabase: openDatabase);
}

/// Runs [action], only reporting a failure: the app starts without it.
Future<void> _reportFailure(
  String library,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: library),
    );
  }
}

Future<void> _closeQuietly(AppDatabase database) async {
  try {
    await database.close();
  } on Object {
    // It could not even open: there is nothing to close.
  }
}
