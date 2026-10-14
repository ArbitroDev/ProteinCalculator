import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/protein_calc.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';
import 'package:protein_calculator/core/food_facts/food_facts.dart';
import 'package:protein_calculator/core/food_facts/open_food_facts.dart';
import 'package:protein_calculator/core/food_facts/product_lookup.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/features/entry_form/entry_form_state.dart';

final entryFormProvider = AsyncNotifierProvider.autoDispose
    .family<EntryFormNotifier, EntryFormState, EntryFormArgs>(
      EntryFormNotifier.new,
    );

/// Products whose name contains [query], best matches first: names starting
/// with the query, then the most used.
final productSuggestionsProvider = Provider.autoDispose
    .family<List<Product>, String>((ref, query) {
      final key = productNameKey(query);
      if (key.isEmpty) return const [];
      final products = ref.watch(productsProvider).value ?? const [];
      final matches = products.where((p) => p.nameKey.contains(key)).toList()
        ..sort((a, b) {
          final prefix =
              (a.nameKey.startsWith(key) ? 0 : 1) -
              (b.nameKey.startsWith(key) ? 0 : 1);
          if (prefix != 0) return prefix;
          final uses = b.useCount.compareTo(a.useCount);
          return uses != 0 ? uses : a.nameKey.compareTo(b.nameKey);
        });
      return matches.take(4).toList();
    });

/// What became of a barcode scanned in the form, for the page to tell.
sealed class ScanOutcome {
  const ScanOutcome();
}

/// The form shows the product of the user with the barcode. [update]
/// completes with what Open Food Facts says of it now, when that changed:
/// the page offers to take it.
final class ScanFoundProduct extends ScanOutcome {
  const ScanFoundProduct(this.product, this.update);

  final Product product;
  final Future<FoodFacts?> update;
}

/// The form shows what Open Food Facts said of the product, [scan].
/// [sameName] is the product of the user with the same name and no barcode
/// yet, which can take the barcode instead. [update] completes with newer
/// values, put in the fields not edited since.
final class ScanFilled extends ScanOutcome {
  const ScanFilled(this.scan, {required this.sameName, required this.update});

  final ScannedProduct scan;
  final Product? sameName;
  final Future<ScannedProduct?> update;
}

/// Another product of the user has the barcode: the form stays as it was.
final class ScanBarcodeTaken extends ScanOutcome {
  const ScanBarcodeTaken(this.product);

  final Product product;
}

/// The product edited takes the barcode, its values stay.
final class ScanKept extends ScanOutcome {
  const ScanKept();
}

/// Nothing is known of the product, or Open Food Facts could not be asked
/// ([problem]): the barcode is kept, the values are typed.
final class ScanNotFound extends ScanOutcome {
  const ScanNotFound([this.problem]);

  final FoodFactsProblem? problem;
}

class EntryFormNotifier extends AsyncNotifier<EntryFormState> {
  EntryFormNotifier(this.args);

  final EntryFormArgs args;

  AppDatabase get _db => ref.read(databaseProvider);

  /// Normalized names of the other products, which the name cannot take.
  Set<String> _takenNames = const {};

  @override
  Future<EntryFormState> build() async {
    final db = ref.read(databaseProvider);
    _takenNames = await db.productsDao.getNameKeys();
    // A new routine is offered at the current time, by steps of 5 minutes.
    final now = ref.read(clockProvider)();
    final blank = EntryFormState(
      routineMinutes:
          ((now.hour * 60 + now.minute) / 5).round() * 5 % minutesPerDay,
    );
    switch (args) {
      case NewEntryArgs(barcode: final barcode?) ||
          NewProductArgs(barcode: final barcode?):
        // From a recent scan, with what Open Food Facts said of it.
        final scan = await db.scansDao.getScan(barcode);
        if (scan == null) return blank.copyWith(barcode: barcode);
        return _withNameStatus(_fromScan(blank, scan));
      case NewEntryArgs(:final productId):
        // From a product: a blank entry filled with its values, which never
        // changes the product.
        if (productId == null) return blank;
        final product = await db.productsDao.getProduct(productId);
        if (product == null) return blank;
        return _withNameStatus(_fromProduct(blank, product, routine: false));
      case NewProductArgs():
        return blank;
      case EditEntryArgs(:final entryId):
        final entry = await db.entriesDao.getEntry(entryId);
        if (entry == null) return const EntryFormState();
        return _withAmount(
          EntryFormState(name: entry.name ?? '', time: entry.createdAt),
          entry.amount,
        );
      case EditProductArgs(:final productId):
        final product = await db.productsDao.getProduct(productId);
        if (product == null) return blank;
        _takenNames = {..._takenNames}..remove(product.nameKey);
        return _fromProduct(blank, product).copyWith(barcode: product.barcode);
    }
  }

