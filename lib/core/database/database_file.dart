/// Where the database file lives, and how to set it aside when it cannot be
/// opened. Not available on the web, where the database lives in the
/// browser storage.
library;

export 'database_file_web.dart'
    if (dart.library.io) 'database_file_native.dart';
