import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/background_changes.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/watch/watch_state.dart';
import 'package:watch_link/watch_link.dart';

/// Link with the Wear OS watch app. Without a watch link (web, tests),
/// [WatchLink.none] sends nothing.
abstract interface class WatchLink {
  /// Sends nothing.
  const factory WatchLink.none() = _NoWatchLink;

  /// The link of Android, or none on other platforms.
  factory WatchLink.platform() => !kIsWeb && Platform.isAndroid
      ? const _AndroidWatchLink()
      : const WatchLink.none();

  /// Sends [state] to the nearby watches having the app.
  Future<void> send(WatchState state);
}

class _NoWatchLink implements WatchLink {
  const _NoWatchLink();

  @override
  Future<void> send(WatchState state) async {}
}

class _AndroidWatchLink implements WatchLink {
  const _AndroidWatchLink();

  @override
  Future<void> send(WatchState state) => sendWatchState(state.toChannel());
}

/// Link with the watch, opened in `startApp`.
final watchLinkProvider = Provider<WatchLink>((ref) => const WatchLink.none());

/// State of the current app day for the watch; null while the data loads.
final watchStateProvider = Provider<WatchState?>((ref) {
  final dayKey = ref.watch(currentDayKeyProvider).value;
  final dayStartHour = ref.watch(dayStartHourProvider).value;
  final products = ref.watch(sortedProductsProvider).value;
  final goalsLoaded =
      ref.watch(goalChangesProvider).hasValue &&
      ref.watch(dailyGoalProvider).hasValue;
  if (dayKey == null || dayStartHour == null || products == null) return null;
  final entries = ref.watch(dayEntriesProvider(dayKey)).value;
  if (entries == null || !goalsLoaded) return null;
  return WatchState.of(
    dayKey: dayKey,
    dayStartHour: dayStartHour,
    entries: entries,
    goal: ref.watch(dayGoalProvider(dayKey)),
    products: products,
  );
});

/// Sends the state of the day to the watch while the app runs: once the data
/// is read, then each time it changes, the day included. A watch coming
/// nearby asks the plugin `watch_link`, even when the app is closed.
final watchSyncProvider = Provider<void>((ref) {
  final link = ref.watch(watchLinkProvider);
  ref.listen(watchStateProvider, (previous, next) {
    if (next == null || next == previous) return;
    unawaited(_report(() => link.send(next)));
  }, fireImmediately: true);
});

/// Sends the state of the day of [now] to the watch, from code run apart
/// from the app, which may be closed: the buttons of the notifications.
Future<void> updateWatch(AppDatabase db, DateTime now) => _report(
  () async => WatchLink.platform().send(await readWatchState(db, now)),
);

/// Runs the Flutter engine the plugin `watch_link` starts apart from the app
/// to answer the watch, even when the app is closed: each request opens the
/// data as the app does.
@pragma('vm:entry-point')
Future<void> watchBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await answerWatchRequests(() async {
    final db = AppDatabase.open();
    try {
      final now = DateTime.now();
      // As when the app starts: the products added automatically while it
      // was closed count in the total.
      await db.entriesDao.addRoutineEntries(now);
      return (await readWatchState(db, now)).toChannel();
    } finally {
      await db.close();
      notifyBackgroundChange();
    }
  });
}

/// Runs [action], only reporting a failure: the watch keeps its state.
Future<void> _report(Future<void> Function() action) async {
  try {
    await action();
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'watch'),
    );
  }
}
