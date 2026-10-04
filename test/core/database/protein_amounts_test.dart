import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import 'test_database.dart';

void main() {
  const perQuantity = PerQuantityAmount(
    consumedGrams: 150,
    proteinPerReference: 10.5,
    referenceGrams: 100,
  );

  test('stores and reads back the amount of an entry', () async {
    final db = openTestDatabase();
    final id = await db.entriesDao.insertEntry(
      amount: perQuantity,
      createdAt: DateTime(2026, 10, 1, 9),
    );

    final entry = (await db.entriesDao.getEntry(id))!;
    expect(entry.amount, perQuantity);
    expect(entry.proteinGrams, 15.8);

    final direct = entry.withAmount(const DirectAmount(20));
    expect(direct.amount, const DirectAmount(20));
    expect(direct.proteinGrams, 20);
    expect(direct.consumedGrams, isNull);
  });

  test('stores the protein of a product only when typed directly', () async {
    final db = openTestDatabase();
    final id = await db.productsDao.insertProduct(
      name: 'Skyr',
      amount: perQuantity,
      createdAt: DateTime(2026, 9, 1),
    );

    final product = (await db.productsDao.getProduct(id))!;
    expect(product.amount, perQuantity);
    expect(product.proteinGrams, isNull);
    expect(product.withAmount(const DirectAmount(24)).proteinGrams, 24);
  });

  test('refuses an incomplete amount', () async {
    final db = openTestDatabase();
    final id = await db.productsDao.insertProduct(
      name: 'Skyr',
      amount: perQuantity,
      createdAt: DateTime(2026, 9, 1),
    );
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      const ProductsCompanion(mode: Value(EntryMode.direct)),
    );

    final product = (await db.productsDao.getProduct(id))!;
    expect(() => product.amount, throwsStateError);
  });
}
