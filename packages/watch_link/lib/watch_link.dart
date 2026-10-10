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
/// (`goal`) and the products (`products`: `id`, `name`, `protein` of one
/// portion, `favorite`), the favorite first.
Future<void> sendWatchState(Map<String, Object?> state) =>
    _channel.invokeMethod<void>('sendState', state);

/// Answers the requests of the watch with [readState], which returns a state
/// as [sendWatchState] takes it.
///
/// Only called in the engine the plugin starts to answer the watch: it waits
/// for this call before asking anything.
Future<void> answerWatchRequests(
  Future<Map<String, Object?>> Function() readState,
) async {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'readState') return readState();
    throw MissingPluginException('Unknown method ${call.method}');
  });
  await _channel.invokeMethod<void>('ready');
}
