/// Link of Protein Calculator with its Wear OS watch app, Android only.
///
/// The Kotlin code of this plugin writes the messages of the watch, see
/// `android/wear/protocol/PROTOCOL.md` in the app, and sends them only to
/// nearby watches. It is registered in every Flutter engine of the app.
library;

import 'package:flutter/services.dart';

const _channel = MethodChannel('protein_calculator/watch');

/// Sends the state of the day to the nearby watches having the app.
///
/// [state] holds the day (`day`, as `yyyymmdd`), the hour app days start
/// (`dayStartHour`), the protein total (`total`), the goal of the day or null
/// (`goal`), the entries of the day, the most recent first (`entries`:
/// `name` or null, `protein`, `time` in milliseconds since the epoch,
/// `fromWatch`), the products (`products`: `id`, `name`, `protein` of one
/// portion, `favorite`), the favorite first, and the ids of the additions of
/// the watch made lately (`handled`).
Future<void> sendWatchState(Map<String, Object?> state) =>
    _channel.invokeMethod<void>('sendState', state);

/// Answers the requests of the watch: [readState] returns a state as
/// [sendWatchState] takes it; [addPortions] makes the additions of the watch,
/// maps of `id`, `productId`, `name`, `protein` and `addedAt` (milliseconds
/// since the epoch), and returns their `results` (`id` and `status`:
/// `added`, `duplicate` or `invalid`) and the new `state`.
///
/// Only called in the engine the plugin starts to answer the watch: it waits
/// for this call before asking anything.
Future<void> answerWatchRequests({
  required Future<Map<String, Object?>> Function() readState,
  required Future<Map<String, Object?>> Function(List<Object?> additions)
  addPortions,
}) async {
  _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'readState':
        return readState();
      case 'addPortions':
        return addPortions(call.arguments as List<Object?>);
    }
    throw MissingPluginException('Unknown method ${call.method}');
  });
  await _channel.invokeMethod<void>('ready');
}
