import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/watch/watch_state.dart';

/// Widget "Today's goal" of the home screen, see `GoalWidget` in the Android
/// app: the progress of the day towards its goal, and whether creatine was
/// taken.
const _widget = 'arbitro.android.protein_calculator.GoalWidget';

/// Key of the day the widget shows, a JSON object, in the storage of the
/// plugin `home_widget`.
const homeWidgetDayKey = 'day';

/// Key of the Christmas theme setting, a bool, in the storage of the plugin
/// `home_widget`: the widget dresses for Christmas from December 1 to 25
/// while it is on, checking the day on its own.
const homeWidgetChristmasKey = 'christmasTheme';

/// What the widget shows of the app day: it starts a new day at
/// [dayStartHour] on its own, with nothing, without waiting for the app.
@immutable
class HomeWidgetDay {
  const HomeWidgetDay({
    required this.dayKey,
    required this.dayStartHour,
    required this.total,
    required this.goal,
    required this.creatineTaken,
  });

  /// The day the watch is sent: the same values, read once.
  factory HomeWidgetDay.of(WatchState state) => HomeWidgetDay(
    dayKey: state.dayKey,
    dayStartHour: state.dayStartHour,
    total: state.total,
    goal: state.goal,
    creatineTaken: state.entries.any((entry) => entry.creatineDoses > 0),
  );

  final int dayKey;
  final int dayStartHour;

  /// Protein grams of the day, exact: the widget rounds them as the app.
  final double total;

  /// Goal of the day; null until the first launch is done.
  final double? goal;

  /// Whether a creatine dose was taken that day.
  final bool creatineTaken;

  Map<String, Object?> toJson() => {
    'day': dayKey,
    'dayStartHour': dayStartHour,
    'total': total,
    'goal': goal,
    'creatine': creatineTaken,
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetDay &&
      other.dayKey == dayKey &&
      other.dayStartHour == dayStartHour &&
      other.total == total &&
      other.goal == goal &&
      other.creatineTaken == creatineTaken;

  @override
  int get hashCode =>
      Object.hash(dayKey, dayStartHour, total, goal, creatineTaken);
}

/// Tells the widget of the home screen whether the Christmas theme is on,
/// each time the user turns it on or off, on Android only.
final homeWidgetChristmasProvider = Provider<void>((ref) {
  final on = ref.watch(christmasThemeProvider).value;
  if (on != null) unawaited(updateHomeWidgetChristmas(on));
});

/// Writes the Christmas theme setting [on] for the widget and draws it
/// again. A failure is only reported: the widget keeps what it showed.
Future<void> updateHomeWidgetChristmas(bool on) => _updateWidget(
  () => HomeWidget.saveWidgetData<bool>(homeWidgetChristmasKey, on),
);

/// Shows [state], the day sent to the watch, in the widget of the home
/// screen, on Android only. A failure is only reported: the widget keeps
/// what it showed.
Future<void> updateHomeWidget(WatchState state) => _updateWidget(
  () => HomeWidget.saveWidgetData<String>(
    homeWidgetDayKey,
    jsonEncode(HomeWidgetDay.of(state).toJson()),
  ),
);

/// Saves data with [save], then draws the widget again, on Android only.
Future<void> _updateWidget(Future<void> Function() save) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await save();
    await HomeWidget.updateWidget(qualifiedAndroidName: _widget);
  } on MissingPluginException {
    // An engine without the plugin, as in the tests: no widget to update.
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'widget'),
    );
  }
}
