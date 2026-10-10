import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/backup.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

import '../helpers.dart';

/// Entries or products of a backup as JSON, to change them in tests.
List<Map<String, dynamic>> rows(Map<String, dynamic> json, String key) =>
    (json[key] as List).cast<Map<String, dynamic>>();

void main() {
  late AppDatabase source;

  setUp(() async {
    source = openTestDatabase();
    addTearDown(source.close);
    await source.settingsDao.setDailyGoal(140);
    await source.settingsDao.setProductSort(ProductSort.mostUsed);
    await source.productsDao.insertProduct(
      name: 'Skyr nature',
      amount: const PerQuantityAmount(
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
      ),
      createdAt: DateTime(2026, 9, 1),
    );
    await source.entriesDao.insertEntry(
      name: 'Skyr nature',
      amount: const PerQuantityAmount(
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
      ),
      createdAt: DateTime(2026, 10, 1, 1, 10),
    );
    await source.entriesDao.insertEntry(
      amount: const DirectAmount(25),
      createdAt: DateTime(2026, 10, 1, 12),
    );
  });

  Future<String> export() => exportBackup(source, DateTime(2026, 10, 1, 13));

  test('restores exactly what was exported', () async {
    final target = openTestDatabase();
    addTearDown(target.close);

    await restoreBackup(target, parseBackup(await export()));

    expect(
      await target.select(target.entries).get(),
      await source.select(source.entries).get(),
    );
    expect(
      await target.select(target.products).get(),
      await source.select(source.products).get(),
    );
    expect(await target.settingsDao.getDailyGoal(), 140);
    expect(
      await target.settingsDao.watchProductSort().first,
      ProductSort.mostUsed,
    );
  });

  test('replaces the data already present', () async {
    final target = openTestDatabase();
    addTearDown(target.close);
    await target.entriesDao.insertEntry(
      name: 'Old',
      amount: const DirectAmount(99),
      createdAt: DateTime(2026, 1, 1, 12),
    );
    await target.productsDao.insertProduct(
      name: 'Old product',
      amount: const DirectAmount(5),
      createdAt: DateTime(2026, 1, 1),
    );

    await restoreBackup(target, parseBackup(await export()));

    final entries = await target.select(target.entries).get();
    final products = await target.select(target.products).get();
    expect(entries.map((e) => e.name), ['Skyr nature', null]);
    expect(products.map((p) => p.name), ['Skyr nature']);
  });

  test('counts the uses of products from the restored entries', () async {
    final json = jsonDecode(await export()) as Map<String, dynamic>;
    rows(json, 'products').first
      ..['useCount'] = 42
      ..['lastUsedAt'] = null;
    final target = openTestDatabase();
    addTearDown(target.close);

    await restoreBackup(target, parseBackup(jsonEncode(json)));

    final product = await target.select(target.products).getSingle();
    expect(product.useCount, 1);
    expect(product.lastUsedAt, DateTime(2026, 10, 1, 1, 10));
  });

  test('keeps the app day of entries made after midnight', () async {
    final backup = parseBackup(await export());

    expect(backup.entries.first.dayKey.value, 20260930);
  });

  test('accepts names of 40 characters, an emoji counting as one', () async {
    final json = jsonDecode(await export()) as Map<String, dynamic>;
    final name = '${'S' * 38}👍🏽💪';
    rows(json, 'entries').first['name'] = name;
    rows(json, 'products').first['name'] = name;

    final backup = parseBackup(jsonEncode(json));

    expect(backup.entries.first.name.value, name);
    expect(backup.products.first.name.value, name);
  });

  test('computes again the protein of entries made per quantity', () async {
    final json = jsonDecode(await export()) as Map<String, dynamic>;
    rows(json, 'entries').first
      ..['proteinPerReference'] = 10.5
      ..['proteinGrams'] = 15.75;

    final backup = parseBackup(jsonEncode(json));

    expect(backup.entries.first.proteinGrams.value, 15.8);
  });

  test('keeps the part of the day of entries', () async {
    final json = jsonDecode(await export()) as Map<String, dynamic>;
    rows(json, 'entries').first['slot'] = 'afternoon';

    final backup = parseBackup(jsonEncode(json));

    expect(backup.entries.first.slot.value, DaySlot.afternoon);
  });

  test('computes the part of the day for backups of version 1', () async {
    final json = jsonDecode(await export()) as Map<String, dynamic>;
    json['version'] = 1;
    for (final entry in rows(json, 'entries')) {
      entry.remove('slot');
    }

    final backup = parseBackup(jsonEncode(json));

    // Added at 1:10 a.m., then at noon.
    expect(backup.entries.map((e) => e.slot.value), [
      DaySlot.evening,
      DaySlot.afternoon,
    ]);
  });

  group('routines, goals over time and settings', () {
    tearDown(() => appDayStartHour = defaultAppDayStartHour);

    test('are restored, routines starting again at the restoration', () async {
      final skyr = (await source.select(source.products).get()).single;
      await source.productsDao.setRoutine(
        skyr.id,
        DailyRoutine.autoAdd,
        minutes: 480,
        now: DateTime(2026, 9, 1),
      );
      await source.settingsDao.setDailyGoal(160, now: DateTime(2026, 9, 20));
      await source.settingsDao.setHistoryView(HistoryView.calendar);
      await source.settingsDao.setDayStartHour(5);
      final target = openTestDatabase();
      addTearDown(target.close);
      final restoredAt = DateTime(2026, 10, 8, 12);

      await restoreBackup(target, parseBackup(await export()), now: restoredAt);

      final product = (await target.select(target.products).get()).single;
      expect(product.routine, DailyRoutine.autoAdd);
      expect(product.routineMinutes, 480);
      // No entry is added for the days between the backup and now.
      expect(product.routineCheckedAt, restoredAt);
      expect(
        (await target.settingsDao.watchGoalChanges().first).map(
          (g) => (g.dayKey, g.grams),
        ),
        (await source.settingsDao.watchGoalChanges().first).map(
          (g) => (g.dayKey, g.grams),
        ),
      );
      expect(
        await target.settingsDao.watchHistoryView().first,
        HistoryView.calendar,
      );
      expect(await target.settingsDao.getDayStartHour(), 5);
    });

    test(
      'older backups take the goal from their first day, at 3 a.m.',
      () async {
        final json = jsonDecode(await export()) as Map<String, dynamic>;
        json
          ..['version'] = 3
          ..remove('goalChanges');
        (json['settings'] as Map<String, dynamic>)
          ..remove('historyView')
          ..remove('dayStartHour');
        final target = openTestDatabase();
        addTearDown(target.close);

        await restoreBackup(target, parseBackup(jsonEncode(json)));

        final goals = await target.settingsDao.watchGoalChanges().first;
        expect(goals.map((g) => (g.dayKey, g.grams)), [(20260930, 140.0)]);
        expect(
          await target.settingsDao.watchHistoryView().first,
          HistoryView.list,
        );
        expect(await target.settingsDao.getDayStartHour(), 3);
      },
    );

    test('refuse an invalid routine, goal or start hour', () async {
      Future<void> refuses(
        void Function(Map<String, dynamic> json) change,
      ) async {
        final json = jsonDecode(await export()) as Map<String, dynamic>;
        change(json);
        expect(
          () => parseBackup(jsonEncode(json)),
          throwsA(isA<InvalidBackupException>()),
        );
      }

      await refuses(
        (json) => rows(json, 'products').first
          ..['routine'] = 'reminder'
          ..['routineMinutes'] = null,
      );
      await refuses(
        (json) => rows(json, 'products').first
          ..['routine'] = 'autoAdd'
          ..['routineMinutes'] = 1440,
      );
      await refuses(
        (json) => json['goalChanges'] = [
          {'dayKey': 20260931, 'grams': 140},
        ],
      );
      await refuses(
        (json) => json['goalChanges'] = [
          {'dayKey': 20260930, 'grams': 0},
        ],
      );
      await refuses(
        (json) =>
            (json['settings'] as Map<String, dynamic>)['dayStartHour'] = 8,
      );
    });
  });

  test('names the file after the date', () {
    expect(
      backupFileName(DateTime(2026, 10, 1, 13)),
      'protein-calculator-2026-10-01.json',
    );
  });

  group('refuses invalid files', () {
    Future<Map<String, dynamic>> exported() async =>
        jsonDecode(await export()) as Map<String, dynamic>;

    void expectInvalid(String text) =>
        expect(() => parseBackup(text), throwsA(isA<InvalidBackupException>()));

    test('that are not JSON', () => expectInvalid('not json'));

    test('from another app', () async {
      expectInvalid(jsonEncode({...await exported(), 'format': 'other'}));
    });

    test('from a newer version', () async {
      expectInvalid(jsonEncode({...await exported(), 'version': 99}));
    });

    test('with a missing field', () async {
      final json = await exported();
      rows(json, 'entries').first.remove('proteinGrams');
      expectInvalid(jsonEncode(json));
    });

    test('with an unknown mode', () async {
      final json = await exported();
      rows(json, 'entries').first['mode'] = 'magic';
      expectInvalid(jsonEncode(json));
    });

    test('with duplicate product names', () async {
      final json = await exported();
      final products = rows(json, 'products');
      products.add({...products.first, 'id': 99, 'name': 'SKYR  nature'});
      expectInvalid(jsonEncode(json));
    });

    test('with duplicate ids', () async {
      final json = await exported();
      final entries = rows(json, 'entries');
      entries.add({...entries.first, 'name': 'Copy'});
      expectInvalid(jsonEncode(json));

      final other = await exported();
      final products = rows(other, 'products');
      products.add({...products.first, 'name': 'Other'});
      expectInvalid(jsonEncode(other));
    });

    test('with a daily goal out of range', () async {
      for (final goal in [0, -5, 1001, 1e9]) {
        final json = await exported();
        (json['settings'] as Map<String, dynamic>)['dailyGoalGrams'] = goal;
        expectInvalid(jsonEncode(json));
      }
    });

    test('with a quantity that is not positive or too large', () async {
      for (final grams in [0, -15, 10000, 1e12]) {
        final json = await exported();
        rows(json, 'entries').last['proteinGrams'] = grams;
        expectInvalid(jsonEncode(json));
      }
    });

    test('with a quantity missing in "per quantity" mode', () async {
      final json = await exported();
      rows(json, 'products').first['referenceGrams'] = null;
      expectInvalid(jsonEncode(json));
    });

    test('with a protein content above the reference quantity', () async {
      final json = await exported();
      rows(json, 'entries').first['proteinPerReference'] = 150;
      expectInvalid(jsonEncode(json));
    });

    test('with a direct product without its protein amount', () async {
      final json = await exported();
      final products = rows(json, 'products');
      products.first
        ..['mode'] = 'direct'
        ..['proteinGrams'] = null;
      expectInvalid(jsonEncode(json));
    });

    test('with a day that does not exist', () async {
      final json = await exported();
      rows(json, 'entries').first['dayKey'] = 20260931;
      expectInvalid(jsonEncode(json));
    });

    test('with an invalid name', () async {
      for (final name in ['', '   ', ' Skyr', 'S' * 41]) {
        final entries = await exported();
        rows(entries, 'entries').first['name'] = name;
        expectInvalid(jsonEncode(entries));

        final products = await exported();
        rows(products, 'products').first['name'] = name;
        expectInvalid(jsonEncode(products));
      }
    });

    test('with more decimals than the form allows', () async {
      final protein = await exported();
      rows(protein, 'entries').last['proteinGrams'] = 25.55;
      expectInvalid(jsonEncode(protein));

      final food = await exported();
      rows(food, 'products').first['consumedGrams'] = 150.5;
      expectInvalid(jsonEncode(food));
    });

    test('with values of the other mode', () async {
      final json = await exported();
      rows(json, 'entries').last['consumedGrams'] = 100;
      expectInvalid(jsonEncode(json));
    });

    test('with an unknown part of the day', () async {
      final json = await exported();
      rows(json, 'entries').first['slot'] = 'night';
      expectInvalid(jsonEncode(json));
    });

    test('with a version below 1', () async {
      expectInvalid(jsonEncode({...await exported(), 'version': 0}));
    });

    test('with a negative use count', () async {
      final json = await exported();
      rows(json, 'products').first['useCount'] = -1;
      expectInvalid(jsonEncode(json));
    });
  });
}
