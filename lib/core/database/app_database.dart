import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:protein_calculator/core/database/app_database.steps.dart';
import 'package:protein_calculator/core/database/database_file.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Entries, Products, AppSettings],
  daos: [EntriesDao, ProductsDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the database stored on the device.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'protein_calculator',
      // The path drift_flutter uses by default, given explicitly so the file
      // can be set aside when it cannot be opened.
      native: const DriftNativeOptions(databasePath: databasePath),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.appSettings, schema.appSettings.crashReports);
        await m.addColumn(schema.products, schema.products.isFavorite);
      },
      from2To3: (m, schema) async {
        await m.addColumn(schema.entries, schema.entries.slot);
        await _fillSlots();
      },
      from3To4: (m, schema) async {
        await m.addColumn(schema.entries, schema.entries.nameKey);
        await m.create(schema.entriesNameKey);
        await _fillNameKeys();
        await refreshUses();
      },
    ),
    beforeOpen: (details) async {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(id: const Value(SettingsDao.rowId)),
        mode: InsertMode.insertOrIgnore,
      );
    },
  );

  /// Sets the part of the day of every entry from the local time it was
  /// added, as it was shown until it was stored. Done in Dart: SQLite time
  /// zone support is unreliable on the web.
  Future<void> _fillSlots() async {
    final rows = await customSelect('SELECT id, created_at FROM entries').get();
    final ids = <DaySlot, List<int>>{};
    for (final row in rows) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at') * 1000,
      );
      ids.putIfAbsent(DaySlot.of(createdAt), () => []).add(row.read<int>('id'));
    }
    for (final MapEntry(key: slot, value: slotIds) in ids.entries) {
      // By batches, under the limit of SQLite on query variables.
      for (final batch in slotIds.slices(500)) {
        await customUpdate(
          'UPDATE entries SET slot = ? '
          'WHERE id IN (${List.filled(batch.length, '?').join(', ')})',
          variables: [
            Variable.withString(slot.name),
            for (final id in batch) Variable.withInt(id),
          ],
          updates: {entries},
        );
      }
    }
  }

  /// Sets the normalized name of every entry having a name. Done in Dart:
  /// the normalization folds accents, which SQLite cannot do.
  Future<void> _fillNameKeys() async {
    final rows = await customSelect(
      'SELECT id, name FROM entries WHERE name IS NOT NULL',
    ).get();
    for (final row in rows) {
      await customUpdate(
        'UPDATE entries SET name_key = ? WHERE id = ?',
        variables: [
          Variable(entryNameKey(row.read<String>('name'))),
          Variable.withInt(row.read<int>('id')),
        ],
        updates: {entries},
      );
    }
  }

  /// Computes again, from the entries, how many times products were used
  /// and when last: those named [nameKey] only, or all of them.
  Future<void> refreshUses([String? nameKey]) => customUpdate(
    'UPDATE products SET '
    'use_count = (SELECT COUNT(*) FROM entries e '
    'WHERE e.name_key = products.name_key), '
    'last_used_at = (SELECT MAX(e.created_at) FROM entries e '
    'WHERE e.name_key = products.name_key)'
    '${nameKey == null ? '' : ' WHERE name_key = ?'}',
    variables: [if (nameKey != null) Variable.withString(nameKey)],
    updates: {products},
  );
}

/// Normalized name of an entry, linking it to the product of the same name,
/// or null without a name.
String? entryNameKey(String? name) {
  if (name == null) return null;
  final key = productNameKey(name);
  return key.isEmpty ? null : key;
}
