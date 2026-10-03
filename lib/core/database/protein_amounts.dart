import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

/// Columns holding a [ProteinAmount]: its mode, the protein grams when typed
/// directly, and the three quantities of the "per quantity" mode, null in
/// the other mode.
typedef AmountColumns = ({
  EntryMode mode,
  double? directGrams,
  double? consumedGrams,
  double? proteinPerReference,
  double? referenceGrams,
});

/// Values of the columns holding [amount].
AmountColumns amountColumns(ProteinAmount amount) => switch (amount) {
  DirectAmount(:final proteinGrams) => (
    mode: amount.mode,
    directGrams: proteinGrams,
    consumedGrams: null,
    proteinPerReference: null,
    referenceGrams: null,
  ),
  PerQuantityAmount(
    :final consumedGrams,
    :final proteinPerReference,
    :final referenceGrams,
  ) =>
    (
      mode: amount.mode,
      directGrams: null,
      consumedGrams: consumedGrams,
      proteinPerReference: proteinPerReference,
      referenceGrams: referenceGrams,
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
    );
  }
}
