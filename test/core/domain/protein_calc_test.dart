import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/protein_calc.dart';

void main() {
  test('computes protein from the quantity consumed', () {
    expect(
      computeProtein(
        consumedGrams: 150,
        proteinPerReference: 10,
        referenceGrams: 100,
      ),
      15,
    );
  });

  test('supports any reference quantity', () {
    expect(
      computeProtein(
        consumedGrams: 60,
        proteinPerReference: 24,
        referenceGrams: 30,
      ),
      48,
    );
  });

  test('rounds to one decimal', () {
    expect(
      computeProtein(
        consumedGrams: 125,
        proteinPerReference: 12.5,
        referenceGrams: 100,
      ),
      15.6,
    );
    expect(
      computeProtein(
        consumedGrams: 150,
        proteinPerReference: 10.5,
        referenceGrams: 100,
      ),
      15.8,
    );
  });
}
