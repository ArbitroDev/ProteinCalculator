import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
  });

  testWidgets('stays open and usable when saving fails', (tester) async {
    await db.customStatement(
      'CREATE TRIGGER fail BEFORE INSERT ON entries '
      "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '30');
    final save = find.widgetWithText(FilledButton, 'Add');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<SqliteException>());
    expect(find.text('Something went wrong, please try again.'), findsOne);
    expect(find.text('New entry'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await disposeApp(tester, db);
  });
}
