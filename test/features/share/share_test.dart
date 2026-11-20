import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
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
    // The image is made in real time, where the shaker of today listens to
    // the accelerometer: there is none in tests.
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
        matching: find.text('5 / 10'),
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
}
