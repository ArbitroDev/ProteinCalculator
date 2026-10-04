import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

import 'test_database.dart';

void main() {
  late SettingsDao dao;

  setUp(() {
    final AppDatabase db = openTestDatabase();
    dao = db.settingsDao;
  });

  group('daily goal', () {
    test('is not set on a new database', () async {
      expect(await dao.getDailyGoal(), isNull);
    });

    test('can be set and watched', () async {
      await dao.setDailyGoal(140);

      expect(await dao.getDailyGoal(), 140);
      expect(await dao.watchDailyGoal().first, 140);
    });
  });

  group('product sort', () {
    test('is alphabetical by default', () async {
      expect(await dao.watchProductSort().first, ProductSort.alphabetical);
    });

    test('remembers the last sort chosen', () async {
      await dao.setProductSort(ProductSort.mostUsed);

      expect(await dao.watchProductSort().first, ProductSort.mostUsed);
    });
  });
}
