import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/hevy/hevy_import.dart';
import 'package:protein_calculator/core/hevy/hevy_import_flow.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

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
  late BuildContext context;
  final firstImport = DateTime(2026, 10, 25, 20);
  final importedAt = DateTime(2026, 10, 26, 9);

  setUp(() => db = openTestDatabase());

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (pageContext) {
            context = pageContext;
            return const SizedBox();
          },
        ),
      ),
    ),
  );

  /// Starts the import of [content]; the history shows the workouts from
  /// Oct 20 to Oct 24.
  Future<void> startImport(String content) => runHevyImport(
    context: context,
    db: db,
    messenger: ScaffoldMessenger.of(context),
    l10n: AppLocalizations.of(context),
    firstDayKey: 20261020,
    todayKey: 20261024,
    content: content,
    clock: () => importedAt,
  );

  Future<List<String>> titles() async => [
    for (final session in await db.select(db.hevySessions).get()) session.title,
  ];

  Future<DateTime?> lastImport() async =>
      (await db.select(db.appSettings).getSingle()).hevyImportedAt;

  /// Imports Push (Oct 20) and Pull (Oct 25) at [firstImport].
  Future<void> importFirst() async => applyHevyImport(
    db,
    await prepareHevyImport(
      db,
      _export([
        ('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00'),
        ('Pull', '25 oct. 2026, 18:00', '25 oct. 2026, 19:00'),
      ]),
    ),
    now: firstImport,
  );

  final olderFile = _export([
    ('Legs', '22 oct. 2026, 18:00', '22 oct. 2026, 19:00'),
  ]);

  testWidgets('imports a file and counts the workouts shown', (tester) async {
    await pumpPage(tester);

    await startImport(
      _export([
        ('Push', '20 oct. 2026, 18:00', '20 oct. 2026, 19:00'),
        ('Legs', '22 oct. 2026, 18:00', '22 oct. 2026, 19:00'),
        ('Pull', '25 oct. 2026, 18:00', '25 oct. 2026, 19:00'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('2 Hevy workouts imported'), findsOneWidget);
    expect(await titles(), ['Push', 'Legs', 'Pull']);
    expect(await lastImport(), importedAt);
  });

  group('an older file', () {
    testWidgets('is kept out when the user cancels', (tester) async {
      await importFirst();
      await pumpPage(tester);

      final done = startImport(olderFile);
      await tester.pumpAndSettle();
      expect(find.text('Older file'), findsOneWidget);
      expect(find.textContaining('This file ends on Oct 22'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await done;

      expect(find.byType(SnackBar), findsNothing);
      expect(await titles(), ['Push', 'Pull']);
      expect(await lastImport(), firstImport);
    });

    testWidgets('replaces the workouts when the user agrees', (tester) async {
      await importFirst();
      await pumpPage(tester);

      final done = startImport(olderFile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await done;

      expect(find.text('1 Hevy workout imported'), findsOneWidget);
      expect(await titles(), ['Legs']);
      expect(await lastImport(), importedAt);
    });

    testWidgets('includes a file without any workout', (tester) async {
      await importFirst();
      await pumpPage(tester);

      final done = startImport(_export([]));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Hevy workouts?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await done;
      expect(await titles(), ['Push', 'Pull']);
      expect(await lastImport(), firstImport);

      final again = startImport(_export([]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await again;

      expect(find.text('Import done, no workout to show'), findsOneWidget);
      expect(await titles(), isEmpty);
      expect(await lastImport(), importedAt);
    });
  });

  group('a refused file', () {
    for (final (name, content, message) in [
      ('empty', '', "This file can't be read."),
      (
        'not an export',
        'name,grams\nSkyr,15\n',
        'This file is not a Hevy workout export.',
      ),
      (
        'with unreadable dates',
        _export([('Legs', 'last Sunday', '25 oct. 2026, 19:00')]),
        "The dates in this file can't be read.",
      ),
    ]) {
      testWidgets('$name is told and changes nothing', (tester) async {
        await importFirst();
        await pumpPage(tester);

        await startImport(content);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(message), findsOneWidget);
        expect(tester.takeException(), equals(null));
        expect(await titles(), ['Push', 'Pull']);
        expect(await lastImport(), firstImport);
      });
    }
  });
}
