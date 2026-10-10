import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

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

    /// Scrolls down to the month before.
    Future<void> showSeptember(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('September 2026'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
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
      expect(day('Sunday, September 27, Nothing'), findsWidgets);
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

    testWidgets('opens a day with entries', (tester) async {
      await addEntry('Skyr', 15, DateTime(2026, 10, 1, 8));
      await openCalendar(tester);

      await tester.tap(
        find.bySemanticsLabel(RegExp('^Thursday, October 1')).first,
      );
      await tester.pumpAndSettle();

      // The entry, in the detail of the day.
      expect(find.textContaining('Skyr', findRichText: true), findsOneWidget);
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
