import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';

/// What Open Food Facts says of a product, kept to what the app uses. Its
/// data come from its contributors and may be wrong: the user always checks
/// them before they are saved.
@immutable
class FoodFacts {
  const FoodFacts({
    this.name,
    this.brands,
    this.proteinPer100,
    this.servingQuantity,
    this.unit = QuantityUnit.grams,
  });

  /// Reads the product of an answer of Open Food Facts, named in [language]
  /// when it has a name in it. Values out of the ranges the forms accept are
  /// left out.
  factory FoodFacts.fromJson(
    Map<String, dynamic> product, {
    required String language,
  }) {
    String? text(String key) {
      final value = product[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final nutriments = product['nutriments'];
    final protein = nutriments is Map
        ? _number(nutriments['proteins_100g'])
        : null;

    // Its unit is given apart, also when the quantity is unknown.
    final servingUnit = switch (text('serving_quantity_unit')?.toLowerCase()) {
      'ml' => QuantityUnit.milliliters,
      'g' || null => QuantityUnit.grams,
      _ => null,
    };
    final serving = servingUnit == null
        ? null
        : _number(product['serving_quantity'])?.roundToDouble();
    final drink =
        servingUnit == QuantityUnit.milliliters ||
        text('product_quantity_unit')?.toLowerCase() == 'ml';

    return FoodFacts(
      name:
          text('product_name_$language') ??
          text('product_name') ??
          text('product_name_en') ??
          text('product_name_fr'),
      brands: text('brands'),
      // Protein per 100 g of food, at most: with one decimal, as typed.
      proteinPer100: protein != null && protein >= 0 && protein <= 100
          ? (protein * 10).round() / 10
          : null,
      servingQuantity: serving != null && isValidFoodGrams(serving)
          ? serving
          : null,
      // The values "per 100 g" of a drink are per 100 ml.
      unit: drink ? QuantityUnit.milliliters : QuantityUnit.grams,
    );
  }

  /// What Open Food Facts said of the product of [scan].
  factory FoodFacts.fromScan(ScannedProduct scan) => FoodFacts(
    name: scan.name,
    brands: scan.brands,
    proteinPer100: scan.proteinPer100,
    servingQuantity: scan.servingQuantity,
    unit: scan.unit,
  );

  /// Name of the product and its brands, comma separated; null when Open
  /// Food Facts has none.
  final String? name;
  final String? brands;

  /// Protein grams per 100 [unit]; null when Open Food Facts does not know.
  final double? proteinPer100;

  /// Quantity of one serving, a whole number of [unit]; null when unknown.
  final double? servingQuantity;
  final QuantityUnit unit;

  /// These values, as saved for [barcode].
  ScannedProduct toScan(
    String barcode, {
    required DateTime fetchedAt,
    required DateTime scannedAt,
  }) => ScannedProduct(
    barcode: barcode,
    name: name,
    brands: brands,
    proteinPer100: proteinPer100,
    servingQuantity: servingQuantity,
    unit: unit,
    fetchedAt: fetchedAt,
    scannedAt: scannedAt,
  );

  /// [value] as a finite number, from a number or from its text.
  static double? _number(Object? value) {
    final number = switch (value) {
      num() => value.toDouble(),
      String() => double.tryParse(value.trim().replaceAll(',', '.')),
      _ => null,
    };
    return number != null && number.isFinite ? number : null;
  }

  @override
  bool operator ==(Object other) =>
      other is FoodFacts &&
      other.name == name &&
      other.brands == brands &&
      other.proteinPer100 == proteinPer100 &&
      other.servingQuantity == servingQuantity &&
      other.unit == unit;

  @override
  int get hashCode =>
      Object.hash(name, brands, proteinPer100, servingQuantity, unit);

  @override
  String toString() =>
      'FoodFacts($name, $brands, $proteinPer100 g per 100 ${unit.name}, '
      'serving $servingQuantity)';
}