  /// [base] filled with the name and the values of [product], and its
  /// [routine] too: a new entry starting from a product does not take it.
  EntryFormState _fromProduct(
    EntryFormState base,
    Product product, {
    bool routine = true,
  }) => _withAmount(
    base.copyWith(
      name: product.name,
      routine: routine ? product.routine : null,
      routineMinutes: routine ? product.routineMinutes : null,
      clearBarcode: true,
      fromFoodFacts: const {},
      errors: const {},
      revision: base.revision + 1,
    ),
    product.amount,
  );

  /// [form] filled with what Open Food Facts said of [scan], showing which
  /// fields it filled in, and keeping its barcode for the product saved. A
  /// value Open Food Facts lacks is left for the user, as is a protein
  /// content of zero, which no entry can have.
  static EntryFormState _fromScan(EntryFormState form, ScannedProduct scan) {
    final name = scannedProductName(scan.name, scan.brands);
    final protein = scan.proteinPer100;
    final serving = scan.servingQuantity;
    final hasProtein = protein != null && protein > 0;
    return form.copyWith(
      name: name ?? form.name,
      mode: EntryMode.perQuantity,
      proteinPerReference: hasProtein ? _proteinText(protein) : '',
      reference: _gramsText(defaultReferenceGrams),
      consumed: serving == null ? '' : _gramsText(serving),
      unit: scan.unit,
      barcode: scan.barcode,
      fromFoodFacts: {
        if (name != null) EntryFormField.name,
        if (hasProtein) EntryFormField.proteinPerReference,
        EntryFormField.reference,
        if (serving != null) EntryFormField.consumed,
      },
      errors: const {},
      revision: form.revision + 1,
    );
  }

  /// [form] showing [amount].
  static EntryFormState _withAmount(
    EntryFormState form,
    ProteinAmount amount,
  ) => switch (amount) {
    DirectAmount(:final proteinGrams) => form.copyWith(
      mode: amount.mode,
      protein: _proteinText(proteinGrams),
      consumed: '',
      proteinPerReference: '',
      reference: _gramsText(defaultReferenceGrams),
      unit: QuantityUnit.grams,
    ),
    PerQuantityAmount() => form.copyWith(
      mode: amount.mode,
      // Ready if the user switches to typing the amount directly.
      protein: _proteinText(amount.proteinGrams),
      consumed: _gramsText(amount.consumedGrams),
      proteinPerReference: _proteinText(amount.proteinPerReference),
      reference: _gramsText(amount.referenceGrams),
      unit: amount.unit,
    ),
  };

  /// Text of a quantity of food, a whole number of grams.
  static String _gramsText(double value) => value.round().toString();

  /// Text of a protein amount, typed with one decimal at most: "10.5", "23".
  static String _proteinText(double value) {
    final tenths = (value * 10).round();
    return tenths % 10 == 0 ? '${tenths ~/ 10}' : (tenths / 10).toString();
  }

  void _update(EntryFormState Function(EntryFormState) change) {
    final current = state.value;
    if (current != null) state = AsyncData(_withNameStatus(change(current)));
  }

  /// [form] knowing whether its name is taken: a new entry is then not
  /// saved as a product, which needs a name of its own.
  EntryFormState _withNameStatus(EntryFormState form) {
    final taken = _takenNames.contains(productNameKey(form.name));
    return form.copyWith(
      nameTaken: taken,
      saveAsProduct: form.saveAsProduct && !taken,
    );
  }

  void setName(String value) =>
      _update((s) => s.edited(EntryFormField.name).copyWith(name: value));

  void setMode(EntryMode value) => _update((s) => s.copyWith(mode: value));

  void setProtein(String value) =>
      _update((s) => s.edited(EntryFormField.protein).copyWith(protein: value));

  void setConsumed(String value) => _update(
    (s) => s.edited(EntryFormField.consumed).copyWith(consumed: value),
  );

  void setProteinPerReference(String value) => _update(
    (s) => s
        .edited(EntryFormField.proteinPerReference)
        .copyWith(proteinPerReference: value),
  );

  void setUnit(QuantityUnit value) => _update((s) => s.copyWith(unit: value));

  void setReference(String value) => _update(
    (s) => s
        .edited(EntryFormField.reference)
        .clearError(EntryFormField.proteinPerReference)
        .copyWith(reference: value),
  );

  /// Gives the product the [barcode], or takes its barcode away when null.
  void setBarcode(String? barcode) => _update(
    (s) => s
        .clearError(EntryFormField.barcode)
        .copyWith(barcode: barcode, clearBarcode: barcode == null),
  );

