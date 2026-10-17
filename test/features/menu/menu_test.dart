import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
    // The version comes from the platform package info.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (call) async => {
            'appName': 'Protein Calculator',
            'packageName': 'arbitro.android.protein_calculator',
            'version': '1.0.0',
            'buildNumber': '1',
          },
        );
  });

  Future<void> openMenu(WidgetTester tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('edits the daily goal', (tester) async {
    await openMenu(tester);
    expect(find.text('140 g'), findsOneWidget);

    // The goal comes first, before the start of the day.
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '160');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('160 g'), findsOneWidget);
    expect(await db.settingsDao.getDailyGoal(), 160);
    await disposeApp(tester, db);
  });

  testWidgets('refuses an invalid goal', (tester) async {
    await openMenu(tester);

    // The goal comes first, before the start of the day.
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a number between 1 and 1,000.'), findsOneWidget);
    expect(await db.settingsDao.getDailyGoal(), 140);
    await disposeApp(tester, db);
  });

  group('creatine', () {
    Finder creatineSwitch() => find.descendant(
      of: find.widgetWithText(ListTile, 'Creatine'),
      matching: find.byType(Switch),
    );

    testWidgets('turning creatine on opens the dose sheet', (tester) async {
      await openMenu(tester);
      expect(find.text('Off'), findsOneWidget);

      await tester.tap(creatineSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Creatine dose'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '60');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Between 1 and 50 g'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Dose: 7 g'), findsOneWidget);
      expect(
        await db.settingsDao.getCreatine(),
        isA<Object>().having((c) => c.toString(), 'settings', contains('7.0')),
      );
      await disposeApp(tester, db);
    });

    testWidgets('a tap on the card turns creatine on, its switch labeled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openMenu(tester);

      expect(tester.getSemantics(creatineSwitch()).label, contains('Creatine'));
      await tester.tap(find.text('Creatine'));
      await tester.pumpAndSettle();
      expect(find.text('Creatine dose'), findsOneWidget);
      expect((await db.settingsDao.getCreatine()).enabled, isTrue);
      await disposeApp(tester, db);
      semantics.dispose();
    });

    testWidgets('takes a dose with one decimal', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await openMenu(tester);

      await tester.tap(find.text('Creatine'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3.5');
      await tester.pumpAndSettle();
      // One decimal at most: a second one is refused.
      await tester.enterText(find.byType(TextField), '3.55');
      await tester.pumpAndSettle();
      expect(find.text('3.5'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Dose: 3.5 g'), findsOneWidget);
      expect((await db.settingsDao.getCreatine()).doseGrams, 3.5);
      await disposeApp(tester, db);
    });

    testWidgets('turning it off and on again keeps the dose', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await db.settingsDao.setCreatineDoseGrams(3);
      await openMenu(tester);

      await tester.tap(creatineSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(creatineSwitch());
      await tester.pumpAndSettle();

      // No sheet the second time.
      expect(find.text('Creatine dose'), findsNothing);
      expect(find.text('Dose: 3 g'), findsOneWidget);
      await disposeApp(tester, db);
    });
  });

  testWidgets('chooses when the day starts', (tester) async {
    addTearDown(() => appDayStartHour = defaultAppDayStartHour);
    await openMenu(tester);
    expect(find.textContaining('3:00'), findsOneWidget);

    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    // The slider runs from midnight to 7 a.m.: its end is 7 a.m.
    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(slider.centerRight - const Offset(24, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.getDayStartHour(), 7);
    expect(appDayStartHour, 7);
    await disposeApp(tester, db);
  });

  testWidgets('turns the missed entry reminders on and off', (tester) async {
    await openMenu(tester);
    expect(await db.settingsDao.getSlotReminders(), isFalse);

    // Off by default; without notifications to allow in tests, it turns on
    // at once.
    await tester.tap(find.text('Missed entry reminders'));
    await tester.pumpAndSettle();
    expect(await db.settingsDao.getSlotReminders(), isTrue);

    await tester.tap(find.text('Missed entry reminders'));
    await tester.pumpAndSettle();
    expect(await db.settingsDao.getSlotReminders(), isFalse);
    await disposeApp(tester, db);
  });

  testWidgets('opens the data and privacy page', (tester) async {
    await openMenu(tester);

    await tester.tap(find.text('Data and privacy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your data stays on your phone.'), findsWidgets);
    expect(
      find.textContaining('only its barcode is sent to Open Food Facts'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Import a backup'), 200);
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Import a backup'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('opens the about page with the GitHub link', (tester) async {
    await openMenu(tester);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0'), findsOneWidget);
    expect(find.textContaining('contributing code on GitHub'), findsOneWidget);
    expect(find.text('View the source code on GitHub'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open Food Facts'), 200);
    expect(find.textContaining('Open Database License (ODbL)'), findsOneWidget);
    expect(find.text('world.openfoodfacts.org'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
