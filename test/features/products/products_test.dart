import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/widgets/creatine_mark.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
    for (final name in ['Skyr', 'Amandes', 'Œufs']) {
      await db.productsDao.insertProduct(
        name: name,
        amount: const PerQuantityAmount(
          consumedGrams: 100,
          proteinPerReference: 10,
          referenceGrams: 100,
        ),
        createdAt: DateTime(2026, 9, 1),
      );
    }
    for (final hour in [8, 9]) {
      await db.entriesDao.insertEntry(
        name: 'Skyr',
        amount: const DirectAmount(10),
        createdAt: DateTime(2026, 9, 30, hour),
      );
    }
  });

  Future<void> openProducts(WidgetTester tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Products'));
    await tester.pumpAndSettle();
  }

  List<String> namesOnScreen(WidgetTester tester) {
    final names = ['Amandes', 'Skyr', 'Œufs'];
    final positions = {
      for (final name in names) name: tester.getTopLeft(find.text(name)).dy,
    };
    return names..sort((a, b) => positions[a]!.compareTo(positions[b]!));
  }

  testWidgets('sorts alphabetically, then by the chosen order', (tester) async {
    await openProducts(tester);
    expect(namesOnScreen(tester), ['Amandes', 'Œufs', 'Skyr']);

    await tester.tap(find.text('Most used'));
    await tester.pumpAndSettle();

    expect(namesOnScreen(tester).first, 'Skyr');
    expect(
      (await db.select(db.appSettings).getSingle()).productSort,
      ProductSort.mostUsed,
    );
    expect(find.textContaining('used 2 times'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('opens a product for editing on tap', (tester) async {
    await openProducts(tester);

    await tester.tap(find.text('Amandes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit product'), findsOneWidget);
    expect(find.text('Usual portion'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('opens a new product from a product on long press', (
    tester,
  ) async {
    await openProducts(tester);

    await tester.longPress(find.text('Amandes'));
    await tester.pumpAndSettle();

    expect(find.text('New product'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Amandes'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('shows the barcode and creatine marks first in the description, '
      'and the name on two lines at most', (tester) async {
    final id = await db.productsDao.insertProduct(
      name: 'Shaker whey vanille ' * 8,
      amount: const DirectAmount(25),
      createdAt: DateTime(2026, 9, 1),
      creatineDoses: 1,
    );
    await db.productsDao.setBarcode(id, '3017620422003');
    final semantics = tester.ensureSemantics();
    await openProducts(tester);

    final barcode = find.byIcon(LucideIcons.barcode);
    final creatine = find.byIcon(creatineIcon);
    final details = find.textContaining('25 g', findRichText: true);
    expect(barcode, findsOneWidget);
    expect(creatine, findsOneWidget);
    // Barcode, creatine, then the rest, on the line of the description.
    expect(
      tester.getCenter(barcode).dx,
      lessThan(tester.getCenter(creatine).dx),
    );
    expect(
      tester.getCenter(creatine).dy,
      moreOrLessEquals(tester.getCenter(barcode).dy, epsilon: 1),
    );
    expect(
      tester.getTopLeft(barcode).dx,
      moreOrLessEquals(tester.getTopLeft(details).dx, epsilon: 1),
    );

    final name = tester.widget<Text>(find.textContaining('Shaker whey'));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    // Screen readers tell both marks.
    expect(find.bySemanticsLabel(RegExp('has a barcode')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('contains creatine')), findsOneWidget);
    semantics.dispose();
    await disposeApp(tester, db);
  });

  testWidgets('adds a product to the day with its plus button', (tester) async {
    await openProducts(tester);

    await tester.tap(find.byTooltip('Add to the day').first);
    await tester.pumpAndSettle();

    expect(find.text('New entry'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Amandes'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('deletes a product with a swipe and restores it', (tester) async {
    await openProducts(tester);

    await tester.drag(find.text('Amandes'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Amandes'), findsNothing);
    expect(find.text('Product deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Amandes'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('says why a deleted product cannot come back', (tester) async {
    await openProducts(tester);

    await tester.drag(find.text('Amandes'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await db.productsDao.insertProduct(
      name: 'amandes',
      amount: const DirectAmount(5),
      createdAt: DateTime(2026, 10, 1),
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "The product couldn't be restored: another product already has this "
        'name.',
      ),
      findsOneWidget,
    );
    await disposeApp(tester, db);
  });

  testWidgets('shows a product again when deleting it fails', (tester) async {
    await db.customStatement(
      'CREATE TRIGGER fail BEFORE DELETE ON products '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await openProducts(tester);

    await tester.drag(find.text('Amandes'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<SqliteException>());
    expect(find.text('Something went wrong, please try again.'), findsOne);
    expect(find.text('Amandes'), findsOneWidget);
    await disposeApp(tester, db);
  });
  group('recent scans', () {
    const nutella = '3017620422003';

    setUp(() async {
      final at = DateTime(2026, 9, 30);
      await db.scansDao.saveScan(
        const FoodFacts(
          name: 'Nutella',
          brands: 'Nutella',
          proteinPer100: 6.3,
          servingQuantity: 15,
        ).toScan(nutella, fetchedAt: at, scannedAt: at).toCompanion(false),
      );
    });

    testWidgets('come under the saved products, both lists folding', (
      tester,
    ) async {
      await openProducts(tester);

      expect(find.text('My products'), findsOneWidget);
      expect(find.text('Recently scanned'), findsOneWidget);
      expect(find.text('6.3 g / 100 g · 15 g portion'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Nutella')).dy,
        greaterThan(tester.getTopLeft(find.text('Skyr')).dy),
      );

      await tester.tap(find.text('My products'));
      await tester.pumpAndSettle();
      expect(find.text('Amandes'), findsNothing);
      expect(find.text('Nutella'), findsOneWidget);
      final settings = await db.select(db.appSettings).getSingle();
      expect(settings.savedProductsCollapsed, isTrue);

      await tester.tap(find.text('Recently scanned'));
      await tester.pumpAndSettle();
      expect(find.text('Nutella'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('leave the favorite on top, its list folded', (tester) async {
      final skyr = await db.productsDao.findByName('Skyr');
      await db.productsDao.setFavorite(skyr!.id, favorite: true);
      await openProducts(tester);

      await tester.tap(find.text('My products'));
      await tester.pumpAndSettle();

      expect(find.text('Skyr'), findsOneWidget);
      expect(find.text('Amandes'), findsNothing);
      await disposeApp(tester, db);
    });

    testWidgets('start a new entry with their plus button, the values of '
        'Open Food Facts in green', (tester) async {
      await openProducts(tester);

      await tester.tap(find.byTooltip('Add to the day').last);
      await tester.pumpAndSettle();

      expect(find.text('New entry'), findsOneWidget);
      final name = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nutella'),
      );
      expect(name.decoration!.fillColor, AppColors.light.scanSurface);
      final consumed = tester.widget<TextField>(
        find.widgetWithText(TextField, '15'),
      );
      expect(consumed.decoration!.fillColor, AppColors.light.scanSurface);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nutella'),
        'Spread',
      );
      await tester.pump();
      final edited = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Spread'),
      );
      expect(edited.decoration!.fillColor, isNull);
      await disposeApp(tester, db);
    });

    testWidgets('open a new product with their barcode on tap', (tester) async {
      await openProducts(tester);

      await tester.tap(find.text('Nutella'));
      await tester.pumpAndSettle();

      expect(find.text('New product'), findsWidgets);
      expect(find.text('Barcode $nutella'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('are deleted with a swipe, and come back', (tester) async {
      await openProducts(tester);

      await tester.drag(find.text('Nutella'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Nutella'), findsNothing);
      expect(find.text('Scan deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Nutella'), findsOneWidget);
      await disposeApp(tester, db);
    });
  });
}
