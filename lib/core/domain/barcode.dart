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

/// Whether [code] is a valid barcode in its stored form, see
/// [normalizeBarcode].
bool isNormalizedBarcode(String code) => normalizeBarcode(code) == code;

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
