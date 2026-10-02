import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
    for (final name in ['Skyr', 'Amandes', 'Œufs']) {
      await db.productsDao.insertProduct(
        name: name,
        mode: EntryMode.perQuantity,
        consumedGrams: 100,
        proteinPerReference: 10,
        referenceGrams: 100,
        createdAt: DateTime(2026, 9, 1),
      );
    }
    for (final hour in [8, 9]) {
      await db.entriesDao.insertEntry(
        name: 'Skyr',
        mode: EntryMode.direct,
        proteinGrams: 10,
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
}
