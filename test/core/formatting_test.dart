import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:protein_calculator/core/formatting.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  test('formatGrams truncates to the unit', () {
    expect(formatGrams(85.6, 'en'), '85');
    expect(formatGrams(59.999999999999, 'en'), '60');
    expect(formatGrams(1234.4, 'en'), '1,234');
  });

  test('formatProtein shows one decimal at most', () {
    expect(formatProtein(12.5, 'fr'), '12,5');
    expect(formatProtein(15.8, 'en'), '15.8');
    expect(formatProtein(23, 'en'), '23');
    expect(formatProtein(1234.5, 'en'), '1,234.5');
  });

  test('formatLongDate starts with a capital letter', () {
    final date = DateTime(2026, 10, 1);

    expect(formatLongDate(date, 'fr'), 'Jeudi 1 octobre');
    expect(formatLongDate(date, 'en'), 'Thursday, October 1');
  });
}
