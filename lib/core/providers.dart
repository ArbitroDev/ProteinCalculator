import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/entries_dao.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/day_progress.dart';
import 'package:protein_calculator/core/domain/history_view.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

/// The app database, opened in `main` before the first frame.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Override databaseProvider in main.'),
);

/// Current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Hour the app day starts, chosen in the menu, see `appDayStartHour`.
final dayStartHourProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchDayStartHour(),
);

/// Key of the current app day. Emits again when the next app day starts,
/// when the app comes back to the foreground and when the start hour
/// changes, so the today screen switches day on its own.
final currentDayKeyProvider = StreamProvider<int>((ref) {
  final now = ref.watch(clockProvider);
  ref.watch(dayStartHourProvider);
  final controller = StreamController<int>();
  Timer? timer;

  void emit() {
    final time = now();
    controller.add(dayKeyOf(time));
    timer?.cancel();
    timer = Timer(nextDayStart(time).difference(time), emit);
  }

  final lifecycle = AppLifecycleListener(onResume: emit);
  emit();

  ref.onDispose(() {
    timer?.cancel();
    lifecycle.dispose();
    unawaited(controller.close());
  });
  return controller.stream.distinct();
});

/// Daily protein goal in grams; null until the first launch is completed.
final dailyGoalProvider = StreamProvider<double?>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchDailyGoal(),
);

/// Daily goals over time as `(dayKey, grams)`, oldest first, see `goalOn`.
final goalChangesProvider = StreamProvider<List<({int dayKey, double grams})>>(
  (ref) => ref
      .watch(databaseProvider)
      .settingsDao
      .watchGoalChanges()
      .map(
        (changes) => [
          for (final change in changes)
            (dayKey: change.dayKey, grams: change.grams),
        ],
      ),
);

/// Goal of one app day: the one it had, which may differ from the current
/// one. Null until the first launch is completed.
final dayGoalProvider = Provider.family<double?, int>(
  (ref, dayKey) =>
      goalOn(dayKey, ref.watch(goalChangesProvider).value ?? const []) ??
      ref.watch(dailyGoalProvider).value,
);

/// Entries of one app day, in the order they were added.
final dayEntriesProvider = StreamProvider.family<List<Entry>, int>(
  (ref, dayKey) =>
      ref.watch(databaseProvider).entriesDao.watchDayEntries(dayKey),
);

/// Saved products, in alphabetical order.
final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref
      .watch(databaseProvider)
      .productsDao
      .watchAll(ProductSort.alphabetical),
);

/// The favorite product, added in one tap from the today screen.
final favoriteProductProvider = Provider<Product?>(
  (ref) => ref
      .watch(productsProvider)
      .value
      ?.firstWhereOrNull((product) => product.isFavorite),
);

/// Days having at least one entry, most recent first.
final historyProvider = StreamProvider<List<DaySummary>>(
  (ref) => ref.watch(databaseProvider).entriesDao.watchHistory(),
);

/// Whether the user agreed to send crash reports, see `setCrashReporting`.
final crashReportsProvider = StreamProvider<bool>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchCrashReports(),
);

/// Sort order chosen in the products tab, remembered between launches.
final productSortProvider = StreamProvider<ProductSort>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchProductSort(),
);

/// How the history tab shows the days, remembered between launches.
final historyViewProvider = StreamProvider<HistoryView>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchHistoryView(),
);

/// Saved products in the order chosen in the products tab.
final sortedProductsProvider = StreamProvider<List<Product>>((ref) {
  final sort = ref.watch(productSortProvider).value ?? ProductSort.alphabetical;
  return ref.watch(databaseProvider).productsDao.watchAll(sort);
});

/// Version of the app, read from the package.
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);
