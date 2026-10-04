import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/startup.dart';

void main() {
  /// Databases opened by the app, closed after each test.
  final opened = <AppDatabase>[];

  AppDatabase unreadable() => AppDatabase(
    NativeDatabase.memory(
      setup: (_) => throw StateError('file is not a database'),
    ),
  );

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    opened.clear();
    // The goal field of the first launch screen has a blinking cursor.
    EditableText.debugDeterministicCursor = true;
    addTearDown(() => EditableText.debugDeterministicCursor = false);
  });

  Future<void> stopApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    for (final database in opened) {
      await database.close();
    }
  }

  testWidgets('starts the app when the data can be read', (tester) async {
    opened.add(AppDatabase(NativeDatabase.memory()));

    expect(await startApp(openDatabase: () => opened.last), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Your daily\ngoal'), findsOneWidget);
    await stopApp(tester);
  });

  testWidgets('offers to try again when the data cannot be read', (
    tester,
  ) async {
    var attempts = 0;
    opened.add(AppDatabase(NativeDatabase.memory()));
    AppDatabase open() => ++attempts == 1 ? unreadable() : opened.last;

    expect(await startApp(openDatabase: open), isFalse);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(find.text("Your data can't be read"), findsOneWidget);
    expect(find.text('Start over from a backup'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Your daily\ngoal'), findsOneWidget);
    await stopApp(tester);
  });

  testWidgets('says so when trying again still fails', (tester) async {
    expect(await startApp(openDatabase: unreadable), isFalse);
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Try again'));
    // Closing a database that could not open completes in real time.
    await tester.runAsync(() => Future<void>.delayed(Durations.short1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(find.text("Your data can't be read"), findsOneWidget);
    expect(find.text("Your data still can't be read."), findsOneWidget);
    await stopApp(tester);
  });
}
