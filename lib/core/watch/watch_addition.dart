import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/product_name.dart';

/// An entry added on the watch, maybe while out of range of the phone, for
/// the phone to add: a portion of a product, or a free entry of protein
/// grams. The watch gives it an [id], the same each time it sends it, so it
/// is never added twice.
@immutable
class WatchAddition {
  const WatchAddition({
    required this.id,
    required this.productId,
    required this.name,
    required this.protein,
    required this.addedAt,
  });

  /// Addition sent by the plugin `watch_link`, null if a value is missing.
  static WatchAddition? fromChannel(Object? value) {
    if (value case {
      'id': final String id,
      'productId': final int? productId,
      'name': final String? name,
      'protein': final double protein,
      'addedAt': final int addedAt,
    }) {
      return WatchAddition(
        id: id,
        productId: productId,
        name: name,
        protein: protein,
        addedAt: DateTime.fromMillisecondsSinceEpoch(addedAt),
      );
    }
    return null;
  }

  final String id;

  /// Id of the product, null for a free entry.
  final int? productId;

  /// Name and protein grams of one portion of the product, as the watch
  /// showed them: they make the entry if the product no longer exists. For
  /// a free entry, those typed on the watch; its name is optional.
  final String? name;
  final double protein;

  /// When it was added on the watch: the time of the entry.
  final DateTime addedAt;

  /// [protein] with one decimal, as the form keeps it: the grams of the
  /// entry made without the product.
  double get roundedProtein => (protein * 10).round() / 10;

  /// Whether the values can make an entry, as the form would accept them.
  bool get isValid =>
      id.isNotEmpty &&
      (productId == null || name != null) &&
      (name == null || isValidName(name!.trim())) &&
      protein.isFinite &&
      isValidProteinGrams(roundedProtein);
}

/// What the phone made of a [WatchAddition], see `AddStatus` in
/// `android/wear/protocol`.
enum WatchAdditionStatus {
  added,

  /// Already made from an earlier sending.
  duplicate,

  /// Values the phone cannot add.
  invalid,
}
