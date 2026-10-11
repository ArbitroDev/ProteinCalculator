import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/router.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
  });

  testWidgets('stays open and usable when saving fails', (tester) async {
    await db.customStatement(
      'CREATE TRIGGER fail BEFORE INSERT ON entries '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '30');
    final save = find.widgetWithText(FilledButton, 'Add');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<SqliteException>());
    expect(find.text('Something went wrong, please try again.'), findsOne);
    expect(find.text('New entry'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await disposeApp(tester, db);
  });

  testWidgets('picks the moment of a new entry', (tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '30');

    final moment = find.widgetWithText(OutlinedButton, 'Now');
    await tester.ensureVisible(moment);
    await tester.tap(moment);
    await tester.pumpAndSettle();
    // The day, then the time, both offered at the current moment.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Today at'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // A direct query: streams never emit in widget tests.
    final entry = (await db.select(db.entries).get()).single;
    expect(entry.createdAt, defaultNow);
    await disposeApp(tester, db);
  });

  testWidgets('shows the moment of an edited entry', (tester) async {
    final id = await db.entriesDao.insertEntry(
      amount: const DirectAmount(15),
      createdAt: DateTime(2026, 9, 30, 20),
    );
    await pumpApp(tester, db);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(router.push(AppRoutes.editEntry(id)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Yesterday at'), findsOneWidget);
    // Its own time: no going back to now.
    expect(find.widgetWithText(TextButton, 'Now'), findsNothing);
    await disposeApp(tester, db);
  });

  group('suggestions', () {
    setUp(
      () => db.productsDao.insertProduct(
        name: 'Skyr',
        amount: const DirectAmount(15),
        createdAt: DateTime(2026),
      ),
    );

    final fields = find.byType(TextField);
    bool focused(Finder field) =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextField>() ==
        (field.evaluate().single.widget);

    Future<void> typeName(WidgetTester tester) async {
      await pumpApp(tester, db);
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.tap(fields.first);
      await tester.enterText(fields.first, 'Sk');
      await tester.pumpAndSettle();
      expect(find.text('Skyr'), findsOneWidget);
    }

    testWidgets('go away when another field is tapped, which keeps the '
        'focus', (tester) async {
      await typeName(tester);

      await tester.tap(fields.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Skyr'), findsNothing);
      expect(focused(fields.at(1)), isTrue);
      expect(focused(fields.first), isFalse);
      await disposeApp(tester, db);
    });

    testWidgets('come back when the name is edited again', (tester) async {
      await typeName(tester);
      await tester.tap(fields.at(1));
      await tester.pumpAndSettle();

      await tester.tap(fields.first);
      await tester.enterText(fields.first, 'Sky');
      await tester.pumpAndSettle();

      expect(find.text('Skyr'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('can be closed', (tester) async {
      await typeName(tester);

      // The close button of the suggestions, not the one of the page.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Saved products'),
            matching: find.byType(Row),
          ),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skyr'), findsNothing);
      expect(find.text('New entry'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('fill the form with the picked product', (tester) async {
      await typeName(tester);

      await tester.tap(find.text('Skyr'));
      await tester.pumpAndSettle();

      expect(find.text('Saved products'), findsNothing);
      expect(tester.widget<TextField>(fields.first).controller!.text, 'Skyr');
      await disposeApp(tester, db);
    });
  });
}
