import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/database/products_dao.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/product_name.dart';
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

  @override
  Future<EntryFormState> build() async {
    final db = ref.read(databaseProvider);
    switch (args.kind) {
      case EntryFormKind.newEntry:
        final productId = args.id;
        if (productId == null) return const EntryFormState();
        final product = await db.productsDao.getProduct(productId);
        return product == null
            ? const EntryFormState()
            : _fromProduct(const EntryFormState(), product);
      case EntryFormKind.newProduct:
        return const EntryFormState();
      case EntryFormKind.editEntry:
        final entry = await db.entriesDao.getEntry(args.id!);
        if (entry == null) return const EntryFormState();
        return EntryFormState(
          name: entry.name ?? '',
          mode: entry.mode,
          protein: _text(entry.proteinGrams),
          consumed: _text(entry.consumedGrams),
          proteinPerReference: _text(entry.proteinPerReference),
          reference: _text(entry.referenceGrams, fallback: '100'),
        );
      case EntryFormKind.editProduct:
        final product = await db.productsDao.getProduct(args.id!);
        return product == null
            ? const EntryFormState()
            : _fromProduct(const EntryFormState(), product);
    }
  }

  EntryFormState _fromProduct(EntryFormState base, Product product) =>
      base.copyWith(
        name: product.name,
        mode: product.mode,
        protein: _text(product.proteinGrams),
        consumed: _text(product.consumedGrams),
        proteinPerReference: _text(product.proteinPerReference),
        reference: _text(product.referenceGrams, fallback: '100'),
        errors: const {},
        revision: base.revision + 1,
      );

  /// Text of a stored quantity, rounded to a whole number of grams like
  /// everything typed in the form.
  static String _text(double? value, {String fallback = ''}) =>
      value == null ? fallback : value.round().toString();

  void _update(EntryFormState Function(EntryFormState) change) {
    final current = state.value;
    if (current != null) state = AsyncData(change(current));
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
  void applyProduct(Product product) =>
      _update((s) => _fromProduct(s, product));

  /// Validates and saves the form. Returns whether it was saved.
  Future<bool> submit() async {
    final current = state.value;
    if (current == null) return false;

    final needsName = args.isProduct || current.saveAsProduct;
    final errors = current.validate(nameRequired: needsName);
    if (needsName && !errors.containsKey(EntryFormField.name)) {
      final taken = await _db.productsDao.isNameTaken(
        current.name,
        exceptId: args.kind == EntryFormKind.editProduct ? args.id : null,
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
    final direct = form.mode == EntryMode.direct;
    final proteinGrams = form.proteinGrams!;
    final consumed = direct ? null : parseGrams(form.consumed);
    final per = direct ? null : parseGrams(form.proteinPerReference);
    final reference = direct ? null : parseGrams(form.reference);

    Future<int> insertProduct() => db.productsDao.insertProduct(
      name: name,
      mode: form.mode,
      proteinGrams: direct ? proteinGrams : null,
      consumedGrams: consumed,
      proteinPerReference: per,
      referenceGrams: reference,
      createdAt: now,
    );

    switch (args.kind) {
      case EntryFormKind.newEntry:
        await db.transaction(() async {
          // The product goes first so this entry counts as its first use.
          if (form.saveAsProduct) await insertProduct();
          await db.entriesDao.insertEntry(
            name: name.isEmpty ? null : name,
            mode: form.mode,
            proteinGrams: proteinGrams,
            consumedGrams: consumed,
            proteinPerReference: per,
            referenceGrams: reference,
            createdAt: now,
          );
        });
      case EntryFormKind.editEntry:
        final entry = await db.entriesDao.getEntry(args.id!);
        if (entry == null) return;
        await db.entriesDao.updateEntry(
          entry.copyWith(
            name: Value(name.isEmpty ? null : name),
            mode: form.mode,
            proteinGrams: proteinGrams,
            consumedGrams: Value(consumed),
            proteinPerReference: Value(per),
            referenceGrams: Value(reference),
          ),
        );
      case EntryFormKind.newProduct:
        await insertProduct();
      case EntryFormKind.editProduct:
        final product = await db.productsDao.getProduct(args.id!);
        if (product == null) return;
        await db.productsDao.updateProduct(
          product.copyWith(
            name: name,
            mode: form.mode,
            proteinGrams: Value(direct ? proteinGrams : null),
            consumedGrams: Value(consumed),
            proteinPerReference: Value(per),
            referenceGrams: Value(reference),
          ),
        );
    }
  }
}
