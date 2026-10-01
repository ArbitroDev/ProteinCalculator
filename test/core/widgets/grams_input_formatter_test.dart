import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/widgets/grams_input_formatter.dart';

void main() {
  final formatter = GramsInputFormatter();

  String type(String before, String after) => formatter
      .formatEditUpdate(
        TextEditingValue(text: before),
        TextEditingValue(text: after),
      )
      .text;

  test('accepts digits up to four', () {
    expect(type('', '1'), '1');
    expect(type('14', '140'), '140');
    expect(type('999', '9999'), '9999');
  });

  test('ignores anything else', () {
    expect(type('12', '12,'), '12');
    expect(type('12', '12.'), '12');
    expect(type('12', '12a'), '12');
    expect(type('', '-'), '');
    expect(type('9999', '99999'), '9999');
  });

  test('lets the field be emptied', () {
    expect(type('1', ''), '');
  });
}
