import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/app.dart';

import 'helpers.dart';

void main() {
  group('first launch', () {
    testWidgets('asks for the daily goal and saves it', (tester) async {
      final db = openTestDatabase();
      await pumpApp(tester, db);

      expect(find.text('Your daily goal'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '150');
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(await db.settingsDao.getDailyGoal(), 150);
      expect(find.text('Thursday, October 1'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('refuses a goal out of range', (tester) async {
      final db = openTestDatabase();
      await pumpApp(tester, db);

      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a number between 1 and 1,000.'), findsOneWidget);
      expect(await db.settingsDao.getDailyGoal(), isNull);
      await disposeApp(tester, db);
    });

    testWidgets('is skipped once a goal is set', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db);

      expect(find.text('Your daily goal'), findsNothing);
      expect(find.text('Thursday, October 1'), findsOneWidget);
      await disposeApp(tester, db);
    });
  });

  group('navigation', () {
    testWidgets('switches between the four tabs', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db);

      for (final tab in ['History', 'Products', 'Menu']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, tab), findsOneWidget);
      }
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Thursday, October 1'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('opens the new entry form above the tabs', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsOneWidget);
      expect(find.text('History'), findsNothing);
      await disposeApp(tester, db);
    });
  });

  group('localization', () {
    testWidgets('uses French when the device is in French', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db, locales: const [Locale('fr', 'FR')]);

      expect(find.text('Jeudi 1 octobre'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      await disposeApp(tester, db);
    });

    test('picks the first supported device language', () {
      const supported = [Locale('en'), Locale('fr')];

      expect(
        resolveLocale(const [Locale('de'), Locale('fr', 'CA')], supported),
        const Locale('fr'),
      );
    });

    test('falls back to English for unsupported languages', () {
      const supported = [Locale('en'), Locale('fr')];

      expect(
        resolveLocale(const [Locale('de')], supported),
        const Locale('en'),
      );
      expect(resolveLocale(null, supported), const Locale('en'));
    });
  });
}
