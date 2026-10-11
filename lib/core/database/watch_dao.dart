import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/watch/watch_addition.dart';
import 'package:protein_calculator/core/watch/watch_deletion.dart';

part 'watch_dao.g.dart';

/// Additions and deletions asked from the watch.
@DriftAccessor(tables: [WatchRequests])
class WatchDao extends DatabaseAccessor<AppDatabase> with _$WatchDaoMixin {
  WatchDao(super.attachedDatabase);

  /// How long the id of an addition or a deletion is kept: the watch sends
  /// it again until the phone answers, as soon as it is nearby.
  static const keptFor = Duration(days: 60);

  /// Adds [addition] at its time, or at [now] if it says later, unless it
  /// was already added: a portion of its product, or, for a free entry or if
  /// no product with that id and name exists any more, the protein the
  /// watch showed.
  ///
  /// The id of the addition and the entry are saved together: an addition
  /// is added once, even sent again.
  Future<WatchAdditionStatus> add(WatchAddition addition, DateTime now) {
    if (!addition.isValid) return Future.value(WatchAdditionStatus.invalid);
    return transaction(() async {
      if (!await _handle(addition.id, now)) {
        return WatchAdditionStatus.duplicate;
      }
      final createdAt = addition.addedAt.isAfter(now) ? now : addition.addedAt;
      final productId = addition.productId;
      final name = addition.name?.trim();
      final product = productId == null
          ? null
          : await attachedDatabase.productsDao.getProduct(productId);
      if (product != null &&
          name != null &&
          product.nameKey == productNameKey(name)) {
        await attachedDatabase.entriesDao.addPortion(
          product,
          createdAt: createdAt,
          fromWatch: true,
        );
      } else {
        // Its id may name another product after a backup was restored.
        await attachedDatabase.entriesDao.insertEntry(
          name: name,
          amount: DirectAmount((addition.protein * 10).round() / 10),
          createdAt: createdAt,
          fromWatch: true,
        );
      }
      return WatchAdditionStatus.added;
    });
  }

  /// Deletes the entry of [deletion], unless it was already deleted: only
  /// if it still has the time the watch got, its id may name another entry
  /// after a backup was restored.
  ///
  /// The id of the deletion is saved with it: a deletion is made once, even
  /// sent again.
  Future<WatchDeletionStatus> deleteEntry(
    WatchDeletion deletion,
    DateTime now,
  ) {
    if (!deletion.isValid) return Future.value(WatchDeletionStatus.invalid);
    return transaction(() async {
      if (!await _handle(deletion.id, now)) {
        return WatchDeletionStatus.duplicate;
      }
      final entries = attachedDatabase.entriesDao;
      final entry = await entries.getEntry(deletion.entryId);
      if (entry == null || !entry.createdAt.isAtSameMomentAs(deletion.time)) {
        return WatchDeletionStatus.missing;
      }
      await entries.deleteEntry(entry.id);
      return WatchDeletionStatus.deleted;
    });
  }

  /// Saves [id], received at [now], and forgets the old ids. Returns false
  /// if it was already saved: the request was made.
  Future<bool> _handle(String id, DateTime now) async {
    final known = await (select(
      watchRequests,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (known != null) return false;
    await into(watchRequests)
        .insert(WatchRequestsCompanion.insert(id: id, handledAt: now));
    await (delete(watchRequests)
          ..where((r) => r.handledAt.isSmallerThanValue(now.subtract(keptFor))))
        .go();
    return true;
  }

  /// Ids of the additions and deletions made from [since] on.
  Stream<List<String>> watchHandledSince(DateTime since) =>
      (select(watchRequests)
            ..where((r) => r.handledAt.isBiggerOrEqualValue(since))
            ..orderBy([(r) => OrderingTerm.asc(r.handledAt)]))
          .map((r) => r.id)
          .watch();
}
