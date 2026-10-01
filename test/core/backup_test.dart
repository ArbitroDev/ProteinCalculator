import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/backup.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

import '../helpers.dart';

void main() {
  late AppDatabase source;

  setUp(() async {
    source = openTestDatabase();
    addTearDown(source.close);
    await source.settingsDao.setDailyGoal(140);
    await source.settingsDao.setProductSort(ProductSort.mostUsed);
    await source.productsDao.insertProduct(
      name: 'Skyr nature',
      mode: EntryMode.perQuantity,
      consumedGrams: 150,
      proteinPerReference: 10,
      referenceGrams: 100,
      createdAt: DateTime(2026, 9, 1),
    );
    await source.entriesDao.insertEntry(
      name: 'Skyr nature',
      mode: EntryMode.perQuantity,
      proteinGrams: 15,
      consumedGrams: 150,
      proteinPerReference: 10,
      referenceGrams: 100,
      createdAt: DateTime(2026, 10, 1, 1, 10),
    );
    await source.entriesDao.insertEntry(
      mode: EntryMode.direct,
      proteinGrams: 25,
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
      mode: EntryMode.direct,
      proteinGrams: 99,
      createdAt: DateTime(2026, 1, 1, 12),
    );
    await target.productsDao.insertProduct(
      name: 'Old product',
      mode: EntryMode.direct,
      proteinGrams: 5,
      createdAt: DateTime(2026, 1, 1),
    );

    await restoreBackup(target, parseBackup(await export()));

    final entries = await target.select(target.entries).get();
    final products = await target.select(target.products).get();
    expect(entries.map((e) => e.name), ['Skyr nature', null]);
    expect(products.map((p) => p.name), ['Skyr nature']);
  });

  test('keeps the app day of entries made after midnight', () async {
    final backup = parseBackup(await export());

    expect(backup.entries.first.dayKey.value, 20260930);
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
      (json['entries'] as List).first.remove('proteinGrams');
      expectInvalid(jsonEncode(json));
    });

    test('with an unknown mode', () async {
      final json = await exported();
      (json['entries'] as List).first['mode'] = 'magic';
      expectInvalid(jsonEncode(json));
    });

    test('with duplicate product names', () async {
      final json = await exported();
      final products = json['products'] as List;
      products.add({...products.first, 'id': 99, 'name': 'SKYR  nature'});
      expectInvalid(jsonEncode(json));
    });
  });
}
