import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/hevy/hevy_import_flow.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Link with `MainActivity`, which keeps the file shared to the app until
/// `take` gives it, and says `available` when one is shared while the app is
/// open.
const _channel = MethodChannel('protein_calculator/shared_file');

/// Imports the Hevy export shared to the app from Hevy, on Android: the one
/// that opened the app, then each one shared while it is open, one after the
/// other. The import runs as from the menu, over whichever screen is open,
/// the first launch screen included.
final sharedFileProvider = Provider<void>((ref) {
  // Only Android shares files to the app.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  var imports = Future<void>.value();
  void importNext() {
    imports = imports.then((_) => _importSharedFile(ref));
  }

  _channel.setMethodCallHandler((call) async {
    if (call.method == 'available') importNext();
  });
  ref.onDispose(() => _channel.setMethodCallHandler(null));
  importNext();
});

/// Takes the file shared to the app, if any, and imports it once the app
/// shows a screen. Only reports an unexpected failure: the next file shared
/// still imports.
Future<void> _importSharedFile(Ref ref) async {
  try {
    String? content;
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('take');
      if (bytes == null) return;
      content = utf8.decode(bytes);
    } on MissingPluginException {
      // An engine without the channel, as in the tests: nothing is shared.
      return;
    } on PlatformException {
      // Larger than 32 MB, or the app that shared it no longer lets it be
      // read: told as unreadable.
    } on FormatException {
      // Not text: told as unreadable.
    }

    final screen = await _shownScreen(ref);
    if (screen == null || !ref.mounted) return;
    if (content == null) {
      screen.messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(screen.l10n.hevyErrorUnreadable)),
        );
      return;
    }
    await runHevyImport(
      context: screen.context,
      db: ref.read(databaseProvider),
      messenger: screen.messenger,
      l10n: screen.l10n,
      firstDayKey: screen.firstDayKey,
      todayKey: screen.todayKey,
      content: content,
    );
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'hevy',
        context: ErrorDescription('while importing a shared file'),
      ),
    );
  }
}

/// What the import needs of the app: the screen it shows, and the days the
/// history shows, which the message counts the workouts of.
typedef _Screen = ({
  BuildContext context,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  int firstDayKey,
  int todayKey,
});

/// Waits until the app shows a screen and knows the days the history shows;
/// null if the app closes before.
Future<_Screen?> _shownScreen(Ref ref) async {
  if (!ref.mounted) return null;
  final firstDayKey = await _firstAppDayKey(ref);
  while (ref.mounted) {
    if (_screen(ref, firstDayKey) case final screen?) return screen;
    // Until the first frame of the app.
    await WidgetsBinding.instance.endOfFrame;
  }
  return null;
}

/// The screen the app shows, or null before its first frame.
_Screen? _screen(Ref ref, int firstDayKey) {
  final context = ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentContext;
  final messenger = appMessengerKey.currentState;
  if (context == null || messenger == null) return null;
  return (
    context: context,
    messenger: messenger,
    l10n: AppLocalizations.of(context),
    firstDayKey: firstDayKey,
    // Read too, since the first app day comes from it.
    todayKey: ref.read(currentDayKeyProvider).requireValue,
  );
}

/// The first app day, once the current day and the data it comes from are
/// read: listened to until then.
Future<int> _firstAppDayKey(Ref ref) {
  final dayKey = Completer<int>();
  final subscription = ref.listen(firstAppDayKeyProvider, (_, next) {
    if (next != null && !dayKey.isCompleted) dayKey.complete(next);
  }, fireImmediately: true);
  return dayKey.future.whenComplete(subscription.close);
}
