import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';

/// What the watch app shows: the protein total, the goal and the entries of
/// the current app day, and the products it adds. The plugin `watch_link`
/// writes it in the format of the watch messages, see
/// `android/wear/protocol/PROTOCOL.md`.
@immutable
class WatchState {
  const WatchState({
    required this.dayKey,
    required this.dayStartHour,
    required this.total,
    required this.goal,
    required this.entries,
    required this.products,
    required this.handled,
    this.creatineEnabled = false,
  });

  /// State of the app day [dayKey], from its [entries], its [goal] and the
  /// [products] in the order of the products tab, the favorite first.
  factory WatchState.of({
    required int dayKey,
    required int dayStartHour,
    required Iterable<Entry> entries,
    required double? goal,
    required Iterable<Product> products,
    required List<String> handled,
    bool creatineEnabled = false,
  }) => WatchState(
    dayKey: dayKey,
    dayStartHour: dayStartHour,
    total: entries.proteinGrams,
    goal: goal,
    entries: [
      for (final entry in entries.toList().reversed)
        WatchEntry(
          id: entry.id,
          name: entry.name,
          protein: entry.proteinGrams,
          time: entry.createdAt,
          fromWatch: entry.fromWatch,
          creatineDoses: entry.creatineDoses,
          creatineGrams: entry.creatineGrams,
        ),
    ],
    products: [
      for (final product in products)
        WatchProduct(
          id: product.id,
          name: product.name,
          protein: product.amount.proteinGrams,
          isFavorite: product.isFavorite,
          creatineDoses: product.creatineDoses,
        ),
    ],
    handled: handled,
    creatineEnabled: creatineEnabled,
  );

  final int dayKey;

  /// Hour the app days start, see `appDayStartHour`.
  final int dayStartHour;

  /// Protein grams of the entries of the day.
  final double total;

  /// Goal of the day in grams; null until the first launch is completed.
  final double? goal;

  /// Entries of the day, the most recent first.
  final List<WatchEntry> entries;

  final List<WatchProduct> products;

  /// Ids of the additions and deletions of the watch made since
  /// [handledSince]: the watch stops sending those whose answer it did not
  /// get.
  final List<String> handled;

  /// Whether the user tracks creatine: the tile of the watch then tells
  /// whether it was taken.
  final bool creatineEnabled;

  /// Values taken by `sendWatchState` of the plugin `watch_link`.
  Map<String, Object?> toChannel() => {
    'day': dayKey,
    'dayStartHour': dayStartHour,
    'total': total,
    'goal': goal,
    'entries': [
      for (final entry in entries)
        {
          'id': entry.id,
          'name': entry.name,
          'protein': entry.protein,
          'time': entry.time.millisecondsSinceEpoch,
          'fromWatch': entry.fromWatch,
          'creatineDoses': entry.creatineDoses,
          'creatineGrams': entry.creatineGrams,
        },
    ],
    'products': [
      for (final product in products)
        {
          'id': product.id,
          'name': product.name,
          'protein': product.protein,
          'favorite': product.isFavorite,
          'creatineDoses': product.creatineDoses,
        },
    ],
    'handled': handled,
    'creatineEnabled': creatineEnabled,
  };

  @override
  bool operator ==(Object other) =>
      other is WatchState &&
      other.dayKey == dayKey &&
      other.dayStartHour == dayStartHour &&
      other.total == total &&
      other.goal == goal &&
      const ListEquality<WatchEntry>().equals(other.entries, entries) &&
      const ListEquality<WatchProduct>().equals(other.products, products) &&
      const ListEquality<String>().equals(other.handled, handled) &&
      other.creatineEnabled == creatineEnabled;

  @override
  int get hashCode => Object.hash(
    dayKey,
    dayStartHour,
    total,
    goal,
    const ListEquality<WatchEntry>().hash(entries),
    const ListEquality<WatchProduct>().hash(products),
    const ListEquality<String>().hash(handled),
    creatineEnabled,
  );
}

/// An entry of the day, as the watch lists it.
@immutable
class WatchEntry {
  const WatchEntry({
    required this.id,
    required this.name,
    required this.protein,
    required this.time,
    required this.fromWatch,
    this.creatineDoses = 0,
    this.creatineGrams = 0,
  });

  final int id;

  /// Null for an entry without a name.
  final String? name;
  final double protein;
  final DateTime time;

  /// Whether it was added on the watch.
  final bool fromWatch;

  /// Creatine doses taken with it, and their grams.
  final int creatineDoses;
  final double creatineGrams;

  @override
  bool operator ==(Object other) =>
      other is WatchEntry &&
      other.id == id &&
      other.name == name &&
      other.protein == protein &&
      other.time == time &&
      other.fromWatch == fromWatch &&
      other.creatineDoses == creatineDoses &&
      other.creatineGrams == creatineGrams;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    protein,
    time,
    fromWatch,
    creatineDoses,
    creatineGrams,
  );
}

/// A product the watch adds one portion of.
@immutable
class WatchProduct {
  const WatchProduct({
    required this.id,
    required this.name,
    required this.protein,
    required this.isFavorite,
    this.creatineDoses = 0,
  });

  final int id;
  final String name;

  /// Protein grams of one portion.
  final double protein;
  final bool isFavorite;

  /// Creatine doses of one portion.
  final int creatineDoses;

  @override
  bool operator ==(Object other) =>
      other is WatchProduct &&
      other.id == id &&
      other.name == name &&
      other.protein == protein &&
      other.isFavorite == isFavorite &&
      other.creatineDoses == creatineDoses;

  @override
  int get hashCode => Object.hash(id, name, protein, isFavorite, creatineDoses);
}

/// Reads the state of the app day of [now] from [db], as the app shows it.
Future<WatchState> readWatchState(AppDatabase db, DateTime now) async {
  // The first query opens the data, which reads the start hour of the day.
  final dayStartHour = await db.settingsDao.getDayStartHour();
  final dayKey = dayKeyOf(now);
  final goals = await db.settingsDao.watchGoalChanges().first;
  final sort = await db.settingsDao.watchProductSort().first;
  return WatchState.of(
    dayKey: dayKey,
    dayStartHour: dayStartHour,
    entries: await db.entriesDao.watchDayEntries(dayKey).first,
    goal:
        goalOn(dayKey, [
          for (final goal in goals) (dayKey: goal.dayKey, grams: goal.grams),
        ]) ??
        await db.settingsDao.getDailyGoal(),
    products: await db.productsDao.watchAll(sort).first,
    handled: await db.watchDao.watchHandledSince(handledSince(dayKey)).first,
    creatineEnabled: (await db.settingsDao.getCreatine()).enabled,
  );
}

/// Start of the app day before [dayKey]: the state tells the additions and
/// deletions of the watch made from then on.
DateTime handledSince(int dayKey) {
  final date = dateOfDayKey(dayKey);
  return DateTime(date.year, date.month, date.day - 1, appDayStartHour);
}
