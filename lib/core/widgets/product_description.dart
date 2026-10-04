import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Protein of [product] in a few words: "24 g", or "10,5 g per 100 g",
/// followed by " · portion 150 g" if [withPortion].
String describeProduct(
  AppLocalizations l10n,
  Product product, {
  bool withPortion = false,
}) {
  final locale = l10n.localeName;
  return switch (product.amount) {
    DirectAmount(:final proteinGrams) => l10n.grams(
      formatProtein(proteinGrams, locale),
    ),
    PerQuantityAmount(
      :final consumedGrams,
      :final proteinPerReference,
      :final referenceGrams,
    ) =>
      [
        l10n.productPerReference(
          formatProtein(proteinPerReference, locale),
          formatGrams(referenceGrams, locale),
        ),
        if (withPortion)
          l10n.productPortion(formatGrams(consumedGrams, locale)),
      ].join(' · '),
  };
}
