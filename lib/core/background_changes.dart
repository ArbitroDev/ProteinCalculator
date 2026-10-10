/// Messages from the code run apart from the app (the buttons of the
/// notifications, the requests of the watch) to the app. Not available on
/// the web, which has neither.
library;

export 'background_changes_web.dart'
    if (dart.library.io) 'background_changes_native.dart';
