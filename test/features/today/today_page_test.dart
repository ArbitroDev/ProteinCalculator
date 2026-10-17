import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
  });

  Future<void> addEntry(double grams, DateTime at) =>
      db.entriesDao.insertEntry(amount: DirectAmount(grams), createdAt: at);

  testWidgets('shows an empty day', (tester) async {
    await pumpApp(tester, db);

    // The total and the goal, on one line.
    expect(find.text('0 g / 140 g'), findsOneWidget);
    expect(find.text('No entries · 140 g left to shake'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('sums the entries of the day', (tester) async {
    await addEntry(15, DateTime(2026, 10, 1, 8));
    await addEntry(44.6, DateTime(2026, 10, 1, 12, 40));
    await addEntry(30, DateTime(2026, 9, 30, 20));
    await pumpApp(tester, db);

    // 59.6 g shows truncated, and what is left follows the shown total.
    expect(find.text('59 g / 140 g'), findsOneWidget);
    expect(find.text('2 entries · 81 g left to shake'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('truncates the total but not the entries', (tester) async {
    await db.entriesDao.insertEntry(
      amount: const DirectAmount(12.5),
      createdAt: DateTime(2026, 10, 1, 8),
    );
    await db.entriesDao.insertEntry(
      amount: const DirectAmount(30.8),
      createdAt: DateTime(2026, 10, 1, 9),
    );
    await pumpApp(tester, db);

    expect(find.text('43 g / 140 g'), findsOneWidget);
    expect(find.text('12.5 g'), findsOneWidget);
    expect(find.text('30.8 g'), findsOneWidget);
    expect(find.text('2 entries · 97 g left to shake'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('marks the entries added on the watch', (tester) async {
    await db.entriesDao.insertEntry(
      name: 'Skyr',
      amount: const DirectAmount(15),
      createdAt: DateTime(2026, 10, 1, 8),
      fromWatch: true,
    );
    await addEntry(20, DateTime(2026, 10, 1, 9));
    await pumpApp(tester, db);

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

  testWidgets('shows when the goal is reached', (tester) async {
    await addEntry(150, DateTime(2026, 10, 1, 12));
    await pumpApp(tester, db);

    // The total, and the label of the entry next to the shaker.
    expect(find.text('150 g / 140 g'), findsOneWidget);
    expect(find.text('150 g'), findsOneWidget);
    expect(find.textContaining('goal reached'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('keeps the previous day until 3 a.m.', (tester) async {
    await addEntry(20, DateTime(2026, 10, 1, 21));
    await addEntry(10, DateTime(2026, 10, 2, 1));
    await pumpApp(tester, db, now: DateTime(2026, 10, 2, 1, 30));

    expect(find.text('Thursday, October 1'), findsOneWidget);
    expect(find.text('30 g / 140 g'), findsOneWidget);
    await disposeApp(tester, db);
  });

  group('creatine', () {
    final check = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.semanticLabel == 'creatine taken',
    );
    final button = find.byTooltip('Add a creatine dose');

    testWidgets('nothing about creatine shows while it was never on', (
      tester,
    ) async {
      await addEntry(20, DateTime(2026, 10, 1, 8));
      await pumpApp(tester, db);

      expect(button, findsNothing);
      expect(check, findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('the blue button adds a dose with undo', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await pumpApp(tester, db);
      expect(check, findsNothing);

      await tester.tap(button);
      await tester.pumpAndSettle();

      final dose = (await db.select(db.entries).get()).single;
      expect(dose.proteinGrams, 0);
      expect(dose.creatineDoses, 1);
      expect(find.text('Creatine dose added'), findsOneWidget);
      expect(find.text('Creatine'), findsOneWidget);
      expect(find.text('5 g'), findsOneWidget);
      expect(check, findsOneWidget);
      // Not an entry of protein: the total stays.
      expect(find.text('0 g / 140 g'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await db.select(db.entries).get(), isEmpty);
      await disposeApp(tester, db);
    });

    testWidgets('screen readers tell the creatine of the entries', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await db.settingsDao.setCreatineEnabled(true);
      await db.entriesDao.insertEntry(
        name: 'Whey',
        amount: const DirectAmount(24),
        createdAt: DateTime(2026, 10, 1, 8),
        creatineDoses: 2,
      );
      await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 1, 9));
      await pumpApp(tester, db);

      expect(
        find.bySemanticsLabel(RegExp('contains 2 doses of creatine')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('5 g of creatine')), findsOneWidget);
      await disposeApp(tester, db);
      semantics.dispose();
    });

    testWidgets('the blue check stays once creatine is off', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 1, 8));
      await db.settingsDao.setCreatineEnabled(false);
      await pumpApp(tester, db);

      expect(check, findsOneWidget);
      expect(button, findsNothing);
      await disposeApp(tester, db);
    });
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