  /// Fills the form from the product of [barcode], looked up on the phone,
  /// then on Open Food Facts, with names in [language]. A product edited
  /// only takes the barcode: the user's values stay.
  Future<ScanOutcome> scanned(
    String barcode, {
    required String language,
  }) async {
    final db = _db;
    if (args case EditProductArgs(:final productId)) {
      final owner = await db.productsDao.findByBarcode(barcode);
      if (owner != null && owner.id != productId) {
        return ScanBarcodeTaken(owner);
      }
      setBarcode(barcode);
      return const ScanKept();
    }

    final lookup = ref.read(productLookupProvider);
    final result = await lookup.lookUp(barcode, language: language);
    if (!ref.mounted) return const ScanKept();
    switch (result) {
      case SavedProductFound(:final product, :final update):
        // A new product cannot take the barcode of another.
        if (args is NewProductArgs) return ScanBarcodeTaken(product);
        applyProduct(product);
        return ScanFoundProduct(
          product,
          update.then((facts) => _isNews(product, facts) ? facts : null),
        );
      case ScannedProductFound(:final scan, :final update):
        _update((s) => _fromScan(s, scan));
        final name = scannedProductName(scan.name, scan.brands);
        final sameName = name == null
            ? null
            : await db.productsDao.findByName(name);
        return ScanFilled(
          scan,
          sameName: sameName?.barcode == null ? sameName : null,
          update: update,
        );
      case ProductNotFound():
        setBarcode(barcode);
        return const ScanNotFound();
      case ProductLookupFailed(:final problem):
        setBarcode(barcode);
        return ScanNotFound(problem);
    }
  }

  /// Whether [facts], newer values of Open Food Facts, change the protein
  /// content of [product]. A product whose protein is typed per portion
  /// stays as the user made it.
  static bool _isNews(Product product, FoodFacts? facts) {
    final protein = facts?.proteinPer100;
    final amount = product.amount;
    if (protein == null || protein <= 0 || amount is! PerQuantityAmount) {
      return false;
    }
    final per100 =
        (amount.proteinPerReference / amount.referenceGrams * 1000).round() /
        10;
    return per100 != protein || amount.unit != facts!.unit;
  }

  /// Gives [barcode] to [product], the product of the user with the same
  /// name, and shows it instead of what Open Food Facts said: the user's
  /// values come first.
  Future<void> giveBarcode(Product product, String barcode) async {
    await _db.productsDao.setBarcode(product.id, barcode);
    applyProduct(product);
  }

  /// Takes the protein content of [facts], newer values of Open Food Facts,
  /// into [product], keeping its portion, and into the form if it shows it.
  Future<void> takeFoodFacts(Product product, FoodFacts facts) async {
    final protein = facts.proteinPer100;
    final amount = product.amount;
    if (protein == null || amount is! PerQuantityAmount) return;
    await _db.productsDao.updateProduct(
      product.withAmount(
        PerQuantityAmount(
          consumedGrams: amount.consumedGrams,
          proteinPerReference: protein,
          referenceGrams: defaultReferenceGrams,
          unit: facts.unit,
        ),
      ),
    );
    _update(
      (s) => productNameKey(s.name) != product.nameKey
          ? s
          : s.copyWith(
              mode: EntryMode.perQuantity,
              proteinPerReference: _proteinText(protein),
              reference: _gramsText(defaultReferenceGrams),
              unit: facts.unit,
              fromFoodFacts: {
                ...s.fromFoodFacts,
                EntryFormField.proteinPerReference,
                EntryFormField.reference,
              },
              revision: s.revision + 1,
            ),
    );
  }

  /// Puts the newer values of [scan] in the fields still showing what Open
  /// Food Facts said, if the form still shows its product.
  void refreshFromFoodFacts(ScannedProduct scan) => _update((s) {
    if (s.barcode != scan.barcode) return s;
    final fresh = _fromScan(s, scan);
    final green = s.fromFoodFacts;
    String take(EntryFormField field, String current, String value) =>
        green.contains(field) ? value : current;
    return s.copyWith(
      name: take(EntryFormField.name, s.name, fresh.name),
      proteinPerReference: take(
        EntryFormField.proteinPerReference,
        s.proteinPerReference,
        fresh.proteinPerReference,
      ),
      reference: take(EntryFormField.reference, s.reference, fresh.reference),
      consumed: take(EntryFormField.consumed, s.consumed, fresh.consumed),
      unit: green.contains(EntryFormField.reference) ? fresh.unit : s.unit,
      fromFoodFacts: green.intersection(fresh.fromFoodFacts),
      revision: s.revision + 1,
    );
  });

  /// Turning it on is ignored while the name is taken, see
  /// [EntryFormState.nameTaken].
  void setSaveAsProduct(bool value) => _update(
    (s) => value && s.nameTaken
        ? s
        : s.clearError(EntryFormField.name).copyWith(saveAsProduct: value),
  );

