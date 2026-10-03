import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/database/protein_amounts.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/protein_calc.dart';
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

  /// Product a new entry starts from: opened from it or picked among the
  /// suggestions.
  Product? _source;

  @override
  Future<EntryFormState> build() async {
    final db = ref.read(databaseProvider);
    switch (args) {
      case NewEntryArgs(:final productId):
        if (productId == null) return const EntryFormState();
        final product = await db.productsDao.getProduct(productId);
        if (product == null) return const EntryFormState();
        _source = product;
        return _withSourceStatus(_fromProduct(const EntryFormState(), product));
      case NewProductArgs():
        return const EntryFormState();
      case EditEntryArgs(:final entryId):
        final entry = await db.entriesDao.getEntry(entryId);
        if (entry == null) return const EntryFormState();
        return _withAmount(
          EntryFormState(name: entry.name ?? ''),
          entry.amount,
        );
      case EditProductArgs(:final productId):
        final product = await db.productsDao.getProduct(productId);
        return product == null
            ? const EntryFormState()
            : _fromProduct(const EntryFormState(), product);
    }
  }

  EntryFormState _fromProduct(EntryFormState base, Product product) =>
      _withAmount(
        base.copyWith(
          name: product.name,
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
    ),
    PerQuantityAmount() => form.copyWith(
      mode: amount.mode,
      // Ready if the user switches to typing the amount directly.
      protein: _proteinText(amount.proteinGrams),
      consumed: _gramsText(amount.consumedGrams),
      proteinPerReference: _proteinText(amount.proteinPerReference),
      reference: _gramsText(amount.referenceGrams),
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
    if (current != null) state = AsyncData(_withSourceStatus(change(current)));
  }

  /// Allows saving as a product only once the values differ from the
  /// product the entry starts from.
  EntryFormState _withSourceStatus(EntryFormState form) {
    final source = _source;
    if (args is! NewEntryArgs || source == null) return form;
    final changed = !_matches(form, source);
    return form.copyWith(
      canSaveAsProduct: changed,
      saveAsProduct: changed && form.saveAsProduct,
      updatesProduct: productNameKey(form.name) == source.nameKey,
    );
  }

  /// Whether [form] holds the same name and quantities as [product].
  bool _matches(EntryFormState form, Product product) {
    final saved = _fromProduct(const EntryFormState(), product);
    bool same(String a, String b) => parseGrams(a) == parseGrams(b);
    if (productNameKey(form.name) != product.nameKey) return false;
    if (form.mode != saved.mode) return false;
    if (form.mode == EntryMode.direct) return same(form.protein, saved.protein);
    return same(form.consumed, saved.consumed) &&
        same(form.proteinPerReference, saved.proteinPerReference) &&
        same(form.reference, saved.reference);
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

  void setReference(String value) => _update(
    (s) => s
        .clearError(EntryFormField.reference)
        .clearError(EntryFormField.proteinPerReference)
        .copyWith(reference: value),
  );

  void setSaveAsProduct(bool value) => _update(
    (s) => s.clearError(EntryFormField.name).copyWith(saveAsProduct: value),
  );

  /// Fills the form with the values of a suggested product.
  void applyProduct(Product product) {
    _source = product;
    _update((s) => _fromProduct(s, product));
  }

  /// Validates and saves the form. Returns whether it was saved.
  Future<bool> submit() async {
    final current = state.value;
    if (current == null) return false;

    final needsName = args.isProduct || current.saveAsProduct;
    final errors = current.validate(nameRequired: needsName);
    if (needsName && !errors.containsKey(EntryFormField.name)) {
      final taken = await _db.productsDao.isNameTaken(
        current.name,
        exceptId: switch (args) {
          EditProductArgs(:final productId) => productId,
          NewEntryArgs() when current.updatesProduct => _source?.id,
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

    switch (args) {
      case NewEntryArgs():
        await db.transaction(() async {
          // The product goes first so this entry counts as its first use.
          if (form.saveAsProduct) {
            final source = form.updatesProduct && _source != null
                ? await db.productsDao.getProduct(_source!.id)
                : null;
            if (source != null) {
              await updateProduct(source);
            } else {
              await insertProduct();
            }
          }
          await db.entriesDao.insertEntry(
            name: name.isEmpty ? null : name,
            amount: amount,
            createdAt: now,
          );
        });
      case EditEntryArgs(:final entryId):
        final entry = await db.entriesDao.getEntry(entryId);
        if (entry == null) return;
        await db.entriesDao.updateEntry(
          entry
              .withAmount(amount)
              .copyWith(name: Value(name.isEmpty ? null : name)),
        );
      case NewProductArgs():
        await insertProduct();
      case EditProductArgs(:final productId):
        final product = await db.productsDao.getProduct(productId);
        if (product != null) await updateProduct(product);
    }
  }
}
