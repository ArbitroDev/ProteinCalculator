import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';
import 'package:protein_calculator/core/food_facts/product_lookup.dart';

import '../database/test_database.dart';

const nutella = '3017620422003';

void main() {
  late AppDatabase db;
  late DateTime now;

  /// What Open Food Facts answers, and the barcodes it was asked about.
  late http.Response Function() answer;
  late List<String> asked;

  setUp(() {
    db = openTestDatabase();
    now = DateTime(2026, 10, 14, 12);
    asked = [];
    answer = () => found(protein: 6.3);
  });

  ProductLookupService service() => ProductLookupService(
    db,
    OpenFoodFacts(
      MockClient((request) async {
        asked.add(request.url.pathSegments.last);
        return answer();
      }),
      appVersion: Future.value('1.3.0'),
    ),
    () => now,
  );

  Future<ProductLookup> lookUp([String barcode = nutella]) =>
      service().lookUp(barcode, language: 'fr');

  Future<void> saveScan({required DateTime fetchedAt, double protein = 6.3}) =>
      db.scansDao.saveScan(
        FoodFacts(name: 'Nutella', brands: 'Nutella', proteinPer100: protein)
            .toScan(nutella, fetchedAt: fetchedAt, scannedAt: fetchedAt)
            .toCompanion(false),
      );

  Future<int> saveProduct({double protein = 6.3}) =>
      db.productsDao.insertProduct(
        name: 'Nutella',
        amount: PerQuantityAmount(
          consumedGrams: 15,
          proteinPerReference: protein,
          referenceGrams: 100,
        ),
        createdAt: DateTime(2026, 9, 1),
        barcode: nutella,
      );

  test('asks Open Food Facts about a product the phone does not know, '
      'and keeps its answer', () async {
    final result = await lookUp() as ScannedProductFound;

    expect(asked, [nutella]);
    expect(result.scan.name, 'Nutella');
    expect(result.scan.proteinPer100, 6.3);
    expect(await result.update, isNull);
    final kept = (await db.scansDao.getScan(nutella))!;
    expect(kept.fetchedAt, now);
    expect(kept.scannedAt, now);
  });

  test('finds a product scanned not long ago without asking', () async {
    await saveScan(fetchedAt: now.subtract(const Duration(days: 29)));

    final result = await lookUp() as ScannedProductFound;

    expect(asked, isEmpty);
    expect(await result.update, isNull);
    // Back on top of the recent scans.
    expect((await db.scansDao.getScan(nutella))!.scannedAt, now);
  });

  test('asks again about a product scanned long ago, and gives what '
      'changed', () async {
    await saveScan(fetchedAt: now.subtract(const Duration(days: 31)));
    answer = () => found(protein: 7);

    final result = await lookUp() as ScannedProductFound;

    // The values known come at once, the newer ones after.
    expect(result.scan.proteinPer100, 6.3);
    final update = await result.update;
    expect(update!.proteinPer100, 7);
    expect(asked, [nutella]);
    final kept = (await db.scansDao.getScan(nutella))!;
    expect(kept.proteinPer100, 7);
    expect(kept.fetchedAt, now);
    expect(kept.scannedAt, now);
  });

  test('gives no update when nothing changed', () async {
    await saveScan(fetchedAt: now.subtract(const Duration(days: 31)));

    final result = await lookUp() as ScannedProductFound;

    expect(await result.update, isNull);
    expect((await db.scansDao.getScan(nutella))!.fetchedAt, now);
  });

  test('keeps the values known when Open Food Facts cannot answer', () async {
    final asked31DaysAgo = now.subtract(const Duration(days: 31));
    await saveScan(fetchedAt: asked31DaysAgo);
    answer = () => http.Response('', 503);

    final result = await lookUp() as ScannedProductFound;

    expect(await result.update, isNull);
    final kept = (await db.scansDao.getScan(nutella))!;
    expect(kept.proteinPer100, 6.3);
    expect(kept.fetchedAt, asked31DaysAgo);
  });

  group('a product of the user', () {
    test('comes first, without asking', () async {
      final id = await saveProduct();
      await saveScan(fetchedAt: now.subtract(const Duration(days: 1)));

      final result = await lookUp() as SavedProductFound;

      expect(result.product.id, id);
      expect(asked, isEmpty);
      expect(await result.update, isNull);
    });

    test('gets what Open Food Facts changed since asked long ago, '
        'but is not changed', () async {
      await saveProduct();
      await saveScan(fetchedAt: now.subtract(const Duration(days: 31)));
      answer = () => found(protein: 7);

      final result = await lookUp() as SavedProductFound;

      expect((await result.update)!.proteinPer100, 7);
      final product = (await db.productsDao.findByBarcode(nutella))!;
      expect(product.proteinPerReference, 6.3);
    });

    test('takes what Open Food Facts says as a start, without telling a '
        'change, when it was never asked', () async {
      await saveProduct(protein: 8);
      answer = () => found(protein: 7);

      final result = await lookUp() as SavedProductFound;

      // Only what Open Food Facts said before tells a change: the 8 g of
      // the user may be a correction.
      expect(await result.update, isNull);
      expect((await db.scansDao.getScan(nutella))!.proteinPer100, 7);
    });
  });

  test('tells a product nobody knows', () async {
    answer = () => http.Response(
      jsonEncode({
        'result': {'id': 'product_not_found'},
      }),
      404,
    );

    expect(await lookUp(), isA<ProductNotFound>());
    expect(await db.scansDao.getScan(nutella), isNull);
  });

  test('tells why Open Food Facts could not be asked', () async {
    answer = () => throw http.ClientException('offline');

    final result = await lookUp() as ProductLookupFailed;

    expect(result.problem, FoodFactsProblem.offline);
  });

  test('keeps the unit of drinks', () async {
    answer = () => found(
      protein: 3.4,
      extra: {'serving_quantity': 250, 'serving_quantity_unit': 'ml'},
    );

    final result = await lookUp() as ScannedProductFound;

    expect(result.scan.unit, QuantityUnit.milliliters);
    expect(result.scan.servingQuantity, 250);
  });

  group('a code of the shop', () {
    // Meat weighed at the counter: the code holds its weight or price.
    const weighed = '2123456789015';

    test('is not sent to Open Food Facts', () async {
      final result = await lookUp(weighed) as ProductNotFound;

      expect(result.storeCode, isTrue);
      expect(asked, isEmpty);
      expect(await db.scansDao.getScan(weighed), isNull);
    });

    test('still finds the product of the user, without asking', () async {
      final id = await db.productsDao.insertProduct(
        name: 'Ham',
        amount: const DirectAmount(10),
        createdAt: DateTime(2026, 9, 1),
        barcode: weighed,
      );

      final result = await lookUp(weighed) as SavedProductFound;

      expect(result.product.id, id);
      expect(await result.update, isNull);
      expect(asked, isEmpty);
    });
  });

  test('tells a product nobody knows apart from a code of the shop', () async {
    answer = () => http.Response('', 404);

    final result = await lookUp() as ProductNotFound;

    expect(result.storeCode, isFalse);
    expect(asked, [nutella]);
  });
}

http.Response found({
  required double protein,
  Map<String, Object> extra = const {},
}) => http.Response(
  jsonEncode({
    'product': {
      'product_name': 'Nutella',
      'brands': 'Nutella',
      'nutriments': {'proteins_100g': protein},
      ...extra,
    },
    'result': {'id': 'product_found'},
    'status': 'success',
  }),
  200,
);
