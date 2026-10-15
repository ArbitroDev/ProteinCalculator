import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:protein_calculator/core/startup.dart';

Future<void> main() async {
  // Registered before the binding adds the packages licenses, so the license
  // of the app comes first and stays at the top of the licenses page.
  LicenseRegistry.addLicense(_bundledLicenses);
  WidgetsFlutterBinding.ensureInitialized();
  await startApp();
}

/// License of the app, then those of the fonts, icons and native code
/// bundled as files, shown in the licenses page next to those of the
/// packages: the barcode reader of flutter_zxing is built from zxing-cpp and
/// libzint, whose licenses its package does not carry.
Stream<LicenseEntry> _bundledLicenses() async* {
  const licenses = {
    'Protein Calculator': 'LICENSE.md',
    'Outfit': 'assets/fonts/OFL-Outfit.txt',
    'Saira Semi Condensed': 'assets/fonts/OFL-SairaSemiCondensed.txt',
    'Octicons (GitHub mark)': 'assets/licenses/LICENSE-Octicons.txt',
    'zxing-cpp': 'assets/licenses/LICENSE-zxing-cpp.txt',
    'libzint': 'assets/licenses/LICENSE-zint.txt',
  };
  for (final MapEntry(key: name, value: path) in licenses.entries) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(path));
  }
}
