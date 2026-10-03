import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late EntriesDao dao;

  setUp(() {
    db = openTestDatabase();
    dao = db.entriesDao;
  });

  Future<int> addEntry(double grams, DateTime createdAt, {String? name}) =>
      dao.insertEntry(
        name: name,
        amount: DirectAmount(grams),
        createdAt: createdAt,
      );

  Future<Product> addProduct(String name) async {
    final id = await db.productsDao.insertProduct(
      name: name,
      amount: const DirectAmount(20),
      createdAt: DateTime(2026, 9, 1),
    );
    return (await db.productsDao.getProduct(id))!;
  }

  group('insertEntry', () {
    test('stores every value and computes the app day', () async {
      final id = await dao.insertEntry(
        name: 'Skyr',
        amount: const PerQuantityAmount(
          consumedGrams: 150,
          proteinPerReference: 10,
          referenceGrams: 100,
        ),
        createdAt: DateTime(2026, 10, 1, 1, 10),
      );

      final entry = (await dao.getEntry(id))!;
      expect(entry.name, 'Skyr');
      expect(entry.mode, EntryMode.perQuantity);
      expect(entry.proteinGrams, 15);
      expect(entry.consumedGrams, 150);
      expect(entry.proteinPerReference, 10);
      expect(entry.referenceGrams, 100);
      expect(entry.createdAt, DateTime(2026, 10, 1, 1, 10));
      expect(entry.dayKey, 20260930);
    });
  });

  test('watchHistory lists days with entries, most recent first', () async {
    await addEntry(20, DateTime(2026, 9, 28, 12));
    await addEntry(15, DateTime(2026, 9, 30, 8));
    await addEntry(10, DateTime(2026, 10, 1, 1));

    expect(await dao.watchHistory().first, const [
      DaySummary(
        dayKey: 20260930,
        bySlot: {DaySlot.morning: 15, DaySlot.evening: 10},
      ),
      DaySummary(dayKey: 20260928, bySlot: {DaySlot.afternoon: 20}),
    ]);
  });

  test('watchHistory sums the entries of the same part of the day', () async {
    await addEntry(15, DateTime(2026, 9, 30, 8));
    await addEntry(12.5, DateTime(2026, 9, 30, 10));
    await addEntry(30, DateTime(2026, 9, 30, 13));

    expect(await dao.watchHistory().first, const [
      DaySummary(
        dayKey: 20260930,
        bySlot: {DaySlot.morning: 27.5, DaySlot.afternoon: 30},
      ),
    ]);
  });

  test('stores the part of the day when the entry is added', () async {
    final id = await addEntry(15, DateTime(2026, 10, 1, 1, 10));

    expect((await dao.getEntry(id))!.slot, DaySlot.evening);
  });

  test('addPortion adds one portion of a product, under its name', () async {
    final productId = await db.productsDao.insertProduct(
      name: 'Skyr',
      amount: const PerQuantityAmount(
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
      ),
      createdAt: DateTime(2026, 9, 1),
    );
    final product = (await db.productsDao.getProduct(productId))!;

    final id = await dao.addPortion(
      product,
      createdAt: DateTime(2026, 9, 30, 8),
    );

    final entry = (await dao.getEntry(id))!;
    expect(entry.name, 'Skyr');
    expect(entry.proteinGrams, 15);
    expect(entry.consumedGrams, 150);
    expect((await db.productsDao.getProduct(productId))!.useCount, 1);
  });

  test('watchDayEntries lists the entries of a day in time order', () async {
    await addEntry(10, DateTime(2026, 10, 1, 1), name: 'late');
    await addEntry(15, DateTime(2026, 9, 30, 8), name: 'morning');
    await addEntry(30, DateTime(2026, 9, 30, 12), name: 'noon');
    await addEntry(40, DateTime(2026, 10, 1, 9), name: 'next day');

    final entries = await dao.watchDayEntries(20260930).first;

    expect(entries.map((e) => e.name), ['morning', 'noon', 'late']);
  });

  group('updateEntry', () {
    test('saves new values but keeps the time and the app day', () async {
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');
      final entry = (await dao.getEntry(id))!;

      await dao.updateEntry(
        entry.copyWith(
          proteinGrams: 20,
          createdAt: DateTime(2026, 10, 5),
          dayKey: 20261005,
          slot: DaySlot.evening,
        ),
      );

      final updated = (await dao.getEntry(id))!;
      expect(updated.proteinGrams, 20);
      expect(updated.createdAt, DateTime(2026, 9, 30, 8));
      expect(updated.dayKey, 20260930);
      expect(updated.slot, DaySlot.morning);
    });
  });

  group('deleteEntry and restoreEntry', () {
    test('delete returns the entry and restore puts it back', () async {
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      final deleted = await dao.deleteEntry(id);
      expect(await dao.getEntry(id), isNull);
      expect(await dao.watchDayEntries(20260930).first, isEmpty);

      await dao.restoreEntry(deleted!);
      expect(await dao.getEntry(id), deleted);
      expect(await dao.watchDayEntries(20260930).first, [deleted]);
    });

    test('delete returns null for an unknown entry', () async {
      expect(await dao.deleteEntry(42), isNull);
    });
  });

  group('product use count', () {
    test('counts entries whose name matches a product', () async {
      final product = await addProduct('Skyr nature');

      await addEntry(15, DateTime(2026, 9, 30, 8), name: ' skyr  NATURE ');
      await addEntry(15, DateTime(2026, 9, 30, 9), name: 'Skyr nature');
      await addEntry(15, DateTime(2026, 9, 30, 10), name: 'Yaourt');
      await addEntry(15, DateTime(2026, 9, 30, 11));

      final updated = (await db.productsDao.getProduct(product.id))!;
      expect(updated.useCount, 2);
      expect(updated.lastUsedAt, DateTime(2026, 9, 30, 9));
    });

    test('follows deletion and restoration of entries', () async {
      final product = await addProduct('Skyr');
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      final deleted = await dao.deleteEntry(id);
      expect((await db.productsDao.getProduct(product.id))!.useCount, 0);

      await dao.restoreEntry(deleted!);
      expect((await db.productsDao.getProduct(product.id))!.useCount, 1);
    });

    test('moves to the new product when an entry is renamed', () async {
      final skyr = await addProduct('Skyr');
      final eggs = await addProduct('Œufs');
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      final entry = (await dao.getEntry(id))!;
      await dao.updateEntry(entry.copyWith(name: const Value('Œufs')));

      expect((await db.productsDao.getProduct(skyr.id))!.useCount, 0);
      expect((await db.productsDao.getProduct(eggs.id))!.useCount, 1);
    });

    test('goes back to the previous use when the latest is deleted', () async {
      final product = await addProduct('Skyr');
      await addEntry(15, DateTime(2026, 9, 28, 8), name: 'Skyr');
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      final deleted = await dao.deleteEntry(id);
      var updated = (await db.productsDao.getProduct(product.id))!;
      expect(updated.useCount, 1);
      expect(updated.lastUsedAt, DateTime(2026, 9, 28, 8));

      await dao.restoreEntry(deleted!);
      updated = (await db.productsDao.getProduct(product.id))!;
      expect(updated.lastUsedAt, DateTime(2026, 9, 30, 8));
    });

    test('has no last use once every entry is deleted', () async {
      final product = await addProduct('Skyr');
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      await dao.deleteEntry(id);

      expect((await db.productsDao.getProduct(product.id))!.lastUsedAt, isNull);
    });

    test('dates the new product of a renamed entry', () async {
      final skyr = await addProduct('Skyr');
      final eggs = await addProduct('Œufs');
      await addEntry(15, DateTime(2026, 9, 28, 8), name: 'Skyr');
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      final entry = (await dao.getEntry(id))!;
      await dao.updateEntry(entry.copyWith(name: const Value('oeufs')));

      expect(
        (await db.productsDao.getProduct(skyr.id))!.lastUsedAt,
        DateTime(2026, 9, 28, 8),
      );
      expect(
        (await db.productsDao.getProduct(eggs.id))!.lastUsedAt,
        DateTime(2026, 9, 30, 8),
      );
    });

    test('counts the entries made before the product', () async {
      await addEntry(15, DateTime(2026, 9, 28, 8), name: 'Skyr');
      await addEntry(15, DateTime(2026, 9, 30, 8), name: 'skyr');

      final product = await addProduct('Skyr');

      expect(product.useCount, 2);
      expect(product.lastUsedAt, DateTime(2026, 9, 30, 8));
    });

    test('counts the entries of the new name of a product', () async {
      final product = await addProduct('Skyr');
      await addEntry(15, DateTime(2026, 9, 28, 8), name: 'Skyr');
      await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Whey');

      await db.productsDao.updateProduct(product.copyWith(name: 'Whey'));

      final renamed = (await db.productsDao.getProduct(product.id))!;
      expect(renamed.useCount, 1);
      expect(renamed.lastUsedAt, DateTime(2026, 9, 30, 8));
    });

    test('never goes below zero', () async {
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');
      final product = await addProduct('Skyr');

      await dao.deleteEntry(id);

      expect((await db.productsDao.getProduct(product.id))!.useCount, 0);
    });
  });
}
