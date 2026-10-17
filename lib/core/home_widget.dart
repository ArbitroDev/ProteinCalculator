import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:protein_calculator/core/watch/watch_state.dart';

/// Widget "Today's goal" of the home screen, see `GoalWidget` in the Android
/// app: the progress of the day towards its goal, and whether creatine was
/// taken.
const _widget = 'arbitro.android.protein_calculator.GoalWidget';

/// Key of the day the widget shows, a JSON object, in the storage of the
/// plugin `home_widget`.
const homeWidgetDayKey = 'day';

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

  /// Protein grams of the day, exact: the widget truncates them as the app.
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

/// Shows [state], the day sent to the watch, in the widget of the home
/// screen, on Android only. A failure is only reported: the widget keeps
/// what it showed.
Future<void> updateHomeWidget(WatchState state) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await HomeWidget.saveWidgetData<String>(
      homeWidgetDayKey,
      jsonEncode(HomeWidgetDay.of(state).toJson()),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: _widget);
  } on MissingPluginException {
    // An engine without the plugin, as in the tests: no widget to update.
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'widget'),
    );
  }
}
