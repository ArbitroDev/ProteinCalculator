import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Whether the database file can be set aside, see [setAsideDatabase].
const canSetAsideDatabase = true;

/// Path of the database file, in the private documents directory of the app.
Future<String> databasePath() async =>
    '${(await getApplicationDocumentsDirectory()).path}/protein_calculator.sqlite';

/// Moves the database file away, so that the next opening starts with empty
/// data. The file is renamed, not deleted: it stays on the device.
Future<void> setAsideDatabase(DateTime now) async =>
    setAsideDatabaseFiles(await databasePath(), now);

/// Renames the database at [path] and the journal files next to it, adding
/// the date [now]: "protein_calculator.sqlite.broken-20261003-153000".
Future<void> setAsideDatabaseFiles(String path, DateTime now) async {
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.rename('$path.broken-$stamp$suffix');
  }
}
