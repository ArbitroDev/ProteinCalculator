import 'package:intl/intl.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Grams truncated to the unit, formatted for [locale] ("1 234" in French).
///
/// For computed values (totals, what is left, the goal) and quantities of
/// food: a total of 139.8 g shows 139 g, so the goal only shows as reached
/// once it really is.
String formatGrams(double grams, String locale) =>
    NumberFormat.decimalPattern(locale).format(truncateGrams(grams));

/// Whole grams shown for [grams]; the epsilon absorbs floating point sums
/// such as 59.99999 for 60.
int truncateGrams(double grams) => (grams + 1e-9).floor();

/// Protein grams of one entry or one product, typed or computed with one
/// decimal at most: "10,5", "23", "1 234,5".
String formatProtein(double grams, String locale) =>
    NumberFormat('#,##0.#', locale).format(grams);

/// Full date of a day, starting with a capital letter in every language:
/// "Mercredi 1 octobre", "Wednesday, October 1".
String formatLongDate(DateTime date, String locale) =>
    _capitalize(DateFormat.MMMMEEEEd(locale).format(date));

/// Short date of a day, starting with a capital letter: "Mer. 30 sept.",
/// "Wed, Sep 30".
String formatShortDate(DateTime date, String locale) =>
    _capitalize(DateFormat.MMMEd(locale).format(date));

/// Day and month of [date], to read in a sentence, so in lower case: "24 oct.",
/// "Oct 24". With the year ("24 oct. 2025", "Oct 24, 2025") when it is not
/// that of [now], which a date from a year back would be taken for otherwise.
String formatDayMonth(DateTime date, String locale, {required DateTime now}) =>
    date.year == now.year
    ? DateFormat.MMMd(locale).format(date)
    : DateFormat.yMMMd(locale).format(date);

/// Month and year: "Octobre 2026", "October 2026".
String formatMonth(DateTime month, String locale) =>
    _capitalize(DateFormat.yMMMM(locale).format(month));

/// Time of day: "08:15", "8:15 AM".
String formatTime(DateTime time, String locale) =>
    DateFormat.jm(locale).format(time);

/// Length of a workout, whole minutes only: "24 min", "2 h", and "1 h 05" or
/// "1 h 5 min" for what is left over, as each language writes it.
String formatDuration(Duration duration, AppLocalizations l10n) {
  final total = duration.inMinutes;
  if (total < 60) return l10n.durationMinutes(total);
  final hours = total ~/ 60;
  final minutes = total % 60;
  if (minutes == 0) return l10n.durationWholeHours(hours);
  return l10n.durationHours(hours, minutes, minutes.toString().padLeft(2, '0'));
}

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
