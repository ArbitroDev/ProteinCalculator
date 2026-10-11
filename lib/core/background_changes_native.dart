import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

/// Name under which the app listens to the changes made apart from it.
const _portName = 'protein_calculator.background_changes';

/// Listens to the changes made apart from the app, by the buttons of the
/// notifications or the requests of the watch, while the app runs, calling
/// [onChange] after each. Returns a function to stop listening.
VoidCallback listenToBackgroundChanges(VoidCallback onChange) {
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(_portName);
  IsolateNameServer.registerPortWithName(port.sendPort, _portName);
  final subscription = port.listen((_) => onChange());
  return () {
    unawaited(subscription.cancel());
    port.close();
    IsolateNameServer.removePortNameMapping(_portName);
  };
}

/// Tells the app, if it runs, that code run apart from it changed the data.
void notifyBackgroundChange() =>
    IsolateNameServer.lookupPortByName(_portName)?.send(null);
