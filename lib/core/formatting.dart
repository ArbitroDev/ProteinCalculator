import 'package:intl/intl.dart';

/// Grams rounded to the unit, formatted for [locale] ("1 234" in French).
String formatGrams(double grams, String locale) =>
    NumberFormat.decimalPattern(locale).format(grams.round());

/// Full date of a day, starting with a capital letter in every language:
/// "Mercredi 1 octobre", "Wednesday, October 1".
String formatLongDate(DateTime date, String locale) {
  final text = DateFormat.MMMMEEEEd(locale).format(date);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
