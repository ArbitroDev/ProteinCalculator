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

  test('accepts whole quantities of food, up to four digits', () {
    expect(isValidFoodGrams(1), isTrue);
    expect(isValidFoodGrams(maxFoodGrams), isTrue);
    expect(isValidFoodGrams(12.5), isFalse);
    expect(isValidFoodGrams(0), isFalse);
    expect(isValidFoodGrams(maxFoodGrams + 1), isFalse);
  });

  test('accepts protein amounts with one decimal at most', () {
    expect(isValidProteinGrams(0.1), isTrue);
    expect(isValidProteinGrams(15.8), isTrue);
    expect(isValidProteinGrams(maxProteinGrams), isTrue);
    expect(isValidProteinGrams(15.75), isFalse);
    expect(isValidProteinGrams(0), isFalse);
    expect(isValidProteinGrams(-1), isFalse);
    expect(isValidProteinGrams(10000), isFalse);
  });

  test('accepts daily goals between the bounds', () {
    expect(isValidDailyGoal(minDailyGoal), isTrue);
    expect(isValidDailyGoal(maxDailyGoal), isTrue);
    expect(isValidDailyGoal(0), isFalse);
    expect(isValidDailyGoal(maxDailyGoal + 1), isFalse);
  });
}
