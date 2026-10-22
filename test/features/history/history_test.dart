import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/theme.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
  });

  Future<void> addEntry(String? name, double grams, DateTime at) => db
      .entriesDao
      .insertEntry(name: name, amount: DirectAmount(grams), createdAt: at);

  Future<void> openHistory(WidgetTester tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
  }

  testWidgets('invites to add a first entry', (tester) async {
    await openHistory(tester);

    expect(
      find.text('Your history will show up here after your first entry.'),
      findsOneWidget,
    );
    await disposeApp(tester, db);
  });

  testWidgets('lists days with their total, most recent first', (tester) async {
    await addEntry('Poulet', 150, DateTime(2026, 9, 30, 12));
    await addEntry('Skyr', 15, DateTime(2026, 10, 1, 8));
    await openHistory(tester);

    final today = tester.getTopLeft(find.text('Thu, Oct 1'));
    final yesterday = tester.getTopLeft(find.text('Wed, Sep 30'));
    expect(today.dy, lessThan(yesterday.dy));
    expect(find.text('15 g'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    await disposeApp(tester, db);
  });

  group('calendar', () {
    Future<void> openCalendar(WidgetTester tester) async {
      await openHistory(tester);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
    }

    /// The list of the months, the current one at the bottom: the only
    /// scrollable going up, the weeks of each month not scrolling.
    final months = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.up,
    );

    /// Scrolls up to the month before, its title last.
    Future<void> showSeptember(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('September 2026'),
        300,
        scrollable: months,
      );
      await tester.pumpAndSettle();
    }

    /// The day labeled [label] for screen readers.
    Finder day(String label) => find.bySemanticsLabel(label);

    testWidgets('is remembered as the view of the history', (tester) async {
      await openCalendar(tester);

      expect(find.text('October 2026'), findsOneWidget);
      // A direct query: streams never emit in the fake time of widget tests.
      expect(
        (await db.select(db.appSettings).getSingle()).historyView,
        HistoryView.calendar,
      );
      await disposeApp(tester, db);
    });

    testWidgets('says how far each day went towards its goal', (tester) async {
      // The goal counts from September 1.
      await db.settingsDao.setDailyGoal(140, now: DateTime(2026, 9, 1, 9));
      await addEntry('Skyr', 150, DateTime(2026, 9, 30, 12));
      await addEntry('Skyr', 80, DateTime(2026, 9, 29, 12));
      await addEntry('Skyr', 20, DateTime(2026, 9, 28, 12));
      await openCalendar(tester);
      await showSeptember(tester);

      expect(day('Wednesday, September 30, Goal reached'), findsWidgets);
      expect(day('Tuesday, September 29, 50% or more'), findsWidgets);
      expect(day('Monday, September 28, Under 50%'), findsWidgets);
      expect(day('Sunday, September 27, None taken'), findsWidgets);
      await disposeApp(tester, db);
    });

    testWidgets('judges a day against the goal it had', (tester) async {
      await db.settingsDao.setDailyGoal(100, now: DateTime(2026, 9, 1, 9));
      await db.settingsDao.setDailyGoal(200, now: DateTime(2026, 9, 30, 9));
      await addEntry('Skyr', 120, DateTime(2026, 9, 29, 12));
      await addEntry('Skyr', 120, DateTime(2026, 9, 30, 12));
      await openCalendar(tester);
      await showSeptember(tester);

      expect(day('Tuesday, September 29, Goal reached'), findsWidgets);
      expect(day('Wednesday, September 30, 50% or more'), findsWidgets);
      await disposeApp(tester, db);
    });

    testWidgets('counts the days given entries before the first use', (
      tester,
    ) async {
      // The app is used from September 15; entries are added afterwards for
      // September 10 and for a day of August.
      await db.settingsDao.setDailyGoal(140, now: DateTime(2026, 9, 15, 9));
      await addEntry('Skyr', 150, DateTime(2026, 9, 10, 12));
      await addEntry('Skyr', 20, DateTime(2026, 8, 20, 12));
      await openCalendar(tester);
      await showSeptember(tester);

      expect(day('Thursday, September 10, Goal reached'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('August 2026'),
        300,
        scrollable: months,
      );
      expect(find.text('August 2026'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('opens a day with entries', (tester) async {
      await addEntry('Skyr', 15, DateTime(2026, 10, 1, 8));
      await openCalendar(tester);

      // The first week, above the screen of the tests.
      final october1 = find.bySemanticsLabel(RegExp('^Thursday, October 1'));
      await tester.scrollUntilVisible(october1.first, 100, scrollable: months);
      await tester.drag(months, const Offset(0, 100));
      await tester.pumpAndSettle();
      await tester.tap(october1.first);
      await tester.pumpAndSettle();

      // The entry, in the detail of the day.
      expect(find.textContaining('Skyr', findRichText: true), findsOneWidget);
      await disposeApp(tester, db);
    });
  });

  group('creatine', () {
    testWidgets('the list shows the blue check before the orange one', (
      tester,
    ) async {
      await addEntry('Skyr', 150, DateTime(2026, 10, 1, 8));
      await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 1, 9));
      await openHistory(tester);

      final creatine = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'creatine taken',
      );
      expect(creatine, findsOneWidget);
      final goal = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == LucideIcons.circleCheck &&
            widget.semanticLabel == null,
      );
      expect(
        tester.getTopLeft(creatine).dx,
        lessThan(tester.getTopLeft(goal).dx),
      );
      await disposeApp(tester, db);
    });

    testWidgets('the calendar legend shows creatine once it was on', (
      tester,
    ) async {
      await addEntry('Skyr', 15, DateTime(2026, 10, 1, 8));
      await openHistory(tester);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Creatine taken'), findsNothing);

      await db.settingsDao.setCreatineEnabled(true);
      await tester.pumpAndSettle();
      expect(find.text('Creatine taken'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('the calendar colors the days by creatine taken on demand', (
      tester,
    ) async {
      // Reaches the goal and takes creatine on October 1.
      await db.settingsDao.setDailyGoal(140, now: DateTime(2026, 9, 1, 9));
      await addEntry('Skyr', 150, DateTime(2026, 10, 1, 8));
      await db.entriesDao.addCreatineDose(
        createdAt: DateTime(2026, 10, 1, 8, 30),
      );
      await openHistory(tester);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      final creatineDays = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.shape is CircleBorder &&
            widget.color == AppColors.creatine,
      );
      final reachedDays = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.shape is CircleBorder &&
            widget.color == AppColors.accent,
      );
      final goalMark = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == LucideIcons.circleCheck,
      );
      expect(find.byTooltip('Protein'), findsOneWidget);
      expect(reachedDays, findsOneWidget);
      expect(creatineDays, findsNothing);
      expect(find.text('Under 50%'), findsOneWidget);
      final marks = tester.widgetList(goalMark).length;
      final first = tester.getCenter(find.text('1'));

      await tester.tap(find.byTooltip('Creatine'));
      await tester.pumpAndSettle();

      // The days stay in place, though the legend is shorter.
      expect(tester.getCenter(find.text('1')), first);

      expect(creatineDays, findsOneWidget);
      expect(reachedDays, findsNothing);
      // The legend tells the new colors, and the marks of the days stay.
      expect(find.text('None taken'), findsOneWidget);
      expect(find.text('Creatine taken'), findsOneWidget);
      expect(find.text('Goal reached'), findsOneWidget);
      expect(find.text('Under 50%'), findsNothing);
      expect(tester.widgetList(goalMark), hasLength(marks));
      await disposeApp(tester, db);
    });

    testWidgets('the calendar has no filter without creatine', (tester) async {
      await addEntry('Skyr', 15, DateTime(2026, 10, 1, 8));
      await openHistory(tester);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Protein'), findsNothing);
      expect(find.byTooltip('Creatine'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('the day details show a dose with its decimal', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await db.settingsDao.setCreatineDoseGrams(3.3);
      for (final hour in [8, 9, 10]) {
        await db.entriesDao.addCreatineDose(
          createdAt: DateTime(2026, 10, 1, hour),
        );
      }
      await openHistory(tester);
      await tester.tap(find.text('Thu, Oct 1'));
      await tester.pumpAndSettle();

      // 3 × 3.3 g, whatever the rounding of the sum.
      expect(find.text('3 doses of creatine · 9.9 g'), findsOneWidget);
      expect(find.text('3.3 g'), findsNWidgets(3));
      await disposeApp(tester, db);
    });

    testWidgets('the day details tell the doses of the day', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 1, 8));
      await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 1, 9));
      await openHistory(tester);
      await tester.tap(find.text('Thu, Oct 1'));
      await tester.pumpAndSettle();

      expect(find.text('2 doses of creatine · 10 g'), findsOneWidget);
      // Creatine taken on its own shows its own grams, under its name.
      expect(find.textContaining('Creatine', findRichText: true), findsWidgets);
      expect(find.text('5 g'), findsNWidgets(2));
      await disposeApp(tester, db);
    });
  });

  group('day detail', () {
    setUp(() async {
      await addEntry('Skyr', 15, DateTime(2026, 10, 1, 8));
      await addEntry('Poulet', 45, DateTime(2026, 10, 1, 12, 40));
      await addEntry(null, 10, DateTime(2026, 10, 2, 1));
    });

    Future<void> openDay(WidgetTester tester) async {
      await openHistory(tester);
      await tester.tap(find.text('Thu, Oct 1'));
      await tester.pumpAndSettle();
    }

    testWidgets('groups entries by part of the day', (tester) async {
      await openDay(tester);

      expect(find.text('Thursday, October 1'), findsOneWidget);
      expect(find.text('70 g'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Afternoon'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.textContaining('Unnamed'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('marks the entries added on the watch', (tester) async {
      await db.entriesDao.insertEntry(
        name: 'Oeufs',
        amount: const DirectAmount(12),
        createdAt: DateTime(2026, 10, 1, 9),
        fromWatch: true,
      );
      await openDay(tester);

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.icon == LucideIcons.watch &&
              widget.semanticLabel == 'Added on the watch',
        ),
        findsOneWidget,
      );
      await disposeApp(tester, db);
    });

    testWidgets('goes back to the history', (tester) async {
      await openDay(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Thu, Oct 1'), findsOneWidget);
      expect(find.text('Thursday, October 1'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('opens an entry for editing', (tester) async {
      await openDay(tester);

      await tester.tap(find.textContaining('Poulet'));
      await tester.pumpAndSettle();

      expect(find.text('Edit entry'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('deletes an entry with a swipe and restores it', (
      tester,
    ) async {
      await openDay(tester);

      await tester.drag(find.textContaining('Skyr'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('Skyr'), findsNothing);
      expect(find.text('Entry deleted'), findsOneWidget);
      expect(await db.select(db.entries).get(), hasLength(2));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Skyr'), findsOneWidget);
      expect(await db.select(db.entries).get(), hasLength(3));
      await disposeApp(tester, db);
    });

    testWidgets('shows an entry again when deleting it fails', (tester) async {
      await db.customStatement(
        'CREATE TRIGGER fail BEFORE DELETE ON entries '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await openDay(tester);

      await tester.drag(find.textContaining('Skyr'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<SqliteException>());
      expect(find.text('Something went wrong, please try again.'), findsOne);
      expect(find.textContaining('Skyr'), findsOneWidget);
      await disposeApp(tester, db);
    });
  });
}
