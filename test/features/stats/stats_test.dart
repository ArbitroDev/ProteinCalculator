import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import '../../helpers.dart';

/// Saturday 10 October 2026, noon.
final _now = DateTime(2026, 10, 10, 12);

void main() {
  late AppDatabase db;

  /// A phone held upright, wide enough for the today tab in the font of the
  /// tests.
  void holdUpright(WidgetTester tester) {
    tester.view.physicalSize = const Size(1236, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(100, now: DateTime(2026, 10, 1, 9));
  });

  Future<void> addEntry(double grams, DateTime at, {String? name}) => db
      .entriesDao
      .insertEntry(name: name, amount: DirectAmount(grams), createdAt: at);

  /// Reaches the goal from the 5th to the 9th, takes 30 g on the 10th.
  Future<void> addOctober() async {
    for (var day = 5; day <= 9; day++) {
      await addEntry(100, DateTime(2026, 10, day, 9), name: 'Whey');
    }
    await addEntry(30, DateTime(2026, 10, 10, 9), name: 'Skyr');
  }

  Future<void> openStats(WidgetTester tester) async {
    await pumpApp(tester, db, now: _now);
    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String tooltip) =>
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed !=
      null;

  testWidgets('invites to add a first entry', (tester) async {
    await openStats(tester);

    expect(find.widgetWithText(AppBar, 'Statistics'), findsOneWidget);
    expect(
      find.text('Your statistics will show here after your first entry.'),
      findsOneWidget,
    );
    await disposeApp(tester, db);
  });

  testWidgets('sums up the current month', (tester) async {
    holdUpright(tester);
    await addOctober();
    await openStats(tester);
    expect(find.text('October 2026'), findsOneWidget);
    // 530 g over the 10 days since the goal was set.
    expect(find.textContaining('53'), findsWidgets);
    expect(find.text('5 / 10'), findsOneWidget);
    expect(find.text('goal reached · 50%'), findsOneWidget);
    expect(find.text('5 d'), findsNWidgets(2));
    // Neither creatine nor Hevy is used.
    expect(find.text('Creatine'), findsNothing);
    expect(find.textContaining('Workouts'), findsNothing);
    expect(find.text('Insights'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('goes to the previous period and back', (tester) async {
    holdUpright(tester);
    await addOctober();
    await db.settingsDao.setDailyGoal(100, now: DateTime(2026, 9, 1, 9));
    await addEntry(100, DateTime(2026, 9, 20, 9));
    await openStats(tester);

    expect(enabled(tester, 'Next period'), isFalse);
    expect(enabled(tester, 'Previous period'), isTrue);

    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('No entry in this period.'), findsNothing);
    // The app is used from September only.
    expect(enabled(tester, 'Previous period'), isFalse);

    await tester.tap(find.byTooltip('Next period'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('shows a week or a year', (tester) async {
    holdUpright(tester);
    await addOctober();
    await openStats(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    // In English, the week starts on Sunday.
    expect(find.text('Week of Oct 4'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('2026'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('a period without entries says so', (tester) async {
    holdUpright(tester);
    await addEntry(100, DateTime(2026, 10, 1, 9));
    await openStats(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.text('No entry in this period.'), findsOneWidget);
    expect(find.text('Insights'), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('shows creatine and workouts once used', (tester) async {
    holdUpright(tester);
    await addOctober();
    await db.settingsDao.setCreatineEnabled(true);
    await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 9, 8));
    await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 10, 8));
    final start = DateTime(2026, 10, 8, 18);
    await db.hevyDao.replaceSessions([
      HevySessionsCompanion.insert(
        title: 'Push',
        startedAt: start,
        endedAt: Value(start.add(const Duration(minutes: 65))),
        dayKey: dayKeyOf(start),
      ),
    ], importedAt: _now);
    await openStats(tester);

    expect(find.text('Creatine'), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('average length'), 200);
    expect(find.textContaining('Workouts'), findsOneWidget);
    expect(find.text('1 h 5 min'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('tapping a bar tells its value, again opens the day', (
    tester,
  ) async {
    holdUpright(tester);
    await addOctober();
    await openStats(tester);

    final bar = find.bySemanticsLabel('Sat, Oct 10 · 30 g');
    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(find.text('Sat, Oct 10 · 30 g'), findsOneWidget);

    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(find.text('Saturday, October 10'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('in landscape, the protein beside the rest', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await addOctober();
    await openStats(tester);

    final protein = tester.getTopLeft(find.text('Protein'));
    final insights = tester.getTopLeft(find.text('Insights'));
    expect(insights.dx, greaterThan(protein.dx));
    expect(tester.takeException(), isNull);
    await disposeApp(tester, db);
  });
}
