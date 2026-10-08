import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

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
    required ProteinAmount amount,
    required DateTime createdAt,
  }) {
    final columns = amountColumns(amount);
    return transaction(() async {
      if (await isNameTaken(name)) throw DuplicateProductNameException(name);
      final id = await into(products).insert(
        ProductsCompanion.insert(
          name: name.trim(),
          nameKey: productNameKey(name),
          mode: columns.mode,
          proteinGrams: Value(columns.directGrams),
          consumedGrams: Value(columns.consumedGrams),
          proteinPerReference: Value(columns.proteinPerReference),
          referenceGrams: Value(columns.referenceGrams),
          createdAt: createdAt,
        ),
      );
      // Entries made before with its name count as uses.
      await attachedDatabase.refreshUses(productNameKey(name));
      return id;
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
      // A new name counts the entries with that name instead.
      await attachedDatabase.refreshUses(productNameKey(product.name));
    });
  }

  /// Makes [id] the favorite product, replacing the previous one, or removes
  /// it from favorites when [favorite] is false.
  Future<void> setFavorite(int id, {required bool favorite}) {
    return transaction(() async {
      await (update(products)..where((p) => p.isFavorite.equals(true))).write(
        const ProductsCompanion(isFavorite: Value(false)),
      );
      if (!favorite) return;
      await (update(products)..where((p) => p.id.equals(id))).write(
        const ProductsCompanion(isFavorite: Value(true)),
      );
    });
  }

  /// Gives the product [id] the daily [routine] at [minutes], from [now]:
  /// automatic additions start after it.
  Future<void> setRoutine(
    int id,
    DailyRoutine routine, {
    required int? minutes,
    required DateTime now,
  }) {
    final none = routine == DailyRoutine.none || minutes == null;
    return (update(products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        routine: Value(none ? DailyRoutine.none : routine),
        routineMinutes: Value(none ? null : minutes),
        routineCheckedAt: Value(none ? null : now),
      ),
    );
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
      // Another product may have become the favorite meanwhile.
      final favoriteTaken = await (select(
        products,
      )..where((p) => p.isFavorite.equals(true))).getSingleOrNull();
      await into(products).insert(
        favoriteTaken == null ? product : product.copyWith(isFavorite: false),
      );
      await attachedDatabase.refreshUses(product.nameKey);
    });
  }
}

/// Sorts [products] by [sort], the favorite first, then those with a daily
/// routine, earliest first, using the accent-insensitive alphabetical order
/// to break ties.
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
    if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
    final aMinutes = a.activeRoutineMinutes, bMinutes = b.activeRoutineMinutes;
    if (aMinutes != bMinutes) {
      if (aMinutes == null) return 1;
      if (bMinutes == null) return -1;
      return aMinutes.compareTo(bMinutes);
    }
    final result = primary(a, b);
    return result != 0 ? result : alphabetical(a, b);
  });
}

extension ProductRoutine on Product {
  /// Time of the daily routine of this product, or null without one.
  int? get activeRoutineMinutes =>
      routine == DailyRoutine.none ? null : routineMinutes;
}
