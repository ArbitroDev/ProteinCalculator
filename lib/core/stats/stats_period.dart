import 'package:flutter/foundation.dart' show immutable;
import 'package:protein_calculator/core/domain/app_day.dart';

/// Length of the periods the statistics tab sums up.
enum StatsSpan { week, month, year }

/// A week, a month or a year of app days, from [start] (at midnight) to
/// [end] (excluded).
///
/// Built from calendar fields rather than durations, so daylight saving
/// changes never shift a day.
@immutable
class StatsPeriod {
  const StatsPeriod._(this.span, this.start);

  /// Period of [span] holding the calendar date of [date]; a week starts on
  /// [firstWeekday], 0 for Sunday as the localizations count.
  factory StatsPeriod.containing(
    StatsSpan span,
    DateTime date, {
    required int firstWeekday,
  }) => StatsPeriod._(span, switch (span) {
    StatsSpan.week => DateTime(
      date.year,
      date.month,
      date.day - (date.weekday % 7 - firstWeekday + 7) % 7,
    ),
    StatsSpan.month => DateTime(date.year, date.month),
    StatsSpan.year => DateTime(date.year),
  });

  final StatsSpan span;
  final DateTime start;

  DateTime get end => _shifted(1);

  StatsPeriod get previous => StatsPeriod._(span, _shifted(-1));
  StatsPeriod get next => StatsPeriod._(span, end);

  DateTime _shifted(int count) => switch (span) {
    StatsSpan.week => DateTime(start.year, start.month, start.day + 7 * count),
    StatsSpan.month => DateTime(start.year, start.month + count),
    StatsSpan.year => DateTime(start.year + count),
  };

  /// Date in the middle of the period, kept when the span changes.
  DateTime get middle =>
      DateTime(start.year, start.month, start.day + dayKeys.length ~/ 2);

  /// Keys of all the days of the period, in order.
  List<int> get dayKeys => [
    for (
      var date = start;
      date.isBefore(end);
      date = DateTime(date.year, date.month, date.day + 1)
    )
      dayKeyOfDate(date),
  ];

  int get firstKey => dayKeyOfDate(start);
  int get lastKey {
    final end = this.end;
    return dayKeyOfDate(DateTime(end.year, end.month, end.day - 1));
  }

  bool contains(int dayKey) => dayKey >= firstKey && dayKey <= lastKey;

  /// The twelve months of a year.
  List<StatsPeriod> get months => [
    for (var month = 1; month <= 12; month++)
      StatsPeriod._(StatsSpan.month, DateTime(start.year, month)),
  ];

  @override
  bool operator ==(Object other) =>
      other is StatsPeriod && other.span == span && other.start == start;

  @override
  int get hashCode => Object.hash(span, start);

  @override
  String toString() => 'StatsPeriod($span, $start)';
}

/// Days of [period] the statistics count: from the first app day of the
/// app to today, so that neither the days to come nor those before the
/// app was used lower the averages.
List<int> countedDayKeys(
  StatsPeriod period, {
  required int firstAppDayKey,
  required int todayKey,
}) => [
  for (final dayKey in period.dayKeys)
    if (dayKey >= firstAppDayKey && dayKey <= todayKey) dayKey,
];

/// Key of the app day after [dayKey].
int nextDayKey(int dayKey) => _shiftDay(dayKey, 1);

/// Key of the app day before [dayKey].
int previousDayKey(int dayKey) => _shiftDay(dayKey, -1);

int _shiftDay(int dayKey, int days) {
  final date = dateOfDayKey(dayKey);
  return dayKeyOfDate(DateTime(date.year, date.month, date.day + days));
}
