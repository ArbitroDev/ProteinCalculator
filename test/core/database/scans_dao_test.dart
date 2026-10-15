import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/scans_dao.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late ScansDao dao;
  final start = DateTime(2026, 10, 1);

  setUp(() {
    db = openTestDatabase();
    dao = db.scansDao;
  });

  /// Saves a scan of [barcode], [minutes] after the start.
  Future<void> scan(String barcode, int minutes, {double protein = 10}) {
    final at = start.add(Duration(minutes: minutes));
    return dao.saveScan(
      FoodFacts(
        name: 'Product $barcode',
        proteinPer100: protein,
      ).toScan(barcode, fetchedAt: at, scannedAt: at).toCompanion(false),
    );
  }

  Future<List<String>> recent() async => [
    for (final s in await dao.watchRecent().first) s.barcode,
  ];

  test('lists the recent scans, latest first', () async {
    await scan('11111111', 1);
    await scan('22222222', 2);

    expect(await recent(), ['22222222', '11111111']);
  });

  test('replaces what was said before of the same barcode', () async {
    await scan('11111111', 1, protein: 10);
    await scan('11111111', 2, protein: 12);

    final kept = (await dao.getScan('11111111'))!;
    expect(kept.proteinPer100, 12);
    expect(await recent(), ['11111111']);
  });

  test('leaves out the barcodes of saved products, but keeps them', () async {
    await scan('11111111', 1);
    await scan('22222222', 2);
    await db.productsDao.insertProduct(
      name: 'Saved',
      amount: const DirectAmount(10),
      createdAt: start,
      barcode: '22222222',
    );

    expect(await recent(), ['11111111']);
    expect(await dao.getScan('22222222'), isNotNull);
  });

  test('keeps only the latest recent scans', () async {
    await db.productsDao.insertProduct(
      name: 'Saved',
      amount: const DirectAmount(10),
      createdAt: start,
      barcode: '99999997',
    );
    await scan('99999997', 0);
    for (var i = 1; i <= ScansDao.recentCount + 2; i++) {
      await scan('${10000000 + i}', i);
    }

    final barcodes = await recent();
    expect(barcodes, hasLength(ScansDao.recentCount));
    expect(barcodes.first, '${10000000 + ScansDao.recentCount + 2}');
    expect(barcodes, isNot(contains('10000001')));
    expect(await dao.getScan('10000001'), isNull);
    // What was said of a saved product stays, however old.
    expect(await dao.getScan('99999997'), isNotNull);
  });

  Future<int> saveProduct(String name, String barcode) =>
      db.productsDao.insertProduct(
        name: name,
        amount: const DirectAmount(10),
        createdAt: start,
        barcode: barcode,
      );

  /// Saves [barcodes] as products scanned at the start, then the
  /// [ScansDao.recentCount] recent scans after them.
  Future<List<int>> fillScans(List<String> barcodes) async {
    final ids = [
      for (final (i, barcode) in barcodes.indexed)
        await saveProduct('Product $i', barcode),
    ];
    for (final barcode in barcodes) {
      await scan(barcode, 0);
    }
    for (var i = 1; i <= ScansDao.recentCount; i++) {
      await scan('${10000000 + i}', i);
    }
    return ids;
  }

  test('keeps only the latest recent scans when a barcode is taken away '
      'from a product', () async {
    final [id] = await fillScans(['99999998']);

    await db.productsDao.setBarcode(id, null);

    final barcodes = await recent();
    expect(barcodes, hasLength(ScansDao.recentCount));
    expect(barcodes, isNot(contains('99999998')));
    expect(await dao.getScan('99999998'), isNull);
  });

  test('keeps what Open Food Facts said of a product deleted, which comes '
      'back with it, and shows 20 recent scans meanwhile', () async {
    final [id] = await fillScans(['99999997']);

    final deleted = (await db.productsDao.deleteProduct(id))!;
    expect(await recent(), hasLength(ScansDao.recentCount));
    expect(await dao.getScan('99999997'), isNotNull);

    await db.productsDao.restoreProduct(deleted);
    expect(await dao.getScan('99999997'), isNotNull);
  });

  test('deletes the scan of a product deleted at the next scan saved, if '
      'too old', () async {
    final [id] = await fillScans(['99999997']);
    await db.productsDao.deleteProduct(id);

    await scan('10000099', 99);

    expect(await recent(), hasLength(ScansDao.recentCount));
    expect(await dao.getScan('99999997'), isNull);
  });

  test('puts a product scanned again on top', () async {
    await scan('11111111', 1);
    await scan('22222222', 2);

    await dao.markScanned('11111111', start.add(const Duration(minutes: 3)));

    expect(await recent(), ['11111111', '22222222']);
  });

  test('deletes a scan, and puts it back', () async {
    await scan('11111111', 1);

    final deleted = (await dao.deleteScan('11111111'))!;
    expect(await recent(), isEmpty);
    expect(await dao.deleteScan('11111111'), isNull);

    await dao.restoreScan(deleted);
    expect(await recent(), ['11111111']);
  });

  test('does not put back a scan made again meanwhile', () async {
    await scan('11111111', 1, protein: 10);
    final deleted = (await dao.deleteScan('11111111'))!;
    await scan('11111111', 2, protein: 12);

    await dao.restoreScan(deleted);

    expect((await dao.getScan('11111111'))!.proteinPer100, 12);
  });
}
