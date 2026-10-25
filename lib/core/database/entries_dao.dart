import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/creatine.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

part 'entries_dao.g.dart';

/// Protein total of one app day, split by part of the day, and its creatine
/// doses.
@immutable
class DaySummary {
  const DaySummary({
    required this.dayKey,
    required this.bySlot,
    this.creatineDoses = 0,
  });

  final int dayKey;

  /// Protein grams per part of the day; parts without entries are absent.
  final Map<DaySlot, double> bySlot;

  /// Creatine doses of all the entries of the day.
  final int creatineDoses;

  double get proteinGrams => bySlot.values.sum;

  @override
  bool operator ==(Object other) =>
      other is DaySummary &&
      other.dayKey == dayKey &&
      const MapEquality<DaySlot, double>().equals(other.bySlot, bySlot) &&
      other.creatineDoses == creatineDoses;

  @override
  int get hashCode => Object.hash(
    dayKey,
    const MapEquality<DaySlot, double>().hash(bySlot),
    creatineDoses,
  );

  @override
  String toString() => 'DaySummary($dayKey, $bySlot, $creatineDoses doses)';
}

@DriftAccessor(tables: [Entries, Products])
class EntriesDao extends DatabaseAccessor<AppDatabase> with _$EntriesDaoMixin {
  EntriesDao(super.attachedDatabase);

  /// Days having at least one entry, most recent first, with their protein
  /// totals by part of the day and their creatine doses, summed by the
  /// database.
  Stream<List<DaySummary>> watchHistory() {
    final total = entries.proteinGrams.sum();
    final doses = entries.creatineDoses.sum();
    final query = selectOnly(entries)
      ..addColumns([entries.dayKey, entries.slot, total, doses])
      ..groupBy([entries.dayKey, entries.slot])
      ..orderBy([OrderingTerm.desc(entries.dayKey)]);
    return query.watch().map((rows) {
      final days = <int, Map<DaySlot, double>>{};
      final dosesByDay = <int, int>{};
      for (final row in rows) {
        final dayKey = row.read(entries.dayKey)!;
        days.putIfAbsent(dayKey, () => {})[row.readWithConverter(
          entries.slot,
        )!] = row.read(
          total,
        )!;
        dosesByDay[dayKey] = (dosesByDay[dayKey] ?? 0) + row.read(doses)!;
      }
      return [
        for (final MapEntry(key: dayKey, value: bySlot) in days.entries)
          DaySummary(
            dayKey: dayKey,
            bySlot: bySlot,
            creatineDoses: dosesByDay[dayKey]!,
          ),
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

  /// Entries of the app days from [fromKey] to [toKey] included, in the
  /// order they were added.
  Stream<List<Entry>> watchEntriesBetween(int fromKey, int toKey) {
    final query = select(entries)
      ..where((e) => e.dayKey.isBetweenValues(fromKey, toKey))
      ..orderBy([
        (e) => OrderingTerm.asc(e.createdAt),
        (e) => OrderingTerm.asc(e.id),
      ]);
    return query.watch();
  }

  /// Parts of the days from [dayKey] onwards having at least one entry of
  /// protein, as `(dayKey, slot)`: creatine taken on its own does not fill
  /// them.
  Future<Set<(int, DaySlot)>> filledSlotsFrom(int dayKey) async {
    final query = selectOnly(entries, distinct: true)
      ..addColumns([entries.dayKey, entries.slot])
      ..where(
        entries.dayKey.isBiggerOrEqualValue(dayKey) &
            entries.proteinGrams.isBiggerThanValue(0),
      );
    return {
      for (final row in await query.get())
        (row.read(entries.dayKey)!, row.readWithConverter(entries.slot)!),
    };
  }

  Future<Entry?> getEntry(int id) =>
      (select(entries)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Adds an entry, a use of the product having the same name. Its
  /// [creatineDoses] take the grams of the dose in force.
  Future<int> insertEntry({
    String? name,
    required ProteinAmount amount,
    required DateTime createdAt,
    bool fromWatch = false,
    int creatineDoses = 0,
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
          unit: Value(columns.unit),
          createdAt: createdAt,
          dayKey: dayKeyOf(createdAt),
          slot: Value(DaySlot.of(createdAt)),
          fromWatch: Value(fromWatch),
          creatineDoses: Value(creatineDoses),
          creatineDoseGrams: Value(
            creatineDoses > 0 ? await _creatineDoseGrams() : null,
          ),
        ),
      );
      await attachedDatabase.refreshUses(entryNameKey(name));
      return id;
    });
  }

  /// Grams of one creatine dose, for the doses added now.
  Future<double> _creatineDoseGrams() async =>
      (await attachedDatabase.settingsDao.getCreatine()).doseGrams ??
      defaultCreatineDoseGrams;

  /// Adds one creatine dose taken on its own: an entry without a name nor
  /// protein.
  Future<int> addCreatineDose({required DateTime createdAt}) => insertEntry(
    amount: const DirectAmount(0),
    createdAt: createdAt,
    creatineDoses: 1,
  );

  /// Adds one portion of [product] at [createdAt], as the product says.
  Future<int> addPortion(
    Product product, {
    required DateTime createdAt,
    bool fromWatch = false,
  }) => insertEntry(
    name: product.name,
    amount: product.amount,
    createdAt: createdAt,
    fromWatch: fromWatch,
    creatineDoses: product.creatineDoses,
  );

  /// Saves the edited values of an existing entry, and the uses of products
  /// follow a name change. Its time, app day and part of the day are kept,
  /// unless [createdAt] moves it to another minute, as times are picked:
  /// they then follow it. Its creatine doses keep the grams of their dose,
  /// or take the dose in force if they had none.
  Future<void> updateEntry(Entry entry, {DateTime? createdAt}) {
    return transaction(() async {
      final previous = await getEntry(entry.id);
      if (previous == null) return;
      final time =
          createdAt != null && !_sameMinute(createdAt, previous.createdAt)
          ? createdAt
          : previous.createdAt;
      final moved = time != previous.createdAt;
      final updated = entry.copyWith(
        nameKey: Value(entryNameKey(entry.name)),
        createdAt: time,
        dayKey: moved ? dayKeyOf(time) : previous.dayKey,
        slot: moved ? DaySlot.of(time) : previous.slot,
        creatineDoseGrams: Value(
          entry.creatineDoses == 0
              ? null
              : entry.creatineDoseGrams ?? await _creatineDoseGrams(),
        ),
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
      final routines = await attachedDatabase.productsDao.getAutoAdds();
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

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  /// Computes again the uses of the products named by [nameKeys].
  Future<void> _refreshUses(Set<String?> nameKeys) async {
    for (final key in nameKeys.nonNulls) {
      await attachedDatabase.refreshUses(key);
    }
  }
}
