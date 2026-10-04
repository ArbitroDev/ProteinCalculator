import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/database_file_native.dart';

void main() {
  test('renames the database and its journal, keeping them', () async {
    final directory = await Directory.systemTemp.createTemp();
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/protein_calculator.sqlite';
    await File(path).writeAsString('data');
    await File('$path-wal').writeAsString('journal');

    await setAsideDatabaseFiles(path, DateTime(2026, 10, 3, 15, 30, 5));

    final stamped = '$path.broken-20261003-153005';
    expect(File(path).existsSync(), isFalse);
    expect(File('$path-wal').existsSync(), isFalse);
    expect(await File(stamped).readAsString(), 'data');
    expect(await File('$stamped-wal').readAsString(), 'journal');
  });
}
