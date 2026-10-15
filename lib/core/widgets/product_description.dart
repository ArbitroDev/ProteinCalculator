import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Protein of [product] in a few words: "24 g", or "10,5 g / 100 g",
/// followed by " · portion 150 g" if [withPortion]; drinks may count in
/// milliliters: "3,4 g / 100 ml · portion 250 ml".
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
      :final unit,
    ) =>
      [
        l10n.productPerReference(
          formatProtein(proteinPerReference, locale),
          formatQuantity(l10n, referenceGrams, unit),
        ),
        if (withPortion)
          l10n.productPortion(formatQuantity(l10n, consumedGrams, unit)),
      ].join(' · '),
  };
}

/// Quantity of food in [unit], in whole units: "150 g", "250 ml".
String formatQuantity(AppLocalizations l10n, double value, QuantityUnit unit) {
  final text = formatGrams(value, l10n.localeName);
  return switch (unit) {
    QuantityUnit.grams => l10n.grams(text),
    QuantityUnit.milliliters => l10n.milliliters(text),
  };
}

/// Symbol of [unit]: "g", "ml".
String quantityUnitSymbol(AppLocalizations l10n, QuantityUnit unit) =>
    switch (unit) {
      QuantityUnit.grams => l10n.gramsUnit,
      QuantityUnit.milliliters => l10n.millilitersUnit,
    };
