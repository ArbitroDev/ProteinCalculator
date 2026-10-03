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

  group('watchDayTotal', () {
    test('is 0 for a day without entries', () async {
      expect(await dao.watchDayTotal(20260930).first, 0);
    });

    test('sums the entries of the app day only', () async {
      await addEntry(15, DateTime(2026, 9, 30, 8));
      await addEntry(30.5, DateTime(2026, 10, 1, 2));
      await addEntry(40, DateTime(2026, 10, 1, 9));

      expect(await dao.watchDayTotal(20260930).first, 45.5);
      expect(await dao.watchDayTotal(20261001).first, 40);
    });

    test('updates when an entry is added', () async {
      final totals = dao.watchDayTotal(20260930);
      final expectation = expectLater(totals, emitsInOrder([0, 15, 45]));

      await pumpEventQueue();
      await addEntry(15, DateTime(2026, 9, 30, 8));
      await pumpEventQueue();
      await addEntry(30, DateTime(2026, 9, 30, 12));

      await expectation;
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
        ),
      );

      final updated = (await dao.getEntry(id))!;
      expect(updated.proteinGrams, 20);
      expect(updated.createdAt, DateTime(2026, 9, 30, 8));
      expect(updated.dayKey, 20260930);
    });
  });

  group('deleteEntry and restoreEntry', () {
    test('delete returns the entry and restore puts it back', () async {
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');

      final deleted = await dao.deleteEntry(id);
      expect(await dao.getEntry(id), isNull);
      expect(await dao.watchDayTotal(20260930).first, 0);

      await dao.restoreEntry(deleted!);
      expect(await dao.getEntry(id), deleted);
      expect(await dao.watchDayTotal(20260930).first, 15);
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

    test('never goes below zero', () async {
      final id = await addEntry(15, DateTime(2026, 9, 30, 8), name: 'Skyr');
      final product = await addProduct('Skyr');

      await dao.deleteEntry(id);

      expect((await db.productsDao.getProduct(product.id))!.useCount, 0);
    });
  });
}
