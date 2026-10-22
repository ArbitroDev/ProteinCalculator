import 'package:drift/drift.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/tables.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/creatine.dart';
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

  /// Whether the products page folds its list of saved products.
  Stream<bool> watchSavedProductsCollapsed() =>
      _row.watchSingle().map((settings) => settings.savedProductsCollapsed);

  Future<void> setSavedProductsCollapsed(bool collapsed) =>
      _write(AppSettingsCompanion(savedProductsCollapsed: Value(collapsed)));

  /// Whether the products page folds its list of recent scans.
  Stream<bool> watchRecentScansCollapsed() =>
      _row.watchSingle().map((settings) => settings.recentScansCollapsed);

  Future<void> setRecentScansCollapsed(bool collapsed) =>
      _write(AppSettingsCompanion(recentScansCollapsed: Value(collapsed)));

  /// Whether the user read what is sent to Open Food Facts, see
  /// `AppSettings.scanNoticeSeen`.
  Future<bool> getScanNoticeSeen() async =>
      (await _row.getSingle()).scanNoticeSeen;

  Future<void> setScanNoticeSeen() =>
      _write(const AppSettingsCompanion(scanNoticeSeen: Value(true)));

  Future<bool> getSlotReminders() async =>
      (await _row.getSingle()).slotReminders;

  Stream<bool> watchSlotReminders() =>
      _row.watchSingle().map((settings) => settings.slotReminders);

  Future<void> setSlotReminders(bool enabled) =>
      _write(AppSettingsCompanion(slotReminders: Value(enabled)));

  static CreatineSettings _creatine(AppSettingsRow settings) =>
      CreatineSettings(
        enabled: settings.creatineEnabled,
        doseGrams: settings.creatineDoseGrams,
      );

  Future<CreatineSettings> getCreatine() async =>
      _creatine(await _row.getSingle());

  Stream<CreatineSettings> watchCreatine() =>
      _row.watchSingle().map(_creatine).distinct();

  /// Turns creatine tracking on or off. The first time it is turned on, the
  /// dose starts at [defaultCreatineDoseGrams]; later, it keeps the one set.
  Future<void> setCreatineEnabled(bool enabled) => transaction(() async {
    final dose = (await _row.getSingle()).creatineDoseGrams;
    await _write(
      AppSettingsCompanion(
        creatineEnabled: Value(enabled),
        creatineDoseGrams: Value(
          enabled ? dose ?? defaultCreatineDoseGrams : dose,
        ),
      ),
    );
  });

  /// Sets the grams of one dose, for the doses added from now on: those
  /// added before keep theirs.
  Future<void> setCreatineDoseGrams(double grams) =>
      _write(AppSettingsCompanion(creatineDoseGrams: Value(grams)));
}
