import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';

/// Thursday 1 October 2026, 9 a.m.
final defaultNow = DateTime(2026, 10, 1, 9);

/// Opens an empty in-memory database.
AppDatabase openTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// Starts the app on an in-memory [database] at a fixed time [now].
///
/// In widget tests, read the database with direct queries (`get`), not
/// streams (`watch`): streams never emit in the fake time of widget tests.
///
/// Starts on the first launch screen if the database has no daily goal.
/// [overrides] replace other providers, such as Open Food Facts.
///
/// The Christmas theme stays off, whatever the date, unless [christmas];
/// [christmasThemes], when given, are the values the setting goes through.
/// [dayKeys], when given, are the app days the app goes through, in place of
/// the day of [now].
Future<void> pumpApp(
  WidgetTester tester,
  AppDatabase database, {
  DateTime? now,
  bool christmas = false,
  Stream<bool>? christmasThemes,
  Stream<int>? dayKeys,
  List<Locale> locales = const [Locale('en', 'US')],
  List<Override> overrides = const [],
}) async {
  // A blinking cursor would keep pumpAndSettle waiting forever.
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);
  final time = now ?? defaultNow;
  final goal = await database.settingsDao.getDailyGoal();
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => time),
        currentDayKeyProvider.overrideWith(
          (ref) => dayKeys ?? Stream.value(dayKeyOf(time)),
        ),
        christmasThemeProvider.overrideWith(
          (ref) => christmasThemes ?? Stream.value(christmas),
        ),
        initialLocationProvider.overrideWithValue(
          goal == null ? AppRoutes.onboarding : AppRoutes.today,
        ),
        ...overrides,
      ],
      child: const ProteinCalculatorApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Removes the app and closes [database], so no stream or timer outlives
/// the test.
Future<void> disposeApp(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(const SizedBox());
  // Drift closes the streams of removed widgets after a short delay: let
  // the fake time of widget tests run before closing the database.
  await tester.pump(const Duration(seconds: 1));
  await database.close();
}
