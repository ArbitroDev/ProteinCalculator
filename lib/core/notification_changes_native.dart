import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

/// Name under which the app listens to the changes made from the buttons
/// of the notifications.
const _portName = 'protein_calculator.notification_changes';

/// Listens to the changes made from the buttons of the notifications while
/// the app runs, calling [onChange] after each. Returns a function to stop
/// listening.
VoidCallback listenToNotificationChanges(VoidCallback onChange) {
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

/// Tells the app, if it runs, that a button of a notification changed the
/// data.
void notifyNotificationChange() =>
    IsolateNameServer.lookupPortByName(_portName)?.send(null);
