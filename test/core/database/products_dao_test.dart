import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';

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

  test('getNameKeys lists the normalized names of the products', () async {
    await addProduct('Skyr nature');
    await addProduct('Œufs');

    expect(await dao.getNameKeys(), {
      productNameKey('Skyr nature'),
      productNameKey('Œufs'),
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

  group('daily routines', () {
    test('setRoutine saves the routine, its time and when it starts', () async {
      final id = await addProduct('Skyr');
      final now = DateTime(2026, 10, 8, 9);

      await dao.setRoutine(id, DailyRoutine.autoAdd, minutes: 480, now: now);

      final product = (await dao.getProduct(id))!;
      expect(product.routine, DailyRoutine.autoAdd);
      expect(product.routineMinutes, 480);
      expect(product.routineCheckedAt, now);
      expect(product.activeRoutineMinutes, 480);
    });

    test('setRoutine with none clears the time', () async {
      final id = await addProduct('Skyr');
      await dao.setRoutine(
        id,
        DailyRoutine.reminder,
        minutes: 480,
        now: DateTime(2026, 10, 8),
      );

      await dao.setRoutine(
        id,
        DailyRoutine.none,
        minutes: 480,
        now: DateTime(2026, 10, 8),
      );

      final product = (await dao.getProduct(id))!;
      expect(product.routine, DailyRoutine.none);
      expect(product.routineMinutes, isNull);
      expect(product.activeRoutineMinutes, isNull);
    });

    test(
      'products with a routine come after the favorite, earliest first',
      () async {
        final apple = await addProduct('Apple');
        final eggs = await addProduct('Eggs');
        final skyr = await addProduct('Skyr');
        final whey = await addProduct('Whey');
        await dao.setFavorite(whey, favorite: true);
        final now = DateTime(2026, 10, 8);
        await dao.setRoutine(
          skyr,
          DailyRoutine.reminder,
          minutes: 420,
          now: now,
        );
        await dao.setRoutine(
          eggs,
          DailyRoutine.autoAdd,
          minutes: 600,
          now: now,
        );

        final names = (await dao.watchAll(ProductSort.alphabetical).first).map(
          (p) => p.name,
        );

        expect(names, ['Whey', 'Skyr', 'Eggs', 'Apple']);
        expect(apple, isPositive);
      },
    );
  });

  group('barcodes', () {
    const nutella = '3017620422003';

    Future<int> addWithBarcode(String name, String? barcode) =>
        dao.insertProduct(
          name: name,
          amount: const DirectAmount(10),
          createdAt: DateTime(2026, 9, 1),
          barcode: barcode,
        );

    test('finds a product by its barcode or its name', () async {
      final id = await addWithBarcode('Nutella', nutella);

      expect((await dao.findByBarcode(nutella))!.id, id);
      expect(await dao.findByBarcode('96385074'), isNull);
      expect((await dao.findByName(' NUTELLA '))!.id, id);
    });

    test('lets products without barcode be many', () async {
      await addWithBarcode('Skyr', null);
      await addWithBarcode('Eggs', null);

      expect(await dao.findByBarcode(nutella), isNull);
    });

    test('refuses a barcode another product has', () async {
      final id = await addWithBarcode('Nutella', nutella);

      expect(
        () => addWithBarcode('Copy', nutella),
        throwsA(isA<DuplicateBarcodeException>()),
      );
      final other = await addWithBarcode('Other', null);
      expect(
        () => dao.setBarcode(other, nutella),
        throwsA(isA<DuplicateBarcodeException>()),
      );
      final product = (await dao.getProduct(other))!;
      expect(
        () =>
            dao.updateProduct(product.copyWith(barcode: const Value(nutella))),
        throwsA(isA<DuplicateBarcodeException>()),
      );
      expect(await dao.isBarcodeTaken(nutella), isTrue);
      expect(await dao.isBarcodeTaken(nutella, exceptId: id), isFalse);
    });

    test('gives a product a barcode, and takes it away', () async {
      final id = await addWithBarcode('Nutella', null);

      await dao.setBarcode(id, nutella);
      expect((await dao.getProduct(id))!.barcode, nutella);

      await dao.setBarcode(id, null);
      expect((await dao.getProduct(id))!.barcode, isNull);
    });

    test('puts back a deleted product without the barcode taken '
        'meanwhile', () async {
      final id = await addWithBarcode('Nutella', nutella);
      final deleted = (await dao.deleteProduct(id))!;
      await addWithBarcode('Nutella pot', nutella);

      await dao.restoreProduct(deleted);

      expect((await dao.getProduct(id))!.barcode, isNull);
    });

    test('puts back a deleted product with its barcode', () async {
      final id = await addWithBarcode('Nutella', nutella);
      final deleted = (await dao.deleteProduct(id))!;

      await dao.restoreProduct(deleted);

      expect((await dao.getProduct(id))!.barcode, nutella);
    });
  });

  group('setProteinPer100', () {
    test('takes the new protein content per 100, keeping the portion, and '
        'the rest as it is now', () async {
      final id = await dao.insertProduct(
        name: 'Skyr',
        amount: const PerQuantityAmount(
          consumedGrams: 150,
          proteinPerReference: 3,
          referenceGrams: 30,
        ),
        createdAt: DateTime(2026, 9, 1),
      );
      // Changed after the values of Open Food Facts came: the routine has
      // added its entries up to now.
      final checkedAt = DateTime(2026, 10, 8, 9);
      await dao.setRoutine(
        id,
        DailyRoutine.autoAdd,
        minutes: 480,
        now: checkedAt,
      );
      await dao.setFavorite(id, favorite: true);

      await dao.setProteinPer100(id, 11.5, unit: QuantityUnit.milliliters);

      final product = (await dao.getProduct(id))!;
      expect(
        product.amount,
        const PerQuantityAmount(
          consumedGrams: 150,
          proteinPerReference: 11.5,
          referenceGrams: 100,
          unit: QuantityUnit.milliliters,
        ),
      );
      expect(product.routine, DailyRoutine.autoAdd);
      expect(product.routineCheckedAt, checkedAt);
      expect(product.isFavorite, isTrue);
    });

    test('leaves a product typed per portion as it is', () async {
      final id = await dao.insertProduct(
        name: 'Bar',
        amount: const DirectAmount(20),
        createdAt: DateTime(2026, 9, 1),
      );

      await dao.setProteinPer100(id, 11.5, unit: QuantityUnit.grams);

      expect((await dao.getProduct(id))!.amount, const DirectAmount(20));
    });
  });
}
