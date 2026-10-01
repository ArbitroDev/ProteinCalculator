import 'dart:math';

import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';

part 'entries_dao.g.dart';

/// Protein total of one app day.
typedef DaySummary = ({int dayKey, double proteinGrams});

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
  Stream<List<DaySummary>> watchHistory() {
    final total = entries.proteinGrams.sum();
    final query = selectOnly(entries)
      ..addColumns([entries.dayKey, total])
      ..groupBy([entries.dayKey])
      ..orderBy([OrderingTerm.desc(entries.dayKey)]);
    return query
        .map(
          (row) => (
            dayKey: row.read(entries.dayKey)!,
            proteinGrams: row.read(total) ?? 0,
          ),
        )
        .watch();
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
    required EntryMode mode,
    required double proteinGrams,
    double? consumedGrams,
    double? proteinPerReference,
    double? referenceGrams,
    required DateTime createdAt,
  }) {
    return transaction(() async {
      final id = await into(entries).insert(
        EntriesCompanion.insert(
          name: Value(name),
          mode: mode,
          proteinGrams: proteinGrams,
          consumedGrams: Value(consumedGrams),
          proteinPerReference: Value(proteinPerReference),
          referenceGrams: Value(referenceGrams),
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
