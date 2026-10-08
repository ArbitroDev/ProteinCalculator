import 'package:flutter/foundation.dart';

/// Does nothing: the web has no notifications.
VoidCallback listenToNotificationChanges(VoidCallback onChange) => () {};

/// Does nothing: the web has no notifications.
void notifyNotificationChange() {}
