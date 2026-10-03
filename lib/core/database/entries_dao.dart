import 'dart:math';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
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

  Stream<double> watchDayTotal(int dayKey) {
    final total = entries.proteinGrams.sum();
    final query = selectOnly(entries)
      ..addColumns([total])
      ..where(entries.dayKey.equals(dayKey));
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }

  /// Days having at least one entry, most recent first.
  ///
  /// The split by part of the day is computed in Dart from the local time of
  /// each entry: SQLite time zone support is unreliable on the web.
  Stream<List<DaySummary>> watchHistory() {
    final query = selectOnly(entries)
      ..addColumns([entries.dayKey, entries.createdAt, entries.proteinGrams])
      ..orderBy([OrderingTerm.desc(entries.dayKey)]);
    return query.watch().map((rows) {
      final days = <int, Map<DaySlot, double>>{};
      for (final row in rows) {
        final bySlot = days.putIfAbsent(row.read(entries.dayKey)!, () => {});
        final slot = DaySlot.of(row.read(entries.createdAt)!);
        bySlot[slot] = (bySlot[slot] ?? 0) + row.read(entries.proteinGrams)!;
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

  /// Adds an entry and counts a use of the product having the same name.
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
          mode: columns.mode,
          proteinGrams: amount.proteinGrams,
          consumedGrams: Value(columns.consumedGrams),
          proteinPerReference: Value(columns.proteinPerReference),
          referenceGrams: Value(columns.referenceGrams),
          createdAt: createdAt,
          dayKey: dayKeyOf(createdAt),
        ),
      );
      await _countUse(name, 1, usedAt: createdAt);
      return id;
    });
  }

  /// Saves the edited values of an existing entry. Its time and app day are
  /// kept, and use counts follow a name change.
  Future<void> updateEntry(Entry entry) {
    return transaction(() async {
      final previous = await getEntry(entry.id);
      if (previous == null) return;
      await update(entries).replace(
        entry.copyWith(createdAt: previous.createdAt, dayKey: previous.dayKey),
      );
      if (_nameKey(previous.name) != _nameKey(entry.name)) {
        await _countUse(previous.name, -1);
        await _countUse(entry.name, 1);
      }
    });
  }

  /// Deletes an entry and returns it, so the deletion can be undone with
  /// [restoreEntry].
  Future<Entry?> deleteEntry(int id) {
    return transaction(() async {
      final entry = await getEntry(id);
      if (entry == null) return null;
      await (delete(entries)..where((e) => e.id.equals(id))).go();
      await _countUse(entry.name, -1);
      return entry;
    });
  }

  /// Puts back an entry removed by [deleteEntry], with the same id.
  Future<void> restoreEntry(Entry entry) {
    return transaction(() async {
      await into(entries).insert(entry);
      await _countUse(entry.name, 1);
    });
  }

  String? _nameKey(String? name) {
    if (name == null) return null;
    final key = productNameKey(name);
    return key.isEmpty ? null : key;
  }

  Future<void> _countUse(String? name, int delta, {DateTime? usedAt}) async {
    final key = _nameKey(name);
    if (key == null) return;
    final product = await (select(
      products,
    )..where((p) => p.nameKey.equals(key))).getSingleOrNull();
    if (product == null) return;
    await (update(products)..where((p) => p.id.equals(product.id))).write(
      ProductsCompanion(
        useCount: Value(max(0, product.useCount + delta)),
        lastUsedAt: usedAt == null ? const Value.absent() : Value(usedAt),
      ),
    );
  }
}
