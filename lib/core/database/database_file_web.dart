/// Whether the database file can be set aside: not on the web, used only to
/// develop the app, where the database lives in the browser storage.
const canSetAsideDatabase = false;

Future<String> databasePath() =>
    throw UnsupportedError('No database file on the web.');

Future<void> setAsideDatabase(DateTime now) =>
    throw UnsupportedError('No database file on the web.');
