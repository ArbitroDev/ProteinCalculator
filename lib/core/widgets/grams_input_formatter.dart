import 'package:flutter/services.dart';

/// Lets only a whole number of grams be typed, up to [maxDigits] digits.
/// Any other character is ignored, whatever the keyboard.
class GramsInputFormatter extends TextInputFormatter {
  GramsInputFormatter({int maxDigits = 4})
    : _pattern = RegExp('^\\d{0,$maxDigits}\$');

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}
