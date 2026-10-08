import 'package:intl/intl.dart';

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

/// Time of day: "08:15", "8:15 AM".
/// Month and year: "Octobre 2026", "October 2026".
String formatMonth(DateTime month, String locale) =>
    _capitalize(DateFormat.yMMMM(locale).format(month));

String formatTime(DateTime time, String locale) =>
    DateFormat.jm(locale).format(time);

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
