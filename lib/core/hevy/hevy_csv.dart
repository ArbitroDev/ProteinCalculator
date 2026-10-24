import 'dart:ui';

import 'package:csv/csv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Why a file is refused, see [HevyFileException].
enum HevyFileError {
  /// Empty, or the CSV reader cannot make sense of it.
  unreadable,

  /// Readable, but without the columns of a Hevy workout export.
  notHevy,

  /// A workout starts at a moment that cannot be read.
  dates,
}

/// Thrown when a file is not a usable Hevy export. It tells only why, never
/// what the file holds.
class HevyFileException implements Exception {
  const HevyFileException(this.error);

  final HevyFileError error;

  @override
  String toString() => 'HevyFileException: ${error.name}';
}

/// A workout read from a Hevy export: all that is kept of it.
class HevyWorkout {
  const HevyWorkout({required this.title, required this.start, this.end});

  final String title;
  final DateTime start;

  /// Null when the file gives no end.
  final DateTime? end;

  /// How long the workout lasted; null when the end is missing or not after
  /// the start.
  Duration? get duration {
    final end = this.end;
    if (end == null || !end.isAfter(start)) return null;
    return end.difference(start);
  }
}

/// Reads the workouts of a Hevy export (Profile > Settings > Export & Import
/// Data), in the order of the file. Throws [HevyFileException] if it is not
/// a usable export.
///
/// The file has one row per set, with an English header whatever the language
/// of the app, and only `title`, `start_time` and `end_time` are used,
/// found by name. A workout is the consecutive rows sharing the same three
/// values. A file with a header and no workout gives an empty list.
Future<List<HevyWorkout>> parseHevyCsv(String content) async {
  final rows = _readRows(content);
  final header = [for (final name in rows.first) name.toString().trim()];
  final titleColumn = header.indexOf('title');
  final startColumn = header.indexOf('start_time');
  final endColumn = header.indexOf('end_time');
  if (titleColumn < 0 || startColumn < 0 || endColumn < 0) {
    throw const HevyFileException(HevyFileError.notHevy);
  }

  String field(List<dynamic> row, int column) =>
      column < row.length ? row[column].toString() : '';

  final sessions = <(String, String, String)>[];
  for (final row in rows.skip(1)) {
    final session = (
      field(row, titleColumn),
      field(row, startColumn),
      field(row, endColumn),
    );
    if (session != sessions.lastOrNull) sessions.add(session);
  }

  await initializeDateFormatting();
  final dates = _FileDates([for (final (_, start, _) in sessions) start]);
  return [
    for (final (title, start, end) in sessions)
      HevyWorkout(
        title: title,
        // A start that cannot be read refuses the file, but without a
        // readable end the workout still counts for its day.
        start:
            dates.read(start) ??
            (throw const HevyFileException(HevyFileError.dates)),
        end: dates.read(end),
      ),
  ];
}

/// Byte order mark (U+FEFF) some tools write first in a UTF-8 file.
const _bom = 0xFEFF;

/// The rows of [content], header first. Throws [HevyFileException] if there
/// is none or the CSV reader gives up.
List<List<dynamic>> _readRows(String content) {
  final text = content.isNotEmpty && content.codeUnitAt(0) == _bom
      ? content.substring(1)
      : content;
  if (text.trim().isEmpty) {
    throw const HevyFileException(HevyFileError.unreadable);
  }

  // Commas, unless the header has tabs and no commas.
  final headerEnd = text.indexOf(RegExp('[\r\n]'));
  final header = headerEnd < 0 ? text : text.substring(0, headerEnd);
  final tabs = header.contains('\t') && !header.contains(',');
  final List<List<dynamic>> rows;
  try {
    rows = Csv(
      fieldDelimiter: tabs ? '\t' : ',',
      autoDetect: false,
    ).decode(text);
  } on Object {
    throw const HevyFileException(HevyFileError.unreadable);
  }
  if (rows.isEmpty) throw const HevyFileException(HevyFileError.unreadable);
  return rows;
}

/// The moment [text] tells as an ISO 8601 date, in the phone's time zone; null
/// if it is not one.
DateTime? _readIsoDate(String text) {
  final date = DateTime.tryParse(text);
  return date != null && date.isUtc ? date.toLocal() : date;
}

/// The dates of an export, all written in one language: Hevy writes them in
/// the language of the phone it was exported from, "23 oct. 2026, 11:48" in
/// French. That language is the first candidate reading every start of the
/// file, the languages of this phone first and then every language `intl`
/// knows: a word such as "lip" is July in Polish and June in Croatian, and
/// only the other dates of the file tell which one this is.
class _FileDates {
  /// Looks for the language reading each of [starts]. Throws
  /// [HevyFileException] if there is none, unless they are all ISO dates, which
  /// need no language.
  factory _FileDates(Iterable<String> starts) {
    final texts = {
      for (final start in starts)
        if (_readIsoDate(start.trim()) == null) start.trim(),
    };
    if (texts.isEmpty) return _FileDates._(null);
    if (texts.contains('')) throw const HevyFileException(HevyFileError.dates);
    for (final locale in _candidateLocales()) {
      final dates = _FileDates._(DateFormat(_pattern, locale));
      if (texts.every((text) => dates._readInLocale(text) != null)) {
        return dates;
      }
    }
    throw const HevyFileException(HevyFileError.dates);
  }

  _FileDates._(this._format);

  static const _pattern = 'd MMM yyyy, HH:mm';

  /// The format of the language found; null while the dates are all ISO.
  final DateFormat? _format;

  /// What each text read in the language gave, null if it cannot be read, so
  /// that a date repeated in the file is read once.
  final _read = <String, DateTime?>{};

  /// The moment [text] tells in the phone's time zone, or null if it cannot
  /// be read.
  DateTime? read(String text) {
    final trimmed = text.trim();
    return _readIsoDate(trimmed) ?? _readInLocale(trimmed);
  }

  DateTime? _readInLocale(String text) {
    final format = _format;
    if (format == null || text.isEmpty) return null;
    return _read.putIfAbsent(text, () {
      // The spellings Hevy Dashboard also tries: without the dots of the
      // abbreviations, and with "at" / "à" instead of the comma.
      final spellings = {
        text,
        text.replaceAll('.', ''),
        text.replaceAll(' at ', ', ').replaceAll(' à ', ', '),
      };
      for (final spelling in spellings) {
        try {
          return format.parseStrict(spelling);
        } on Object {
          // Whatever the way this language gives up, it only means that the
          // spelling does not fit.
        }
      }
      return null;
    });
  }

  /// The languages to try, the phone's first: those of the phone with and
  /// without their country, when `intl` knows them, then all the others.
  static List<String> _candidateLocales() {
    final known = DateFormat.allLocalesWithSymbols();
    final phone = <String>{};
    for (final locale in PlatformDispatcher.instance.locales) {
      final country = locale.countryCode;
      for (final name in [
        if (country != null && country.isNotEmpty)
          '${locale.languageCode}_$country',
        locale.languageCode,
      ]) {
        if (known.contains(name)) phone.add(name);
      }
    }
    return [...phone, ...known.where((name) => !phone.contains(name))];
  }
}
