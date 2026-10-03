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

/// Largest quantity accepted, in grams: the four digits the forms let type.
const maxGrams = 9999.0;

/// Whether [grams] is a quantity the forms accept: above zero and at most
/// [maxGrams].
bool isValidQuantity(double grams) => grams > 0 && grams <= maxGrams;

/// Smallest and largest daily goal accepted, in grams.
const minDailyGoal = 1.0;
const maxDailyGoal = 1000.0;

/// Whether [goal] is between [minDailyGoal] and [maxDailyGoal].
bool isValidDailyGoal(double goal) =>
    goal >= minDailyGoal && goal <= maxDailyGoal;

/// Daily goal typed by the user, or null if it is not a number between
/// [minDailyGoal] and [maxDailyGoal].
double? parseDailyGoal(String input) {
  final goal = parseGrams(input);
  return goal != null && isValidDailyGoal(goal) ? goal : null;
}
