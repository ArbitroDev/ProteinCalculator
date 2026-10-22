import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';

/// Columns holding a [ProteinAmount]: its mode, the protein grams when typed
/// directly, and the three quantities of the "per quantity" mode, null in
/// the other mode, with their unit, grams in the other mode.
typedef AmountColumns = ({
  EntryMode mode,
  double? directGrams,
  double? consumedGrams,
  double? proteinPerReference,
  double? referenceGrams,
  QuantityUnit unit,
});

/// Values of the columns holding [amount].
AmountColumns amountColumns(ProteinAmount amount) => switch (amount) {
  DirectAmount(:final proteinGrams) => (
    mode: amount.mode,
    directGrams: proteinGrams,
    consumedGrams: null,
    proteinPerReference: null,
    referenceGrams: null,
    unit: QuantityUnit.grams,
  ),
  PerQuantityAmount(
    :final consumedGrams,
    :final proteinPerReference,
    :final referenceGrams,
    :final unit,
  ) =>
    (
      mode: amount.mode,
      directGrams: null,
      consumedGrams: consumedGrams,
      proteinPerReference: proteinPerReference,
      referenceGrams: referenceGrams,
      unit: unit,
    ),
};

/// Protein amount stored in the columns of [row]. The forms and the backup
/// import only save complete amounts: anything else means damaged data.
ProteinAmount _readAmount(
  String row,
  EntryMode mode,
  double? directGrams,
  double? consumedGrams,
  double? proteinPerReference,
  double? referenceGrams,
  QuantityUnit unit,
) {
  switch (mode) {
    case EntryMode.direct:
      if (directGrams != null) return DirectAmount(directGrams);
    case EntryMode.perQuantity:
      if (consumedGrams != null &&
          proteinPerReference != null &&
          referenceGrams != null) {
        return PerQuantityAmount(
          consumedGrams: consumedGrams,
          proteinPerReference: proteinPerReference,
          referenceGrams: referenceGrams,
          unit: unit,
        );
      }
  }
  throw StateError('$row has an incomplete protein amount');
}

extension EntryAmount on Entry {
  /// How the protein amount of this entry was given.
  ProteinAmount get amount => _readAmount(
    'Entry $id',
    mode,
    proteinGrams,
    consumedGrams,
    proteinPerReference,
    referenceGrams,
    unit,
  );

  /// This entry with [amount] instead of its own.
  Entry withAmount(ProteinAmount amount) {
    final columns = amountColumns(amount);
    return copyWith(
      mode: columns.mode,
      proteinGrams: amount.proteinGrams,
      consumedGrams: Value(columns.consumedGrams),
      proteinPerReference: Value(columns.proteinPerReference),
      referenceGrams: Value(columns.referenceGrams),
      unit: columns.unit,
    );
  }
}

extension ProductAmount on Product {
  /// Protein amount of one portion of this product.
  ProteinAmount get amount => _readAmount(
    'Product $id',
    mode,
    proteinGrams,
    consumedGrams,
    proteinPerReference,
    referenceGrams,
    unit,
  );

  /// This product with [amount] instead of its own.
  Product withAmount(ProteinAmount amount) {
    final columns = amountColumns(amount);
    return copyWith(
      mode: columns.mode,
      proteinGrams: Value(columns.directGrams),
      consumedGrams: Value(columns.consumedGrams),
      proteinPerReference: Value(columns.proteinPerReference),
      referenceGrams: Value(columns.referenceGrams),
      unit: columns.unit,
    );
  }
}

extension EntriesProtein on Iterable<Entry> {
  /// Protein grams of all these entries.
  double get proteinGrams => map((entry) => entry.proteinGrams).sum;
}

extension EntryCreatine on Entry {
  /// Whether the entry is creatine taken on its own: no protein, but at
  /// least one dose. It then shows its creatine grams instead.
  bool get isCreatineOnly => proteinGrams == 0 && creatineDoses > 0;

  /// Grams of creatine of the entry, from the dose it was added with.
  double get creatineGrams => creatineDoses * (creatineDoseGrams ?? 0);
}

extension EntriesCreatine on Iterable<Entry> {
  /// Creatine doses of all these entries.
  int get creatineDoses => map((entry) => entry.creatineDoses).sum;

  /// Grams of creatine of all these entries.
  double get creatineGrams => map((entry) => entry.creatineGrams).sum;
}
