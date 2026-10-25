import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/app.dart';

import 'helpers.dart';

void main() {
  group('first launch', () {
    testWidgets('asks for the daily goal and saves it', (tester) async {
      final db = openTestDatabase();
      await pumpApp(tester, db);

      expect(find.text('Your daily\ngoal'), findsOneWidget);

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

      expect(find.text('Your daily\ngoal'), findsNothing);
      expect(find.text('Thursday, October 1'), findsOneWidget);
      await disposeApp(tester, db);
    });
  });

  group('navigation', () {
    testWidgets('opens the today tab for an invalid address', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db);
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.byType(Scaffold).last)).go('/entries/x');
      await tester.pumpAndSettle();

      expect(find.text('Thursday, October 1'), findsOneWidget);
      expect(find.text('New entry'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('switches between the five tabs, in order', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db);

      const tabs = ['Today', 'Products', 'History', 'Statistics', 'Menu'];
      final lefts = [
        for (final tab in tabs) tester.getCenter(find.byTooltip(tab)).dx,
      ];
      expect(lefts, [...lefts]..sort());
      for (final tab in ['History', 'Products', 'Statistics', 'Menu']) {
        await tester.tap(find.byTooltip(tab));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, tab), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Today'));
      await tester.pumpAndSettle();
      expect(find.text('Thursday, October 1'), findsOneWidget);
      await disposeApp(tester, db);
    });

    for (final (name, size) in [
      ('a narrow phone held upright', const Size(320, 640)),
      ('a low phone in landscape', const Size(640, 360)),
    ]) {
      testWidgets('the five tabs fit $name', (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 72);
        addTearDown(tester.view.reset);
        final db = openTestDatabase();
        await db.settingsDao.setDailyGoal(140);
        await pumpApp(tester, db);

        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Statistics'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Statistics'), findsOneWidget);
        await disposeApp(tester, db);
      });
    }

    testWidgets('opens the new entry form above the tabs', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db);

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsOneWidget);
      expect(find.byTooltip('History'), findsNothing);
      await disposeApp(tester, db);
    });
  });

  group('localization', () {
    testWidgets('uses French when the device is in French', (tester) async {
      final db = openTestDatabase();
      await db.settingsDao.setDailyGoal(140);
      await pumpApp(tester, db, locales: const [Locale('fr', 'FR')]);

      expect(find.text('Jeudi 1 octobre'), findsOneWidget);
      expect(find.byTooltip('Historique'), findsOneWidget);
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
