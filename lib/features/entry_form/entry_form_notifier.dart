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
        return _fromProduct(blank, product);
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
      errors: const {},
      revision: base.revision + 1,
    ),
    product.amount,
  );

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
      _update((s) => s.clearError(EntryFormField.name).copyWith(name: value));

  void setMode(EntryMode value) => _update((s) => s.copyWith(mode: value));

  void setProtein(String value) => _update(
    (s) => s.clearError(EntryFormField.protein).copyWith(protein: value),
  );

  void setConsumed(String value) => _update(
    (s) => s.clearError(EntryFormField.consumed).copyWith(consumed: value),
  );

  void setProteinPerReference(String value) => _update(
    (s) => s
        .clearError(EntryFormField.proteinPerReference)
        .copyWith(proteinPerReference: value),
  );

  void setUnit(QuantityUnit value) => _update((s) => s.copyWith(unit: value));

  void setReference(String value) => _update(
    (s) => s
        .clearError(EntryFormField.reference)
        .clearError(EntryFormField.proteinPerReference)
        .copyWith(reference: value),
  );

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
    if (needsName && !errors.containsKey(EntryFormField.name)) {
      final taken = await _db.productsDao.isNameTaken(
        current.name,
        exceptId: switch (args) {
          EditProductArgs(:final productId) => productId,
          _ => null,
        },
      );
      if (taken) errors[EntryFormField.name] = EntryFormError.nameTaken;
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
    );

    Future<void> updateProduct(Product product) => db.productsDao.updateProduct(
      product.withAmount(amount).copyWith(name: name),
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
