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

  test('accepts trimmed names of up to 40 characters', () {
    expect(isValidName('Skyr'), isTrue);
    expect(isValidName('S' * 40), isTrue);
    expect(isValidName('${'S' * 39}👍🏽'), isTrue);
    expect(isValidName(''), isFalse);
    expect(isValidName(' '), isFalse);
    expect(isValidName('Skyr '), isFalse);
    expect(isValidName('S' * 41), isFalse);
  });

  group('scannedProductName', () {
    test('adds the first brand to the name', () {
      expect(
        scannedProductName('Skyr nature', "Siggi's, Arla"),
        "Skyr nature (Siggi's)",
      );
    });

    test('leaves out a brand the name already says', () {
      expect(scannedProductName('Nutella', 'Nutella'), 'Nutella');
      expect(
        scannedProductName('Coca-Cola Zero', 'coca-cola'),
        'Coca-Cola Zero',
      );
    });

    test('leaves out the brand when the name would be too long', () {
      final name = 'S' * 35;
      expect(scannedProductName(name, 'Brand'), name);
      expect(isValidName(scannedProductName('S' * 30, 'Brand')!), isTrue);
    });

    test('cuts a name too long and collapses its spaces', () {
      expect(scannedProductName('S' * 50, null), 'S' * 40);
      expect(scannedProductName('  Skyr   nature ', ' '), 'Skyr nature');
    });

    test('is null without a name', () {
      expect(scannedProductName(null, 'Brand'), isNull);
      expect(scannedProductName('  ', 'Brand'), isNull);
    });
  });
}
