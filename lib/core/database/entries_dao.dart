import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

part 'entries_dao.g.dart';

/// Protein total of one app day, split by part of the day.
@immutable
class DaySummary {
  const DaySummary({required this.dayKey, required this.bySlot});

  final int dayKey;

  /// Protein grams per part of the day; parts without entries are absent.
  final Map<DaySlot, double> bySlot;

  double get proteinGrams => bySlot.values.sum;

  @override
  bool operator ==(Object other) =>
      other is DaySummary &&
      other.dayKey == dayKey &&
      const MapEquality<DaySlot, double>().equals(other.bySlot, bySlot);

  @override
  int get hashCode =>
      Object.hash(dayKey, const MapEquality<DaySlot, double>().hash(bySlot));

  @override
  String toString() => 'DaySummary($dayKey, $bySlot)';
}

@DriftAccessor(tables: [Entries, Products])
class EntriesDao extends DatabaseAccessor<AppDatabase> with _$EntriesDaoMixin {
  EntriesDao(super.attachedDatabase);

  /// Days having at least one entry, most recent first, with their protein
  /// totals by part of the day, summed by the database.
  Stream<List<DaySummary>> watchHistory() {
    final total = entries.proteinGrams.sum();
    final query = selectOnly(entries)
      ..addColumns([entries.dayKey, entries.slot, total])
      ..groupBy([entries.dayKey, entries.slot])
      ..orderBy([OrderingTerm.desc(entries.dayKey)]);
    return query.watch().map((rows) {
      final days = <int, Map<DaySlot, double>>{};
      for (final row in rows) {
        days.putIfAbsent(row.read(entries.dayKey)!, () => {})[row
            .readWithConverter(entries.slot)!] = row.read(
          total,
        )!;
      }
      return [
        for (final MapEntry(key: dayKey, value: bySlot) in days.entries)
          DaySummary(dayKey: dayKey, bySlot: bySlot),
      ];
    });
  }

  /// Entries of one app day, in the order they were added.
  Stream<List<Entry>> watchDayEntries(int dayKey) {
    final query = select(entries)
      ..where((e) => e.dayKey.equals(dayKey))
      ..orderBy([
        (e) => OrderingTerm.asc(e.createdAt),
        (e) => OrderingTerm.asc(e.id),
      ]);
    return query.watch();
  }

  Future<Entry?> getEntry(int id) =>
      (select(entries)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Adds an entry, a use of the product having the same name.
  Future<int> insertEntry({
    String? name,
    required ProteinAmount amount,
    required DateTime createdAt,
  }) {
    final columns = amountColumns(amount);
    return transaction(() async {
      final id = await into(entries).insert(
        EntriesCompanion.insert(
          name: Value(name),
          nameKey: Value(entryNameKey(name)),
          mode: columns.mode,
          proteinGrams: amount.proteinGrams,
          consumedGrams: Value(columns.consumedGrams),
          proteinPerReference: Value(columns.proteinPerReference),
          referenceGrams: Value(columns.referenceGrams),
          createdAt: createdAt,
          dayKey: dayKeyOf(createdAt),
          slot: Value(DaySlot.of(createdAt)),
        ),
      );
      await attachedDatabase.refreshUses(entryNameKey(name));
      return id;
    });
  }

  /// Adds one portion of [product] at [createdAt], as the product says.
  Future<int> addPortion(Product product, {required DateTime createdAt}) =>
      insertEntry(
        name: product.name,
        amount: product.amount,
        createdAt: createdAt,
      );

  /// Saves the edited values of an existing entry. Its time, app day and
  /// part of the day are kept, and the uses of products follow a name change.
  Future<void> updateEntry(Entry entry) {
    return transaction(() async {
      final previous = await getEntry(entry.id);
      if (previous == null) return;
      final updated = entry.copyWith(
        nameKey: Value(entryNameKey(entry.name)),
        createdAt: previous.createdAt,
        dayKey: previous.dayKey,
        slot: previous.slot,
      );
      await update(entries).replace(updated);
      await _refreshUses({previous.nameKey, updated.nameKey});
    });
  }

  /// Deletes an entry and returns it, so the deletion can be undone with
  /// [restoreEntry].
  Future<Entry?> deleteEntry(int id) {
    return transaction(() async {
      final entry = await getEntry(id);
      if (entry == null) return null;
      await (delete(entries)..where((e) => e.id.equals(id))).go();
      await _refreshUses({entry.nameKey});
      return entry;
    });
  }

  /// Puts back an entry removed by [deleteEntry], with the same id.
  Future<void> restoreEntry(Entry entry) {
    return transaction(() async {
      await into(entries).insert(entry);
      await _refreshUses({entry.nameKey});
    });
  }

  /// Adds the entries of the products added automatically every day, for
  /// each of their times up to [now] not added yet, at that time: also those
  /// of the days the app was not opened.
  Future<void> addRoutineEntries(DateTime now) {
    return transaction(() async {
      final routines = await (select(
        products,
      )..where((p) => p.routine.equalsValue(DailyRoutine.autoAdd))).get();
      for (final product in routines) {
        final minutes = product.routineMinutes;
        if (minutes == null) continue;
        final times = routineTimesBetween(
          minutes,
          product.routineCheckedAt ?? now,
          now,
        );
        if (times.isEmpty) continue;
        for (final time in times) {
          await addPortion(product, createdAt: time);
        }
        await (update(products)..where((p) => p.id.equals(product.id))).write(
          ProductsCompanion(routineCheckedAt: Value(now)),
        );
      }
    });
  }

  /// Removes the entry the product [productId] added on its own at its
  /// latest time, after making the additions due up to [now] so it exists.
  /// Does nothing if the user already removed it.
  Future<void> removeRoutineEntry(int productId, DateTime now) {
    return transaction(() async {
      await addRoutineEntries(now);
      final product = await (select(
        products,
      )..where((p) => p.id.equals(productId))).getSingleOrNull();
      final minutes = product?.routineMinutes;
      if (product == null || minutes == null) return;
      final entry =
          await (select(entries)
                ..where(
                  (e) =>
                      e.nameKey.equals(product.nameKey) &
                      e.createdAt.equals(latestRoutineTime(minutes, now)),
                )
                ..limit(1))
              .getSingleOrNull();
      if (entry != null) await deleteEntry(entry.id);
    });
  }

  /// Computes again the uses of the products named by [nameKeys].
  Future<void> _refreshUses(Set<String?> nameKeys) async {
    for (final key in nameKeys.nonNulls) {
      await attachedDatabase.refreshUses(key);
    }
  }
}
