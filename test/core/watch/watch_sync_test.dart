import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/watch/watch_state.dart';
import 'package:protein_calculator/core/watch/watch_sync.dart';

import '../database/test_database.dart';

/// Keeps the states sent to the watch.
class _RecordingLink implements WatchLink {
  final sent = <WatchState>[];
  final _sends = StreamController<WatchState>.broadcast();

  /// The next state sent matching [test], to ask for before what sends it.
  Future<WatchState> next([bool Function(WatchState state)? test]) => _sends
      .stream
      .firstWhere(test ?? (_) => true)
      .timeout(const Duration(seconds: 5));

  @override
  Future<void> send(WatchState state) async {
    sent.add(state);
    _sends.add(state);
  }
}

void main() {
  late AppDatabase db;
  late _RecordingLink link;
  late ProviderContainer container;
  late Future<WatchState> first;

  setUp(() async {
    db = openTestDatabase();
    link = _RecordingLink();
    await db.settingsDao.setDailyGoal(140, now: DateTime(2026, 9, 1));
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentDayKeyProvider.overrideWith((ref) => Stream.value(20261001)),
        watchLinkProvider.overrideWithValue(link),
      ],
    );
    addTearDown(container.dispose);
    first = link.next();
    container.listen(watchSyncProvider, (_, _) {});
  });

  Future<void> addEntry(double grams, DateTime at) => db.entriesDao.insertEntry(
    name: 'Skyr',
    amount: DirectAmount(grams),
    createdAt: at,
  );

  test('sends the day once its data is read', () async {
    final state = await first;

    expect(link.sent, [state]);
    expect(state.dayKey, 20261001);
    expect(state.goal, 140);
    expect(state.total, 0);
  });

  test('sends the day again each time it changes, and only then', () async {
    await first;
    final added = link.next();
    await addEntry(20, DateTime(2026, 10, 1, 8));

    expect((await added).total, 20);
    expect((await added).entries.single.name, 'Skyr');

    // Reading the data again without change sends nothing: the next state
    // sent is the one of the next change.
    final next = link.next();
    db.markTablesUpdated([db.entries, db.products]);
    await addEntry(12, DateTime(2026, 10, 1, 9));

    expect((await next).total, 32);
    expect(link.sent, hasLength(3));
  });

  test('sends the products, the favorite first', () async {
    await first;
    final sorted = link.next(
      (state) => state.products.length == 2 && state.products.first.isFavorite,
    );
    for (final name in ['Amandes', 'Whey']) {
      await db.productsDao.insertProduct(
        name: name,
        amount: const DirectAmount(10),
        createdAt: DateTime(2026, 9),
      );
    }
    final whey = (await db.select(db.products).get()).last;
    await db.productsDao.setFavorite(whey.id, favorite: true);

    expect(
      [for (final product in (await sorted).products) product.name],
      ['Whey', 'Amandes'],
    );
  });
}
