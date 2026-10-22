import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_sort.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/features/entry_form/entry_form_notifier.dart';
import 'package:protein_calculator/features/entry_form/entry_form_state.dart';

import '../../helpers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final now = DateTime(2026, 10, 1, 9);

  /// What Open Food Facts answers about any barcode.
  late http.Response Function() foodFacts;

  setUp(() {
    db = openTestDatabase();
    foodFacts = () => http.Response('', 404);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        openFoodFactsProvider.overrideWithValue(
          OpenFoodFacts(
            MockClient((_) async => foodFacts()),
            appVersion: Future.value('1.3.0'),
          ),
        ),
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
    amount: const PerQuantityAmount(
      consumedGrams: 150,
      proteinPerReference: 10,
      referenceGrams: 100,
    ),
    createdAt: DateTime(2026, 9, 1),
  );

  group('new entry', () {
    const args = NewEntryArgs();

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

    test('saves a protein amount typed with a decimal', () async {
      final form = await open(args);
      form.setProtein('12,5');

      expect(await form.submit(), isTrue);

      expect((await todayEntries()).single.proteinGrams, 12.5);
    });

    test('rounds the computed protein to one decimal', () async {
      final form = await open(args);
      form
        ..setMode(EntryMode.perQuantity)
        ..setConsumed('150')
        ..setProteinPerReference('10,5');

      expect(stateOf(args).amount?.proteinGrams, 15.8);
      expect(await form.submit(), isTrue);

      expect((await todayEntries()).single.proteinGrams, 15.8);
    });

    test('computes the protein of a quantity eaten', () async {
      final form = await open(args);
      form
        ..setMode(EntryMode.perQuantity)
        ..setConsumed('150')
        ..setProteinPerReference('10');

      expect(stateOf(args).amount?.proteinGrams, 15);
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

    test('needs a name to save as a product', () async {
      final form = await open(args);
      form
        ..setProtein('25')
        ..setSaveAsProduct(true);

      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.name],
        EntryFormError.nameRequired,
      );
      expect(await todayEntries(), isEmpty);
    });

    test('is not saved as a product under a taken name', () async {
      await addProduct('Skyr');
      final form = await open(args);
      form
        ..setProtein('25')
        ..setSaveAsProduct(true)
        ..setName('skyr');

      // Another product has the name: the option goes off, and stays off.
      expect(stateOf(args).nameTaken, isTrue);
      expect(stateOf(args).saveAsProduct, isFalse);
      form.setSaveAsProduct(true);
      expect(stateOf(args).saveAsProduct, isFalse);

      // The entry is added alone.
      expect(await form.submit(), isTrue);
      expect(await products(), hasLength(1));
      expect((await todayEntries()).single.name, 'skyr');

      form.setName('Skyr vanille');
      expect(stateOf(args).nameTaken, isFalse);
    });

    test('starts from a product', () async {
      final productId = await addProduct('Skyr');
      final productArgs = NewEntryArgs(productId: productId);
      await open(productArgs);

      final state = stateOf(productArgs);
      expect(state.name, 'Skyr');
      expect(state.mode, EntryMode.perQuantity);
      expect(state.consumed, '150');
      expect(state.amount?.proteinGrams, 15);
      expect(state.nameTaken, isTrue);
      expect(state.saveAsProduct, isFalse);
    });

    test('adds an entry from a product, which stays as it was', () async {
      final productId = await addProduct('Skyr');
      await db.productsDao.setRoutine(
        productId,
        DailyRoutine.reminder,
        minutes: 480,
        now: DateTime(2026, 9, 20),
      );
      final productArgs = NewEntryArgs(productId: productId);
      final form = await open(productArgs);
      // The routine stays the one of the product.
      expect(stateOf(productArgs).routine, DailyRoutine.none);

      form.setConsumed('200');
      expect(await form.submit(), isTrue);

      expect((await todayEntries()).single.proteinGrams, 20);
      final product = (await db.productsDao.getProduct(productId))!;
      expect(product.consumedGrams, 150);
      expect(product.routine, DailyRoutine.reminder);
      expect(product.routineMinutes, 480);
      expect(product.useCount, 1);
    });

    test('saves an entry from a product under a new name', () async {
      final productId = await addProduct('Skyr');
      final productArgs = NewEntryArgs(productId: productId);
      final form = await open(productArgs);
      form
        ..setName('Skyr vanille')
        ..setSaveAsProduct(true);

      expect(await form.submit(), isTrue);

      expect((await products()).map((p) => p.name), ['Skyr', 'Skyr vanille']);
    });

    test('fills the form with a picked product', () async {
      final productId = await addProduct('Skyr');
      final form = await open(args);

      form.applyProduct((await db.productsDao.getProduct(productId))!);

      expect(stateOf(args).name, 'Skyr');
      expect(stateOf(args).revision, 1);
      expect(stateOf(args).nameTaken, isTrue);
    });
  });

  group('creatine', () {
    const args = NewEntryArgs();

    test('0 g is accepted with a dose', () async {
      final form = await open(args);
      form
        ..setProtein('0')
        ..setCreatineDoses(1);

      expect(stateOf(args).amount, const DirectAmount(0));
      expect(stateOf(args).validate(nameRequired: false, now: now), isEmpty);
    });

    test('0 g without doses is not positive', () async {
      final form = await open(args);
      form
        ..setProtein('0')
        ..setCreatineDoses(1)
        ..setCreatineDoses(0);

      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.protein],
        EntryFormError.notPositive,
      );
      expect(await todayEntries(), isEmpty);
    });

    test('a product prefills its doses', () async {
      final id = await db.productsDao.insertProduct(
        name: 'Whey',
        amount: const DirectAmount(24),
        createdAt: DateTime(2026, 9, 1),
        creatineDoses: 2,
      );
      await open(NewEntryArgs(productId: id));

      expect(stateOf(NewEntryArgs(productId: id)).creatineDoses, 2);
    });

    test('saving a new entry stores its doses', () async {
      await db.settingsDao.setCreatineEnabled(true);
      final form = await open(args);
      form
        ..setName('Pre-workout')
        ..setProtein('0')
        ..setCreatineDoses(1)
        ..setSaveAsProduct(true);

      expect(await form.submit(), isTrue);

      final entry = (await todayEntries()).single;
      expect(entry.proteinGrams, 0);
      expect(entry.creatineDoses, 1);
      expect(entry.creatineDoseGrams, 5);
      expect((await products()).single.creatineDoses, 1);
    });

    test('the doses stop at 0 and 9', () async {
      final form = await open(args);
      form.setCreatineDoses(-1);
      expect(stateOf(args).creatineDoses, 0);
      form.setCreatineDoses(12);
      expect(stateOf(args).creatineDoses, 9);
    });
  });

  group('daily routine', () {
    const args = NewEntryArgs();

    test('is offered at the current time, by steps of 5 minutes', () async {
      await open(args);

      expect(stateOf(args).routine, DailyRoutine.none);
      expect(stateOf(args).routineMinutes, 9 * 60);
    });

    test('goes nowhere without a new product', () async {
      final form = await open(args);
      form
        ..setName('Skyr')
        ..setProtein('20')
        ..setRoutine(DailyRoutine.reminder);

      expect(stateOf(args).saveAsProduct, isFalse);
      expect(await form.submit(), isTrue);

      expect(await products(), isEmpty);
      expect(await todayEntries(), hasLength(1));
    });

    test('is saved on the new product, from now', () async {
      final form = await open(args);
      form
        ..setName('Skyr')
        ..setProtein('20')
        ..setSaveAsProduct(true)
        ..setRoutine(DailyRoutine.autoAdd)
        ..setRoutineMinutes(7 * 60 + 30);

      expect(await form.submit(), isTrue);

      final product = (await products()).single;
      expect(product.routine, DailyRoutine.autoAdd);
      expect(product.routineMinutes, 7 * 60 + 30);
      expect(product.routineCheckedAt, now);
      expect(await todayEntries(), hasLength(1));
    });

    test('is kept as it was when an edited product keeps it', () async {
      final productId = await addProduct('Skyr');
      final since = DateTime(2026, 9, 20);
      await db.productsDao.setRoutine(
        productId,
        DailyRoutine.autoAdd,
        minutes: 480,
        now: since,
      );
      final productArgs = EditProductArgs(productId);
      final form = await open(productArgs);

      expect(stateOf(productArgs).routine, DailyRoutine.autoAdd);
      expect(stateOf(productArgs).routineMinutes, 480);
      form.setConsumed('200');
      expect(await form.submit(), isTrue);

      // Choosing it again would skip the additions due since.
      final product = (await db.productsDao.getProduct(productId))!;
      expect(product.consumedGrams, 200);
      expect(product.routineCheckedAt, since);
    });
  });

  test('editing an entry updates it instead of adding one', () async {
    final id = await db.entriesDao.insertEntry(
      name: 'Skyr',
      amount: const DirectAmount(15),
      createdAt: DateTime(2026, 10, 1, 8),
    );
    final args = EditEntryArgs(id);
    final form = await open(args);
    expect(stateOf(args).protein, '15');

    form.setProtein('20');
    expect(await form.submit(), isTrue);

    final entries = await todayEntries();
    expect(entries.map((e) => (e.id, e.proteinGrams, e.createdAt)), [
      (id, 20.0, DateTime(2026, 10, 1, 8)),
    ]);
  });

  test('saves an edited entry as a product, counted as one use', () async {
    final id = await db.entriesDao.insertEntry(
      name: 'Shaker',
      amount: const DirectAmount(25),
      createdAt: DateTime(2026, 10, 1, 8),
    );
    final args = EditEntryArgs(id);
    final form = await open(args);
    expect(stateOf(args).nameTaken, isFalse);

    form
      ..setName('Shaker whey')
      ..setSaveAsProduct(true);
    expect(await form.submit(), isTrue);

    final product = (await products()).single;
    expect(product.name, 'Shaker whey');
    expect(product.proteinGrams, 25);
    expect(product.useCount, 1);
    final entry = (await todayEntries()).single;
    expect((entry.id, entry.name), (id, 'Shaker whey'));
  });

  test(
    'an edited entry is not saved as a product under a taken name',
    () async {
      await addProduct('Skyr');
      final id = await db.entriesDao.insertEntry(
        name: 'Skyr',
        amount: const DirectAmount(15),
        createdAt: DateTime(2026, 10, 1, 8),
      );
      final args = EditEntryArgs(id);
      final form = await open(args);

      expect(stateOf(args).nameTaken, isTrue);
      form.setSaveAsProduct(true);
      expect(stateOf(args).saveAsProduct, isFalse);
      expect(await form.submit(), isTrue);
      expect(await products(), hasLength(1));
    },
  );

  group('time of the entry', () {
    test('is now for a new entry, the time added for one edited', () async {
      await open(const NewEntryArgs());
      expect(stateOf(const NewEntryArgs()).time, isNull);

      final id = await db.entriesDao.insertEntry(
        amount: const DirectAmount(15),
        createdAt: DateTime(2026, 10, 1, 8),
      );
      await open(EditEntryArgs(id));
      expect(stateOf(EditEntryArgs(id)).time, DateTime(2026, 10, 1, 8));
    });

    test('adds a new entry afterwards, on its own day', () async {
      const args = NewEntryArgs();
      final form = await open(args);
      form
        ..setProtein('25')
        ..setTime(DateTime(2026, 9, 30, 20));

      expect(await form.submit(), isTrue);

      expect(await todayEntries(), isEmpty);
      final entry =
          (await db.entriesDao.watchDayEntries(20260930).first).single;
      expect(entry.createdAt, DateTime(2026, 9, 30, 20));
    });

    test('refuses a time yet to come, until it is changed', () async {
      const args = NewEntryArgs();
      final form = await open(args);
      form
        ..setProtein('25')
        ..setTime(DateTime(2026, 10, 1, 10));
      expect(stateOf(args).errors[EntryFormField.time], EntryFormError.future);

      expect(await form.submit(), isFalse);
      expect(await todayEntries(), isEmpty);

      form.setTime(null);
      expect(stateOf(args).errors, isEmpty);
      expect(await form.submit(), isTrue);
      expect((await todayEntries()).single.createdAt, now);
    });

    test('moves an edited entry to the time chosen', () async {
      final id = await db.entriesDao.insertEntry(
        amount: const DirectAmount(15),
        createdAt: DateTime(2026, 10, 1, 8),
      );
      final args = EditEntryArgs(id);
      final form = await open(args);

      form.setTime(DateTime(2026, 9, 30, 19, 45));
      expect(await form.submit(), isTrue);

      expect(await todayEntries(), isEmpty);
      final entry = (await db.entriesDao.getEntry(id))!;
      expect(entry.createdAt, DateTime(2026, 9, 30, 19, 45));
      expect(entry.dayKey, 20260930);
    });
  });

  group('product', () {
    test('creates a product only', () async {
      const args = NewProductArgs();
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
        amount: const PerQuantityAmount(
          consumedGrams: 150,
          proteinPerReference: 10,
          referenceGrams: 100,
        ),
        createdAt: DateTime(2026, 10, 1, 8),
      );
      final args = EditProductArgs(id);
      final form = await open(args);

      form.setProteinPerReference('9');
      expect(await form.submit(), isTrue);

      expect((await db.productsDao.getProduct(id))!.proteinPerReference, 9);
      expect((await todayEntries()).single.proteinPerReference, 10);
    });

    test(
      'copies another product, but not its barcode nor its routine',
      () async {
        final id = await addProduct('Skyr');
        await db.productsDao.setBarcode(id, '3017620422003');
        await db.productsDao.setRoutine(
          id,
          DailyRoutine.autoAdd,
          minutes: 480,
          now: DateTime(2026, 9, 20),
        );
        final args = NewProductArgs(copyOf: id);
        final form = await open(args);

        final state = stateOf(args);
        expect(state.name, 'Skyr');
        expect(state.consumed, '150');
        expect(state.proteinPerReference, '10');
        expect(state.barcode, isNull);
        expect(state.routine, DailyRoutine.none);
        expect(state.nameTaken, isTrue);
        // The name field tells at once that it must change.
        expect(state.errors[EntryFormField.name], EntryFormError.nameTaken);

        expect(await form.submit(), isFalse);
        expect(
          stateOf(args).errors[EntryFormField.name],
          EntryFormError.nameTaken,
        );
        form.setName('Skyr vanille');
        expect(await form.submit(), isTrue);

        final copy = (await products()).firstWhere((p) => p.id != id);
        expect(copy.name, 'Skyr vanille');
        expect(copy.consumedGrams, 150);
        expect(copy.barcode, isNull);
        expect(copy.routine, DailyRoutine.none);
      },
    );

    test('needs a name', () async {
      const args = NewProductArgs();
      final form = await open(args);
      form.setProtein('25');

      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.name],
        EntryFormError.nameRequired,
      );
    });
  });
  test('saves quantities in milliliters', () async {
    const args = NewEntryArgs();
    final form = await open(args);
    form
      ..setName('Milk')
      ..setMode(EntryMode.perQuantity)
      ..setUnit(QuantityUnit.milliliters)
      ..setConsumed('250')
      ..setProteinPerReference('3.4')
      ..setSaveAsProduct(true);

    expect(await form.submit(), isTrue);

    final entry = (await todayEntries()).single;
    expect(entry.unit, QuantityUnit.milliliters);
    expect(entry.proteinGrams, 8.5);
    expect((await products()).single.unit, QuantityUnit.milliliters);
  });

  group('scanned barcode', () {
    const nutella = '3017620422003';

    /// Open Food Facts knowing [name], with [protein] per 100 g if given.
    void answer({String name = 'Nutella', double? protein, int? serving}) =>
        foodFacts = () => http.Response(
          jsonEncode({
            'product': {
              'product_name': name,
              'brands': 'Nutella',
              'nutriments': {'proteins_100g': ?protein},
              'serving_quantity': ?serving,
            },
            'result': {'id': 'product_found'},
          }),
          200,
        );

    test('a scan leaves no creatine doses', () async {
      answer(protein: 6.3, serving: 15);
      const args = NewEntryArgs();
      final form = await open(args);
      // The doses of a product picked before.
      form.setCreatineDoses(1);

      final outcome = await form.scanned(nutella, language: 'fr');

      expect(outcome, isA<ScanFilled>());
      expect(stateOf(args).creatineDoses, 0);
    });

    test(
      'fills a new entry with what Open Food Facts says, in green',
      () async {
        answer(protein: 6.3, serving: 15);
        const args = NewEntryArgs();
        final form = await open(args);

        final outcome = await form.scanned(nutella, language: 'fr');

        expect(outcome, isA<ScanFilled>());
        final state = stateOf(args);
        expect(state.name, 'Nutella');
        expect(state.mode, EntryMode.perQuantity);
        expect(state.proteinPerReference, '6.3');
        expect(state.reference, '100');
        expect(state.consumed, '15');
        expect(state.barcode, nutella);
        expect(state.fromFoodFacts, {
          EntryFormField.name,
          EntryFormField.proteinPerReference,
          EntryFormField.reference,
          EntryFormField.consumed,
        });
        expect(state.amount!.proteinGrams, 0.9);
      },
    );

    test('shows a field edited no longer in green', () async {
      answer(protein: 6.3);
      const args = NewEntryArgs();
      final form = await open(args);
      await form.scanned(nutella, language: 'fr');

      form.setProteinPerReference('7');

      expect(
        stateOf(args).fromFoodFacts,
        isNot(contains(EntryFormField.proteinPerReference)),
      );
      expect(stateOf(args).fromFoodFacts, contains(EntryFormField.name));
    });

    test('leaves for the user a protein content unknown or zero', () async {
      for (final (barcode, protein) in [('96385074', null), (nutella, 0.0)]) {
        answer(name: 'Water', protein: protein);
        const args = NewProductArgs();
        final form = await open(args);

        await form.scanned(barcode, language: 'fr');

        expect(stateOf(args).name, 'Water (Nutella)');
        expect(stateOf(args).proteinPerReference, '');
        expect(
          stateOf(args).fromFoodFacts,
          isNot(contains(EntryFormField.proteinPerReference)),
        );
      }
    });

    test('gives its barcode to the product saved from the entry', () async {
      answer(protein: 6.3);
      const args = NewEntryArgs();
      final form = await open(args);
      await form.scanned(nutella, language: 'fr');
      form
        ..setConsumed('15')
        ..setSaveAsProduct(true);

      expect(await form.submit(), isTrue);

      final product = (await db.productsDao.findByBarcode(nutella))!;
      expect(product.name, 'Nutella');
      expect(await db.scansDao.watchRecent().first, isEmpty);
    });

    test('starts a new entry from a recent scan', () async {
      await db.scansDao.saveScan(
        const FoodFacts(
          name: 'Nutella',
          proteinPer100: 6.3,
        ).toScan(nutella, fetchedAt: now, scannedAt: now).toCompanion(false),
      );
      const args = NewEntryArgs(barcode: nutella);
      await open(args);

      expect(stateOf(args).name, 'Nutella');
      expect(stateOf(args).proteinPerReference, '6.3');
      expect(stateOf(args).barcode, nutella);
    });

    test('takes the product of the user with that barcode, not in '
        'green', () async {
      final id = await addProduct('My Nutella');
      await db.productsDao.setBarcode(id, nutella);
      const args = NewEntryArgs();
      final form = await open(args);

      final outcome = await form.scanned(nutella, language: 'fr');

      expect((outcome as ScanFoundProduct).product.id, id);
      expect(stateOf(args).name, 'My Nutella');
      expect(stateOf(args).fromFoodFacts, isEmpty);
    });

    test('offers the barcode to the product of the same name', () async {
      answer(protein: 6.3);
      final id = await addProduct('Nutella');
      const args = NewEntryArgs();
      final form = await open(args);

      final outcome = await form.scanned(nutella, language: 'fr') as ScanFilled;
      expect(outcome.sameName!.id, id);

      await form.giveBarcode(outcome.sameName!, nutella);

      expect((await db.productsDao.getProduct(id))!.barcode, nutella);
      // The values of the user come instead of those of Open Food Facts.
      expect(stateOf(args).proteinPerReference, '10');
      expect(stateOf(args).fromFoodFacts, isEmpty);
    });

    test('takes a newer protein content into a saved product', () async {
      final id = await addProduct('Nutella');
      const args = NewEntryArgs();
      final form = await open(args);
      final product = (await db.productsDao.getProduct(id))!;

      await form.takeFoodFacts(
        product,
        const FoodFacts(name: 'Nutella', proteinPer100: 7),
      );

      final updated = (await db.productsDao.getProduct(id))!;
      expect(updated.proteinPerReference, 7);
      expect(updated.consumedGrams, 150);
    });

    test('keeps the barcode of an unknown product', () async {
      const args = NewProductArgs();
      final form = await open(args);

      final outcome = await form.scanned(nutella, language: 'fr');

      expect((outcome as ScanNotFound).problem, isNull);
      expect(stateOf(args).barcode, nutella);
    });

    test('tells why Open Food Facts could not be asked', () async {
      foodFacts = () => throw http.ClientException('offline');
      const args = NewProductArgs();
      final form = await open(args);

      final outcome = await form.scanned(nutella, language: 'fr');

      expect((outcome as ScanNotFound).problem, FoodFactsProblem.offline);
      expect(stateOf(args).barcode, nutella);
    });

    test('does not give a new product the barcode of another', () async {
      final id = await addProduct('Nutella');
      await db.productsDao.setBarcode(id, nutella);
      const args = NewProductArgs();
      final form = await open(args);

      final outcome = await form.scanned(nutella, language: 'fr');

      expect((outcome as ScanBarcodeTaken).product.id, id);
      expect(stateOf(args).barcode, isNull);
    });

    test('only gives its barcode to a product edited', () async {
      answer(protein: 6.3);
      final id = await addProduct('Spread');
      final args = EditProductArgs(id);
      final form = await open(args);

      expect(await form.scanned(nutella, language: 'fr'), isA<ScanKept>());
      expect(stateOf(args).name, 'Spread');
      expect(stateOf(args).proteinPerReference, '10');
      expect(await form.submit(), isTrue);

      expect((await db.productsDao.getProduct(id))!.barcode, nutella);
    });

    test('takes away the barcode of a product edited', () async {
      final id = await addProduct('Spread');
      await db.productsDao.setBarcode(id, nutella);
      final args = EditProductArgs(id);
      final form = await open(args);
      expect(stateOf(args).barcode, nutella);

      form.setBarcode(null);
      expect(await form.submit(), isTrue);

      expect((await db.productsDao.getProduct(id))!.barcode, isNull);
    });

    test('refuses to save a barcode another product took', () async {
      const args = NewProductArgs();
      final form = await open(args);
      await form.scanned(nutella, language: 'fr');
      form
        ..setName('Spread')
        ..setProtein('5');
      final id = await addProduct('Nutella');
      await db.productsDao.setBarcode(id, nutella);

      expect(await form.submit(), isFalse);
      expect(
        stateOf(args).errors[EntryFormField.barcode],
        EntryFormError.barcodeTaken,
      );
    });

    test('keeps the unit chosen by the user when newer values come', () async {
      answer(protein: 6.3, serving: 15);
      const args = NewEntryArgs();
      final form = await open(args);
      await form.scanned(nutella, language: 'fr');

      form.setUnit(QuantityUnit.milliliters);

      expect(stateOf(args).fromFoodFacts, {
        EntryFormField.name,
        EntryFormField.proteinPerReference,
      });

      form.refreshFromFoodFacts(
        const FoodFacts(
          name: 'Nutella',
          brands: 'Nutella',
          proteinPer100: 7,
          servingQuantity: 20,
        ).toScan(nutella, fetchedAt: now, scannedAt: now),
      );

      final state = stateOf(args);
      expect(state.unit, QuantityUnit.milliliters);
      expect(state.consumed, '15');
      expect(state.proteinPerReference, '7');
    });

    test('keeps the green of a unit picked again', () async {
      answer(protein: 6.3, serving: 15);
      const args = NewEntryArgs();
      final form = await open(args);
      await form.scanned(nutella, language: 'fr');

      form.setUnit(QuantityUnit.grams);

      expect(
        stateOf(args).fromFoodFacts,
        containsAll([EntryFormField.reference, EntryFormField.consumed]),
      );
    });

    test('takes a newer protein content without undoing what changed '
        'since the scan', () async {
      final id = await addProduct('Nutella');
      const args = NewEntryArgs();
      final form = await open(args);
      final product = (await db.productsDao.getProduct(id))!;
      // The routine adds its entries while the form is open.
      final checkedAt = DateTime(2026, 10, 1, 8);
      await db.productsDao.setRoutine(
        id,
        DailyRoutine.autoAdd,
        minutes: 480,
        now: checkedAt,
      );

      await form.takeFoodFacts(
        product,
        const FoodFacts(name: 'Nutella', proteinPer100: 7),
      );

      final updated = (await db.productsDao.getProduct(id))!;
      expect(updated.proteinPerReference, 7);
      expect(updated.routine, DailyRoutine.autoAdd);
      expect(updated.routineCheckedAt, checkedAt);
    });

    test('keeps a code of the shop without asking about it', () async {
      const weighed = '2123456789015';
      var asked = false;
      foodFacts = () {
        asked = true;
        return http.Response('', 404);
      };
      const args = NewProductArgs();
      final form = await open(args);

      final outcome = await form.scanned(weighed, language: 'fr');

      expect((outcome as ScanNotFound).storeCode, isTrue);
      expect(outcome.problem, isNull);
      expect(asked, isFalse);
      expect(stateOf(args).barcode, weighed);
    });
  });
}
