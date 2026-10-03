import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';

/// What the form creates or edits, with the ids it needs.
@immutable
sealed class EntryFormArgs {
  const EntryFormArgs();

  bool get isProduct => this is NewProductArgs || this is EditProductArgs;

  bool get isNew => this is NewEntryArgs || this is NewProductArgs;
}

/// New entry, prefilled from the product [productId] if given.
final class NewEntryArgs extends EntryFormArgs {
  const NewEntryArgs({this.productId});

  final int? productId;

  @override
  bool operator ==(Object other) =>
      other is NewEntryArgs && other.productId == productId;

  @override
  int get hashCode => Object.hash(NewEntryArgs, productId);
}

final class EditEntryArgs extends EntryFormArgs {
  const EditEntryArgs(this.entryId);

  final int entryId;

  @override
  bool operator ==(Object other) =>
      other is EditEntryArgs && other.entryId == entryId;

  @override
  int get hashCode => Object.hash(EditEntryArgs, entryId);
}

final class NewProductArgs extends EntryFormArgs {
  const NewProductArgs();

  @override
  bool operator ==(Object other) => other is NewProductArgs;

  @override
  int get hashCode => (NewProductArgs).hashCode;
}

final class EditProductArgs extends EntryFormArgs {
  const EditProductArgs(this.productId);

  final int productId;

  @override
  bool operator ==(Object other) =>
      other is EditProductArgs && other.productId == productId;

  @override
  int get hashCode => Object.hash(EditProductArgs, productId);
}

enum EntryFormField { name, protein, consumed, proteinPerReference, reference }

enum EntryFormError {
  /// A quantity is missing or is not a number.
  required,

  /// A quantity must be greater than zero.
  notPositive,

  /// The protein content is higher than the reference quantity.
  aboveReference,

  /// A product needs a name.
  nameRequired,

  /// Another product already has this name.
  nameTaken,
}

/// Values typed in the entry form, kept as text while typing and parsed
/// when needed. Protein amounts take one decimal, quantities of food are
/// whole numbers of grams.
@immutable
class EntryFormState {
  const EntryFormState({
    this.name = '',
    this.mode = EntryMode.direct,
    this.protein = '',
    this.consumed = '',
    this.proteinPerReference = '',
    this.reference = '100',
    this.saveAsProduct = false,
    this.canSaveAsProduct = true,
    this.updatesProduct = false,
    this.errors = const {},
    this.revision = 0,
  });

  final String name;
  final EntryMode mode;
  final String protein;
  final String consumed;
  final String proteinPerReference;
  final String reference;
  final bool saveAsProduct;

  /// Whether a new entry can be saved as a product: when it starts from a
  /// saved product, only once its values have been changed.
  final bool canSaveAsProduct;

  /// Whether saving as a product updates the product the entry starts from,
  /// because it keeps its name, instead of creating a new one.
  final bool updatesProduct;
  final Map<EntryFormField, EntryFormError> errors;

  /// Increases when the values are replaced as a whole (a product is
  /// picked), so the text fields reload them.
  final int revision;

  /// Protein amount of the entry, or null while the quantities are invalid.
  ProteinAmount? get amount {
    if (mode == EntryMode.direct) {
      final value = parseGrams(protein);
      return value != null && value > 0 ? DirectAmount(value) : null;
    }
    final consumedGrams = parseGrams(consumed);
    final per = parseGrams(proteinPerReference);
    final referenceGrams = parseGrams(reference);
    if (consumedGrams == null ||
        per == null ||
        referenceGrams == null ||
        referenceGrams <= 0) {
      return null;
    }
    return PerQuantityAmount(
      consumedGrams: consumedGrams,
      proteinPerReference: per,
      referenceGrams: referenceGrams,
    );
  }

  /// Checks the quantities of the current mode and, if [nameRequired], the
  /// name. Duplicate names are checked against the database separately.
  Map<EntryFormField, EntryFormError> validate({required bool nameRequired}) {
    final errors = <EntryFormField, EntryFormError>{};
    if (nameRequired && name.trim().isEmpty) {
      errors[EntryFormField.name] = EntryFormError.nameRequired;
    }

    void positive(EntryFormField field, String text) {
      final value = parseGrams(text);
      if (value == null) {
        errors[field] = EntryFormError.required;
      } else if (value <= 0) {
        errors[field] = EntryFormError.notPositive;
      }
    }

    if (mode == EntryMode.direct) {
      positive(EntryFormField.protein, protein);
    } else {
      positive(EntryFormField.consumed, consumed);
      positive(EntryFormField.proteinPerReference, proteinPerReference);
      positive(EntryFormField.reference, reference);
      final per = parseGrams(proteinPerReference);
      final referenceGrams = parseGrams(reference);
      if (per != null &&
          referenceGrams != null &&
          referenceGrams > 0 &&
          per > referenceGrams) {
        errors[EntryFormField.proteinPerReference] =
            EntryFormError.aboveReference;
      }
    }
    return errors;
  }

  EntryFormState copyWith({
    String? name,
    EntryMode? mode,
    String? protein,
    String? consumed,
    String? proteinPerReference,
    String? reference,
    bool? saveAsProduct,
    bool? canSaveAsProduct,
    bool? updatesProduct,
    Map<EntryFormField, EntryFormError>? errors,
    int? revision,
  }) => EntryFormState(
    name: name ?? this.name,
    mode: mode ?? this.mode,
    protein: protein ?? this.protein,
    consumed: consumed ?? this.consumed,
    proteinPerReference: proteinPerReference ?? this.proteinPerReference,
    reference: reference ?? this.reference,
    saveAsProduct: saveAsProduct ?? this.saveAsProduct,
    canSaveAsProduct: canSaveAsProduct ?? this.canSaveAsProduct,
    updatesProduct: updatesProduct ?? this.updatesProduct,
    errors: errors ?? this.errors,
    revision: revision ?? this.revision,
  );

  /// Same state without the error of [field], once the user edits it.
  EntryFormState clearError(EntryFormField field) =>
      copyWith(errors: {...errors}..remove(field));
}
