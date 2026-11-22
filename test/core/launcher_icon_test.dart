import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/launcher_icon.dart';
import 'package:protein_calculator/core/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Object?> calls;

  setUp(() {
    calls = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherIconChannel, (call) async {
          calls.add(call.arguments);
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherIconChannel, null);
  });

  ProviderContainer container({
    required Stream<bool> theme,
    required Stream<int> days,
    required Stream<int> startHours,
  }) {
    final container = ProviderContainer(
      overrides: [
        christmasThemeProvider.overrideWith((ref) => theme),
        currentDayKeyProvider.overrideWith((ref) => days),
        dayStartHourProvider.overrideWith((ref) => startHours),
      ],
    );
    addTearDown(container.dispose);
    container.listen(launcherIconProvider, (_, _) {});
    return container;
  }

  test('asks for the Christmas icon until the end of the season', () async {
    final theme = StreamController<bool>();
    addTearDown(theme.close);
    container(
      theme: theme.stream,
      days: Stream.value(20261215),
      startHours: Stream.value(4),
    );
    await pumpEventQueue();
    // The setting still loads: the icon stays as it is.
    expect(calls, isEmpty);

    theme.add(true);
    await pumpEventQueue();
    expect(calls, [
      {
        'christmas': true,
        'seasonEnd': DateTime(2026, 12, 26, 4).millisecondsSinceEpoch,
      },
    ]);
  });

  test('asks for the usual icon out of the season or theme off', () async {
    container(
      theme: Stream.value(true),
      days: Stream.value(20261226),
      startHours: Stream.value(4),
    );
    await pumpEventQueue();
    expect(calls, [
      {'christmas': false, 'seasonEnd': null},
    ]);
  });
}
