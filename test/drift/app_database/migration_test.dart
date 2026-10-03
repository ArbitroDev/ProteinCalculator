// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 does not corrupt data', () async {
    final oldEntriesData = [
      const v1.EntriesData(
        id: 1,
        name: 'Skyr',
        mode: 'perQuantity',
        proteinGrams: 15,
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
        createdAt: 1790000000,
        dayKey: 20261001,
      ),
    ];
    final expectedNewEntriesData = [
      const v2.EntriesData(
        id: 1,
        name: 'Skyr',
        mode: 'perQuantity',
        proteinGrams: 15,
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
        createdAt: 1790000000,
        dayKey: 20261001,
      ),
    ];

    final oldProductsData = [
      const v1.ProductsData(
        id: 1,
        name: 'Whey',
        nameKey: 'whey',
        mode: 'direct',
        proteinGrams: 24,
        useCount: 3,
        lastUsedAt: 1790000000,
        createdAt: 1780000000,
      ),
    ];
    // Existing products are not favorite.
    final expectedNewProductsData = [
      const v2.ProductsData(
        id: 1,
        name: 'Whey',
        nameKey: 'whey',
        mode: 'direct',
        proteinGrams: 24,
        useCount: 3,
        lastUsedAt: 1790000000,
        createdAt: 1780000000,
        isFavorite: 0,
      ),
    ];

    final oldAppSettingsData = [
      const v1.AppSettingsData(
        id: 1,
        dailyGoalGrams: 140,
        productSort: 'mostUsed',
      ),
    ];
    // Crash reports stay off until the user agrees.
    final expectedNewAppSettingsData = [
      const v2.AppSettingsData(
        id: 1,
        dailyGoalGrams: 140,
        productSort: 'mostUsed',
        crashReports: 0,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.entries, oldEntriesData);
        batch.insertAll(oldDb.products, oldProductsData);
        batch.insertAll(oldDb.appSettings, oldAppSettingsData);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.entries).get(), expectedNewEntriesData);
        expect(
          await newDb.select(newDb.products).get(),
          expectedNewProductsData,
        );
        expect(
          await newDb.select(newDb.appSettings).get(),
          expectedNewAppSettingsData,
        );
      },
    );
  });

  test('migration from v2 to v3 sets the part of the day of entries', () async {
    // Times in seconds since the epoch, as stored; parts of the day follow
    // the local time of the test machine.
    int at(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
    v2.EntriesData entry(int id, DateTime time) => v2.EntriesData(
      id: id,
      mode: 'direct',
      proteinGrams: 20,
      createdAt: at(time),
      dayKey: 20261001,
    );
    final times = {
      1: DateTime(2026, 10, 1, 8),
      2: DateTime(2026, 10, 1, 13),
      3: DateTime(2026, 10, 1, 20),
      4: DateTime(2026, 10, 2, 1, 30),
    };
    const slots = {1: 'morning', 2: 'afternoon', 3: 'evening', 4: 'evening'};

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.entries, [
          for (final MapEntry(key: id, value: time) in times.entries)
            entry(id, time),
        ]);
      },
      validateItems: (newDb) async {
        expect(await newDb.select(newDb.entries).get(), [
          for (final MapEntry(key: id, value: time) in times.entries)
            v3.EntriesData(
              id: id,
              mode: 'direct',
              proteinGrams: 20,
              createdAt: at(time),
              dayKey: 20261001,
              slot: slots[id]!,
            ),
        ]);
      },
    );
  });
}
