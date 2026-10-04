import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:protein_calculator/core/backup.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Lets the user pick a backup file and reads it. Returns null if the user
/// cancels, or if the file is not a valid backup, which [messenger] says.
///
/// Other errors, such as a file that cannot be read, are thrown.
Future<Backup?> pickBackup(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (file == null) return null;
  try {
    return parseBackup(utf8.decode(await file.readAsBytes()));
  } on Exception catch (error) {
    // Not text, or not a backup.
    if (error is! FormatException && error is! InvalidBackupException) rethrow;
    messenger.showSnackBar(SnackBar(content: Text(l10n.importInvalid)));
    return null;
  }
}
