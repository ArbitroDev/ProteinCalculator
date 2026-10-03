import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
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

  /// Computes again the uses of the products named by [nameKeys].
  Future<void> _refreshUses(Set<String?> nameKeys) async {
    for (final key in nameKeys.nonNulls) {
      await attachedDatabase.refreshUses(key);
    }
  }
}
