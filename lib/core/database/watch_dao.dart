import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/watch/watch_addition.dart';

part 'watch_dao.g.dart';

/// Additions asked from the watch.
@DriftAccessor(tables: [WatchRequests])
class WatchDao extends DatabaseAccessor<AppDatabase> with _$WatchDaoMixin {
  WatchDao(super.attachedDatabase);

  /// How long the id of an addition is kept: the watch sends an addition
  /// again until the phone answers, as soon as it is nearby.
  static const keptFor = Duration(days: 60);

  /// Adds [addition] at its time, or at [now] if it says later, unless it
  /// was already added: a portion of its product, or, if no product with
  /// that id and name exists any more, the protein the watch showed.
  ///
  /// The id of the addition and the entry are saved together: an addition
  /// is added once, even sent again.
  Future<WatchAdditionStatus> add(WatchAddition addition, DateTime now) {
    if (!addition.isValid) return Future.value(WatchAdditionStatus.invalid);
    return transaction(() async {
      final known = await (select(
        watchRequests,
      )..where((r) => r.id.equals(addition.id))).getSingleOrNull();
      if (known != null) return WatchAdditionStatus.duplicate;
      await into(
        watchRequests,
      ).insert(WatchRequestsCompanion.insert(id: addition.id, handledAt: now));
      final createdAt = addition.addedAt.isAfter(now) ? now : addition.addedAt;
      final product = await attachedDatabase.productsDao.getProduct(
        addition.productId,
      );
      if (product != null && product.nameKey == productNameKey(addition.name)) {
        await attachedDatabase.entriesDao.addPortion(
          product,
          createdAt: createdAt,
          fromWatch: true,
        );
      } else {
        // Its id may name another product after a backup was restored.
        await attachedDatabase.entriesDao.insertEntry(
          name: addition.name.trim(),
          amount: DirectAmount((addition.protein * 10).round() / 10),
          createdAt: createdAt,
          fromWatch: true,
        );
      }
      await (delete(watchRequests)..where(
            (r) => r.handledAt.isSmallerThanValue(now.subtract(keptFor)),
          ))
          .go();
      return WatchAdditionStatus.added;
    });
  }

  /// Ids of the additions made from [since] on.
  Stream<List<String>> watchHandledSince(DateTime since) =>
      (select(watchRequests)
            ..where((r) => r.handledAt.isBiggerOrEqualValue(since))
            ..orderBy([(r) => OrderingTerm.asc(r.handledAt)]))
          .map((r) => r.id)
          .watch();
}
