import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';
import 'package:protein_calculator/core/crash_reporting.dart';
import 'package:protein_calculator/core/database/app_database.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';

Future<void> main() async {
  // Registered before the binding adds the packages licenses, so the license
  // of the app comes first and stays at the top of the licenses page.
  LicenseRegistry.addLicense(_bundledLicenses);
  WidgetsFlutterBinding.ensureInitialized();

  // Reading the goal before the first frame avoids flashing the today
  // screen before the first launch screen.
  final database = AppDatabase.open();
  final goal = await database.settingsDao.getDailyGoal();

  // Until the first launch screen is done, the user has not seen the
  // choice: nothing is sent.
  if (goal != null) {
    await setCrashReporting(await database.settingsDao.getCrashReports());
  }

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
