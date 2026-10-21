import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/domain/daily_routine.dart';
import 'package:protein_calculator/core/domain/entry_mode.dart';
import 'package:protein_calculator/core/domain/grams.dart';
import 'package:protein_calculator/core/domain/protein_amount.dart';
import 'package:protein_calculator/core/domain/quantity_unit.dart';

/// What the form creates or edits, with the ids it needs.
@immutable
sealed class EntryFormArgs {
  const EntryFormArgs();

  bool get isProduct => this is NewProductArgs || this is EditProductArgs;
}

/// New entry, prefilled from the product [productId], or from what Open
/// Food Facts said of the product scanned with [barcode], if given.
final class NewEntryArgs extends EntryFormArgs {
  const NewEntryArgs({this.productId, this.barcode});

  final int? productId;
  final String? barcode;

  @override
  bool operator ==(Object other) =>
      other is NewEntryArgs &&
      other.productId == productId &&
      other.barcode == barcode;

  @override
  int get hashCode => Object.hash(NewEntryArgs, productId, barcode);
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

/// New product, prefilled from what Open Food Facts said of the product
/// scanned with [barcode], or with the values of the product [copyOf], if
/// given.
final class NewProductArgs extends EntryFormArgs {
  const NewProductArgs({this.barcode, this.copyOf});

  final String? barcode;
  final int? copyOf;

  @override
  bool operator ==(Object other) =>
      other is NewProductArgs &&
      other.barcode == barcode &&
      other.copyOf == copyOf;

  @override
  int get hashCode => Object.hash(NewProductArgs, barcode, copyOf);
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

enum EntryFormField {
  name,
  protein,
  consumed,
  proteinPerReference,
  reference,
  time,
  barcode,
}

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

  /// The time of the entry has not come yet.
  future,

  /// Another product already has this barcode.
  barcodeTaken,
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
    this.unit = QuantityUnit.grams,
    this.saveAsProduct = false,
    this.nameTaken = false,
    this.routine = DailyRoutine.none,
    this.routineMinutes = 8 * 60,
    this.time,
    this.barcode,
    this.fromFoodFacts = const {},
    this.errors = const {},
    this.revision = 0,
    this.creatineDoses = 0,
    this.creatineDoseGrams,
  });

  final String name;
  final EntryMode mode;
  final String protein;
  final String consumed;
  final String proteinPerReference;
  final String reference;

  /// Unit of [consumed] and [reference]: grams, or milliliters for drinks.
  final QuantityUnit unit;

  /// Whether a new entry is also saved as a new product, which then gets the
  /// [routine]. Off while the [name] is [nameTaken].
  final bool saveAsProduct;

  /// Whether another product already has the [name]: a new entry cannot be
  /// saved as a product, a product cannot take it.
  final bool nameTaken;

  /// Daily routine of the product, and its time in minutes since midnight,
  /// kept when the routine is turned off in case it is turned on again.
  final DailyRoutine routine;
  final int routineMinutes;

  /// Moment of an entry: the one it was added at when edited, or the one
  /// chosen to add it afterwards. Null for a new entry added now.
  final DateTime? time;

  /// Barcode of the product, see `normalizeBarcode`: the one scanned, or
  /// the one of the product edited. Only products keep it, not entries.
  final String? barcode;

  /// Fields filled in from Open Food Facts, until the user edits them.
  final Set<EntryFormField> fromFoodFacts;
  final Map<EntryFormField, EntryFormError> errors;

  /// Increases when the values are replaced as a whole (a product is
  /// picked), so the text fields reload them.
  final int revision;

  /// Creatine doses of the entry or of one portion of the product. With at
  /// least one, the protein may be zero: creatine taken on its own.
  final int creatineDoses;

  /// Grams of one dose of the entry edited, kept from when it was added;
  /// null otherwise, the dose in force then applying.
  final double? creatineDoseGrams;

  /// Protein amount of the entry, or null while the quantities are invalid.
  ProteinAmount? get amount {
    if (mode == EntryMode.direct) {
      final value = parseGrams(protein);
      return value != null && (value > 0 || (value == 0 && creatineDoses > 0))
          ? DirectAmount(value)
          : null;
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
      unit: unit,
    );
  }

  /// Checks the quantities of the current mode, the [time] against [now]
  /// and, if [nameRequired], the name. Duplicate names are checked against
  /// the database separately.
  Map<EntryFormField, EntryFormError> validate({
    required bool nameRequired,
    required DateTime now,
  }) {
    final errors = <EntryFormField, EntryFormError>{};
    if (nameRequired && name.trim().isEmpty) {
      errors[EntryFormField.name] = EntryFormError.nameRequired;
    }
    if (time?.isAfter(now) ?? false) {
      errors[EntryFormField.time] = EntryFormError.future;
    }

    void positive(EntryFormField field, String text, {bool orZero = false}) {
      final value = parseGrams(text);
      if (value == null) {
        errors[field] = EntryFormError.required;
      } else if (value < 0 || (value == 0 && !orZero)) {
        errors[field] = EntryFormError.notPositive;
      }
    }

    // Creatine taken on its own has no protein.
    final noProtein = creatineDoses > 0;
    if (mode == EntryMode.direct) {
      positive(EntryFormField.protein, protein, orZero: noProtein);
    } else {
      positive(EntryFormField.consumed, consumed);
      positive(
        EntryFormField.proteinPerReference,
        proteinPerReference,
        orZero: noProtein,
      );
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
    QuantityUnit? unit,
    bool? saveAsProduct,
    bool? nameTaken,
    DailyRoutine? routine,
    int? routineMinutes,
    DateTime? time,
    bool clearTime = false,
    String? barcode,
    bool clearBarcode = false,
    Set<EntryFormField>? fromFoodFacts,
    Map<EntryFormField, EntryFormError>? errors,
    int? revision,
    int? creatineDoses,
    double? creatineDoseGrams,
  }) => EntryFormState(
    name: name ?? this.name,
    mode: mode ?? this.mode,
    protein: protein ?? this.protein,
    consumed: consumed ?? this.consumed,
    proteinPerReference: proteinPerReference ?? this.proteinPerReference,
    reference: reference ?? this.reference,
    unit: unit ?? this.unit,
    saveAsProduct: saveAsProduct ?? this.saveAsProduct,
    nameTaken: nameTaken ?? this.nameTaken,
    routine: routine ?? this.routine,
    routineMinutes: routineMinutes ?? this.routineMinutes,
    time: clearTime ? null : time ?? this.time,
    barcode: clearBarcode ? null : barcode ?? this.barcode,
    fromFoodFacts: fromFoodFacts ?? this.fromFoodFacts,
    errors: errors ?? this.errors,
    revision: revision ?? this.revision,
    creatineDoses: creatineDoses ?? this.creatineDoses,
    creatineDoseGrams: creatineDoseGrams ?? this.creatineDoseGrams,
  );

  /// Same state without the error of [field], once the user edits it.
  EntryFormState clearError(EntryFormField field) =>
      copyWith(errors: {...errors}..remove(field));

  /// Same state once the user edits [field]: without its error, and no
  /// longer showing it came from Open Food Facts.
  EntryFormState edited(EntryFormField field) =>
      clearError(field)
          .copyWith(fromFoodFacts: {...fromFoodFacts}..remove(field));
}
