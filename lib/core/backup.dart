import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

/// Identifies Protein Calculator backup files.
const backupFormat = 'protein-calculator';

/// Version of the backup file layout, increased when it changes.
///
/// 2: entries hold their part of the day.
const backupVersion = 2;

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
  });

  final List<EntriesCompanion> entries;
  final List<ProductsCompanion> products;
  final double? dailyGoal;
  final ProductSort productSort;
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

  return const JsonEncoder.withIndent('  ').convert({
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': now.toUtc().toIso8601String(),
    'settings': {
      'dailyGoalGrams': settings.dailyGoalGrams,
      'productSort': settings.productSort.name,
    },
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
          'createdAt': e.createdAt.toUtc().toIso8601String(),
          'dayKey': e.dayKey,
          'slot': e.slot.name,
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
          'useCount': p.useCount,
          'lastUsedAt': p.lastUsedAt?.toUtc().toIso8601String(),
          'createdAt': p.createdAt.toUtc().toIso8601String(),
          'isFavorite': p.isFavorite,
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
        _product(p as Map<String, dynamic>),
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
    if (products.where((p) => p.isFavorite.value).length > 1) {
      throw const InvalidBackupException('several favorite products');
    }

    final dailyGoal = _optionalDouble(settings['dailyGoalGrams']);
    if (dailyGoal != null && !isValidDailyGoal(dailyGoal)) {
      throw const InvalidBackupException('daily goal out of range');
    }

    return Backup(
      entries: entries,
      products: products,
      dailyGoal: dailyGoal,
      productSort: ProductSort.values.byName(settings['productSort'] as String),
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
Future<void> restoreBackup(AppDatabase db, Backup backup) {
  return db.transaction(() async {
    await db.delete(db.entries).go();
    await db.delete(db.products).go();
    await db.batch((batch) {
      batch
        ..insertAll(db.entries, backup.entries)
        ..insertAll(db.products, backup.products);
    });
    await (db.update(
      db.appSettings,
    )..where((s) => s.id.equals(SettingsDao.rowId))).write(
      AppSettingsCompanion(
        dailyGoalGrams: backup.dailyGoal == null
            ? const Value.absent()
            : Value(backup.dailyGoal),
        productSort: Value(backup.productSort),
      ),
    );
  });
}

EntriesCompanion _entry(Map<String, dynamic> e, int version) {
  final amount = _amount(e, storesProtein: true);
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
    mode: columns.mode,
    proteinGrams: amount.proteinGrams,
    consumedGrams: Value(columns.consumedGrams),
    proteinPerReference: Value(columns.proteinPerReference),
    referenceGrams: Value(columns.referenceGrams),
    createdAt: createdAt,
    dayKey: dayKey,
    // Backups made before the part of the day was stored: computed from the
    // local time, as it was shown then.
    slot: Value(
      version < 2
          ? DaySlot.of(createdAt)
          : DaySlot.values.byName(e['slot'] as String),
    ),
  );
}

ProductsCompanion _product(Map<String, dynamic> p) {
  final name = p['name'] as String;
  if (!isValidName(name)) {
    throw const InvalidBackupException('invalid product name');
  }
  final columns = amountColumns(_amount(p, storesProtein: false));
  final useCount = p['useCount'] as int;
  if (useCount < 0) throw const InvalidBackupException('negative use count');
  final lastUsedAt = p['lastUsedAt'] as String?;
  return ProductsCompanion.insert(
    id: Value(_id(p['id'])),
    name: name,
    nameKey: productNameKey(name),
    mode: columns.mode,
    proteinGrams: Value(columns.directGrams),
    consumedGrams: Value(columns.consumedGrams),
    proteinPerReference: Value(columns.proteinPerReference),
    referenceGrams: Value(columns.referenceGrams),
    useCount: Value(useCount),
    lastUsedAt: Value(
      lastUsedAt == null ? null : DateTime.parse(lastUsedAt).toLocal(),
    ),
    createdAt: DateTime.parse(p['createdAt'] as String).toLocal(),
    // Absent from backups made before favorites existed.
    isFavorite: Value(p['isFavorite'] as bool? ?? false),
  );
}

/// Protein amount of an entry or a product, following the rules of the
/// form: protein amounts with one decimal at most, whole grams of food, a
/// protein content not above the reference quantity, and nothing from the
/// other mode.
///
/// In "per quantity" mode, an entry also stores the protein it amounts to
/// ([storesProtein]); it is computed again rather than read.
ProteinAmount _amount(
  Map<String, dynamic> json, {
  required bool storesProtein,
}) {
  final mode = EntryMode.values.byName(json['mode'] as String);
  final protein = _optionalDouble(json['proteinGrams']);
  final consumed = _optionalDouble(json['consumedGrams']);
  final perReference = _optionalDouble(json['proteinPerReference']);
  final reference = _optionalDouble(json['referenceGrams']);
  switch (mode) {
    case EntryMode.direct:
      if (protein != null &&
          isValidProteinGrams(protein) &&
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
          isValidProteinGrams(perReference) &&
          reference != null &&
          isValidFoodGrams(reference) &&
          perReference <= reference) {
        return PerQuantityAmount(
          consumedGrams: consumed,
          proteinPerReference: perReference,
          referenceGrams: reference,
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
