import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/grams.dart';

void main() {
  test('parses integers and decimals with a comma or a point', () {
    expect(parseGrams('140'), 140);
    expect(parseGrams('12,5'), 12.5);
    expect(parseGrams('12.5'), 12.5);
    expect(parseGrams(' 1 000 '), 1000);
  });

  test('rejects empty or invalid input', () {
    expect(parseGrams(''), isNull);
    expect(parseGrams('  '), isNull);
    expect(parseGrams('abc'), isNull);
    expect(parseGrams('1,2,3'), isNull);
    expect(parseGrams('Infinity'), isNull);
  });

  test('accepts quantities above zero, up to four digits', () {
    expect(isValidQuantity(0.1), isTrue);
    expect(isValidQuantity(maxGrams), isTrue);
    expect(isValidQuantity(0), isFalse);
    expect(isValidQuantity(-1), isFalse);
    expect(isValidQuantity(maxGrams + 1), isFalse);
  });

  test('accepts daily goals between the bounds', () {
    expect(isValidDailyGoal(minDailyGoal), isTrue);
    expect(isValidDailyGoal(maxDailyGoal), isTrue);
    expect(isValidDailyGoal(0), isFalse);
    expect(isValidDailyGoal(maxDailyGoal + 1), isFalse);
  });
}
