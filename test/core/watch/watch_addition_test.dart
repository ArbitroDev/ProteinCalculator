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
      String name = 'Skyr',
      double protein = 25,
    }) => WatchAddition(
      id: id,
      productId: 3,
      name: name,
      protein: protein,
      addedAt: DateTime(2026, 10, 1),
    );

    test('accepts the values of the form', () {
      expect(addition().isValid, isTrue);
      expect(addition(name: ' Skyr ').isValid, isTrue);
      expect(addition(protein: 0.1).isValid, isTrue);
      expect(addition(name: 'a' * 40).isValid, isTrue);
    });

    test('refuses the others', () {
      expect(addition(id: '').isValid, isFalse);
      expect(addition(name: '').isValid, isFalse);
      expect(addition(name: 'a' * 41).isValid, isFalse);
      expect(addition(protein: 0).isValid, isFalse);
      expect(addition(protein: -1).isValid, isFalse);
      expect(addition(protein: double.infinity).isValid, isFalse);
      expect(addition(protein: 10000).isValid, isFalse);
    });
  });
}
