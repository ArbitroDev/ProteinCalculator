import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/barcode.dart';
import 'package:protein_calculator/core/domain/creatine.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';

/// Identifies Protein Calculator backup files.
const backupFormat = 'protein-calculator';

/// Version of the backup file layout, increased when it changes.
///
/// 2: entries hold their part of the day.
/// 3: products hold their daily routine.
/// 4: the goals set over time, how the history shows the days and the
/// start hour of the day.
/// 5: entries tell whether they were added on the watch.
/// 6: entries and products hold the unit of their quantities.
/// 7: products hold their barcode.
/// 8: entries and products hold their creatine doses, and the settings
/// whether creatine is tracked and the grams of one dose.
const backupVersion = 8;

/// Thrown when a file is not a valid Protein Calculator backup.
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.reason);

  final String reason;

  @override
  String toString() => 'InvalidBackupException: $reason';
}

/// Content of a backup file, checked and ready to be restored.
class Backup {
  const Backup({
    required this.entries,
    required this.products,
    required this.dailyGoal,
    required this.productSort,
    this.historyView = HistoryView.list,
    this.dayStartHour = defaultAppDayStartHour,
    this.goalChanges = const [],
    this.creatineEnabled = false,
    this.creatineDoseGrams,
  });

  final List<EntriesCompanion> entries;
  final List<ProductsCompanion> products;
  final double? dailyGoal;

  /// Goals set over time; empty in backups made before they were kept.
  final List<GoalChangesCompanion> goalChanges;
  final ProductSort productSort;
  final HistoryView historyView;
  final int dayStartHour;

  /// Whether creatine is tracked, and the grams of one dose; null until it
  /// was first turned on.
  final bool creatineEnabled;
  final double? creatineDoseGrams;
}

/// File name suggested for a backup made on [date].
String backupFileName(DateTime date) =>
    'protein-calculator-${date.toIso8601String().substring(0, 10)}.json';

/// Every entry, product and setting, as a JSON backup file.
Future<String> exportBackup(AppDatabase db, DateTime now) async {
  final entries = await db.select(db.entries).get();
  final products = await db.select(db.products).get();
  final settings = await (db.select(
    db.appSettings,
  )..where((s) => s.id.equals(SettingsDao.rowId))).getSingle();
  final goalChanges = await db.select(db.goalChanges).get();

  return const JsonEncoder.withIndent('  ').convert({
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': now.toUtc().toIso8601String(),
    'settings': {
      'dailyGoalGrams': settings.dailyGoalGrams,
      'productSort': settings.productSort.name,
      'historyView': settings.historyView.name,
      'dayStartHour': settings.dayStartHour,
      'creatineEnabled': settings.creatineEnabled,
      'creatineDoseGrams': settings.creatineDoseGrams,
    },
    'goalChanges': [
      for (final g in goalChanges) {'dayKey': g.dayKey, 'grams': g.grams},
    ],
    'entries': [
      for (final e in entries)
        {
          'id': e.id,
          'name': e.name,
          'mode': e.mode.name,
          'proteinGrams': e.proteinGrams,
          'consumedGrams': e.consumedGrams,
          'proteinPerReference': e.proteinPerReference,
          'referenceGrams': e.referenceGrams,
          'unit': e.unit.name,
          'createdAt': e.createdAt.toUtc().toIso8601String(),
          'dayKey': e.dayKey,
          'slot': e.slot.name,
          'fromWatch': e.fromWatch,
          'creatineDoses': e.creatineDoses,
          'creatineDoseGrams': e.creatineDoseGrams,
        },
    ],
    'products': [
      for (final p in products)
        {
          'id': p.id,
          'name': p.name,
          'mode': p.mode.name,
          'proteinGrams': p.proteinGrams,
          'consumedGrams': p.consumedGrams,
          'proteinPerReference': p.proteinPerReference,
          'referenceGrams': p.referenceGrams,
          'unit': p.unit.name,
          'useCount': p.useCount,
          'lastUsedAt': p.lastUsedAt?.toUtc().toIso8601String(),
          'createdAt': p.createdAt.toUtc().toIso8601String(),
          'isFavorite': p.isFavorite,
          'routine': p.routine.name,
          'routineMinutes': p.routineMinutes,
          'barcode': p.barcode,
          'creatineDoses': p.creatineDoses,
        },
    ],
  });
}

