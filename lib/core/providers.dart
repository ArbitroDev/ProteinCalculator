import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';

/// The app database, opened in `main` before the first frame.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Override databaseProvider in main.'),
);

/// Current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Key of the current app day. Emits again at 3 a.m. and when the app comes
/// back to the foreground, so the today screen switches day on its own.
final currentDayKeyProvider = StreamProvider<int>((ref) {
  final now = ref.watch(clockProvider);
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
    controller.close();
  });
  return controller.stream.distinct();
});

/// Daily protein goal in grams; null until the first launch is completed.
final dailyGoalProvider = StreamProvider<double?>(
  (ref) => ref.watch(databaseProvider).settingsDao.watchDailyGoal(),
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
