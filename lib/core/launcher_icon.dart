import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/domain/christmas.dart';
import 'package:protein_calculator/core/providers.dart';

/// Link with `AppActivity`, which switches the icon of the app in the
/// launcher.
const _channel = MethodChannel('protein_calculator/launcher_icon');

/// Shows the Christmas icon in the launcher while the Christmas theme is on,
/// the usual one otherwise: checked when the app opens, at the start of each
/// app day and when the user turns the theme on or off. The icon changes
/// once the app is left, as Android closes an app whose icon changes. Waits for both the
/// setting and the day, so the icon does not change back and forth while
/// they load.
final launcherIconProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  final on = ref.watch(christmasThemeProvider).value;
  final today = ref.watch(currentDayKeyProvider).value;
  if (on == null || today == null) return;
  final christmas = on && isChristmasSeason(today);
  unawaited(
    _channel.invokeMethod<void>('setChristmas', christmas).catchError((_) {
      // The icon is a detail: the app goes on with the one it has.
    }),
  );
});
