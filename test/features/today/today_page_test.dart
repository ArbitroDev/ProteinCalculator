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

  Future<void> addEntry(double grams, DateTime at) => db.entriesDao.insertEntry(
    mode: EntryMode.direct,
    proteinGrams: grams,
    createdAt: at,
  );

  testWidgets('shows an empty day', (tester) async {
    await pumpApp(tester, db);

    expect(find.text('0 g'), findsOneWidget);
    expect(find.text('Goal 140 g'), findsOneWidget);
    expect(find.text('No entries · 140 g left to shake'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('sums the entries of the day', (tester) async {
    await addEntry(15, DateTime(2026, 10, 1, 8));
    await addEntry(44.6, DateTime(2026, 10, 1, 12, 40));
    await addEntry(30, DateTime(2026, 9, 30, 20));
    await pumpApp(tester, db);

    expect(find.text('60 g'), findsOneWidget);
    expect(find.text('2 entries · 80 g left to shake'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('shows when the goal is reached', (tester) async {
    await addEntry(150, DateTime(2026, 10, 1, 12));
    await pumpApp(tester, db);

    expect(find.text('150 g'), findsOneWidget);
    expect(find.textContaining('goal reached'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('keeps the previous day until 3 a.m.', (tester) async {
    await addEntry(20, DateTime(2026, 10, 1, 21));
    await addEntry(10, DateTime(2026, 10, 2, 1));
    await pumpApp(tester, db, now: DateTime(2026, 10, 2, 1, 30));

    expect(find.text('Thursday, October 1'), findsOneWidget);
    expect(find.text('30 g'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('updates when an entry is added', (tester) async {
    await pumpApp(tester, db);

    await addEntry(25, DateTime(2026, 10, 1, 10));
    await tester.pumpAndSettle();

    expect(find.text('25 g'), findsWidgets);
    expect(find.text('1 entry · 115 g left to shake'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
