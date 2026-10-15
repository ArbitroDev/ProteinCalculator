import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';

part 'scans_dao.g.dart';

/// Products scanned, and what Open Food Facts said of them.
@DriftAccessor(tables: [ScannedProducts, Products])
class ScansDao extends DatabaseAccessor<AppDatabase> with _$ScansDaoMixin {
  ScansDao(super.attachedDatabase);

  /// Number of recent scans kept: the older ones no product has the barcode
  /// of are deleted, see [keepRecent].
  static const recentCount = 20;

  Future<ScannedProduct?> getScan(String barcode) => (select(
    scannedProducts,
  )..where((s) => s.barcode.equals(barcode))).getSingleOrNull();

  /// Recent scans: the latest products scanned that no product has the
  /// barcode of, latest first.
  Stream<List<ScannedProduct>> watchRecent() =>
      (_unsaved()..limit(recentCount)).watch();

  /// Saves what Open Food Facts said of a product, in place of what it said
  /// before, and keeps only the [recentCount] latest recent scans.
  Future<void> saveScan(ScannedProductsCompanion scan) => transaction(() async {
    await into(scannedProducts).insertOnConflictUpdate(scan);
    await keepRecent();
  });

  /// Deletes the recent scans older than the [recentCount] latest. Called
  /// whenever there may be more: a scan saved, or a barcode no product has
  /// any longer, whose scan becomes a recent one again.
  Future<void> keepRecent() => transaction(() async {
    // SQLite takes a negative limit as none.
    final older = (await (_unsaved()..limit(-1, offset: recentCount)).get())
        .map((s) => s.barcode);
    if (older.isEmpty) return;
    await (delete(scannedProducts)..where((s) => s.barcode.isIn(older))).go();
  });

  /// Marks the product [barcode] as scanned at [now]: it goes back to the top
  /// of the recent scans.
  Future<void> markScanned(String barcode, DateTime now) =>
      (update(scannedProducts)..where((s) => s.barcode.equals(barcode))).write(
        ScannedProductsCompanion(scannedAt: Value(now)),
      );

  /// Deletes a scan and returns it, so the deletion can be undone with
  /// [restoreScan].
  Future<ScannedProduct?> deleteScan(String barcode) => transaction(() async {
    final scan = await getScan(barcode);
    if (scan == null) return null;
    await (delete(
      scannedProducts,
    )..where((s) => s.barcode.equals(barcode))).go();
    return scan;
  });

  /// Puts back a scan removed by [deleteScan], unless the product was scanned
  /// again meanwhile.
  Future<void> restoreScan(ScannedProduct scan) =>
      into(scannedProducts).insert(scan, mode: InsertMode.insertOrIgnore);

  /// Scans no product has the barcode of, latest first.
  SimpleSelectStatement<$ScannedProductsTable, ScannedProduct> _unsaved() =>
      select(scannedProducts)
        ..where(
          (s) => notExistsQuery(
            select(products)..where((p) => p.barcode.equalsExp(s.barcode)),
          ),
        )
        ..orderBy([(s) => OrderingTerm.desc(s.scannedAt)]);
}
