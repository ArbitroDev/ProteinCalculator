import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/widgets/pill_tabs.dart';
import 'package:protein_calculator/features/share/share_sheet.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

import '../../helpers.dart';

/// Saturday 10 October 2026, noon.
final _now = DateTime(2026, 10, 10, 12);

final _fr = lookupAppLocalizations(const Locale('fr'));

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(1000, now: DateTime(2026, 1, 1, 9));
    await db.settingsDao.setCreatineEnabled(true);
    // Large numbers, many entries, long names, creatine and workouts every
    // other day, from January.
    final sessions = <HevySessionsCompanion>[];
    for (
      var day = DateTime(2026, 1, 1);
      day.isBefore(DateTime(2026, 10, 11));
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      for (var hour = 7; hour <= 15; hour++) {
        await db.entriesDao.insertEntry(
          name: 'Fromage blanc à la vanille de Madagascar $hour',
          amount: DirectAmount(day.day.isEven ? 140 : 95),
          createdAt: DateTime(day.year, day.month, day.day, hour),
          creatineDoses: hour == 7 && day.day % 3 != 0 ? 1 : 0,
        );
      }
      if (day.day.isOdd) {
        final start = DateTime(day.year, day.month, day.day, 18);
        sessions.add(
          HevySessionsCompanion.insert(
            title: 'Jambes et fessiers, séance longue',
            startedAt: start,
            endedAt: Value(start.add(const Duration(minutes: 135))),
            dayKey: dayKeyOf(start),
          ),
        );
      }
    }
    await db.hevyDao.replaceSessions(sessions, importedAt: _now);
  });

  void holdUpright(WidgetTester tester) {
    tester.view.physicalSize = const Size(1236, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Fails on a text of the tile shown cut without an ellipsis.
  void expectWholeTexts(WidgetTester tester, String tile) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$tile: $error');
    final frame = find.byType(ShareTileFrame);
    expect(frame, findsOneWidget, reason: tile);
    final paragraphs = find
        .descendant(of: frame, matching: find.byType(RichText))
        .evaluate()
        .map((element) => element.renderObject! as RenderParagraph);
    for (final paragraph in paragraphs) {
      expect(
        paragraph.didExceedMaxLines &&
            paragraph.overflow != TextOverflow.ellipsis,
        isFalse,
        reason: '$tile: "${paragraph.text.toPlainText()}" is cut',
      );
    }
  }

  /// Shows each tile of the open sheet, in each of its variants; a layout
  /// overflow fails the test.
  Future<void> checkSheet(WidgetTester tester, String page) async {
    final sheet = find.byType(BottomSheet);
    final tabs = find.descendant(
      of: sheet,
      matching: find.byType(PillTabs<int>),
    );
    if (tabs.evaluate().isEmpty) {
      expectWholeTexts(tester, page);
      return;
    }
    final choices = tester.widget<PillTabs<int>>(tabs.first).labels.values;
    for (final choice in choices) {
      await tester.tap(
        find.descendant(of: tabs.first, matching: find.text(choice)),
      );
      await tester.pumpAndSettle();
      final current = find.descendant(
        of: sheet,
        matching: find.byType(PillTabs<int>),
      );
      if (current.evaluate().length < 2) {
        expectWholeTexts(tester, '$page, $choice');
        continue;
      }
      final variants = tester.widget<PillTabs<int>>(current.last).labels;
      for (final variant in variants.values) {
        await tester.tap(
          find.descendant(of: current.last, matching: find.text(variant)),
        );
        await tester.pumpAndSettle();
        expectWholeTexts(tester, '$page, $choice, $variant');
      }
    }
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip(_fr.shareButton).first);
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
  }

  testWidgets('every tile fits in French, with large numbers', (tester) async {
    holdUpright(tester);
    // The shaker of today listens to the accelerometer, absent in tests.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const events = EventChannel(
      'dev.fluttercommunity.plus/sensors/accelerometer',
    );
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() => messenger.setMockStreamHandler(events, null));
    await pumpApp(tester, db, now: _now, locales: const [Locale('fr')]);

    // Today.
    await openSheet(tester);
    await checkSheet(tester, 'Today');
    await closeSheet(tester);

    // The statistics of a week, a month and a year.
    await tester.tap(find.byTooltip(_fr.tabStats));
    await tester.pumpAndSettle();
    for (final span in [_fr.statsWeek, _fr.statsMonth, _fr.statsYear]) {
      await tester.tap(find.text(span).first);
      await tester.pumpAndSettle();
      await openSheet(tester);
      await checkSheet(tester, span);
      await closeSheet(tester);
    }

    // The history, then a day of it.
    await tester.tap(find.byTooltip(_fr.tabHistory));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await checkSheet(tester, 'History');
    await closeSheet(tester);
    await tester.tap(find.textContaining('9 oct').first);
    await tester.pumpAndSettle();
    await openSheet(tester);
    await checkSheet(tester, 'Day');
    await closeSheet(tester);

    await disposeApp(tester, db);
  });
}
