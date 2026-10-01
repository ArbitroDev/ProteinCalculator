import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

part 'products_dao.g.dart';

/// Thrown when saving a product whose name is already used by another one.
class DuplicateProductNameException implements Exception {
  const DuplicateProductNameException(this.name);

  final String name;

  @override
  String toString() => 'DuplicateProductNameException: $name';
}

@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.attachedDatabase);

  Stream<List<Product>> watchAll(ProductSort sort) =>
      select(products).watch().map((list) => sortProducts(list, sort));

  Future<Product?> getProduct(int id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Whether [name] is already used by a product other than [exceptId].
  Future<bool> isNameTaken(String name, {int? exceptId}) async {
    final query = select(products)
      ..where((p) => p.nameKey.equals(productNameKey(name)));
    if (exceptId != null) query.where((p) => p.id.equals(exceptId).not());
    return (await query.get()).isNotEmpty;
  }

  /// Saves a new product.
  ///
  /// Throws [DuplicateProductNameException] if the name is already used.
  Future<int> insertProduct({
    required String name,
    required EntryMode mode,
    double? proteinGrams,
    double? consumedGrams,
    double? proteinPerReference,
    double? referenceGrams,
    required DateTime createdAt,
  }) {
    return transaction(() async {
      if (await isNameTaken(name)) throw DuplicateProductNameException(name);
      return into(products).insert(
        ProductsCompanion.insert(
          name: name.trim(),
          nameKey: productNameKey(name),
          mode: mode,
          proteinGrams: Value(proteinGrams),
          consumedGrams: Value(consumedGrams),
          proteinPerReference: Value(proteinPerReference),
          referenceGrams: Value(referenceGrams),
          createdAt: createdAt,
        ),
      );
    });
  }

  /// Saves the edited values of an existing product.
  ///
  /// Throws [DuplicateProductNameException] if the new name is already used.
  Future<void> updateProduct(Product product) {
    return transaction(() async {
      if (await isNameTaken(product.name, exceptId: product.id)) {
        throw DuplicateProductNameException(product.name);
      }
      await update(products).replace(
        product.copyWith(
          name: product.name.trim(),
          nameKey: productNameKey(product.name),
        ),
      );
    });
  }

  /// Deletes a product and returns it, so the deletion can be undone with
  /// [restoreProduct]. Entries are not affected: they keep their own copy of
  /// the values.
  Future<Product?> deleteProduct(int id) {
    return transaction(() async {
      final product = await getProduct(id);
      if (product == null) return null;
      await (delete(products)..where((p) => p.id.equals(id))).go();
      return product;
    });
  }

  /// Puts back a product removed by [deleteProduct], with the same id.
  ///
  /// Throws [DuplicateProductNameException] if its name was reused meanwhile.
  Future<void> restoreProduct(Product product) {
    return transaction(() async {
      if (await isNameTaken(product.name)) {
        throw DuplicateProductNameException(product.name);
      }
      await into(products).insert(product);
    });
  }
}

/// Sorts [products] by [sort], using the accent-insensitive alphabetical
/// order to break ties.
List<Product> sortProducts(List<Product> products, ProductSort sort) {
  int alphabetical(Product a, Product b) => a.nameKey.compareTo(b.nameKey);

  int mostUsed(Product a, Product b) => b.useCount.compareTo(a.useCount);

  int recentlyUsed(Product a, Product b) {
    final aTime = a.lastUsedAt, bTime = b.lastUsedAt;
    if (aTime == bTime) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  }

  final primary = switch (sort) {
    ProductSort.alphabetical => alphabetical,
    ProductSort.mostUsed => mostUsed,
    ProductSort.recentlyUsed => recentlyUsed,
  };

  return [...products]..sort((a, b) {
    final result = primary(a, b);
    return result != 0 ? result : alphabetical(a, b);
  });
}
