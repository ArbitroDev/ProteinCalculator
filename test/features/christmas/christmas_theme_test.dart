import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/knit.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:protein_calculator/core/widgets/snow.dart';
import 'package:protein_calculator/features/history/christmas_day.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/features/share/share_tiles.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140, now: DateTime(2026, 11, 1, 9));
  });

  /// The falling snow never settles: the tests of the theme run with
  /// animations reduced, as a device can ask.
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  final knitted = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is KnitTabBackground,
  );

  testWidgets('dresses the app for Christmas on December 15', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, db, now: DateTime(2026, 12, 15, 9), christmas: true);

    expect(knitted, findsOneWidget);
    expect(find.byType(Snowfall), findsOneWidget);
    expect(find.byType(SnowBank), findsOneWidget);
    expect(find.bySemanticsLabel('Christmas in 10 days'), findsOneWidget);
    final theme = Theme.of(tester.element(find.byType(Snowfall)));
    expect(theme.colorScheme.primary, const Color(0xFFD7263D));
    await disposeApp(tester, db);
  });

  testWidgets('counts down to Christmas day', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, db, now: DateTime(2026, 12, 24, 9), christmas: true);
    expect(find.bySemanticsLabel('Christmas tomorrow'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('wishes a merry Christmas on the 25th', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, db, now: DateTime(2026, 12, 25, 9), christmas: true);
    expect(find.bySemanticsLabel('Merry Christmas'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('the countdown moves nothing on the upright page', (
    tester,
  ) async {
    reduceMotion(tester);
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    Future<Rect> shakerWith({required bool christmas}) async {
      await pumpApp(
        tester,
        db,
        now: DateTime(2026, 12, 15, 9),
        christmas: christmas,
      );
      return tester.getRect(find.byType(Shaker));
    }

    final plain = await shakerWith(christmas: false);
    // A new app, its providers set again.
    await tester.pumpWidget(const SizedBox());
    final dressed = await shakerWith(christmas: true);

    expect(find.bySemanticsLabel('Christmas in 10 days'), findsOneWidget);
    expect(dressed, plain);
    await disposeApp(tester, db);
  });

  testWidgets('the days up to the 25th hang from a garland', (tester) async {
    reduceMotion(tester);
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    Future<int> baubles({required bool christmas}) async {
      await pumpApp(
        tester,
        db,
        now: DateTime(2026, 12, 15, 9),
        christmas: christmas,
      );
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      return find.byType(ChristmasDay).evaluate().length;
    }

    // From December 1 to 25, the last of them the star.
    expect(await baubles(christmas: true), 25);
    expect(tester.widget<ChristmasDay>(find.byType(ChristmasDay).last).day, 25);
    await tester.pumpWidget(const SizedBox());
    expect(await baubles(christmas: false), 0);
    await disposeApp(tester, db);
  });

  testWidgets('stays plain with the theme turned off', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, db, now: DateTime(2026, 12, 15, 9));

    expect(knitted, findsNothing);
    expect(find.byType(Snowfall), findsNothing);
    expect(find.textContaining('Christmas'), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('stays plain out of the season', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, db, now: DateTime(2026, 11, 30, 9), christmas: true);

    expect(knitted, findsNothing);
    expect(find.byType(Snowfall), findsNothing);
    final theme = Theme.of(tester.element(find.byTooltip('Add')));
    expect(theme.colorScheme.primary, const Color(0xFFFF8A3D));
    await disposeApp(tester, db);
  });

  testWidgets('the knitted tabs still open their pages', (tester) async {
    reduceMotion(tester);
    await pumpApp(tester, db, now: DateTime(2026, 12, 15, 9), christmas: true);

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);
    expect(knitted, findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('the share sheet dresses its tiles for Christmas', (
    tester,
  ) async {
    reduceMotion(tester);
    tester.view
      ..physicalSize = const Size(1236, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await db.entriesDao.insertEntry(
      amount: DirectAmount(60),
      createdAt: DateTime(2026, 12, 15, 8),
    );
    await pumpApp(tester, db, now: DateTime(2026, 12, 15, 9), christmas: true);

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    final tile = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Shaker),
    );
    expect(tester.widget<Shaker>(tile).snowy, isTrue);
    expect(
      AppColors.of(tester.element(tile)).accent,
      AppColors.christmasLight.accent,
    );
    await disposeApp(tester, db);
  });

  Widget tileApp(Widget tile, {required bool christmas}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Center(
      child: ShareTileChristmas(christmas: christmas, child: tile),
    ),
  );

  Color streakBackground(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(ShareTileFrame),
              matching: find.byType(ColoredBox),
            )
            .first,
      )
      .color;

  testWidgets('the streak tile turns red for Christmas only', (tester) async {
    await tester.pumpWidget(
      tileApp(const StreakTile(streak: 4), christmas: false),
    );
    expect(streakBackground(tester), AppColors.brandAccent);

    await tester.pumpWidget(
      tileApp(const StreakTile(streak: 4), christmas: true),
    );
    expect(streakBackground(tester), AppColors.christmasLight.accent);
  });

  testWidgets('the calendar tile hangs December up to the 25th', (
    tester,
  ) async {
    MonthShare month(int number) => MonthShare(
      month: DateTime(2026, number),
      grams: const {},
      goalOf: (_) => 140,
      todayKey: 20261231,
      firstAppDayKey: 20261101,
      firstWeekday: 1,
    );
    await tester.pumpWidget(
      tileApp(CalendarMonthTile(data: month(12)), christmas: true),
    );
    expect(find.byType(ChristmasDay), findsNWidgets(25));

    await tester.pumpWidget(
      tileApp(CalendarMonthTile(data: month(11)), christmas: true),
    );
    expect(find.byType(ChristmasDay), findsNothing);

    await tester.pumpWidget(
      tileApp(CalendarMonthTile(data: month(12)), christmas: false),
    );
    expect(find.byType(ChristmasDay), findsNothing);
  });

  testWidgets('turning the theme off in the menu undresses the app', (
    tester,
  ) async {
    reduceMotion(tester);
    final themes = StreamController<bool>();
    addTearDown(themes.close);
    themes.add(true);
    await pumpApp(
      tester,
      db,
      now: DateTime(2026, 12, 15, 9),
      christmasThemes: themes.stream,
    );
    expect(knitted, findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    final setting = find.widgetWithText(SwitchListTile, 'Christmas theme');
    await tester.scrollUntilVisible(setting, 100);
    await tester.tap(setting);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(db.settingsDao.getChristmasTheme), isFalse);

    // The database tells the app, as its stream does on a phone.
    themes.add(false);
    await tester.pumpAndSettle();
    expect(knitted, findsNothing);
    expect(find.byType(Snowfall), findsNothing);
    await disposeApp(tester, db);
  });

  test('the first frame is dressed while the setting and the day load', () {
    final container = ProviderContainer(
      overrides: [
        christmasThemeProvider.overrideWith((ref) => const Stream.empty()),
        currentDayKeyProvider.overrideWith((ref) => const Stream.empty()),
        initialChristmasThemeProvider.overrideWithValue(true),
        clockProvider.overrideWithValue(() => DateTime(2026, 12, 15, 9)),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(christmasActiveProvider), isTrue);
  });

  Widget snowApp() => MaterialApp(
    theme: AppTheme.christmasLight,
    home: const Stack(children: [Snowfall()]),
  );

  testWidgets('the snow falls while animations run', (tester) async {
    await tester.pumpWidget(snowApp());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
    // Never settles: removed before the end of the test.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the snow stays still where animations are reduced', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(snowApp());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the bar stays knitted in landscape', (tester) async {
    reduceMotion(tester);
    tester.view
      ..physicalSize = const Size(2400, 1080)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(tester, db, now: DateTime(2026, 12, 15, 9), christmas: true);

    final painter =
        tester.widget<CustomPaint>(knitted).painter! as KnitTabBackground;
    expect(painter.vertical, isTrue);
    await disposeApp(tester, db);
  });

  testWidgets('the theme leaves on December 26 without a restart', (
    tester,
  ) async {
    reduceMotion(tester);
    final days = StreamController<int>();
    addTearDown(days.close);
    days.add(20261225);
    await pumpApp(
      tester,
      db,
      now: DateTime(2026, 12, 25, 23),
      christmas: true,
      dayKeys: days.stream,
    );
    expect(knitted, findsOneWidget);

    days.add(20261226);
    await tester.pumpAndSettle();

    expect(knitted, findsNothing);
    expect(find.byType(Snowfall), findsNothing);
    await disposeApp(tester, db);
  });
}
