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

  testWidgets('opens the data and privacy page', (tester) async {
    await openMenu(tester);

    await tester.tap(find.text('Data and privacy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your data stays on your phone.'), findsWidgets);
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
    await disposeApp(tester, db);
  });
}
