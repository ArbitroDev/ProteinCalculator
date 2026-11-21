import 'package:drift/drift.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/day_slot.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';

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

  /// Whether the entry was added on the watch, see `WatchDao.add`.
  BoolColumn get fromWatch => boolean().withDefault(const Constant(false))();

  /// Unit of [consumedGrams] and [referenceGrams], despite their names:
  /// grams, or milliliters for drinks.
  TextColumn get unit =>
      textEnum<QuantityUnit>().withDefault(Constant(QuantityUnit.grams.name))();

  /// Creatine doses taken with the entry, and the grams of one dose when it
  /// was added, null without doses: changing the dose in the menu never
  /// changes the history.
  IntColumn get creatineDoses => integer().withDefault(const Constant(0))();
  RealColumn get creatineDoseGrams => real().nullable()();
}

/// Products saved by the user to fill in entries quickly.
@TableIndex(name: 'products_barcode', columns: {#barcode}, unique: true)
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

  /// Unit of [consumedGrams] and [referenceGrams], despite their names:
  /// grams, or milliliters for drinks.
  TextColumn get unit =>
      textEnum<QuantityUnit>().withDefault(Constant(QuantityUnit.grams.name))();

  /// Barcode of the product, see `normalizeBarcode`; null without one. Two
  /// products never share one: the index is unique.
  TextColumn get barcode => text().nullable()();

  /// Creatine doses in one portion: their grams are those of the dose in
  /// force when the product is added.
  IntColumn get creatineDoses => integer().withDefault(const Constant(0))();
}

/// What Open Food Facts said of the products scanned, by barcode, and when.
///
/// The latest ones no product has the barcode of are the recent scans. For
/// the others, it keeps the values Open Food Facts gave, to tell when they
/// change. Specific to the phone: not in the backups.
class ScannedProducts extends Table {
  /// See `normalizeBarcode`.
  TextColumn get barcode => text()();

  /// Name and brands of the product, in the language of the app when Open
  /// Food Facts has it; null when it has none.
  TextColumn get name => text().nullable()();
  TextColumn get brands => text().nullable()();

  /// Protein grams per 100 [unit]; null when Open Food Facts does not know.
  RealColumn get proteinPer100 => real().nullable()();

  /// Quantity of one serving, in [unit]; null when Open Food Facts does not
  /// know.
  RealColumn get servingQuantity => real().nullable()();
  TextColumn get unit =>
      textEnum<QuantityUnit>().withDefault(Constant(QuantityUnit.grams.name))();

  /// When Open Food Facts was last asked about the product.
  DateTimeColumn get fetchedAt => dateTime()();

  /// When the product was last scanned: the recent scans come latest first.
  DateTimeColumn get scannedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {barcode};
}

/// Workouts read from a Hevy export, all replaced by each import. Only what
/// the history shows is kept: when, how long, and the name.
class HevySessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get startedAt => dateTime()();

  /// Null when the file gives no end: the duration is then unknown.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// App day of [startedAt], see `dayKeyOf`. Like the day of an entry, it is
  /// fixed when the workout is imported: the next import computes it again.
  IntColumn get dayKey => integer()();
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

/// Additions and deletions of the watch already made, by the id the watch
/// gave them: one sent again, its answer lost, is not made twice. Kept 60
/// days, specific to the phone: not in the backups.
class WatchRequests extends Table {
  TextColumn get id => text()();
  DateTimeColumn get handledAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
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

  /// Whether a notification reminds the user to add entries in a part of the
  /// day left empty, see `SlotReminder`; off until the user turns it on.
  BoolColumn get slotReminders =>
      boolean().withDefault(const Constant(false))();

  /// Whether the products page folds its list of saved products, and its
  /// list of recent scans.
  BoolColumn get savedProductsCollapsed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get recentScansCollapsed =>
      boolean().withDefault(const Constant(false))();

  /// Whether the user read, before a first scan, what is sent to Open Food
  /// Facts. Specific to the phone: not in the backups.
  BoolColumn get scanNoticeSeen =>
      boolean().withDefault(const Constant(false))();

  /// Whether the user tracks creatine; off until turned on in the menu.
  BoolColumn get creatineEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Grams of one creatine dose; null until creatine is first turned on.
  RealColumn get creatineDoseGrams => real().nullable()();

  /// When the Hevy workouts were last imported; null while there are none,
  /// which leaves the Hevy marks off the history.
  DateTimeColumn get hevyImportedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
