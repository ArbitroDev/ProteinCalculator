// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;

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

  test('migration from v4, the version of 1.0.0, to v7', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 7,
      createOld: v4.DatabaseAtV4.new,
      createNew: v7.DatabaseAtV7.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        v4.EntriesData entry(int id, int dayKey) => v4.EntriesData(
          id: id,
          name: 'Skyr',
          nameKey: 'skyr',
          mode: 'direct',
          proteinGrams: 20,
          createdAt: 1790000000 + id,
          dayKey: dayKey,
          slot: 'morning',
        );
        batch
          ..insertAll(oldDb.entries, [entry(1, 20260920), entry(2, 20260915)])
          ..insert(
            oldDb.products,
            const v4.ProductsData(
              id: 1,
              name: 'Skyr',
              nameKey: 'skyr',
              mode: 'direct',
              proteinGrams: 20,
              useCount: 2,
              createdAt: 1780000000,
              isFavorite: 1,
            ),
          )
          ..insert(
            oldDb.appSettings,
            const v4.AppSettingsData(
              id: 1,
              dailyGoalGrams: 140,
              productSort: 'mostUsed',
              crashReports: 1,
            ),
          );
      },
      validateItems: (newDb) async {
        // The goal counts from the first day with entries.
        final goal = await newDb.select(newDb.goalChanges).getSingle();
        expect(goal.dayKey, 20260915);
        expect(goal.grams, 140);

        final product = await newDb.select(newDb.products).getSingle();
        expect(product.routine, 'none');
        expect(product.routineMinutes, null);
        expect(product.isFavorite, 1);

        final settings = await newDb.select(newDb.appSettings).getSingle();
        expect(settings.dailyGoalGrams, 140);
        expect(settings.productSort, 'mostUsed');
        expect(settings.crashReports, 1);
        expect(settings.historyView, 'list');
        expect(settings.dayStartHour, 3);

        expect(await newDb.select(newDb.entries).get(), hasLength(2));
      },
    );
  });

  test(
    'migration from v7 to v8 keeps the entries, none from the watch',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 7,
        newVersion: 8,
        createOld: v7.DatabaseAtV7.new,
        createNew: v8.DatabaseAtV8.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(
            oldDb.entries,
            const v7.EntriesData(
              id: 1,
              name: 'Skyr',
              nameKey: 'skyr',
              mode: 'direct',
              proteinGrams: 20,
              createdAt: 1790000000,
              dayKey: 20260921,
              slot: 'morning',
            ),
          );
        },
        validateItems: (newDb) async {
          final entry = await newDb.select(newDb.entries).getSingle();
          expect(entry.name, 'Skyr');
          expect(entry.proteinGrams, 20);
          expect(entry.fromWatch, 0);
          expect(await newDb.select(newDb.watchRequests).get(), isEmpty);
        },
      );
    },
  );

  test(
    'migration from v8 to v9 keeps the settings, reminders turned off',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 8,
        newVersion: 9,
        createOld: v8.DatabaseAtV8.new,
        createNew: v9.DatabaseAtV9.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(
            oldDb.appSettings,
            const v8.AppSettingsData(
              id: 1,
              dailyGoalGrams: 140,
              productSort: 'mostUsed',
              dayStartHour: 5,
              historyView: 'calendar',
              crashReports: 1,
            ),
          );
        },
        validateItems: (newDb) async {
          final settings = await newDb.select(newDb.appSettings).getSingle();
          expect(settings.dailyGoalGrams, 140);
          expect(settings.productSort, 'mostUsed');
          expect(settings.dayStartHour, 5);
          expect(settings.historyView, 'calendar');
          expect(settings.crashReports, 1);
          expect(settings.slotReminders, 0);
        },
      );
    },
  );

  test('migration from v9, the version of 1.2.0, to v11 keeps the data, '
      'in grams and without barcodes', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 9,
      newVersion: 11,
      createOld: v9.DatabaseAtV9.new,
      createNew: v11.DatabaseAtV11.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insert(
            oldDb.entries,
            const v9.EntriesData(
              id: 1,
              name: 'Skyr',
              nameKey: 'skyr',
              mode: 'perQuantity',
              proteinGrams: 15,
              consumedGrams: 150,
              proteinPerReference: 10,
              referenceGrams: 100,
              createdAt: 1790000000,
              dayKey: 20260921,
              slot: 'morning',
              fromWatch: 0,
            ),
          )
          ..insert(
            oldDb.products,
            const v9.ProductsData(
              id: 1,
              name: 'Skyr',
              nameKey: 'skyr',
              mode: 'perQuantity',
              consumedGrams: 150,
              proteinPerReference: 10,
              referenceGrams: 100,
              useCount: 1,
              createdAt: 1790000000,
              isFavorite: 1,
              routine: 'none',
            ),
          );
      },
      validateItems: (newDb) async {
        final entry = await newDb.select(newDb.entries).getSingle();
        expect(entry.consumedGrams, 150);
        expect(entry.unit, 'grams');
        final product = await newDb.select(newDb.products).getSingle();
        expect(product.name, 'Skyr');
        expect(product.unit, 'grams');
        expect(product.barcode, equals(null));
        expect(await newDb.select(newDb.scannedProducts).get(), isEmpty);
        final settings = await newDb.select(newDb.appSettings).getSingle();
        expect(settings.savedProductsCollapsed, 0);
        expect(settings.recentScansCollapsed, 0);
      },
    );
  });
}
