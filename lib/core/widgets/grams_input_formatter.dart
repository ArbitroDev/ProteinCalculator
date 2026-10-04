import 'package:flutter/services.dart';

/// Lets only a number of grams be typed: up to [maxDigits] digits, then, if
/// [maxDecimals] is not zero, a decimal comma or point followed by up to
/// [maxDecimals] digits. Any other character is ignored, whatever the
/// keyboard.
class GramsInputFormatter extends TextInputFormatter {
  GramsInputFormatter({int maxDigits = 4, int maxDecimals = 0})
    : _pattern = RegExp(
        maxDecimals == 0
            ? '^\\d{0,$maxDigits}\$'
            : '^\\d{0,$maxDigits}([.,]\\d{0,$maxDecimals})?\$',
      );

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}
