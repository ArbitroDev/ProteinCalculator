import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/watch_dao.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/watch/watch_addition.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late WatchDao dao;
  final now = DateTime(2026, 10, 1, 9);

  setUp(() {
    db = openTestDatabase();
    dao = db.watchDao;
  });

  Future<int> addProduct(String name, ProteinAmount amount) => db.productsDao
      .insertProduct(name: name, amount: amount, createdAt: DateTime(2026, 9));

  WatchAddition addition({
    String id = 'a1',
    int productId = 1,
    String name = 'Skyr',
    double protein = 15,
    DateTime? addedAt,
  }) => WatchAddition(
    id: id,
    productId: productId,
    name: name,
    protein: protein,
    addedAt: addedAt ?? DateTime(2026, 10, 1, 8, 30),
  );

  Future<List<Entry>> entries() => db.select(db.entries).get();

  test('adds a portion of the product at the time of the tap', () async {
    final id = await addProduct(
      'Skyr',
      const PerQuantityAmount(
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
      ),
    );

    final status = await dao.add(addition(productId: id), now);

    expect(status, WatchAdditionStatus.added);
    final entry = (await entries()).single;
    expect(entry.name, 'Skyr');
    expect(entry.mode, EntryMode.perQuantity);
    expect(entry.consumedGrams, 150);
    expect(entry.proteinGrams, 15);
    expect(entry.createdAt, DateTime(2026, 10, 1, 8, 30));
    expect(entry.dayKey, 20261001);
    expect(entry.slot, DaySlot.morning);
    expect(entry.fromWatch, isTrue);
    final product = (await db.productsDao.getProduct(id))!;
    expect(product.useCount, 1);
  });

  test('adds an addition sent again only once', () async {
    final id = await addProduct('Skyr', const DirectAmount(15));

    expect(
      await dao.add(addition(productId: id), now),
      WatchAdditionStatus.added,
    );
    expect(
      await dao.add(addition(productId: id), now.add(const Duration(hours: 1))),
      WatchAdditionStatus.duplicate,
    );
    expect(await entries(), hasLength(1));
  });

  test('adds what the watch showed when the product is gone', () async {
    final status = await dao.add(addition(protein: 25.26), now);

    expect(status, WatchAdditionStatus.added);
    final entry = (await entries()).single;
    expect(entry.name, 'Skyr');
    expect(entry.mode, EntryMode.direct);
    // Rounded to one decimal, like the protein amounts typed.
    expect(entry.proteinGrams, 25.3);
    expect(entry.fromWatch, isTrue);
  });

  test('ignores a product of another name having the same id', () async {
    // A backup restored meanwhile gave the id to another product.
    final id = await addProduct('Whey', const DirectAmount(30));

    await dao.add(addition(productId: id), now);

    final entry = (await entries()).single;
    expect(entry.name, 'Skyr');
    expect(entry.proteinGrams, 15);
  });

  test('finds the product whatever the case and accents of its name', () async {
    final id = await addProduct('Pâté', const DirectAmount(12));

    await dao.add(addition(productId: id, name: 'pate', protein: 99), now);

    final entry = (await entries()).single;
    expect(entry.name, 'Pâté');
    expect(entry.proteinGrams, 12);
  });

  test('counts an addition in the app day of the tap', () async {
    // Tapped late in the evening, sent the next morning.
    await dao.add(
      addition(addedAt: DateTime(2026, 10, 1, 23, 30)),
      DateTime(2026, 10, 2, 10),
    );

    final entry = (await entries()).single;
    expect(entry.dayKey, 20261001);
    expect(entry.slot, DaySlot.evening);
  });

  test('adds at the current time an addition dated later', () async {
    // The clock of the watch runs ahead.
    await dao.add(addition(addedAt: now.add(const Duration(hours: 2))), now);

    expect((await entries()).single.createdAt, now);
  });

  test('refuses values the form would not accept', () async {
    for (final invalid in [
      addition(name: '  '),
      addition(protein: 0),
      addition(protein: double.nan),
      addition(protein: 10000),
      addition(id: ''),
    ]) {
      expect(await dao.add(invalid, now), WatchAdditionStatus.invalid);
    }
    expect(await entries(), isEmpty);
    expect(await db.select(db.watchRequests).get(), isEmpty);
  });

  test('forgets the ids after 60 days', () async {
    await dao.add(addition(id: 'old'), now);
    await dao.add(
      addition(id: 'new', addedAt: now.add(const Duration(days: 61))),
      now.add(const Duration(days: 61)),
    );

    final ids = [
      for (final row in await db.select(db.watchRequests).get()) row.id,
    ];
    expect(ids, ['new']);
  });

  test('lists the ids of the additions made from a time on', () async {
    await dao.add(addition(id: 'yesterday'), DateTime(2026, 9, 30, 20));
    await dao.add(addition(id: 'today'), now);

    expect(await dao.watchHandledSince(DateTime(2026, 10, 1, 3)).first, [
      'today',
    ]);
    expect(await dao.watchHandledSince(DateTime(2026, 9, 30, 3)).first, [
      'yesterday',
      'today',
    ]);
  });
}
