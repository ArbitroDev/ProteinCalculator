import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/barcode.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';

/// Where the product of a barcode was found.
sealed class ProductLookup {
  const ProductLookup(this.barcode);

  /// In its stored form, see `normalizeBarcode`.
  final String barcode;
}

/// A product of the user has the barcode: its values come first. [update]
/// completes with what Open Food Facts says of it now, when that changed
/// since it was last asked long ago; with null otherwise.
final class SavedProductFound extends ProductLookup {
  const SavedProductFound(super.barcode, this.product, {required this.update});

  final Product product;
  final Future<FoodFacts?> update;
}

/// Open Food Facts knows the product, asked now or not long ago: [scan].
/// [update] completes with what it says now, when asked again long after
/// and it changed; with null otherwise.
final class ScannedProductFound extends ProductLookup {
  const ScannedProductFound(super.barcode, this.scan, {required this.update});

  final ScannedProduct scan;
  final Future<ScannedProduct?> update;
}

/// Neither the user nor Open Food Facts knows the product, or it has a
/// code of the shop ([storeCode], see `isStoreBarcode`), which Open Food
/// Facts is not asked about.
final class ProductNotFound extends ProductLookup {
  const ProductNotFound(super.barcode, {this.storeCode = false});

  final bool storeCode;
}

/// Open Food Facts could not be asked.
final class ProductLookupFailed extends ProductLookup {
  const ProductLookupFailed(super.barcode, this.problem);

  final FoodFactsProblem problem;
}

/// Looks up the product of a barcode on the phone first: in the products of
/// the user, then in what Open Food Facts said not long ago. Open Food Facts
/// is only asked when the phone does not know the product, or knows it from
/// too long ago, see [maxAge]; never about a code of the shop, see
/// `isStoreBarcode`.
class ProductLookupService {
  ProductLookupService(this._db, this._foodFacts, this._clock);

  final AppDatabase _db;
  final OpenFoodFacts _foodFacts;
  final DateTime Function() _clock;

  /// How long what Open Food Facts said is used without asking again: each
  /// request tells it a product the user scanned.
  static const maxAge = Duration(days: 30);

  /// Looks up [barcode], in its stored form; names are taken in [language]
  /// when Open Food Facts has them in it.
  Future<ProductLookup> lookUp(
    String barcode, {
    required String language,
  }) async {
    final now = _clock();
    final product = await _db.productsDao.findByBarcode(barcode);
    final scan = await _db.scansDao.getScan(barcode);
    // A code of the shop would tell Open Food Facts the weight or the price.
    final askable = !isStoreBarcode(barcode);
    final fresh =
        !askable || scan != null && now.difference(scan.fetchedAt) < maxAge;

    if (product != null) {
      return SavedProductFound(
        barcode,
        product,
        update: fresh ? Future.value() : _updateSaved(barcode, scan, language),
      );
    }
    if (scan != null) {
      await _db.scansDao.markScanned(barcode, now);
      final scanned = scan.copyWith(scannedAt: now);
      return ScannedProductFound(
        barcode,
        scanned,
        update: fresh ? Future.value() : _updateScan(scanned, language),
      );
    }

    if (!askable) return ProductNotFound(barcode, storeCode: true);
    switch (await _foodFacts.lookUp(barcode, language: language)) {
      case FoodFactsFound(:final facts):
        final found = facts.toScan(barcode, fetchedAt: now, scannedAt: now);
        await _db.scansDao.saveScan(found.toCompanion(false));
        return ScannedProductFound(barcode, found, update: Future.value());
      case FoodFactsNotFound():
        return ProductNotFound(barcode);
      case FoodFactsUnavailable(:final problem):
        return ProductLookupFailed(barcode, problem);
    }
  }

  /// What Open Food Facts says now of a product of the user, kept for next
  /// time, and returned when it changed since [previous]. Without anything
  /// said before, nothing tells what changed: the user's values may be
  /// corrections.
  Future<FoodFacts?> _updateSaved(
    String barcode,
    ScannedProduct? previous,
    String language,
  ) => _quietly(() async {
    final facts = await _ask(barcode, language);
    if (facts == null) return null;
    final now = _clock();
    await _db.scansDao.saveScan(
      facts
          .toScan(
            barcode,
            fetchedAt: now,
            scannedAt: previous?.scannedAt ?? now,
          )
          .toCompanion(false),
    );
    if (previous == null || facts == FoodFacts.fromScan(previous)) return null;
    return facts;
  });

  /// What Open Food Facts says now of a product scanned before, saved in
  /// place of [previous], and returned when it changed.
  Future<ScannedProduct?> _updateScan(
    ScannedProduct previous,
    String language,
  ) => _quietly(() async {
    final facts = await _ask(previous.barcode, language);
    if (facts == null) return null;
    final updated = facts.toScan(
      previous.barcode,
      fetchedAt: _clock(),
      scannedAt: previous.scannedAt,
    );
    await _db.scansDao.saveScan(updated.toCompanion(false));
    return facts == FoodFacts.fromScan(previous) ? null : updated;
  });

  /// What Open Food Facts says of [barcode], or null if it could not say.
  Future<FoodFacts?> _ask(String barcode, String language) async {
    final answer = await _foodFacts.lookUp(barcode, language: language);
    return answer is FoodFactsFound ? answer.facts : null;
  }

  /// [update], or null if it fails: an update comes after the values known,
  /// which stay, and nothing waits for it to fail.
  static Future<T?> _quietly<T>(Future<T?> Function() update) async {
    try {
      return await update();
    } on Object {
      return null;
    }
  }
}
