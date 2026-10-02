import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
  });

  Future<void> addEntry(String? name, double grams, DateTime at) =>
      db.entriesDao.insertEntry(
        name: name,
        mode: EntryMode.direct,
        proteinGrams: grams,
        createdAt: at,
      );

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
  });
}
