import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:protein_calculator/core/formatting.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  test('formatGrams rounds to the unit', () {
    expect(formatGrams(85.6, 'en'), '86');
    expect(formatGrams(1234.4, 'en'), '1,234');
  });

  test('formatLongDate starts with a capital letter', () {
    final date = DateTime(2026, 10, 1);

    expect(formatLongDate(date, 'fr'), 'Jeudi 1 octobre');
    expect(formatLongDate(date, 'en'), 'Thursday, October 1');
  });
}
