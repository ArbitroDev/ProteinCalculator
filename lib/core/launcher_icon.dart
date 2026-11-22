import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/domain/christmas.dart';
import 'package:protein_calculator/core/providers.dart';

/// Link with `AppActivity`, which switches the icon of the app in the
/// launcher, see `LauncherIcon` in the Android app.
const launcherIconChannel = MethodChannel('protein_calculator/launcher_icon');

/// Shows the Christmas icon in the launcher while the Christmas theme is on,
/// the usual one otherwise: checked when the app opens, at the start of each
/// app day and when the user turns the theme on or off. The icon changes
/// once the app is no longer seen, and goes back to the usual one at the end
/// of the season even if the app is not opened. Waits for the setting, the
/// day and its start hour, so the icon does not change back and forth while
/// they load.
final launcherIconProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final on = ref.watch(christmasThemeProvider).value;
  final today = ref.watch(currentDayKeyProvider).value;
  final dayStartHour = ref.watch(dayStartHourProvider).value;
  if (on == null || today == null || dayStartHour == null) return;
  final christmas = on && isChristmasSeason(today);
  unawaited(
    launcherIconChannel
        .invokeMethod<void>('setChristmas', {
          'christmas': christmas,
          'seasonEnd': christmas
              ? christmasSeasonEnd(today, dayStartHour).millisecondsSinceEpoch
              : null,
        })
        .catchError((_) {
          // The icon is a detail: the app goes on with the one it has.
        }),
  );
});
