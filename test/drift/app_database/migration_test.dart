// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

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

  test('migration from v3 to v4 links entries and counts uses', () async {
    v3.EntriesData entry(int id, String? name, int createdAt) => v3.EntriesData(
      id: id,
      name: name,
      mode: 'direct',
      proteinGrams: 20,
      createdAt: createdAt,
      dayKey: 20261001,
      slot: 'morning',
    );
    // Counts left wrong by the previous versions.
    const product = v3.ProductsData(
      id: 1,
      name: 'Pâté',
      nameKey: 'pate',
      mode: 'direct',
      proteinGrams: 10,
      useCount: 5,
      lastUsedAt: 1790000500,
      createdAt: 1780000000,
      isFavorite: 0,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.entries, [
            entry(1, 'Pâté', 1790000000),
            entry(2, ' PATE ', 1790000100),
            entry(3, 'Skyr', 1790000200),
            entry(4, null, 1790000300),
          ])
          ..insert(oldDb.products, product);
      },
      validateItems: (newDb) async {
        expect(
          (await newDb.select(newDb.entries).get()).map((e) => e.nameKey),
          ['pate', 'pate', 'skyr', null],
        );
        final counted = await newDb.select(newDb.products).getSingle();
        expect(counted.useCount, 2);
        expect(counted.lastUsedAt, 1790000100);
      },
    );
  });

  test('migration from v2 to v4, the version of the first testers', () async {
    final morning = DateTime(2026, 10, 1, 8).millisecondsSinceEpoch ~/ 1000;
    final evening = DateTime(2026, 10, 1, 20).millisecondsSinceEpoch ~/ 1000;

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 4,
      createOld: v2.DatabaseAtV2.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.entries, [
            v2.EntriesData(
              id: 1,
              name: 'Œufs',
              mode: 'direct',
              proteinGrams: 12,
              createdAt: morning,
              dayKey: 20261001,
            ),
            v2.EntriesData(
              id: 2,
              mode: 'direct',
              proteinGrams: 30,
              createdAt: evening,
              dayKey: 20261001,
            ),
          ])
          ..insert(
            oldDb.products,
            const v2.ProductsData(
              id: 1,
              name: 'Oeufs',
              nameKey: 'oeufs',
              mode: 'direct',
              proteinGrams: 12,
              useCount: 0,
              createdAt: 1780000000,
              isFavorite: 0,
            ),
          );
      },
      validateItems: (newDb) async {
        final entries = await newDb.select(newDb.entries).get();
        expect(entries.map((e) => (e.slot, e.nameKey)), [
          ('morning', 'oeufs'),
          ('evening', null),
        ]);
        final product = await newDb.select(newDb.products).getSingle();
        expect(product.useCount, 1);
        expect(product.lastUsedAt, morning);
      },
    );
  });
}