/// Reads a backup file. Throws [InvalidBackupException] if it is not a
/// valid Protein Calculator backup.
///
/// Values follow the rules of the forms, so a damaged or hand-edited file
/// cannot bring data the app was never meant to show.
Backup parseBackup(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['format'] != backupFormat) {
      throw const InvalidBackupException('not a Protein Calculator backup');
    }
    final version = json['version'];
    if (version is! int || version < 1 || version > backupVersion) {
      throw const InvalidBackupException('unsupported version');
    }

    final settings = json['settings'] as Map<String, dynamic>;
    final entries = [
      for (final e in json['entries'] as List)
        _entry(e as Map<String, dynamic>, version),
    ];
    final products = [
      for (final p in json['products'] as List)
        _product(p as Map<String, dynamic>, version),
    ];
    if (!_unique(entries.map((e) => e.id.value))) {
      throw const InvalidBackupException('duplicate entry ids');
    }
    if (!_unique(products.map((p) => p.id.value))) {
      throw const InvalidBackupException('duplicate product ids');
    }
    if (!_unique(products.map((p) => p.nameKey.value))) {
      throw const InvalidBackupException('duplicate product names');
    }
    if (!_unique(products.map((p) => p.barcode.value).nonNulls)) {
      throw const InvalidBackupException('duplicate barcodes');
    }
    if (products.where((p) => p.isFavorite.value).length > 1) {
      throw const InvalidBackupException('several favorite products');
    }

    final dailyGoal = _optionalDouble(settings['dailyGoalGrams']);
    if (dailyGoal != null && !isValidDailyGoal(dailyGoal)) {
      throw const InvalidBackupException('daily goal out of range');
    }
    // Absent from backups made before the start hour could be chosen.
    final dayStartHour =
        settings['dayStartHour'] as int? ?? defaultAppDayStartHour;
    if (!isValidAppDayStartHour(dayStartHour)) {
      throw const InvalidBackupException('invalid start hour');
    }
    // Absent from backups made before creatine was tracked: off, never
    // turned on.
    final creatineEnabled = version >= 8 && settings['creatineEnabled'] as bool;
    final creatineDoseGrams = version < 8
        ? null
        : _optionalDouble(settings['creatineDoseGrams']);
    if ((creatineDoseGrams != null &&
            !isValidCreatineDoseGrams(creatineDoseGrams)) ||
        (creatineEnabled && creatineDoseGrams == null)) {
      throw const InvalidBackupException('invalid creatine dose');
    }
    final goalChanges = [
      for (final g in json['goalChanges'] as List? ?? const [])
        _goalChange(g as Map<String, dynamic>),
    ];
    if (!_unique(goalChanges.map((g) => g.dayKey.value))) {
      throw const InvalidBackupException('duplicate goal days');
    }

    return Backup(
      entries: entries,
      products: products,
      dailyGoal: dailyGoal,
      productSort: ProductSort.values.byName(settings['productSort'] as String),
      // Absent from backups made before the calendar existed.
      historyView: HistoryView.values.byName(
        settings['historyView'] as String? ?? HistoryView.list.name,
      ),
      dayStartHour: dayStartHour,
      goalChanges: goalChanges,
      creatineEnabled: creatineEnabled,
      creatineDoseGrams: creatineDoseGrams,
    );
  } on InvalidBackupException {
    rethrow;
  } on Object catch (error) {
    // Malformed JSON, missing field, wrong type or unknown value.
    throw InvalidBackupException('$error');
  }
}

