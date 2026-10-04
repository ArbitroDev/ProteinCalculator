// Renders the Google Play screenshots of the app, in French and English.
//
// Not part of the test suite: run it on demand with
//   flutter test tool/store_screenshots --update-goldens
// The images land in tool/store_screenshots/<language>/.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/router.dart';

import '../../test/helpers.dart';

/// Thursday 1 October 2026, 7:40 p.m.: the three parts of the day are filled.
final _now = DateTime(2026, 10, 1, 19, 40);

/// Loads every font of the app and its packages, so text and icons render
/// as on a phone instead of the blocks of the test font.
Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

class _Texts {
  const _Texts({
    required this.locale,
    required this.products,
    required this.entries,
    required this.earlierDays,
  });

  final Locale locale;

  /// Name, protein per 100 g, portion; the first one is the favorite.
  final List<(String, double, double)> products;

  /// Name, protein, hour, minute, on the current day.
  final List<(String, double, int, int)> entries;

  /// Names used on the previous days.
  final List<String> earlierDays;
}

const _french = _Texts(
  locale: Locale('fr', 'FR'),
  products: [
    ('Skyr nature', 10, 150),
    ('Blanc de poulet', 26, 120),
    ('Whey vanille', 78, 30),
    ('Œufs', 12.5, 120),
    ('Lentilles cuites', 9, 200),
  ],
  entries: [
    ('Œufs', 15, 8, 10),
    ('Skyr nature', 15, 10, 30),
    ('Blanc de poulet', 31.2, 12, 45),
    ('Whey vanille', 23.4, 17, 15),
    ('Lentilles cuites', 18, 19, 20),
  ],
  earlierDays: ['Skyr nature', 'Blanc de poulet', 'Whey vanille', 'Œufs'],
);

const _english = _Texts(
  locale: Locale('en', 'US'),
  products: [
    ('Plain skyr', 10, 150),
    ('Chicken breast', 26, 120),
    ('Vanilla whey', 78, 30),
    ('Eggs', 12.5, 120),
    ('Cooked lentils', 9, 200),
  ],
  entries: [
    ('Eggs', 15, 8, 10),
    ('Plain skyr', 15, 10, 30),
    ('Chicken breast', 31.2, 12, 45),
    ('Vanilla whey', 23.4, 17, 15),
    ('Cooked lentils', 18, 19, 20),
  ],
  earlierDays: ['Plain skyr', 'Chicken breast', 'Vanilla whey', 'Eggs'],
);

Future<AppDatabase> _seed(_Texts texts) async {
  final db = openTestDatabase();
  await db.settingsDao.setDailyGoal(140);
  for (final (name, per, portion) in texts.products) {
    await db.productsDao.insertProduct(
      name: name,
      amount: PerQuantityAmount(
        consumedGrams: portion,
        proteinPerReference: per,
        referenceGrams: 100,
      ),
      createdAt: _now.subtract(const Duration(days: 20)),
    );
  }
  final favorite = (await db.productsDao.watchAll(_sortAz).first).firstWhere(
    (product) => product.name == texts.products.first.$1,
  );
  await db.productsDao.setFavorite(favorite.id, favorite: true);

  Future<void> add(String name, double grams, DateTime at) => db.entriesDao
      .insertEntry(name: name, amount: DirectAmount(grams), createdAt: at);

  for (final (name, grams, hour, minute) in texts.entries) {
    await add(name, grams, DateTime(2026, 10, 1, hour, minute));
  }
  // Earlier days, around the goal.
  const totals = [146, 121, 138, 152, 97, 143];
  for (var day = 1; day <= totals.length; day++) {
    final date = DateTime(2026, 10, 1 - day);
    final total = totals[day - 1];
    final names = texts.earlierDays;
    await add(names[0], total * 0.25, date.add(const Duration(hours: 8)));
    await add(names[1], total * 0.35, date.add(const Duration(hours: 13)));
    await add(names[2], total * 0.2, date.add(const Duration(hours: 17)));
    await add(names[3], total * 0.2, date.add(const Duration(hours: 20)));
  }
  return db;
}

const _sortAz = ProductSort.alphabetical;

void main() {
  setUpAll(_loadFonts);
  // No "debug" banner, as in the published app.
  setUp(() => WidgetsApp.debugAllowBannerOverride = false);
  tearDown(() => WidgetsApp.debugAllowBannerOverride = true);

  for (final (texts, folder) in [(_french, 'fr'), (_english, 'en')]) {
    for (final dark in [true, false]) {
      final theme = dark ? 'dark' : 'light';

      testWidgets('$folder $theme', (tester) async {
        // No accelerometer here: the shaker simply stays still.
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        for (final channel in [
          'dev.fluttercommunity.plus/sensors/method',
          'dev.fluttercommunity.plus/sensors/accelerometer',
        ]) {
          messenger.setMockMethodCallHandler(
            MethodChannel(channel),
            (_) async => null,
          );
        }
        // A 1080 x 1920 phone screen (9:16).
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        final db = await tester.runAsync(() => _seed(texts));
        await pumpApp(tester, db!, now: _now, locales: [texts.locale]);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        Future<void> shoot(String name) async {
          await tester.pumpAndSettle(const Duration(seconds: 2));
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('$folder/$theme-$name.png'),
          );
        }

        GoRouter router() =>
            GoRouter.of(tester.element(find.byType(Navigator).first));

        await shoot('1-today');

        router().go(AppRoutes.historyDay(20261001));
        await shoot('2-day');

        router().go(AppRoutes.history);
        await shoot('3-history');

        router().go(AppRoutes.products);
        await shoot('4-products');

        final products = await tester.runAsync(
          () => db.productsDao.watchAll(_sortAz).first,
        );
        final chicken = products!.firstWhere(
          (product) => product.name == texts.products[1].$1,
        );
        unawaited(router().push(AppRoutes.newEntryFrom(chicken.id)));
        await shoot('5-entry');

        await disposeApp(tester, db);
      });
    }
  }
}
