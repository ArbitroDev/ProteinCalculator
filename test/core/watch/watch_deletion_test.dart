import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/watch/watch_deletion.dart';

void main() {
  final values = <String, Object?>{
    'id': 'd1',
    'entryId': 8,
    'time': DateTime(2026, 10, 1, 8, 30).millisecondsSinceEpoch,
  };

  test('reads a deletion sent by the plugin', () {
    final deletion = WatchDeletion.fromChannel(values)!;

    expect(deletion.id, 'd1');
    expect(deletion.entryId, 8);
    expect(deletion.time, DateTime(2026, 10, 1, 8, 30));
    expect(deletion.isValid, isTrue);
  });

  test('refuses a missing value or a value of another type', () {
    for (final key in values.keys) {
      expect(WatchDeletion.fromChannel({...values}..remove(key)), isNull);
    }
    expect(WatchDeletion.fromChannel({...values, 'entryId': '8'}), isNull);
    expect(WatchDeletion.fromChannel('d1'), isNull);
  });

  test('is invalid without id', () {
    expect(WatchDeletion.fromChannel({...values, 'id': ''})!.isValid, isFalse);
  });
}
