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

  test('keeps only the latest recent scans when a barcode no product has '
      'any longer makes one again', () async {
    Future<int> save(String name, String barcode) =>
        db.productsDao.insertProduct(
          name: name,
          amount: const DirectAmount(10),
          createdAt: start,
          barcode: barcode,
        );
    final deleted = await save('Deleted', '99999997');
    final kept = await save('Kept', '99999998');
    await scan('99999997', 0);
    await scan('99999998', 0);
    for (var i = 1; i <= ScansDao.recentCount; i++) {
      await scan('${10000000 + i}', i);
    }

    await db.productsDao.deleteProduct(deleted);
    await db.productsDao.setBarcode(kept, null);

    final barcodes = await recent();
    expect(barcodes, hasLength(ScansDao.recentCount));
    expect(barcodes, isNot(contains('99999997')));
    expect(await dao.getScan('99999997'), isNull);
    expect(await dao.getScan('99999998'), isNull);
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
