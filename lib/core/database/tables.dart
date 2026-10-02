import 'package:drift/drift.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

/// Protein entries. Each entry keeps a full copy of the values it was created
/// with, so editing or deleting a product never changes the history.
@TableIndex(name: 'entries_day_key', columns: {#dayKey})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  TextColumn get mode => textEnum<EntryMode>()();

  /// Final protein amount, entered or computed, so totals are plain sums.
  RealColumn get proteinGrams => real()();
  RealColumn get consumedGrams => real().nullable()();
  RealColumn get proteinPerReference => real().nullable()();
  RealColumn get referenceGrams => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// App day of [createdAt], see `dayKeyOf`.
  IntColumn get dayKey => integer()();
}

/// Products saved by the user to fill in entries quickly.
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Normalized name, see `productNameKey`: forbids duplicate names.
  TextColumn get nameKey => text().unique()();
  TextColumn get mode => textEnum<EntryMode>()();
  RealColumn get proteinGrams => real().nullable()();

  /// Default portion offered when the product is used.
  RealColumn get consumedGrams => real().nullable()();
  RealColumn get proteinPerReference => real().nullable()();
  RealColumn get referenceGrams => real().nullable()();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// The favorite product, listed first whatever the sort; one at most.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

/// Single-row table holding the app settings.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer()();

  /// Daily protein goal; null until the first launch is completed.
  RealColumn get dailyGoalGrams => real().nullable()();
  TextColumn get productSort => textEnum<ProductSort>().withDefault(
    Constant(ProductSort.alphabetical.name),
  )();

  /// Whether crash reports are sent; off until the user agrees.
  BoolColumn get crashReports => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
