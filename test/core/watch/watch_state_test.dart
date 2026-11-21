import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/app_day.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/watch/watch_addition.dart';
import 'package:protein_calculator/core/watch/watch_state.dart';

import '../database/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = openTestDatabase();
    addTearDown(() => appDayStartHour = defaultAppDayStartHour);
  });

  Future<void> addEntry(double grams, DateTime createdAt, {String? name}) =>
      db.entriesDao.insertEntry(
        name: name,
        amount: DirectAmount(grams),
        createdAt: createdAt,
      );

  group('WatchState', () {
    test(
      'holds the day, its entries the most recent first, and the products',
      () async {
        await db.productsDao.insertProduct(
          name: 'Skyr',
          amount: const PerQuantityAmount(
            consumedGrams: 150,
            proteinPerReference: 10,
            referenceGrams: 100,
          ),
          createdAt: DateTime(2026, 9),
        );
        await addEntry(20, DateTime(2026, 10, 1, 8), name: 'Oeufs');
        await addEntry(12.5, DateTime(2026, 10, 1, 12));
        final products = await db.select(db.products).get();
        await db.productsDao.setFavorite(products.single.id, favorite: true);

        final entries = await db.entriesDao.watchDayEntries(20261001).first;
        final state = WatchState.of(
          dayKey: 20261001,
          dayStartHour: 3,
          entries: entries,
          goal: 140,
          products: await db.select(db.products).get(),
          handled: const ['a1'],
        );

        expect(state.total, 32.5);
        expect(state.toChannel(), {
          'day': 20261001,
          'dayStartHour': 3,
          'total': 32.5,
          'goal': 140.0,
          'entries': [
            {
              'id': entries.last.id,
              'name': null,
              'protein': 12.5,
              'time': DateTime(2026, 10, 1, 12).millisecondsSinceEpoch,
              'fromWatch': false,
              'creatineDoses': 0,
              'creatineGrams': 0.0,
            },
            {
              'id': entries.first.id,
              'name': 'Oeufs',
              'protein': 20.0,
              'time': DateTime(2026, 10, 1, 8).millisecondsSinceEpoch,
              'fromWatch': false,
              'creatineDoses': 0,
              'creatineGrams': 0.0,
            },
          ],
          'products': [
            {
              'id': products.single.id,
              'name': 'Skyr',
              'protein': 15.0,
              'favorite': true,
              'creatineDoses': 0,
            },
          ],
          'handled': ['a1'],
          'creatineEnabled': false,
          'hevyWorkouts': 0,
        });
      },
    );

    test('sends the creatine of the entries and the products', () async {
      await db.settingsDao.setCreatineEnabled(true);
      await db.productsDao.insertProduct(
        name: 'Whey',
        amount: const DirectAmount(24),
        createdAt: DateTime(2026, 9),
        creatineDoses: 2,
      );
      await db.entriesDao.addCreatineDose(createdAt: DateTime(2026, 10, 1, 8));

      final state = WatchState.of(
        dayKey: 20261001,
        dayStartHour: 3,
        entries: await db.entriesDao.watchDayEntries(20261001).first,
        goal: 140,
        products: await db.select(db.products).get(),
        handled: const [],
      );

      final channel = state.toChannel();
      final entry = (channel['entries']! as List).single as Map;
      expect(entry['protein'], 0.0);
      expect(entry['creatineDoses'], 1);
      expect(entry['creatineGrams'], 5.0);
      final product = (channel['products']! as List).single as Map;
      expect(product['creatineDoses'], 2);
    });

    test('equals another state of the same values only', () {
      WatchState state({
        double total = 20,
        List<String> handled = const [],
        int hevyWorkouts = 0,
      }) => WatchState(
        dayKey: 20261001,
        dayStartHour: 3,
        total: total,
        goal: 140,
        entries: [
          WatchEntry(
            id: 1,
            name: 'Skyr',
            protein: 20,
            time: DateTime(2026, 10, 1, 8),
            fromWatch: true,
          ),
        ],
        products: const [
          WatchProduct(id: 1, name: 'Skyr', protein: 20, isFavorite: false),
        ],
        handled: handled,
        hevyWorkouts: hevyWorkouts,
      );

      expect(state(), state());
      expect(state().hashCode, state().hashCode);
      expect(state(total: 21), isNot(state()));
      expect(state(handled: ['a1']), isNot(state()));
      expect(state(hevyWorkouts: 1), isNot(state()));
    });
  });

  group('readWatchState', () {
    final now = DateTime(2026, 10, 1, 9);

    test('counts the Hevy workouts of the day only', () async {
      await db.hevyDao.replaceSessions([
        for (final (day, hour) in [(1, 7), (1, 18), (2, 7)])
          HevySessionsCompanion.insert(
            title: 'Push',
            startedAt: DateTime(2026, 10, day, hour),
            dayKey: dayKeyOf(DateTime(2026, 10, day, hour)),
          ),
      ], importedAt: now);

      final state = await readWatchState(db, now);

      expect(state.hevyWorkouts, 2);
      expect(state.toChannel()['hevyWorkouts'], 2);
    });

    test(
      'reads the current app day, its goal and the sorted products',
      () async {
        await db.settingsDao.setDailyGoal(120, now: DateTime(2026, 9, 1));
        await db.settingsDao.setDailyGoal(140, now: DateTime(2026, 10, 1, 8));
        await db.settingsDao.setProductSort(ProductSort.mostUsed);
        for (final name in ['Amandes', 'Whey']) {
          await db.productsDao.insertProduct(
            name: name,
            amount: const DirectAmount(10),
            createdAt: DateTime(2026, 9),
          );
        }
        // The day before, and after midnight in that same day.
        await addEntry(30, DateTime(2026, 9, 30, 20), name: 'Whey');
        await addEntry(10, DateTime(2026, 10, 1, 2), name: 'Whey');
        await addEntry(25, DateTime(2026, 10, 1, 8), name: 'Whey');

        final state = await readWatchState(db, now);

        expect(state.dayKey, 20261001);
        expect(state.dayStartHour, 3);
        expect(state.total, 25);
        expect(state.goal, 140);
        expect([for (final p in state.products) p.name], ['Whey', 'Amandes']);
        expect(state.entries.single.protein, 25);
      },
    );

    test('starts the day at the hour chosen in the menu', () async {
      await db.settingsDao.setDayStartHour(5);
      await addEntry(10, DateTime(2026, 10, 1, 4));

      final state = await readWatchState(db, DateTime(2026, 10, 1, 4, 30));

      expect(state.dayKey, 20260930);
      expect(state.dayStartHour, 5);
      expect(state.total, 10);
    });

    test('has no goal before the first launch', () async {
      expect((await readWatchState(db, now)).goal, isNull);
    });

    test('lists the additions of the watch since the day before', () async {
      WatchAddition addition(String id) => WatchAddition(
        id: id,
        productId: 1,
        name: 'Skyr',
        protein: 20,
        addedAt: DateTime(2026, 9, 28),
      );
      await db.watchDao.add(addition('older'), DateTime(2026, 9, 30, 2));
      await db.watchDao.add(addition('yesterday'), DateTime(2026, 9, 30, 4));
      await db.watchDao.add(addition('today'), DateTime(2026, 10, 1, 8));

      expect((await readWatchState(db, now)).handled, ['yesterday', 'today']);
    });
  });

  test('handledSince is the start of the app day before', () {
    expect(handledSince(20261001), DateTime(2026, 9, 30, 3));
    expect(handledSince(20260101), DateTime(2025, 12, 31, 3));
  });
}
