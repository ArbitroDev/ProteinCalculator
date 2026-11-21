import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/shaker_icon.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/features/share/share_tiles.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

import '../../helpers.dart';

/// Saturday 10 October 2026, noon.
final _now = DateTime(2026, 10, 10, 12);

/// Width and height of a PNG, read from its header.
(int, int) _pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  late AppDatabase db;
  final shared = <(Uint8List, String)>[];

  setUp(() async {
    shared.clear();
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(100, now: DateTime(2026, 10, 1, 9));
  });

  void holdUpright(WidgetTester tester) {
    tester.view.physicalSize = const Size(1236, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// An image is made in real time, where the shaker of today listens to
  /// the accelerometer: there is none in tests.
  void mockSensors() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const methods = MethodChannel('dev.fluttercommunity.plus/sensors/method');
    const events = EventChannel(
      'dev.fluttercommunity.plus/sensors/accelerometer',
    );
    messenger
      ..setMockMethodCallHandler(methods, (_) async => null)
      ..setMockStreamHandler(
        events,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(methods, null)
        ..setMockStreamHandler(events, null);
    });
  }

  Future<void> addEntry(double grams, DateTime at, {String? name}) => db
      .entriesDao
      .insertEntry(name: name, amount: DirectAmount(grams), createdAt: at);

  Future<void> open(WidgetTester tester) => pumpApp(
    tester,
    db,
    now: _now,
    overrides: [
      shareImageProvider.overrideWithValue(
        (png, fileName, origin) async => shared.add((png, fileName)),
      ),
    ],
  );

  testWidgets('shares the shaker of today as a 1080 px image', (tester) async {
    holdUpright(tester);
    mockSensors();
    await addEntry(60, DateTime(2026, 10, 10, 8), name: 'Skyr');
    await open(tester);

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Shaker'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('of 100 g · 60%'), findsOneWidget);
    expect(find.text('40 g left to shake'), findsWidgets);

    await tester.runAsync(() async {
      await tester.tap(find.text('Share the image'));
      for (var i = 0; i < 50 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    expect(shared, hasLength(1));
    expect(shared.single.$2, 'protein-20261010.png');
    expect(_pngSize(shared.single.$1), (1080, 1080));
    await disposeApp(tester, db);
  });

  testWidgets('the timeline of a day hides the products until asked', (
    tester,
  ) async {
    // Wide enough for the total and "goal reached" of the day detail in the
    // square font of tests.
    tester.view.physicalSize = const Size(1500, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (var hour = 7; hour <= 14; hour++) {
      await addEntry(15, DateTime(2026, 10, 9, hour), name: 'Egg $hour');
    }
    await open(tester);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Oct 9').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    // The detail of a day shows its timeline first.
    // 7 entries of 15 g reach the goal at 1 PM.
    expect(find.textContaining('100 g goal reached at 1:00'), findsOneWidget);
    // 6 lines at most, fewer when they do not fit in the square font of
    // tests.
    expect(find.textContaining(RegExp(r'and \d more entries')), findsOneWidget);
    expect(find.text('Egg 7'), findsNothing);

    await tester.tap(find.text('Show the products'));
    await tester.pumpAndSettle();
    expect(find.text('Egg 7'), findsOneWidget);
    expect(find.text('Egg 13'), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('offers the streak, then the month of statistics', (
    tester,
  ) async {
    holdUpright(tester);
    for (var day = 5; day <= 9; day++) {
      await addEntry(100, DateTime(2026, 10, day, 9));
    }
    await open(tester);
    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('days in a row at the goal'), findsOneWidget);
    expect(find.byType(ShakerIcon), findsNWidgets(5 + 1));

    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        // Today, not over, is left out until its goal is reached.
        matching: find.text('5 / 9'),
      ),
      findsOneWidget,
    );
    await disposeApp(tester, db);
  });

  testWidgets('the history shares a month, browsed back to the first one', (
    tester,
  ) async {
    holdUpright(tester);
    await addEntry(100, DateTime(2026, 10, 2, 9));
    await addEntry(60, DateTime(2026, 10, 3, 9));
    await open(tester);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    // The list is shown: its last 7 days first.
    expect(find.text('My week'), findsOneWidget);

    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();
    expect(find.text('1 day at the goal'), findsOneWidget);
    // The app is used from October only.
    final previous = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Previous period'),
        matching: find.byType(IconButton),
      ),
    );
    expect(previous.onPressed, isNull);
    await disposeApp(tester, db);
  });

  testWidgets('the month of the history is colored by creatine on demand', (
    tester,
  ) async {
    holdUpright(tester);
    await addEntry(100, DateTime(2026, 10, 2, 9));
    await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 3, 9));
    await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 5, 9));
    await open(tester);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();
    // The legend of the calendar, from no protein to the goal.
    for (final label in [
      'None taken',
      'Under 50%',
      '50% or more',
      'Goal reached',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.tap(find.text('Creatine'));
    await tester.pumpAndSettle();
    expect(find.text('2 creatine days'), findsOneWidget);
    expect(find.text('Creatine taken'), findsOneWidget);
    expect(find.text('Under 50%'), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('the statistics share their creatine', (tester) async {
    holdUpright(tester);
    for (var day = 5; day <= 7; day++) {
      await db.entriesDao.insertEntry(
        amount: const DirectAmount(40),
        createdAt: DateTime(2026, 10, day, 9),
        creatineDoses: 1,
      );
    }
    await open(tester);
    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Creatine').last);
    await tester.pumpAndSettle();
    expect(find.byType(CreatineTile), findsOneWidget);
    // 3 days out of those from the first dose, Monday, to yesterday: today
    // counts once a dose is taken.
    Finder inTile(String text) => find.descendant(
      of: find.byType(CreatineTile),
      matching: find.text(text),
    );
    expect(inTile('3 / 5'), findsOneWidget);
    expect(inTile('60%'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('the bars of a period stand on the bottom of the chart', (
    tester,
  ) async {
    holdUpright(tester);
    await addEntry(30, DateTime(2026, 10, 5, 9));
    await addEntry(100, DateTime(2026, 10, 6, 9));
    await addEntry(60, DateTime(2026, 10, 7, 9));
    await open(tester);
    await tester.tap(find.byTooltip('Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();

    final bars = find.descendant(
      of: find.byType(PeriodTile),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).borderRadius ==
                const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
    final bottoms = {
      for (final element in bars.evaluate())
        tester.getBottomLeft(find.byWidget(element.widget)).dy.round(),
    };
    // The line under the bars.
    final baseline = find.descendant(
      of: find.byType(PeriodTile),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == AppColors.light.divider &&
            widget.constraints?.maxHeight == 1,
      ),
    );
    expect(bars, findsAtLeast(3));
    expect(bottoms, {tester.getTopLeft(baseline).dy.round()});
    await disposeApp(tester, db);
  });

  testWidgets('the share button of today takes taps on its whole circle', (
    tester,
  ) async {
    holdUpright(tester);
    await open(tester);

    final button = tester.getRect(find.byTooltip('Share'));
    expect(button.size, const Size.square(40));
    // Its top and bottom edges, outside the line of the date.
    for (final y in [button.top + 2, button.bottom - 2]) {
      await tester.tapAt(Offset(button.center.dx, y));
      await tester.pumpAndSettle();
      expect(find.text('Share the image'), findsOneWidget);
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
    }
    await disposeApp(tester, db);
  });

  testWidgets('the month browsed stays when coming back to its tile', (
    tester,
  ) async {
    holdUpright(tester);
    mockSensors();
    await addEntry(100, DateTime(2026, 8, 2, 9));
    await open(tester);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);

    // Named after its month and what colors it.
    await tester.runAsync(() async {
      await tester.tap(find.text('Share the image'));
      for (var i = 0; i < 50 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(shared.single.$2, 'protein-calendar-protein-202609.png');
    await disposeApp(tester, db);
  });

  testWidgets('a long streak draws 30 shakers and counts the others', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: StreakTile(streak: 100)),
      ),
    );
    await tester.pumpAndSettle();

    // The logo of the signature is not a shaker icon.
    expect(find.byType(ShakerIcon), findsNWidgets(streakMaxShakers));
    expect(find.text('+70'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('the shaker of a day rounds its total as the goal does', (
    tester,
  ) async {
    await db.entriesDao.insertEntry(
      amount: const DirectAmount(100),
      createdAt: DateTime(2026, 10, 5, 9),
    );
    await db.entriesDao.insertEntry(
      amount: const DirectAmount(39.6),
      createdAt: DateTime(2026, 10, 5, 13),
    );
    // A direct query: streams never emit in the fake time of widget tests.
    final entries = await (db.select(
      db.entries,
    )..orderBy([(e) => OrderingTerm.asc(e.createdAt)])).get();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: DayShakerTile(
            day: DayShare(dayKey: 20261005, entries: entries, goal: 140),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 139.6 g shows 140 g, all of the goal, and reaches it.
    expect(find.text('140 g', findRichText: true), findsOneWidget);
    expect(find.text('of 140 g · 100%'), findsOneWidget);
    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.textContaining('short'), findsNothing);
  });
}
