import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';

/// What the watch app shows: the protein total and the goal of the current
/// app day, and the products it adds. The plugin `watch_link` writes it in
/// the format of the watch messages, see `android/wear/protocol/PROTOCOL.md`.
@immutable
class WatchState {
  const WatchState({
    required this.dayKey,
    required this.dayStartHour,
    required this.total,
    required this.goal,
    required this.products,
  });

  /// State of the app day [dayKey], from its [entries], its [goal] and the
  /// [products] in the order of the products tab, the favorite first.
  factory WatchState.of({
    required int dayKey,
    required int dayStartHour,
    required Iterable<Entry> entries,
    required double? goal,
    required Iterable<Product> products,
  }) => WatchState(
    dayKey: dayKey,
    dayStartHour: dayStartHour,
    total: entries.proteinGrams,
    goal: goal,
    products: [
      for (final product in products)
        WatchProduct(
          id: product.id,
          name: product.name,
          protein: product.amount.proteinGrams,
          isFavorite: product.isFavorite,
        ),
    ],
  );

  final int dayKey;

  /// Hour the app days start, see `appDayStartHour`.
  final int dayStartHour;

  /// Protein grams of the entries of the day.
  final double total;

  /// Goal of the day in grams; null until the first launch is completed.
  final double? goal;

  final List<WatchProduct> products;

  /// Values taken by `sendWatchState` of the plugin `watch_link`.
  Map<String, Object?> toChannel() => {
    'day': dayKey,
    'dayStartHour': dayStartHour,
    'total': total,
    'goal': goal,
    'products': [
      for (final product in products)
        {
          'id': product.id,
          'name': product.name,
          'protein': product.protein,
          'favorite': product.isFavorite,
        },
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is WatchState &&
      other.dayKey == dayKey &&
      other.dayStartHour == dayStartHour &&
      other.total == total &&
      other.goal == goal &&
      const ListEquality<WatchProduct>().equals(other.products, products);

  @override
  int get hashCode => Object.hash(
    dayKey,
    dayStartHour,
    total,
    goal,
    const ListEquality<WatchProduct>().hash(products),
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
  });

  final int id;
  final String name;

  /// Protein grams of one portion.
  final double protein;
  final bool isFavorite;

  @override
  bool operator ==(Object other) =>
      other is WatchProduct &&
      other.id == id &&
      other.name == name &&
      other.protein == protein &&
      other.isFavorite == isFavorite;

  @override
  int get hashCode => Object.hash(id, name, protein, isFavorite);
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
  );
}
