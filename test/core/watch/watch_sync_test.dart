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

  @override
  Future<void> send(WatchState state) async => sent.add(state);
}

void main() {
  late AppDatabase db;
  late _RecordingLink link;
  late ProviderContainer container;

  /// Lets the streams of the data and the providers run.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

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
    container.listen(watchSyncProvider, (_, _) {});
  });

  test('sends the day once its data is read', () async {
    await settle();

    expect(link.sent, hasLength(1));
    expect(link.sent.single.dayKey, 20261001);
    expect(link.sent.single.goal, 140);
    expect(link.sent.single.total, 0);
  });

  test('sends the day again each time it changes, and only then', () async {
    await settle();
    await db.entriesDao.insertEntry(
      name: 'Skyr',
      amount: const DirectAmount(20),
      createdAt: DateTime(2026, 10, 1, 8),
    );
    await settle();

    expect(link.sent, hasLength(2));
    expect(link.sent.last.total, 20);
    expect(link.sent.last.entries.single.name, 'Skyr');

    // Reading the data again without change sends nothing.
    db.markTablesUpdated([db.entries, db.products]);
    await settle();
    expect(link.sent, hasLength(2));
  });

  test('sends the products, the favorite first', () async {
    await settle();
    for (final name in ['Amandes', 'Whey']) {
      await db.productsDao.insertProduct(
        name: name,
        amount: const DirectAmount(10),
        createdAt: DateTime(2026, 9),
      );
    }
    final whey = (await db.select(db.products).get()).last;
    await db.productsDao.setFavorite(whey.id, favorite: true);
    await settle();

    expect(
      [for (final product in link.sent.last.products) product.name],
      ['Whey', 'Amandes'],
    );
    expect(link.sent.last.products.first.isFavorite, isTrue);
  });
}
