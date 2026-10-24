import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/slot_reminder.dart';
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

  /// Asks the user to allow notifications. Completes with whether the
  /// reminders of the parts of the day show.
  Future<bool> requestSlotReminders() async {
    await _notifications.requestPermission();
    await refresh();
    return state.value?.showsSlotReminders ?? false;
  }

  Future<void> openSettings() => _notifications.openSettings();

  /// Asks the user to let notifications show at their exact time. Completes
  /// with whether they do.
  Future<bool> requestExactAlarms() async {
    await _notifications.requestExactAlarms();
    await refresh();
    return state.value?.exact ?? false;
  }
}

/// The automatic additions of [products] adding protein, which fill a part
/// of the day before it is over: no reminder for it. Creatine taken on its
/// own fills none.
List<AutoAddRoutine> slotFillingAutoAdds(Iterable<Product> products) => [
  for (final product in products)
    if (product.routineMinutes case final minutes?
        when product.amount.proteinGrams > 0)
      (minutes: minutes, checkedAt: product.routineCheckedAt),
];

/// Keeps the daily routines of the products running while the app runs:
/// plans their notifications, and adds the products added automatically at
/// their time and when the app comes back to the foreground. Also plans the
/// reminders of the parts of the day left empty, see [SlotReminder], each
/// time the data changes.
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
    _dataChanges = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.entries,
            db.products,
            db.appSettings,
          ]),
        )
        .listen((_) => _planSlots());
    _planSlots();
  }

  final AppDatabase db;
  final RoutineNotifications notifications;
  final DateTime Function() now;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _dataChanges;

  List<Product> _products = const [];

  /// What the planned notifications show, to plan them again only when it
  /// changes: the products change each time one is used.
  String? _planned;
  Timer? _timer;

  /// What the planned reminders of the parts of the day are, like
  /// [_planned], with their language and mode ([_slotsSetup]), and whether
  /// they are being planned, again if [_slotsAgain].
  String? _plannedSlots;
  String? _slotsSetup;
  bool _planningSlots = false;
  bool _slotsAgain = false;
  bool _disposed = false;

  void update(List<Product> products) {
    _products = products;
    _plan();
    _arm();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle.dispose();
    unawaited(_dataChanges.cancel());
  }

  /// The buttons of the notifications, the watch and a Hevy import made in
  /// another window of the app change the data apart from the app, maybe
  /// while it was in the background: the screens read it again.
  void _reloadData() => db.markTablesUpdated([
    db.entries,
    db.products,
    db.watchRequests,
    db.hevySessions,
    db.appSettings,
  ]);

  Future<void> _onResume() async {
    _reloadData();
    await _addDue();
    // The language of the phone, or the permission of exact times, may have
    // changed, and the days to remind have moved on.
    _plan();
    _planSlots();
  }

  Future<void> _addDue() =>
      _report(() => db.entriesDao.addRoutineEntries(now()));

  void _plan() => unawaited(_report(_planNow));

  Future<void> _planNow() async {
    final exact = (await notifications.status()).exact;
    final l10n = _l10n();
    final planned = [
      l10n.localeName,
      exact,
      for (final product in _products)
        if (product.activeRoutineMinutes case final minutes?)
          '${product.id}/${product.name}/${product.routine.name}/$minutes/'
              '${product.amount.proteinGrams}',
    ].join('|');
    if (planned == _planned) return;
    _planned = planned;
    await notifications.schedule(_products, l10n);
  }

  /// Plans the reminders of the parts of the day, once at a time: the data
  /// often changes several times in a row.
  void _planSlots() {
    if (_planningSlots) {
      _slotsAgain = true;
      return;
    }
    _planningSlots = true;
    unawaited(() async {
      do {
        _slotsAgain = false;
        await _report(_planSlotsNow);
      } while (_slotsAgain && !_disposed);
      _planningSlots = false;
    }());
  }

  Future<void> _planSlotsNow() async {
    final current = now();
    final enabled = await db.settingsDao.getSlotReminders();
    final plan = planSlotReminders(
      now: current,
      enabled: enabled,
      filledSlots: enabled
          ? await db.entriesDao.filledSlotsFrom(
              slotReminderDayKeys(current).first,
            )
          : const {},
      autoAdds: enabled
          ? slotFillingAutoAdds(await db.productsDao.getAutoAdds())
          : const [],
    );
    if (_disposed) return;
    // The texts follow the language of the phone, and the reminders show
    // late without exact times: when either changes, all are planned again.
    final l10n = _l10n();
    final exact = plan.planned.isEmpty || (await notifications.status()).exact;
    final setup = '${l10n.localeName}|$exact';
    final planned = [
      setup,
      for (final reminder in plan.planned) reminder.id,
      '/',
      for (final reminder in plan.outdated) reminder.id,
    ].join('|');
    if (planned == _plannedSlots) return;
    await notifications.scheduleSlotReminders(
      plan.planned,
      plan.outdated,
      l10n,
      replace: setup != _slotsSetup,
    );
    // Only once planned: after a failure, the next change tries again.
    _plannedSlots = planned;
    _slotsSetup = setup;
  }

  /// Texts in the language of the phone, which the notifications show.
  static AppLocalizations _l10n() => lookupAppLocalizations(
    resolveLocale(
      PlatformDispatcher.instance.locales,
      AppLocalizations.supportedLocales,
    ),
  );

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
