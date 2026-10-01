import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/features/entry_form/entry_form_notifier.dart';
import 'package:protein_calculator/features/entry_form/entry_form_state.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 10, 1, 9);

  setUp(() {
    db = openTestDatabase();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<EntryFormNotifier> open(EntryFormArgs args) async {
    final subscription = container.listen(entryFormProvider(args), (_, _) {});
    addTearDown(subscription.close);
    await container.read(entryFormProvider(args).future);
    return container.read(entryFormProvider(args).notifier);
  }

  EntryFormState stateOf(EntryFormArgs args) =>
      container.read(entryFormProvider(args)).value!;

  Future<List<Entry>> todayEntries() =>
      db.entriesDao.watchDayEntries(20261001).first;

  Future<List<Product>> products() =>
      db.productsDao.watchAll(ProductSort.alphabetical).first;

  Future<int> addProduct(String name) => db.productsDao.insertProduct(
    name: name,
    mode: EntryMode.perQuantity,
    consumedGrams: 150,
    proteinPerReference: 10,
    referenceGrams: 100,
    createdAt: DateTime(2026, 9, 1),
  );

  group('new entry', () {
    const args = EntryFormArgs.newEntry();

    test('saves a direct protein amount at the current time', () async {
      final form = await open(args);
      form
        ..setName('Shaker')
        ..setProtein('25');

      expect(await form.submit(), isTrue);

      final entry = (await todayEntries()).single;
      expect(entry.name, 'Shaker');
      expect(entry.mode, EntryMode.direct);
      expect(entry.proteinGrams, 25);
      expect(entry.consumedGrams, isNull);
      expect(entry.createdAt, now);
    });

    test('computes the protein of a quantity eaten', () async {
      final form = await open(args);
      form
        ..setMode(EntryMode.perQuantity)
        ..setConsumed('150')
        ..setProteinPerReference('10');

      expect(stateOf(args).proteinGrams, 15);
      expect(await form.submit(), isTrue);

      final entry = (await todayEntries()).single;
      expect(entry.name, isNull);
      expect(entry.proteinGrams, 15);
      expect(entry.consumedGrams, 150);
      expect(entry.proteinPerReference, 10);
      expect(entry.referenceGrams, 100);
    });

    test('reports missing, zero and inconsistent values', () async {
      final form = await open(args);
      expect(await form.submit(), isFalse);
      expect(stateOf(args).errors, {
        EntryFormField.protein: EntryFormError.required,
      });

      form
        ..setMode(EntryMode.perQuantity)
        ..setConsumed('0')
        ..setProteinPerReference('120');
      expect(await form.submit(), isFalse);
      expect(stateOf(args).errors, {
        EntryFormField.consumed: EntryFormError.notPositive,
        EntryFormField.proteinPerReference: EntryFormError.aboveReference,
      });
      expect(await todayEntries(), isEmpty);
    });

    test('clears the error of a field once it is edited', () async {
      final form = await open(args);
      await form.submit();

      form.setProtein('3');

      expect(stateOf(args).errors, isEmpty);
    });

    test('saves the entry as a product, counted as one use', () async {
      final form = await open(args);
      form
        ..setName('Shaker whey')
        ..setProtein('25')
        ..setSaveAsProduct(true);

      expect(await form.submit(), isTrue);

      final product = (await products()).single;
      expect(product.name, 'Shaker whey');
      expect(product.proteinGrams, 25);
      expect(product.useCount, 1);
      expect((await todayEntries()).single.name, 'Shaker whey');
    });

    test('needs a free name to save as a product', () async {
      await addProduct('Skyr');
      final form = await open(args);
      form
        ..setProtein('25')
        ..setSaveAsProduct(true);

      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.name],
        EntryFormError.nameRequired,
      );

      form.setName('skyr');
      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.name],
        EntryFormError.nameTaken,
      );
      expect(await todayEntries(), isEmpty);
    });

    test('starts from a product', () async {
      final productId = await addProduct('Skyr');
      final productArgs = EntryFormArgs.newEntry(productId: productId);
      await open(productArgs);

      final state = stateOf(productArgs);
      expect(state.name, 'Skyr');
      expect(state.mode, EntryMode.perQuantity);
      expect(state.consumed, '150');
      expect(state.proteinGrams, 15);
    });

    test('fills the form with a picked product', () async {
      final productId = await addProduct('Skyr');
      final form = await open(args);

      form.applyProduct((await db.productsDao.getProduct(productId))!);

      expect(stateOf(args).name, 'Skyr');
      expect(stateOf(args).revision, 1);
    });
  });

  test('editing an entry updates it instead of adding one', () async {
    final id = await db.entriesDao.insertEntry(
      name: 'Skyr',
      mode: EntryMode.direct,
      proteinGrams: 15,
      createdAt: DateTime(2026, 10, 1, 8),
    );
    final args = EntryFormArgs.editEntry(id);
    final form = await open(args);
    expect(stateOf(args).protein, '15');

    form.setProtein('20');
    expect(await form.submit(), isTrue);

    final entries = await todayEntries();
    expect(entries.map((e) => (e.id, e.proteinGrams, e.createdAt)), [
      (id, 20.0, DateTime(2026, 10, 1, 8)),
    ]);
  });

  group('product', () {
    test('creates a product only', () async {
      const args = EntryFormArgs.newProduct();
      final form = await open(args);
      form
        ..setName('Poulet')
        ..setMode(EntryMode.perQuantity)
        ..setConsumed('150')
        ..setProteinPerReference('23');

      expect(await form.submit(), isTrue);

      final product = (await products()).single;
      expect(product.name, 'Poulet');
      expect(product.consumedGrams, 150);
      expect(product.proteinPerReference, 23);
      expect(await todayEntries(), isEmpty);
    });

    test('edits a product without touching past entries', () async {
      final id = await addProduct('Skyr');
      await db.entriesDao.insertEntry(
        name: 'Skyr',
        mode: EntryMode.perQuantity,
        proteinGrams: 15,
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
        createdAt: DateTime(2026, 10, 1, 8),
      );
      final args = EntryFormArgs.editProduct(id);
      final form = await open(args);

      form.setProteinPerReference('9');
      expect(await form.submit(), isTrue);

      expect((await db.productsDao.getProduct(id))!.proteinPerReference, 9);
      expect((await todayEntries()).single.proteinPerReference, 10);
    });

    test('needs a name', () async {
      const args = EntryFormArgs.newProduct();
      final form = await open(args);
      form.setProtein('25');

      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.name],
        EntryFormError.nameRequired,
      );
    });
  });
}
