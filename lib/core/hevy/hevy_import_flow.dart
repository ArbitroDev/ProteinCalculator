import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/formatting.dart';
import 'package:protein_calculator/core/hevy/hevy_csv.dart';
import 'package:protein_calculator/core/hevy/hevy_import.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Lets the user pick a Hevy export and reads it as text. Returns null if the
/// user cancels, or if the file is not text, which [messenger] says.
///
/// Other errors, such as a file that cannot be read, are thrown.
Future<String?> pickHevyFile(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  // Any file: Android greys out the CSV files typed application/octet-stream
  // or application/csv when the picker asks for extensions, and a file that
  // is not an export is refused with a message anyway.
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  try {
    return utf8.decode(await file.readAsBytes());
  } on FormatException {
    _say(messenger, l10n.hevyErrorUnreadable);
    return null;
  }
}

/// Imports [content], a Hevy export, in place of the workouts kept, and says
/// so with [messenger]. [context] asks the user first when the file stops
/// before the latest workout already kept. [firstDayKey] and [todayKey] tell
/// which workouts the history shows, the ones the message counts.
///
/// A file that is refused is told to the user and nothing more: it is never
/// reported, so that nothing of its content leaves the phone. [clock] tells
/// when the import is made.
Future<void> runHevyImport({
  required BuildContext context,
  required AppDatabase db,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required int? firstDayKey,
  required int todayKey,
  required String content,
  DateTime Function() clock = DateTime.now,
}) async {
  final prepared = await runUserAction(messenger, l10n, () async {
    try {
      return await prepareHevyImport(db, content);
    } on HevyFileException catch (error) {
      _say(messenger, _errorMessage(l10n, error.error));
      return null;
    }
  });
  if (prepared == null) return;

  if (prepared.isOlder) {
    if (!context.mounted) return;
    final today = clock();
    final fileLastStart = prepared.fileLastStart;
    final replace = await showDialog<bool>(
      context: context,
      // A file without any workout would remove those imported: the user is
      // asked as when deleting them from the menu.
      builder: (context) => AlertDialog(
        title: Text(
          fileLastStart == null ? l10n.hevyClearTitle : l10n.hevyOlderTitle,
        ),
        content: Text(
          fileLastStart == null
              ? l10n.hevyClearBody
              : l10n.hevyOlderBody(
                  formatDayMonth(fileLastStart, l10n.localeName, now: today),
                  // An older file means workouts are already imported.
                  formatDayMonth(
                    prepared.currentLastStart!,
                    l10n.localeName,
                    now: today,
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              fileLastStart == null
                  ? l10n.hevyClearConfirm
                  : l10n.hevyOlderReplace,
            ),
          ),
        ],
      ),
    );
    if (replace != true) return;
  }

  final imported = await runUserAction(messenger, l10n, () async {
    try {
      await applyHevyImport(db, prepared, now: clock());
    } on Object catch (error, stack) {
      // The message of a database error may quote the titles of the workouts:
      // only the kind of error is reported.
      Error.throwWithStackTrace(HevyImportFailure(error.runtimeType), stack);
    }
    return true;
  });
  if (imported == null) return;
  _say(
    messenger,
    l10n.hevyImported(
      shownSessionCount(prepared, firstDayKey: firstDayKey, todayKey: todayKey),
    ),
  );
}

/// An import that failed to be saved, reported without the message of the
/// error, which may quote the content of the file.
class HevyImportFailure implements Exception {
  const HevyImportFailure(this.errorType);

  /// The type of the error that made the import fail.
  final Type errorType;

  @override
  String toString() => 'HevyImportFailure: $errorType';
}

String _errorMessage(AppLocalizations l10n, HevyFileError error) =>
    switch (error) {
      HevyFileError.unreadable => l10n.hevyErrorUnreadable,
      HevyFileError.notHevy => l10n.hevyErrorNotHevy,
      HevyFileError.dates => l10n.hevyErrorDates,
    };

/// Shows [message] in place of the one on screen.
void _say(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));
