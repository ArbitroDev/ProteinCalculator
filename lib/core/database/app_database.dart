import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
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
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(id: const Value(SettingsDao.rowId)),
        mode: InsertMode.insertOrIgnore,
      );
    },
  );
}
