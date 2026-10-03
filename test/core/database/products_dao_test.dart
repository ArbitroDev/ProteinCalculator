import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late ProductsDao dao;

  setUp(() {
    db = openTestDatabase();
    dao = db.productsDao;
  });

  Future<int> addProduct(String name) => dao.insertProduct(
    name: name,
    amount: const PerQuantityAmount(
      consumedGrams: 150,
      proteinPerReference: 10,
      referenceGrams: 100,
    ),
    createdAt: DateTime(2026, 9, 1),
  );

  group('insertProduct', () {
    test('stores every value and trims the name', () async {
      final id = await addProduct('  Skyr nature ');

      final product = (await dao.getProduct(id))!;
      expect(product.name, 'Skyr nature');
      expect(product.nameKey, 'skyr nature');
      expect(product.mode, EntryMode.perQuantity);
      expect(product.consumedGrams, 150);
      expect(product.proteinPerReference, 10);
      expect(product.referenceGrams, 100);
      expect(product.useCount, 0);
      expect(product.lastUsedAt, isNull);
    });

    test('refuses a name already used, ignoring accents', () async {
      await addProduct('Pâte complète');

      expect(
        () => addProduct('pate complete'),
        throwsA(isA<DuplicateProductNameException>()),
      );
    });

    test('refuses a name already used, ignoring case and spaces', () async {
      await addProduct('Skyr nature');

      expect(
        () => addProduct(' skyr   NATURE'),
        throwsA(isA<DuplicateProductNameException>()),
      );
    });
  });

  group('isNameTaken', () {
    test('detects names used by another product', () async {
      final id = await addProduct('Skyr');

      expect(await dao.isNameTaken('SKYR'), isTrue);
      expect(await dao.isNameTaken('Skyr', exceptId: id), isFalse);
      expect(await dao.isNameTaken('Yaourt'), isFalse);
    });
  });

  group('updateProduct', () {
    test('saves the new values and name key', () async {
      final id = await addProduct('Skyr');
      final product = (await dao.getProduct(id))!;

      await dao.updateProduct(
        product.copyWith(
          name: 'Skyr vanille ',
          proteinPerReference: const Value(9),
        ),
      );

      final updated = (await dao.getProduct(id))!;
      expect(updated.name, 'Skyr vanille');
      expect(updated.nameKey, 'skyr vanille');
      expect(updated.proteinPerReference, 9);
    });

    test('refuses the name of another product', () async {
      await addProduct('Skyr');
      final id = await addProduct('Yaourt');
      final product = (await dao.getProduct(id))!;

      expect(
        () => dao.updateProduct(product.copyWith(name: 'skyr')),
        throwsA(isA<DuplicateProductNameException>()),
      );
    });
  });

  group('deleteProduct and restoreProduct', () {
    test('delete returns the product and restore puts it back', () async {
      final id = await addProduct('Skyr');

      final deleted = await dao.deleteProduct(id);
      expect(await dao.getProduct(id), isNull);
      expect(await dao.isNameTaken('Skyr'), isFalse);

      await dao.restoreProduct(deleted!);
      expect(await dao.getProduct(id), deleted);
    });

    test('does not affect entries', () async {
      final id = await addProduct('Skyr');
      await db.entriesDao.insertEntry(
        name: 'Skyr',
        amount: const DirectAmount(15),
        createdAt: DateTime(2026, 9, 30, 8),
      );

      await dao.deleteProduct(id);

      final entries = await db.entriesDao.watchDayEntries(20260930).first;
      expect(entries.single.name, 'Skyr');
      expect(entries.single.proteinGrams, 15);
    });
  });

  group('watchAll', () {
    Future<void> useProduct(String name, DateTime at) => db.entriesDao
        .insertEntry(name: name, amount: const DirectAmount(10), createdAt: at);

    setUp(() async {
      for (final name in ['Poulet', 'Œufs', 'Épinards', 'amandes', 'Skyr']) {
        await addProduct(name);
      }
      await useProduct('Skyr', DateTime(2026, 9, 28, 8));
      await useProduct('Skyr', DateTime(2026, 9, 29, 8));
      await useProduct('Poulet', DateTime(2026, 9, 30, 12));
    });

    Future<List<String>> namesSortedBy(ProductSort sort) async =>
        (await dao.watchAll(sort).first).map((p) => p.name).toList();

    test('sorts alphabetically, accents included', () async {
      expect(await namesSortedBy(ProductSort.alphabetical), [
        'amandes',
        'Épinards',
        'Œufs',
        'Poulet',
        'Skyr',
      ]);
    });

    test('sorts by use count, then alphabetically', () async {
      expect(await namesSortedBy(ProductSort.mostUsed), [
        'Skyr',
        'Poulet',
        'amandes',
        'Épinards',
        'Œufs',
      ]);
    });

    test('sorts by last use, never used last', () async {
      expect(await namesSortedBy(ProductSort.recentlyUsed), [
        'Poulet',
        'Skyr',
        'amandes',
        'Épinards',
        'Œufs',
      ]);
    });
  });
}
