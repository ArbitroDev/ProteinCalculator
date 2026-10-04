import 'package:flutter/material.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Runs [action], started by the user, and returns its result, or null if
/// it failed.
///
/// A failure is reported like any other error, so it reaches the crash
/// reports when the user agreed to send them, and [messenger] tells the user
/// that it did not work. The screen never stays stuck waiting for it.
Future<T?> runUserAction<T>(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'protein_calculator',
        context: ErrorDescription('while running an action of the user'),
      ),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    return null;
  }
}
