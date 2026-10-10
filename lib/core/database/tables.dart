import 'package:drift/drift.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

/// Protein entries. Each entry keeps a full copy of the values it was created
/// with, so editing or deleting a product never changes the history.
@TableIndex(name: 'entries_day_key', columns: {#dayKey})
@TableIndex(name: 'entries_name_key', columns: {#nameKey})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();

  /// Normalized [name], see `productNameKey`; null without a name. Links the
  /// entry to the product of the same name, to count its uses.
  TextColumn get nameKey => text().nullable()();
  TextColumn get mode => textEnum<EntryMode>()();

  /// Final protein amount, entered or computed, so totals are plain sums.
  RealColumn get proteinGrams => real()();
  RealColumn get consumedGrams => real().nullable()();
  RealColumn get proteinPerReference => real().nullable()();
  RealColumn get referenceGrams => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// App day of [createdAt], see `dayKeyOf`.
  IntColumn get dayKey => integer()();

  /// Part of the day of [createdAt], see `DaySlot.of`. Like [dayKey], it is
  /// fixed when the entry is added, so a change of time zone never moves an
  /// entry. The default only serves the migration adding the column, which
  /// then computes the right value of every entry.
  TextColumn get slot =>
      textEnum<DaySlot>().withDefault(Constant(DaySlot.morning.name))();
}

/// Products saved by the user to fill in entries quickly.
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Normalized name, see `productNameKey`: forbids duplicate names.
  TextColumn get nameKey => text().unique()();
  TextColumn get mode => textEnum<EntryMode>()();
  RealColumn get proteinGrams => real().nullable()();

  /// Default portion offered when the product is used.
  RealColumn get consumedGrams => real().nullable()();
  RealColumn get proteinPerReference => real().nullable()();
  RealColumn get referenceGrams => real().nullable()();

  /// Number of entries with the name of the product, and when the latest
  /// was added: computed from the entries, see `AppDatabase.refreshUses`.
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// The favorite product, listed first whatever the sort; one at most.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// What the product does every day at [routineMinutes]: remind the user,
  /// or add itself.
  TextColumn get routine =>
      textEnum<DailyRoutine>().withDefault(Constant(DailyRoutine.none.name))();

  /// Time of day of the [routine], in minutes since midnight; null without
  /// a routine.
  IntColumn get routineMinutes => integer().nullable()();

  /// Up to when the automatic additions of the [routine] were made: the
  /// next ones come after it. Set when the routine is chosen, so it never
  /// adds entries for the days before.
  DateTimeColumn get routineCheckedAt => dateTime().nullable()();
}

/// Daily goals over time: each row holds the goal set on an app day, which
/// counts from that day until the next change. Days are judged against the
/// goal they had, not the current one.
class GoalChanges extends Table {
  /// App day the goal was set, see `dayKeyOf`.
  IntColumn get dayKey => integer()();
  RealColumn get grams => real()();

  @override
  Set<Column<Object>> get primaryKey => {dayKey};
}

/// Single-row table holding the app settings.
@DataClassName('AppSettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer()();

  /// Daily protein goal; null until the first launch is completed.
  RealColumn get dailyGoalGrams => real().nullable()();
  TextColumn get productSort => textEnum<ProductSort>().withDefault(
    Constant(ProductSort.alphabetical.name),
  )();

  /// Hour the app day starts, see `appDayStartHour`.
  IntColumn get dayStartHour =>
      integer().withDefault(const Constant(defaultAppDayStartHour))();

  /// How the history tab shows the days.
  TextColumn get historyView =>
      textEnum<HistoryView>().withDefault(Constant(HistoryView.list.name))();

  /// Whether crash reports are sent; off until the user agrees.
  BoolColumn get crashReports => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