/// Replaces all data with the content of [backup], in a single transaction:
/// either everything is restored, or nothing changes.
///
/// Daily routines start again from [now] (the current time by default):
/// the products added automatically are not added for the days between the
/// backup and its restoration.
Future<void> restoreBackup(
  AppDatabase db,
  Backup backup, {
  DateTime? now,
}) async {
  final checkedAt = now ?? DateTime.now();
  await db.transaction(() async {
    await db.delete(db.entries).go();
    await db.delete(db.products).go();
    await db.delete(db.goalChanges).go();
    await db.batch((batch) {
      batch
        ..insertAll(db.entries, backup.entries)
        ..insertAll(db.products, [
          for (final product in backup.products)
            product.routine.value == DailyRoutine.none
                ? product
                : product.copyWith(routineCheckedAt: Value(checkedAt)),
        ]);
    });
    final goal = backup.dailyGoal;
    if (backup.goalChanges.isNotEmpty) {
      await db.batch(
        (batch) => batch.insertAll(db.goalChanges, backup.goalChanges),
      );
    } else if (goal != null) {
      // Backups made before goals were kept over time: the goal counts from
      // the first day with entries.
      final first = backup.entries.map((e) => e.dayKey.value).minOrNull;
      await db
          .into(db.goalChanges)
          .insert(
            GoalChangesCompanion.insert(
              dayKey: Value(first ?? dayKeyOf(checkedAt)),
              grams: goal,
            ),
          );
    }
    // Uses follow the restored entries, whatever the file says.
    await db.refreshUses();
    // The barcodes of the products replaced make recent scans again.
    await db.scansDao.keepRecent();
    await (db.update(
      db.appSettings,
    )..where((s) => s.id.equals(SettingsDao.rowId))).write(
      AppSettingsCompanion(
        dailyGoalGrams: backup.dailyGoal == null
            ? const Value.absent()
            : Value(backup.dailyGoal),
        productSort: Value(backup.productSort),
        historyView: Value(backup.historyView),
        dayStartHour: Value(backup.dayStartHour),
        creatineEnabled: Value(backup.creatineEnabled),
        creatineDoseGrams: Value(backup.creatineDoseGrams),
      ),
    );
  });
  appDayStartHour = backup.dayStartHour;
}

GoalChangesCompanion _goalChange(Map<String, dynamic> g) {
  final dayKey = g['dayKey'] as int;
  if (!isValidDayKey(dayKey)) throw const InvalidBackupException('invalid day');
  final grams = (g['grams'] as num).toDouble();
  if (!isValidDailyGoal(grams)) {
    throw const InvalidBackupException('daily goal out of range');
  }
  return GoalChangesCompanion.insert(dayKey: Value(dayKey), grams: grams);
}

EntriesCompanion _entry(Map<String, dynamic> e, int version) {
  final doses = _creatineDoses(e, version);
  // Absent from backups made before creatine was tracked.
  final doseGrams = version < 8
      ? null
      : _optionalDouble(e['creatineDoseGrams']);
  if ((doses > 0) != (doseGrams != null) ||
      (doseGrams != null && !isValidCreatineDoseGrams(doseGrams))) {
    throw const InvalidBackupException('invalid creatine dose');
  }
  final amount = _amount(e, storesProtein: true, creatineDoses: doses);
  final columns = amountColumns(amount);
  final dayKey = e['dayKey'] as int;
  if (!isValidDayKey(dayKey)) throw const InvalidBackupException('invalid day');
  final name = e['name'] as String?;
  if (name != null && !isValidName(name)) {
    throw const InvalidBackupException('invalid entry name');
  }
  final createdAt = DateTime.parse(e['createdAt'] as String).toLocal();
  return EntriesCompanion.insert(
    id: Value(_id(e['id'])),
    name: Value(name),
    nameKey: Value(entryNameKey(name)),
    mode: columns.mode,
    proteinGrams: amount.proteinGrams,
    consumedGrams: Value(columns.consumedGrams),
    proteinPerReference: Value(columns.proteinPerReference),
    referenceGrams: Value(columns.referenceGrams),
    unit: Value(columns.unit),
    createdAt: createdAt,
    dayKey: dayKey,
    // Backups made before the part of the day was stored: computed from the
    // local time, as it was shown then.
    slot: Value(
      version < 2
          ? DaySlot.of(createdAt)
          : DaySlot.values.byName(e['slot'] as String),
    ),
    fromWatch: Value(version < 5 ? false : e['fromWatch'] as bool),
    creatineDoses: Value(doses),
    creatineDoseGrams: Value(doseGrams),
  );
}

