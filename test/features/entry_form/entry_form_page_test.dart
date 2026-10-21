import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';
import 'package:protein_calculator/core/providers.dart';
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

  group('creatine counter', () {
    Future<void> openForm(WidgetTester tester) async {
      await pumpApp(tester, db);
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden while creatine is off', (tester) async {
      await openForm(tester);
      expect(find.byTooltip('One dose more'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('counts the doses, up to 9, and adds them', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await openForm(tester);

      final more = find.byTooltip('One dose more');
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('1 dose · 5 g'), findsOneWidget);
      for (var i = 0; i < 9; i++) {
        await tester.tap(more);
        await tester.pump();
      }
      expect(find.text('9 doses · 45 g'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, LucideIcons.plus),
            )
            .onPressed,
        isNull,
      );

      // Creatine on its own: no protein.
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final entry = (await db.select(db.entries).get()).single;
      expect(entry.proteinGrams, 0);
      expect(entry.creatineDoses, 9);
      await disposeApp(tester, db);
    });
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

  testWidgets('saves as a product only under a free name', (tester) async {
    final productId = await db.productsDao.insertProduct(
      name: 'Skyr',
      amount: const DirectAmount(15),
      createdAt: DateTime(2026),
    );
    await pumpApp(tester, db);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(router.push(AppRoutes.newEntryFrom(productId)));
    await tester.pumpAndSettle();

    // Filled from the product, whose name is taken.
    final box = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(box).onChanged, isNull);
    expect(find.text('A product already has this name.'), findsOneWidget);
    expect(find.text('Every day'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Skyr vanille');
    await tester.pumpAndSettle();
    expect(find.text('A product already has this name.'), findsNothing);

    // The routine comes with the new product.
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(find.text('Every day'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('offers to save an edited entry as a product, its box on the '
      'left edge of the button', (tester) async {
    final id = await db.entriesDao.insertEntry(
      name: 'Shaker',
      amount: const DirectAmount(25),
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    await pumpApp(tester, db);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(router.push(AppRoutes.editEntry(id)));
    await tester.pumpAndSettle();

    final box = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(box).onChanged, isNotNull);
    final button = find.widgetWithText(FilledButton, 'Save');
    // The box drawn is 18 wide, centered in its larger tap area.
    expect(
      tester.getCenter(box).dx - 9,
      moreOrLessEquals(tester.getTopLeft(button).dx),
    );
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
  testWidgets('offers to scan a barcode, but not for an entry edited', (
    tester,
  ) async {
    await db.entriesDao.insertEntry(
      name: 'Shaker',
      amount: const DirectAmount(25),
      createdAt: DateTime(2026, 10, 1, 8),
    );
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Scan a barcode'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shaker'));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);
    expect(find.byTooltip('Scan a barcode'), findsNothing);
    await disposeApp(tester, db);
  });

  testWidgets('tells what is sent before the first scan', (tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Scan a barcode'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Only the barcodes you scan are sent'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Still on the form, and told again next time.
    expect(find.text('New entry'), findsOneWidget);
    expect(await db.settingsDao.getScanNoticeSeen(), isFalse);
    await disposeApp(tester, db);
  });

  testWidgets('measures a quantity in milliliters', (tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('From the product'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<QuantityUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '250');
    await tester.enterText(fields.at(2), '3.4');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    final entry = await db.select(db.entries).getSingle();
    expect(entry.unit, QuantityUnit.milliliters);
    expect(entry.proteinGrams, 8.5);
    await disposeApp(tester, db);
  });

  group('the message of a scan, once the form is closed', () {
    const nutella = '3017620422003';

    /// Opens the form at [location], scans [nutella] there, Open Food Facts
    /// knowing it with [protein] per 100 g, then closes the form.
    Future<void> scanThenClose(
      WidgetTester tester,
      String location, {
      double protein = 6.3,
    }) async {
      await db.settingsDao.setScanNoticeSeen();
      await pumpApp(
        tester,
        db,
        overrides: [
          openFoodFactsProvider.overrideWithValue(
            OpenFoodFacts(
              MockClient(
                (_) async => http.Response(
                  jsonEncode({
                    'product': {
                      'product_name': 'Nutella',
                      'brands': 'Nutella',
                      'nutriments': {'proteins_100g': protein},
                    },
                    'result': {'id': 'product_found'},
                  }),
                  200,
                ),
              ),
              appVersion: Future.value('1.3.0'),
            ),
          ),
        ],
      );
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      unawaited(router.push(location));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Scan a barcode'));
      await tester.pumpAndSettle();
      tester.widget<ReaderWidget>(find.byType(ReaderWidget)).onScan!(
        Code(text: nutella, format: Format.ean13, isValid: true),
      );
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('New entry'), findsNothing);
      expect(find.text('New product'), findsNothing);
    }

    testWidgets('gives the barcode to the product of the same name', (
      tester,
    ) async {
      final id = await db.productsDao.insertProduct(
        name: 'Nutella',
        amount: const DirectAmount(2),
        createdAt: DateTime(2026, 9, 1),
      );
      await scanThenClose(tester, AppRoutes.newEntry);

      await tester.tap(find.text('Give it this code'));
      await tester.pumpAndSettle();

      expect((await db.productsDao.getProduct(id))!.barcode, nutella);
      expect(find.text('Barcode added to "Nutella".'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('takes the newer protein content into the product', (
      tester,
    ) async {
      final id = await db.productsDao.insertProduct(
        name: 'Nutella',
        amount: const PerQuantityAmount(
          consumedGrams: 15,
          proteinPerReference: 6.3,
          referenceGrams: 100,
        ),
        createdAt: DateTime(2026, 9, 1),
        barcode: nutella,
      );
      // Asked long ago: Open Food Facts is asked again.
      final longAgo = DateTime(2026, 8, 1);
      await db.scansDao.saveScan(
        const FoodFacts(name: 'Nutella', brands: 'Nutella', proteinPer100: 6.3)
            .toScan(nutella, fetchedAt: longAgo, scannedAt: longAgo)
            .toCompanion(false),
      );
      await scanThenClose(tester, AppRoutes.newEntry, protein: 7);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      final product = (await db.productsDao.getProduct(id))!;
      expect(product.proteinPerReference, 7);
      expect(product.consumedGrams, 15);
      expect(
        find.text('Something went wrong, please try again.'),
        findsNothing,
      );
      await disposeApp(tester, db);
    });

    testWidgets('opens the product that has the barcode', (tester) async {
      await db.productsDao.insertProduct(
        name: 'My spread',
        amount: const DirectAmount(2),
        createdAt: DateTime(2026, 9, 1),
        barcode: nutella,
      );
      await scanThenClose(tester, AppRoutes.newProduct);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit product'), findsOneWidget);
      expect(find.text('My spread'), findsWidgets);
      await disposeApp(tester, db);
    });

    testWidgets('goes away after a while', (tester) async {
      await db.productsDao.insertProduct(
        name: 'Nutella',
        amount: const DirectAmount(2),
        createdAt: DateTime(2026, 9, 1),
      );
      await scanThenClose(tester, AppRoutes.newEntry);
      expect(find.text('Give it this code'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Give it this code'), findsNothing);
      await disposeApp(tester, db);
    });
  });
}
