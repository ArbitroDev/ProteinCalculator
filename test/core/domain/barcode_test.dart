import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/domain/barcode.dart';

void main() {
  group('isValidBarcode', () {
    test('accepts EAN-13, EAN-8 and UPC-A codes with a right check digit', () {
      expect(isValidBarcode('3017620422003'), isTrue);
      expect(isValidBarcode('5449000000996'), isTrue);
      expect(isValidBarcode('96385074'), isTrue);
      expect(isValidBarcode('049000028911'), isTrue);
    });

    test('refuses a wrong check digit', () {
      expect(isValidBarcode('3017620422004'), isFalse);
      expect(isValidBarcode('96385075'), isFalse);
    });

    test('refuses other lengths, letters and spaces', () {
      expect(isValidBarcode(''), isFalse);
      expect(isValidBarcode('1234567'), isFalse);
      expect(isValidBarcode('01234565123'), isFalse);
      expect(isValidBarcode('30176204220030'), isFalse);
      expect(isValidBarcode('301762042200A'), isFalse);
      expect(isValidBarcode(' 3017620422003'), isFalse);
    });
  });

  group('normalizeBarcode', () {
    test('turns a UPC-A into the EAN-13 it is part of', () {
      expect(normalizeBarcode('049000028911'), '0049000028911');
    });

    test('keeps EAN-13 and EAN-8 codes, without spaces around', () {
      expect(normalizeBarcode('3017620422003'), '3017620422003');
      expect(normalizeBarcode(' 96385074 '), '96385074');
    });

    test('is null for an invalid code', () {
      expect(normalizeBarcode('3017620422004'), isNull);
      expect(normalizeBarcode('12345'), isNull);
    });

    test('tells codes in their stored form', () {
      expect(isNormalizedBarcode('0049000028911'), isTrue);
      expect(isNormalizedBarcode('049000028911'), isFalse);
      expect(isNormalizedBarcode('3017620422004'), isFalse);
    });
  });

  group('expandUpcE', () {
    test('puts back the zeros the last digit tells', () {
      // Last digit 0 to 2: three digits of manufacturer, then the product.
      expect(expandUpcE('04252614'), '042100005264');
      // 3: three digits of manufacturer, two of product.
      expect(expandUpcE('01234531'), '012300000451');
      // 4: four digits of manufacturer, one of product.
      expect(expandUpcE('01234642'), '012340000062');
      // 5 to 9: five digits of manufacturer, the last digit of product.
      expect(expandUpcE('01234574'), '012345000074');
    });

    test('gives a UPC-A whose check digit is the one of the UPC-E', () {
      expect(isValidBarcode(expandUpcE('04252614')!), isTrue);
    });

    test('is null for anything but 8 digits', () {
      expect(expandUpcE('0425261'), isNull);
      expect(expandUpcE('042526145'), isNull);
      expect(expandUpcE('0425261A'), isNull);
    });
  });
}
