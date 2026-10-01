import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  /// Id of the single settings row, created when the database opens.
  static const rowId = 1;

  SimpleSelectStatement<$AppSettingsTable, AppSettingsRow> get _row =>
      select(appSettings)..where((s) => s.id.equals(rowId));

  Future<void> _write(AppSettingsCompanion values) =>
      (update(appSettings)..where((s) => s.id.equals(rowId))).write(values);

  Future<double?> getDailyGoal() async =>
      (await _row.getSingle()).dailyGoalGrams;

  Stream<double?> watchDailyGoal() =>
      _row.watchSingle().map((settings) => settings.dailyGoalGrams);

  Future<void> setDailyGoal(double grams) =>
      _write(AppSettingsCompanion(dailyGoalGrams: Value(grams)));

  Stream<ProductSort> watchProductSort() =>
      _row.watchSingle().map((settings) => settings.productSort);

  Future<void> setProductSort(ProductSort sort) =>
      _write(AppSettingsCompanion(productSort: Value(sort)));
}
