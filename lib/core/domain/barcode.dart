/// Whether [code] is the digits of an EAN-13, EAN-8 or UPC-A barcode, the
/// codes printed on food packaging, with its check digit right.
bool isValidBarcode(String code) =>
    _digits.hasMatch(code) &&
    const {8, 12, 13}.contains(code.length) &&
    _checkDigitIsRight(code);

/// [code] the way barcodes are stored and looked up: a UPC-A takes a leading
/// zero to become the EAN-13 it is part of, as Open Food Facts stores it, so
/// a product is found whichever way it was read. Null if [code] is not a
/// valid barcode, see [isValidBarcode].
String? normalizeBarcode(String code) {
  final trimmed = code.trim();
  if (!isValidBarcode(trimmed)) return null;
  return trimmed.length == 12 ? '0$trimmed' : trimmed;
}

/// Whether [barcode], in its stored form, is a code a shop gives to its own
/// goods, often with their weight or price in it: the restricted
/// circulation numbers of GS1, an EAN-13 starting with 02, 04 or 2, or an
/// EAN-8 starting with 0 or 2. Open Food Facts is not asked about them.
bool isStoreBarcode(String barcode) => switch (barcode.length) {
  13 => barcode.startsWith(RegExp('0[24]|2')),
  8 => barcode.startsWith(RegExp('[02]')),
  _ => false,
};

/// Whether [code] is a valid barcode in its stored form, see
/// [normalizeBarcode].
bool isNormalizedBarcode(String code) => normalizeBarcode(code) == code;

/// [code] typed by the user, in its stored form: an EAN-13, EAN-8 or UPC-A,
/// or else a UPC-E, printed with 8 digits too but whose check digit is the
/// one of its UPC-A, see [expandUpcE]. Null if it is none of them.
String? normalizeTypedBarcode(String code) {
  final trimmed = code.trim();
  final barcode = normalizeBarcode(trimmed);
  // A UPC-E starts with its number system, 0 or 1.
  if (barcode != null || !trimmed.startsWith(RegExp('[01]'))) return barcode;
  final upcA = expandUpcE(trimmed);
  return upcA == null ? null : normalizeBarcode(upcA);
}

/// The UPC-A a UPC-E [code] is the short form of, both of 8 digits with
/// their number system and check digit: the zeros left out of the
/// manufacturer and product numbers come back, where the sixth digit says.
/// Null if [code] is not 8 digits.
String? expandUpcE(String code) {
  if (code.length != 8 || !_digits.hasMatch(code)) return null;
  final system = code[0];
  final d = code.substring(1, 7);
  final check = code[7];
  final body = switch (d[5]) {
    '0' || '1' || '2' => '${d.substring(0, 2)}${d[5]}0000${d.substring(2, 5)}',
    '3' => '${d.substring(0, 3)}00000${d.substring(3, 5)}',
    '4' => '${d.substring(0, 4)}00000${d[4]}',
    _ => '${d.substring(0, 5)}0000${d[5]}',
  };
  return '$system$body$check';
}

final _digits = RegExp(r'^\d+$');

/// From the right, the check digit counts once, then the digits count three
/// times and once in turn: the sum is a multiple of 10.
bool _checkDigitIsRight(String code) {
  var sum = 0;
  for (var i = 0; i < code.length; i++) {
    final digit = code.codeUnitAt(code.length - 1 - i) - 0x30;
    sum += i.isOdd ? digit * 3 : digit;
  }
  return sum % 10 == 0;
}
