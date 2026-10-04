import 'package:characters/characters.dart';

/// Longest name of an entry or a product, in characters as the user sees
/// them: an emoji counts as one.
const maxNameLength = 40;

/// Whether [name] can name an entry or a product: not blank, without spaces
/// around it, and at most [maxNameLength] characters, like the form allows.
bool isValidName(String name) =>
    name.isNotEmpty &&
    name.trim() == name &&
    name.characters.length <= maxNameLength;

const _foldedLetters = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
};

/// Normalized product name, ignoring case, accents and extra spaces:
/// "Pâte", "pate" and " PATE " are the same product.
///
/// Used both to detect duplicate names and to sort products alphabetically,
/// so that "Épinards" and "Œufs" sort with E and O.
String productNameKey(String name) {
  final buffer = StringBuffer();
  final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  for (final char in cleaned.split('')) {
    buffer.write(_foldedLetters[char] ?? char);
  }
  return buffer.toString();
}