ProductsCompanion _product(Map<String, dynamic> p, int version) {
  final name = p['name'] as String;
  if (!isValidName(name)) {
    throw const InvalidBackupException('invalid product name');
  }
  final doses = _creatineDoses(p, version);
  final columns = amountColumns(
    _amount(p, storesProtein: false, creatineDoses: doses),
  );
  final useCount = p['useCount'] as int;
  if (useCount < 0) throw const InvalidBackupException('negative use count');
  final lastUsedAt = p['lastUsedAt'] as String?;
  // Absent from backups made before routines existed.
  final routine = DailyRoutine.values.byName(
    p['routine'] as String? ?? DailyRoutine.none.name,
  );
  final routineMinutes = p['routineMinutes'] as int?;
  if ((routine == DailyRoutine.none) != (routineMinutes == null) ||
      (routineMinutes != null && !isValidRoutineMinutes(routineMinutes))) {
    throw const InvalidBackupException('invalid daily routine');
  }
  // Absent from backups made before barcodes existed.
  final barcode = p['barcode'] as String?;
  if (barcode != null && !isNormalizedBarcode(barcode)) {
    throw const InvalidBackupException('invalid barcode');
  }
  return ProductsCompanion.insert(
    id: Value(_id(p['id'])),
    name: name,
    nameKey: productNameKey(name),
    mode: columns.mode,
    proteinGrams: Value(columns.directGrams),
    consumedGrams: Value(columns.consumedGrams),
    proteinPerReference: Value(columns.proteinPerReference),
    referenceGrams: Value(columns.referenceGrams),
    unit: Value(columns.unit),
    useCount: Value(useCount),
    lastUsedAt: Value(
      lastUsedAt == null ? null : DateTime.parse(lastUsedAt).toLocal(),
    ),
    createdAt: DateTime.parse(p['createdAt'] as String).toLocal(),
    // Absent from backups made before favorites existed.
    isFavorite: Value(p['isFavorite'] as bool? ?? false),
    routine: Value(routine),
    routineMinutes: Value(routineMinutes),
    barcode: Value(barcode),
    creatineDoses: Value(doses),
  );
}

/// Creatine doses of an entry or a product; none in backups made before
/// creatine was tracked.
int _creatineDoses(Map<String, dynamic> json, int version) {
  if (version < 8) return 0;
  final doses = json['creatineDoses'] as int;
  if (!isValidCreatineDoses(doses)) {
    throw const InvalidBackupException('invalid creatine doses');
  }
  return doses;
}

/// Protein amount of an entry or a product, following the rules of the
/// form: protein amounts with one decimal at most, zero only with
/// [creatineDoses], whole grams or milliliters of food, a protein content
/// not above the reference quantity, and nothing from the other mode.
///
/// In "per quantity" mode, an entry also stores the protein it amounts to
/// ([storesProtein]); it is computed again rather than read.
ProteinAmount _amount(
  Map<String, dynamic> json, {
  required bool storesProtein,
  required int creatineDoses,
}) {
  final mode = EntryMode.values.byName(json['mode'] as String);
  final protein = _optionalDouble(json['proteinGrams']);
  final consumed = _optionalDouble(json['consumedGrams']);
  final perReference = _optionalDouble(json['proteinPerReference']);
  final reference = _optionalDouble(json['referenceGrams']);
  // Absent from backups made before milliliters existed.
  final unit = QuantityUnit.values.byName(
    json['unit'] as String? ?? QuantityUnit.grams.name,
  );
  switch (mode) {
    case EntryMode.direct:
      if (protein != null &&
          isValidEntryProtein(protein, creatineDoses: creatineDoses) &&
          consumed == null &&
          perReference == null &&
          reference == null) {
        return DirectAmount(protein);
      }
    case EntryMode.perQuantity:
      if ((protein != null) == storesProtein &&
          consumed != null &&
          isValidFoodGrams(consumed) &&
          perReference != null &&
          isValidEntryProtein(perReference, creatineDoses: creatineDoses) &&
          reference != null &&
          isValidFoodGrams(reference) &&
          perReference <= reference) {
        return PerQuantityAmount(
          consumedGrams: consumed,
          proteinPerReference: perReference,
          referenceGrams: reference,
          unit: unit,
        );
      }
  }
  throw const InvalidBackupException('invalid protein amount');
}

int _id(Object? value) {
  final id = value as int;
  if (id <= 0) throw const InvalidBackupException('invalid id');
  return id;
}

double? _optionalDouble(Object? value) => (value as num?)?.toDouble();

bool _unique(Iterable<Object?> values) {
  final list = values.toList();
  return list.toSet().length == list.length;
}
