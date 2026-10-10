import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings, GoalChanges])
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

  /// Sets the daily goal from the app day of [now] (the current time by
  /// default) onwards; the days before keep the goal they had.
  Future<void> setDailyGoal(double grams, {DateTime? now}) =>
      transaction(() async {
        await _write(AppSettingsCompanion(dailyGoalGrams: Value(grams)));
        await into(goalChanges).insertOnConflictUpdate(
          GoalChangesCompanion.insert(
            dayKey: Value(dayKeyOf(now ?? DateTime.now())),
            grams: grams,
          ),
        );
      });

  /// Goals over time, oldest first.
  Stream<List<GoalChange>> watchGoalChanges() => (select(
    goalChanges,
  )..orderBy([(g) => OrderingTerm.asc(g.dayKey)])).watch();

  Stream<ProductSort> watchProductSort() =>
      _row.watchSingle().map((settings) => settings.productSort);

  Future<void> setProductSort(ProductSort sort) =>
      _write(AppSettingsCompanion(productSort: Value(sort)));

  Future<int> getDayStartHour() async => (await _row.getSingle()).dayStartHour;

  Stream<int> watchDayStartHour() =>
      _row.watchSingle().map((settings) => settings.dayStartHour);

  /// Makes the app days start at [hour] from now on, see `appDayStartHour`.
  Future<void> setDayStartHour(int hour) async {
    await _write(AppSettingsCompanion(dayStartHour: Value(hour)));
    appDayStartHour = hour;
  }

  Stream<HistoryView> watchHistoryView() =>
      _row.watchSingle().map((settings) => settings.historyView);

  Future<void> setHistoryView(HistoryView view) =>
      _write(AppSettingsCompanion(historyView: Value(view)));

  Future<bool> getCrashReports() async => (await _row.getSingle()).crashReports;

  Stream<bool> watchCrashReports() =>
      _row.watchSingle().map((settings) => settings.crashReports);

  Future<void> setCrashReports(bool enabled) =>
      _write(AppSettingsCompanion(crashReports: Value(enabled)));
}
