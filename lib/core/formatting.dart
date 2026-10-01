import 'package:intl/intl.dart';

/// Grams rounded to the unit, formatted for [locale] ("1 234" in French).
String formatGrams(double grams, String locale) =>
    NumberFormat.decimalPattern(locale).format(grams.round());

/// Full date of a day, starting with a capital letter in every language:
/// "Mercredi 1 octobre", "Wednesday, October 1".
String formatLongDate(DateTime date, String locale) =>
    _capitalize(DateFormat.MMMMEEEEd(locale).format(date));

/// Short date of a day, starting with a capital letter: "Mer. 30 sept.",
/// "Wed, Sep 30".
String formatShortDate(DateTime date, String locale) =>
    _capitalize(DateFormat.MMMEd(locale).format(date));

/// Time of day: "08:15", "8:15 AM".
String formatTime(DateTime time, String locale) =>
    DateFormat.jm(locale).format(time);

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
