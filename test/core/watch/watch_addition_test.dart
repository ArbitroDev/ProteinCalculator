import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/watch/watch_addition.dart';

void main() {
  final values = <String, Object?>{
    'id': 'a1',
    'productId': 3,
    'name': 'Skyr',
    'protein': 25.0,
    'addedAt': DateTime(2026, 10, 1, 8, 30).millisecondsSinceEpoch,
  };

  group('fromChannel', () {
    test('reads an addition sent by the plugin', () {
      final addition = WatchAddition.fromChannel(values)!;

      expect(addition.id, 'a1');
      expect(addition.productId, 3);
      expect(addition.name, 'Skyr');
      expect(addition.protein, 25);
      expect(addition.addedAt, DateTime(2026, 10, 1, 8, 30));
    });

    test('reads a free entry, without product and maybe without name', () {
      final addition = WatchAddition.fromChannel({
        ...values,
        'productId': null,
        'name': null,
      })!;

      expect(addition.productId, isNull);
      expect(addition.name, isNull);
      expect(addition.isValid, isTrue);
    });

    test('refuses a missing value or a value of another type', () {
      for (final key in values.keys) {
        expect(WatchAddition.fromChannel({...values}..remove(key)), isNull);
      }
      expect(WatchAddition.fromChannel({...values, 'protein': '25'}), isNull);
      expect(WatchAddition.fromChannel('a1'), isNull);
    });
  });

  group('isValid', () {
    WatchAddition addition({
      String id = 'a1',
      int? productId = 3,
      String? name = 'Skyr',
      double protein = 25,
    }) => WatchAddition(
      id: id,
      productId: productId,
      name: name,
      protein: protein,
      addedAt: DateTime(2026, 10, 1),
    );

    test('accepts the values of the form', () {
      expect(addition().isValid, isTrue);
      expect(addition(name: ' Skyr ').isValid, isTrue);
      expect(addition(protein: 0.1).isValid, isTrue);
      expect(addition(name: 'a' * 40).isValid, isTrue);
      expect(addition(productId: null).isValid, isTrue);
      expect(addition(productId: null, name: null).isValid, isTrue);
    });

    test('refuses the others', () {
      expect(addition(id: '').isValid, isFalse);
      expect(addition(name: '').isValid, isFalse);
      expect(addition(name: 'a' * 41).isValid, isFalse);
      // A product always has its name, to be found again.
      expect(addition(name: null).isValid, isFalse);
      expect(addition(protein: 0).isValid, isFalse);
      expect(addition(protein: -1).isValid, isFalse);
      expect(addition(protein: double.infinity).isValid, isFalse);
      expect(addition(protein: 10000).isValid, isFalse);
    });
  });
}
