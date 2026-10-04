import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/providers.dart';

void main() {
  testWidgets('current day key switches at 3 a.m. and on resume', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 1, 23);
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final keys = <int>[];
    container.listen(currentDayKeyProvider, (_, next) {
      if (next.hasValue) keys.add(next.value!);
    }, fireImmediately: true);

    await tester.pump();
    expect(keys, [20261001]);

    // 3 a.m. the next calendar day: a new app day starts.
    now = DateTime(2026, 10, 2, 3);
    await tester.pump(const Duration(hours: 4));
    expect(keys, [20261001, 20261002]);

    // The app was in the background for a whole day.
    now = DateTime(2026, 10, 3, 10);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(keys, [20261001, 20261002, 20261003]);

    container.dispose();
  });
}
