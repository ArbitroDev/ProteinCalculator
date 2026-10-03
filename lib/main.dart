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

/// License of the app, then those of the fonts and icons bundled as files,
/// shown in the licenses page next to those of the packages.
Stream<LicenseEntry> _bundledLicenses() async* {
  const licenses = {
    'Protein Calculator': 'LICENSE.md',
    'Outfit': 'assets/fonts/OFL-Outfit.txt',
    'Saira Semi Condensed': 'assets/fonts/OFL-SairaSemiCondensed.txt',
    'Octicons (GitHub mark)': 'assets/licenses/LICENSE-Octicons.txt',
  };
  for (final MapEntry(key: name, value: path) in licenses.entries) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(path));
  }
}
