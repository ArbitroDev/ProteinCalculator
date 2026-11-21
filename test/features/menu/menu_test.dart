import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openTestDatabase();
    await db.settingsDao.setDailyGoal(140);
    // The version comes from the platform package info.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (call) async => {
            'appName': 'Protein Calculator',
            'packageName': 'arbitro.android.protein_calculator',
            'version': '1.0.0',
            'buildNumber': '1',
          },
        );
  });

  Future<void> openMenu(WidgetTester tester) async {
    await pumpApp(tester, db);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('edits the daily goal', (tester) async {
    await openMenu(tester);
    expect(find.text('140 g'), findsOneWidget);

    // The goal comes first, before the start of the day.
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '160');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('160 g'), findsOneWidget);
    expect(await db.settingsDao.getDailyGoal(), 160);
    await disposeApp(tester, db);
  });

  testWidgets('refuses an invalid goal', (tester) async {
    await openMenu(tester);

    // The goal comes first, before the start of the day.
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a number between 1 and 1,000.'), findsOneWidget);
    expect(await db.settingsDao.getDailyGoal(), 140);
    await disposeApp(tester, db);
  });

  group('creatine', () {
    Finder creatineSwitch() => find.descendant(
      of: find.widgetWithText(ListTile, 'Creatine'),
      matching: find.byType(Switch),
    );

    testWidgets('turning creatine on opens the dose sheet', (tester) async {
      await openMenu(tester);
      expect(find.text('Off'), findsOneWidget);

      await tester.tap(creatineSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Creatine dose'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '60');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Between 1 and 50 g'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Dose: 7 g'), findsOneWidget);
      expect(
        await db.settingsDao.getCreatine(),
        isA<Object>().having((c) => c.toString(), 'settings', contains('7.0')),
      );
      await disposeApp(tester, db);
    });

    testWidgets('a tap on the card turns creatine on, its switch labeled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openMenu(tester);

      expect(tester.getSemantics(creatineSwitch()).label, contains('Creatine'));
      await tester.tap(find.text('Creatine'));
      await tester.pumpAndSettle();
      expect(find.text('Creatine dose'), findsOneWidget);
      expect((await db.settingsDao.getCreatine()).enabled, isTrue);
      await disposeApp(tester, db);
      semantics.dispose();
    });

    testWidgets('takes a dose with one decimal', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await openMenu(tester);

      await tester.tap(find.text('Creatine'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3.5');
      await tester.pumpAndSettle();
      // One decimal at most: a second one is refused.
      await tester.enterText(find.byType(TextField), '3.55');
      await tester.pumpAndSettle();
      expect(find.text('3.5'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Dose: 3.5 g'), findsOneWidget);
      expect((await db.settingsDao.getCreatine()).doseGrams, 3.5);
      await disposeApp(tester, db);
    });

    testWidgets('turning it off and on again keeps the dose', (tester) async {
      await db.settingsDao.setCreatineEnabled(true);
      await db.settingsDao.setCreatineDoseGrams(3);
      await openMenu(tester);

      await tester.tap(creatineSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(creatineSwitch());
      await tester.pumpAndSettle();

      // No sheet the second time.
      expect(find.text('Creatine dose'), findsNothing);
      expect(find.text('Dose: 3 g'), findsOneWidget);
      await disposeApp(tester, db);
    });
  });

  group('sheets', () {
    /// Opens each sheet of the menu in turn, with [check] run on it open.
    Future<void> eachSheet(
      WidgetTester tester,
      Future<void> Function() check,
    ) async {
      await db.settingsDao.setCreatineEnabled(true);
      await openMenu(tester);
      for (final open in [
        () => tester.tap(find.text('Edit').first),
        () => tester.tap(find.text('Creatine')),
        () => tester.tap(find.text('Edit').last),
      ]) {
        await open();
        await tester.pumpAndSettle();
        expect(find.text('Save'), findsOneWidget);
        await check();
        // Closes the sheet, if it is still open.
        if (find.text('Save').evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(400, 20));
          await tester.pumpAndSettle();
        }
      }
      await disposeApp(tester, db);
    }

    testWidgets('cover the tab bar', (tester) async {
      await eachSheet(tester, () async {
        // A tap on the tab bar closes the sheet instead of changing tab.
        await tester.tap(find.byTooltip('History'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('History'), findsNothing);
        expect(find.text('Save'), findsNothing);
      });
    });

    testWidgets('keep clear of the Android navigation bar', (tester) async {
      // A navigation bar of 48 logical pixels at the bottom of the screen.
      tester.view.padding = FakeViewPadding(
        bottom: 48 * tester.view.devicePixelRatio,
      );
      tester.view.viewPadding = FakeViewPadding(
        bottom: 48 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.reset);
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await eachSheet(tester, () async {
        expect(
          tester.getRect(find.text('Save')).bottom,
          lessThanOrEqualTo(height - 48),
        );
      });
    });
  });

  group('Hevy', () {
    /// Scrolls the menu down to the Hevy card and opens its sheet.
    Future<void> openHevySheet(WidgetTester tester) async {
      await openMenu(tester);
      await tester.scrollUntilVisible(find.text('Hevy workouts'), 100);
      await tester.tap(find.text('Hevy workouts'));
      await tester.pumpAndSettle();
    }

    /// The scrollable of the sheet, opened over the menu.
    final sheet = find.byType(Scrollable).last;

    testWidgets('the Hevy card opens its sheet', (tester) async {
      await openMenu(tester);
      await tester.scrollUntilVisible(find.text('Hevy workouts'), 100);
      expect(find.text('Not imported yet'), findsOneWidget);

      await tester.tap(find.text('Hevy workouts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('In Hevy: Profile'), findsOneWidget);
      expect(find.textContaining('Only the date, name'), findsOneWidget);
      expect(find.text('Choose the file'), findsOneWidget);
      // Nothing to delete before an import.
      expect(find.text('Delete Hevy workouts'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('trademark of Hevy Studios'),
        100,
        scrollable: sheet,
      );
      expect(find.textContaining('trademark of Hevy Studios'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('the import button of the Hevy card imports at once', (
      tester,
    ) async {
      final picker = _FakeFilePicker(
        'title,start_time,end_time\n'
        'Push,2026-10-01T07:00:00,2026-10-01T08:00:00\n',
      );
      final previous = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = previous);
      await openMenu(tester);
      await tester.scrollUntilVisible(find.text('Hevy workouts'), 100);

      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      expect(picker.picks, 1);
      // No sheet: the file is imported from the card.
      expect(find.text('Choose the file'), findsNothing);
      expect(find.text('1 Hevy workout imported'), findsOneWidget);
      expect(await db.select(db.hevySessions).get(), hasLength(1));
      expect(find.text('1 day · imported on Oct 1'), findsOneWidget);
      await disposeApp(tester, db);
    });

    testWidgets('clearing Hevy workouts asks first', (tester) async {
      await db.hevyDao.replaceSessions([
        HevySessionsCompanion.insert(
          title: 'Push',
          startedAt: DateTime(2026, 10, 1, 7),
          endedAt: Value(DateTime(2026, 10, 1, 8)),
          dayKey: dayKeyOf(DateTime(2026, 10, 1, 7)),
        ),
      ], importedAt: DateTime(2026, 10, 1, 8, 30));
      await openHevySheet(tester);

      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('Last workout: Oct 1'), findsOneWidget);
      expect(find.text('Imported on Oct 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Delete Hevy workouts'),
        100,
        scrollable: sheet,
      );
      await tester.tap(find.text('Delete Hevy workouts'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Hevy workouts?'), findsOneWidget);

      // Cancelling keeps them.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await db.select(db.hevySessions).get(), hasLength(1));

      await tester.tap(find.text('Delete Hevy workouts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await db.select(db.hevySessions).get(), isEmpty);
      expect(
        (await db.select(db.appSettings).getSingle()).hevyImportedAt,
        equals(null),
      );
      // The sheet follows: nothing left to delete.
      expect(find.text('Delete Hevy workouts'), findsNothing);
      expect(find.text('1 day'), findsNothing);
      await disposeApp(tester, db);
    });
  });

  testWidgets('chooses when the day starts', (tester) async {
    addTearDown(() => appDayStartHour = defaultAppDayStartHour);
    await openMenu(tester);
    expect(find.textContaining('3:00'), findsOneWidget);

    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    // The slider runs from midnight to 7 a.m.: its end is 7 a.m.
    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(slider.centerRight - const Offset(24, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await db.settingsDao.getDayStartHour(), 7);
    expect(appDayStartHour, 7);
    await disposeApp(tester, db);
  });

  testWidgets('turns the missed entry reminders on and off', (tester) async {
    await openMenu(tester);
    expect(await db.settingsDao.getSlotReminders(), isFalse);

    // Off by default; without notifications to allow in tests, it turns on
    // at once.
    await tester.tap(find.text('Missed entry reminders'));
    await tester.pumpAndSettle();
    expect(await db.settingsDao.getSlotReminders(), isTrue);

    await tester.tap(find.text('Missed entry reminders'));
    await tester.pumpAndSettle();
    expect(await db.settingsDao.getSlotReminders(), isFalse);
    await disposeApp(tester, db);
  });

  testWidgets('opens the data and privacy page', (tester) async {
    await openMenu(tester);

    await tester.tap(find.text('Data and privacy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your data stays on your phone.'), findsWidgets);
    expect(
      find.textContaining('only its barcode is sent to Open Food Facts'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Import a backup'), 200);
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Import a backup'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('opens the about page with the GitHub link', (tester) async {
    await openMenu(tester);

    await tester.scrollUntilVisible(find.text('About'), 200);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0'), findsOneWidget);
    expect(find.textContaining('contributing code on GitHub'), findsOneWidget);
    expect(find.text('View the source code on GitHub'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open Food Facts'), 200);
    expect(find.textContaining('Open Database License (ODbL)'), findsOneWidget);
    expect(find.text('world.openfoodfacts.org'), findsOneWidget);
    await disposeApp(tester, db);
  });
}

/// File picker giving a file of [content] each time it is asked.
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this.content);

  final String content;

  /// How many times a file was asked for.
  int picks = 0;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    picks++;
    return _FakeFile(utf8.encode(content));
  }
}

/// A picked file holding [bytes].
final class _FakeFile extends PlatformFile {
  _FakeFile(this.bytes);

  final Uint8List bytes;

  @override
  String get name => 'workouts.csv';

  @override
  Uri get uri => Uri.file('/workouts.csv');

  // Not read by the import. Its type is inferred, as the package giving it
  // is not a dependency of the app.
  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}
