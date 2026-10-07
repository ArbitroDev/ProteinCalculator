import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/notification_changes.dart';
import 'package:protein_calculator/core/notifications.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Notifications of the daily routines, opened in `startApp`.
final routineNotificationsProvider = Provider<RoutineNotifications>(
  (ref) => const RoutineNotifications.none(),
);

/// Whether the notifications of the routines can show, read again when the
/// app comes back to the foreground, as the user may have changed it in the
/// settings of Android.
final notificationStatusProvider =
    AsyncNotifierProvider<NotificationStatusNotifier, NotificationStatus>(
      NotificationStatusNotifier.new,
    );

class NotificationStatusNotifier extends AsyncNotifier<NotificationStatus> {
  RoutineNotifications get _notifications =>
      ref.read(routineNotificationsProvider);

  @override
  Future<NotificationStatus> build() {
    final lifecycle = AppLifecycleListener(
      onResume: () => unawaited(refresh()),
    );
    ref.onDispose(lifecycle.dispose);
    return ref.watch(routineNotificationsProvider).status();
  }

  Future<void> refresh() async {
    state = AsyncData(await _notifications.status());
  }

  /// Asks the user to allow notifications. Completes with whether those of
  /// [routine] show.
  Future<bool> request(DailyRoutine routine) async {
    await _notifications.requestPermission();
    await refresh();
    return state.value?.shows(routine) ?? false;
  }

  Future<void> openSettings() => _notifications.openSettings();
}

/// Keeps the daily routines of the products running while the app runs:
/// plans their notifications, and adds the products added automatically at
/// their time, when the app comes back to the foreground, and after a
/// button of a notification changed the data.
final dailyRoutinesProvider = Provider<void>((ref) {
  final runner = _RoutineRunner(
    db: ref.watch(databaseProvider),
    notifications: ref.watch(routineNotificationsProvider),
    now: ref.watch(clockProvider),
  );
  ref
    ..listen(productsProvider, (_, next) {
      if (next.value case final products?) runner.update(products);
    }, fireImmediately: true)
    ..onDispose(runner.dispose);
});

class _RoutineRunner {
  _RoutineRunner({
    required this.db,
    required this.notifications,
    required this.now,
  }) {
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    _stopListening = listenToNotificationChanges(_reloadData);
  }

  final AppDatabase db;
  final RoutineNotifications notifications;
  final DateTime Function() now;
  late final AppLifecycleListener _lifecycle;
  late final VoidCallback _stopListening;

  List<Product> _products = const [];

  /// What the planned notifications show, to plan them again only when it
  /// changes: the products change each time one is used.
  String? _planned;
  Timer? _timer;

  void update(List<Product> products) {
    _products = products;
    _plan();
    _arm();
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _stopListening();
  }

  /// The buttons of the notifications change the data apart from the app:
  /// the screens read it again.
  void _reloadData() => db.markTablesUpdated([db.entries, db.products]);

  Future<void> _onResume() async {
    _reloadData();
    await _addDue();
    // The language of the phone may have changed.
    _plan();
  }

  Future<void> _addDue() =>
      _report(() => db.entriesDao.addRoutineEntries(now()));

  void _plan() {
    final l10n = lookupAppLocalizations(
      resolveLocale(
        PlatformDispatcher.instance.locales,
        AppLocalizations.supportedLocales,
      ),
    );
    final planned = [
      l10n.localeName,
      for (final product in _products)
        if (product.activeRoutineMinutes case final minutes?)
          '${product.id}/${product.name}/${product.routine.name}/$minutes/'
              '${product.amount.proteinGrams}',
    ].join('|');
    if (planned == _planned) return;
    _planned = planned;
    unawaited(_report(() => notifications.schedule(_products, l10n)));
  }

  /// Wakes up at the next time a product adds itself.
  void _arm() {
    _timer?.cancel();
    final current = now();
    DateTime? next;
    for (final product in _products) {
      final minutes = product.routineMinutes;
      if (product.routine != DailyRoutine.autoAdd || minutes == null) continue;
      final today = routineTimeOn(current, minutes);
      final time = today.isAfter(current)
          ? today
          : routineTimeOn(
              DateTime(current.year, current.month, current.day + 1),
              minutes,
            );
      if (next == null || time.isBefore(next)) next = time;
    }
    if (next == null) return;
    // A second later, so the time has passed.
    final delay = next.difference(current) + const Duration(seconds: 1);
    _timer = Timer(Duration(microseconds: max(0, delay.inMicroseconds)), () {
      unawaited(_addDue().then((_) => _arm()));
    });
  }

  /// Runs [action], reporting a failure without stopping the app: the next
  /// launch tries again.
  static Future<void> _report(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'daily routines',
        ),
      );
    }
  }
}
