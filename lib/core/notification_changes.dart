/// Messages from the buttons of the notifications, run apart from the app,
/// to the app. Not available on the web, which has no notifications.
library;

export 'notification_changes_web.dart'
    if (dart.library.io) 'notification_changes_native.dart';
