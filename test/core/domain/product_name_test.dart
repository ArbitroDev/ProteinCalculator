import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/product_name.dart';

void main() {
  group('productNameKey', () {
    test('ignores case and surrounding spaces', () {
      expect(productNameKey('Skyr'), productNameKey('  skyr '));
    });

    test('collapses inner spaces', () {
      expect(productNameKey('Skyr   nature'), 'skyr nature');
    });

    test('ignores accents', () {
      expect(productNameKey('Pâte'), productNameKey('pate'));
      expect(productNameKey('Épinards'), 'epinards');
      expect(productNameKey('Œufs'), 'oeufs');
    });

    test('sorts accented names with their base letter', () {
      final names = ['Poulet', 'Œufs', 'Épinards', 'amandes', 'Skyr'];

      names.sort((a, b) => productNameKey(a).compareTo(productNameKey(b)));

      expect(names, ['amandes', 'Épinards', 'Œufs', 'Poulet', 'Skyr']);
    });
  });
}
