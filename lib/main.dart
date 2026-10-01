import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_bundledLicenses);

  // Reading the goal before the first frame avoids flashing the today
  // screen before the first launch screen.
  final database = AppDatabase.open();
  final goal = await database.settingsDao.getDailyGoal();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialLocationProvider.overrideWithValue(
          goal == null ? AppRoutes.onboarding : AppRoutes.today,
        ),
      ],
      child: const ProteinCalculatorApp(),
    ),
  );
}

/// Licenses of the fonts and icons bundled as files, shown in the licenses
/// page next to those of the packages.
Stream<LicenseEntry> _bundledLicenses() async* {
  const licenses = {
    'Outfit': 'assets/fonts/OFL-Outfit.txt',
    'Saira Semi Condensed': 'assets/fonts/OFL-SairaSemiCondensed.txt',
    'Octicons (GitHub mark)': 'assets/licenses/LICENSE-Octicons.txt',
  };
  for (final MapEntry(key: name, value: path) in licenses.entries) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(path));
  }
}
