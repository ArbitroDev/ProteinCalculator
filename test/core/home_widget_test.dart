import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/home_widget.dart';
import 'package:protein_calculator/core/watch/watch_state.dart';

void main() {
  WatchEntry entry(int id, {double protein = 20, int doses = 0}) => WatchEntry(
    id: id,
    name: null,
    protein: protein,
    time: DateTime(2026, 10, 1, 8),
    fromWatch: false,
    creatineDoses: doses,
    creatineGrams: doses * 5.0,
  );

  WatchState state(List<WatchEntry> entries, {double? goal = 140}) =>
      WatchState(
        dayKey: 20261001,
        dayStartHour: 3,
        total: 32.5,
        goal: goal,
        entries: entries,
        products: const [],
        handled: const [],
      );

  test('the widget shows the day sent to the watch', () {
    final day = HomeWidgetDay.of(state([entry(1)]));

    expect(day.toJson(), {
      'day': 20261001,
      'dayStartHour': 3,
      'total': 32.5,
      'goal': 140.0,
      'creatine': false,
    });
  });

  test('the widget tells creatine taken once a dose is in the day', () {
    final day = HomeWidgetDay.of(
      state([entry(1), entry(2, protein: 0, doses: 1)]),
    );

    expect(day.creatineTaken, isTrue);
  });

  test('the widget has no goal until the first launch', () {
    expect(
      HomeWidgetDay.of(state(const [], goal: null)).toJson()['goal'],
      null,
    );
  });

  test('updating the widget without its plugin does nothing', () async {
    // The engines of the tests have no plugin: no error reported.
    await updateHomeWidget(state([entry(1)]));
  });
}
