import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/protein_calc.dart';

/// Protein amount of an entry or of a portion of a product, in one of the
/// two ways the form offers, each with exactly the values it needs.
sealed class ProteinAmount {
  const ProteinAmount();

  /// Protein grams it amounts to.
  double get proteinGrams;

  /// How the amount is expressed, as stored in the database.
  EntryMode get mode;
}

/// Protein amount typed directly, in grams.
final class DirectAmount extends ProteinAmount {
  const DirectAmount(this.proteinGrams);

  @override
  final double proteinGrams;

  @override
  EntryMode get mode => EntryMode.direct;

  @override
  bool operator ==(Object other) =>
      other is DirectAmount && other.proteinGrams == proteinGrams;

  @override
  int get hashCode => proteinGrams.hashCode;

  @override
  String toString() => 'DirectAmount($proteinGrams g)';
}

/// Protein in [consumedGrams] of a product containing [proteinPerReference]
/// grams of protein per [referenceGrams].
final class PerQuantityAmount extends ProteinAmount {
  const PerQuantityAmount({
    required this.consumedGrams,
    required this.proteinPerReference,
    required this.referenceGrams,
  });

  final double consumedGrams;
  final double proteinPerReference;
  final double referenceGrams;

  @override
  double get proteinGrams => computeProtein(
    consumedGrams: consumedGrams,
    proteinPerReference: proteinPerReference,
    referenceGrams: referenceGrams,
  );

  @override
  EntryMode get mode => EntryMode.perQuantity;

  @override
  bool operator ==(Object other) =>
      other is PerQuantityAmount &&
      other.consumedGrams == consumedGrams &&
      other.proteinPerReference == proteinPerReference &&
      other.referenceGrams == referenceGrams;

  @override
  int get hashCode =>
      Object.hash(consumedGrams, proteinPerReference, referenceGrams);

  @override
  String toString() =>
      'PerQuantityAmount($consumedGrams g at '
      '$proteinPerReference g per $referenceGrams g)';
}
