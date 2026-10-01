/// Parses a quantity in grams typed by the user, accepting both a decimal
/// comma and a decimal point ("12,5" or "12.5").
///
/// Returns null if [input] is not a finite number.
double? parseGrams(String input) {
  final normalized = input.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  return value != null && value.isFinite ? value : null;
}

/// Smallest and largest daily goal accepted, in grams.
const minDailyGoal = 1.0;
const maxDailyGoal = 1000.0;
