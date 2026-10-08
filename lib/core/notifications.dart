import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/notification_changes.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notifications of the daily routines of the products, see [DailyRoutine].
///
/// Android shows them at the time of each routine, even when the app is
/// closed: the app only plans them. Without notifications (web, tests),
/// [RoutineNotifications.none] plans nothing.
abstract interface class RoutineNotifications {
  /// Does nothing.
  const factory RoutineNotifications.none() = _NoNotifications;

  /// Plans the notifications of the [products] having a routine, in the
  /// language of [l10n], replacing those planned before.
  Future<void> schedule(List<Product> products, AppLocalizations l10n);

  /// Whether the notifications of each routine can show.
  Future<NotificationStatus> status();

  /// Asks the user to allow notifications, if not done yet. Completes with
  /// whether they are allowed. After two refusals, Android no longer asks:
  /// only the settings can allow them, see [openSettings].
  Future<bool> requestPermission();

  /// Opens the notification settings of the app in Android.
  Future<void> openSettings();

  /// Opens the page of Android allowing the app to show notifications at
  /// their exact time, if not allowed yet. Completes with whether it is.
  Future<bool> requestExactAlarms();
}

/// Whether notifications can show: those of the app, and those of each
/// routine, which the user can turn off one by one in Android.
@immutable
class NotificationStatus {
  const NotificationStatus({
    required this.allowed,
    this.blocked = const {},
    this.exact = true,
  });

  /// Notifications that always show, where there are none to turn off.
  static const all = NotificationStatus(allowed: true);

  /// Whether the app may show notifications at all.
  final bool allowed;

  /// Routines whose notifications are turned off.
  final Set<DailyRoutine> blocked;

  /// Whether notifications show at their exact time. Otherwise, Android may
  /// delay them by hours.
  final bool exact;

  /// Whether the notifications of [routine] show.
  bool shows(DailyRoutine routine) => allowed && !blocked.contains(routine);

  @override
  bool operator ==(Object other) =>
      other is NotificationStatus &&
      other.allowed == allowed &&
      setEquals(other.blocked, blocked) &&
      other.exact == exact;

  @override
  int get hashCode =>
      Object.hash(allowed, Object.hashAllUnordered(blocked), exact);
}

const _remindersChannel = 'routine_reminders';
const _autoAddsChannel = 'routine_auto_adds';
const _addAction = 'add';
const _removeAction = 'remove';

/// The notifications of Android, or none on other platforms.
Future<RoutineNotifications> openRoutineNotifications() async {
  if (kIsWeb || !Platform.isAndroid) return const RoutineNotifications.none();
  tz.initializeTimeZones();
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } on Object catch (error, stack) {
    // Unknown zone: times stay in UTC, off by the offset of the zone.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'notifications',
      ),
    );
  }
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    ),
    onDidReceiveBackgroundNotificationResponse: onNotificationAction,
  );
  return _AndroidNotifications(plugin);
}

/// Runs the button tapped in a notification: adds the product of a
/// reminder, or removes the entry a product added on its own.
///
/// Android runs it apart from the app, which may be closed: it opens the
/// data itself, then tells the app if it runs, see
/// [listenToNotificationChanges].
@pragma('vm:entry-point')
Future<void> onNotificationAction(NotificationResponse response) async {
  final productId = int.tryParse(response.payload ?? '');
  final action = response.actionId;
  if (productId == null || (action != _addAction && action != _removeAction)) {
    return;
  }
  DartPluginRegistrant.ensureInitialized();
  final db = AppDatabase.open();
  try {
    final now = DateTime.now();
    if (action == _addAction) {
      final product = await db.productsDao.getProduct(productId);
      if (product != null) {
        await db.entriesDao.addPortion(product, createdAt: now);
      }
    } else {
      await db.entriesDao.removeRoutineEntry(productId, now);
    }
  } finally {
    await db.close();
  }
  notifyNotificationChange();
}

class _NoNotifications implements RoutineNotifications {
  const _NoNotifications();

  @override
  Future<void> schedule(List<Product> products, AppLocalizations l10n) async {}

  @override
  Future<NotificationStatus> status() async => NotificationStatus.all;

  /// Nothing to allow.
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> openSettings() async {}

  @override
  Future<bool> requestExactAlarms() async => true;
}

class _AndroidNotifications implements RoutineNotifications {
  _AndroidNotifications(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static const _settings = MethodChannel('protein_calculator/settings');

  @override
  Future<NotificationStatus> status() async {
    final android = _android;
    if (android == null) return NotificationStatus.all;
    // Channels exist once a notification of theirs was planned.
    final channels = await android.getNotificationChannels() ?? const [];
    bool off(String id) => channels.any(
      (channel) => channel.id == id && channel.importance == Importance.none,
    );
    return NotificationStatus(
      allowed: await android.areNotificationsEnabled() ?? false,
      blocked: {
        if (off(_remindersChannel)) DailyRoutine.reminder,
        if (off(_autoAddsChannel)) DailyRoutine.autoAdd,
      },
      exact: await android.canScheduleExactNotifications() ?? false,
    );
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> openSettings() =>
      _settings.invokeMethod<void>('openNotificationSettings');

  @override
  Future<bool> requestExactAlarms() async =>
      await _android?.requestExactAlarmsPermission() ?? false;

  @override
  Future<void> schedule(List<Product> products, AppLocalizations l10n) async {
    final routines = {
      for (final product in products)
        if (product.activeRoutineMinutes != null) product.id: product,
    };
    // Only those of products without a routine any more are cancelled: a
    // notification on screen stays until it is replaced.
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (!routines.containsKey(pending.id)) {
        await _plugin.cancel(id: pending.id);
      }
    }
    // At their exact time when allowed. Otherwise Android may delay them
    // by up to three quarters of the time left: hours for a time set the
    // day before.
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    for (final product in routines.values) {
      await _schedule(
        product,
        l10n,
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _schedule(
    Product product,
    AppLocalizations l10n,
    AndroidScheduleMode mode,
  ) {
    final reminder = product.routine == DailyRoutine.reminder;
    final grams = formatProtein(product.amount.proteinGrams, l10n.localeName);
    return _plugin.zonedSchedule(
      id: product.id,
      title: product.name,
      body: reminder
          ? l10n.notificationReminderBody(grams)
          : l10n.notificationAutoAddBody(grams),
      payload: '${product.id}',
      scheduledDate: _next(product.routineMinutes!),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: mode,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          reminder ? _remindersChannel : _autoAddsChannel,
          reminder
              ? l10n.notificationChannelReminders
              : l10n.notificationChannelAutoAdds,
          icon: 'ic_notification',
          color: AppColors.accent,
          category: reminder
              ? AndroidNotificationCategory.reminder
              : AndroidNotificationCategory.status,
          actions: [
            AndroidNotificationAction(
              reminder ? _addAction : _removeAction,
              reminder ? l10n.notificationAdd : l10n.notificationRemove,
            ),
          ],
        ),
      ),
    );
  }

  /// Next local moment at the time of day [minutes].
  static tz.TZDateTime _next(int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    return today.isAfter(now)
        ? today
        : tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + 1,
            minutes ~/ 60,
            minutes % 60,
          );
  }
}