  /// The routine of the product, or of the new product a new entry is saved
  /// as.
  void setRoutine(DailyRoutine value) =>
      _update((s) => s.copyWith(routine: value));

  void setRoutineMinutes(int value) =>
      _update((s) => s.copyWith(routineMinutes: value));

  /// Sets the moment of the entry, or null for now; a moment yet to come is
  /// refused at once.
  void setTime(DateTime? value) {
    final future = value?.isAfter(ref.read(clockProvider)()) ?? false;
    _update((s) {
      final next = s
          .clearError(EntryFormField.time)
          .copyWith(time: value, clearTime: value == null);
      return future
          ? next.copyWith(
              errors: {
                ...next.errors,
                EntryFormField.time: EntryFormError.future,
              },
            )
          : next;
    });
  }

  /// Fills the form with the values of a suggested product, which the entry
  /// never changes.
  void applyProduct(Product product) =>
      _update((s) => _fromProduct(s, product, routine: false));

  /// Validates and saves the form. Returns whether it was saved.
  Future<bool> submit() async {
    final current = state.value;
    if (current == null) return false;

    final needsName = args.isProduct || current.saveAsProduct;
    final errors = current.validate(
      nameRequired: needsName,
      now: ref.read(clockProvider)(),
    );
    final productId = switch (args) {
      EditProductArgs(:final productId) => productId,
      _ => null,
    };
    if (needsName && !errors.containsKey(EntryFormField.name)) {
      final taken = await _db.productsDao.isNameTaken(
        current.name,
        exceptId: productId,
      );
      if (taken) errors[EntryFormField.name] = EntryFormError.nameTaken;
    }
    final barcode = current.barcode;
    if (needsName &&
        barcode != null &&
        await _db.productsDao.isBarcodeTaken(barcode, exceptId: productId)) {
      errors[EntryFormField.barcode] = EntryFormError.barcodeTaken;
    }
    if (errors.isNotEmpty) {
      if (ref.mounted) state = AsyncData(current.copyWith(errors: errors));
      return false;
    }

    try {
      await _save(current);
    } on DuplicateProductNameException {
      if (ref.mounted) {
        state = AsyncData(
          current.copyWith(
            errors: {EntryFormField.name: EntryFormError.nameTaken},
          ),
        );
      }
      return false;
    } on DuplicateBarcodeException {
      if (ref.mounted) {
        state = AsyncData(
          current.copyWith(
            errors: {EntryFormField.barcode: EntryFormError.barcodeTaken},
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _save(EntryFormState form) async {
    final db = _db;
    final now = ref.read(clockProvider)();
    final name = form.name.trim();
    // Valid once the form is validated.
    final amount = form.amount!;

    Future<int> insertProduct() => db.productsDao.insertProduct(
      name: name,
      amount: amount,
      createdAt: now,
      barcode: form.barcode,
    );

    Future<void> updateProduct(Product product) => db.productsDao.updateProduct(
      product
          .withAmount(amount)
          .copyWith(name: name, barcode: Value(form.barcode)),
    );

    /// Gives the product [id] the routine of the form, if [product], its
    /// values before, had another one: choosing it again would skip the
    /// additions due meanwhile.
    Future<void> setRoutine(int id, Product? product) async {
      final same =
          product != null &&
          product.routine == form.routine &&
          (form.routine == DailyRoutine.none ||
              product.routineMinutes == form.routineMinutes);
      if (same) return;
      await db.productsDao.setRoutine(
        id,
        form.routine,
        minutes: form.routineMinutes,
        now: now,
      );
    }

    switch (args) {
      case NewEntryArgs():
        await db.transaction(() async {
          // The new product goes first so this entry counts as its first
          // use.
          if (form.saveAsProduct) await setRoutine(await insertProduct(), null);
          await db.entriesDao.insertEntry(
            name: name.isEmpty ? null : name,
            amount: amount,
            createdAt: form.time ?? now,
          );
        });
      case EditEntryArgs(:final entryId):
        final entry = await db.entriesDao.getEntry(entryId);
        if (entry == null) return;
        await db.entriesDao.updateEntry(
          entry
              .withAmount(amount)
              .copyWith(name: Value(name.isEmpty ? null : name)),
          createdAt: form.time,
        );
      case NewProductArgs():
        await db.transaction(
          () async => setRoutine(await insertProduct(), null),
        );
      case EditProductArgs(:final productId):
        await db.transaction(() async {
          final product = await db.productsDao.getProduct(productId);
          if (product == null) return;
          await updateProduct(product);
          await setRoutine(productId, product);
        });
    }
  }
}
