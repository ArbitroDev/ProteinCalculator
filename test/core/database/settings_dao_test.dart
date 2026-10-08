import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/settings_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
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

  group('goals over time', () {
    test('a goal counts from the app day it is set', () async {
      await dao.setDailyGoal(120, now: DateTime(2026, 9, 1, 10));
      await dao.setDailyGoal(150, now: DateTime(2026, 9, 20, 10));

      expect(await dao.watchGoalChanges().first, [
        isA<GoalChange>()
            .having((g) => g.dayKey, 'dayKey', 20260901)
            .having((g) => g.grams, 'grams', 120),
        isA<GoalChange>()
            .having((g) => g.dayKey, 'dayKey', 20260920)
            .having((g) => g.grams, 'grams', 150),
      ]);
      expect(await dao.getDailyGoal(), 150);
    });

    test('a second change on the same day replaces the first', () async {
      await dao.setDailyGoal(120, now: DateTime(2026, 9, 1, 10));
      await dao.setDailyGoal(130, now: DateTime(2026, 9, 1, 18));

      final changes = await dao.watchGoalChanges().first;
      expect(changes, hasLength(1));
      expect(changes.single.grams, 130);
    });
  });

  group('start of the day', () {
    tearDown(() => appDayStartHour = defaultAppDayStartHour);

    test('is 3 a.m. by default', () async {
      expect(await dao.getDayStartHour(), defaultAppDayStartHour);
    });

    test('is saved and applied at once', () async {
      await dao.setDayStartHour(5);

      expect(await dao.getDayStartHour(), 5);
      expect(appDayStartHour, 5);
    });
  });

  group('history view', () {
    test('is the list by default, and remembers the choice', () async {
      expect(await dao.watchHistoryView().first, HistoryView.list);

      await dao.setHistoryView(HistoryView.calendar);

      expect(await dao.watchHistoryView().first, HistoryView.calendar);
    });
  });
}
