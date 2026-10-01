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
  LicenseRegistry.addLicense(_fontLicenses);

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

Stream<LicenseEntry> _fontLicenses() async* {
  const fonts = {
    'Outfit': 'assets/fonts/OFL-Outfit.txt',
    'Saira Semi Condensed': 'assets/fonts/OFL-SairaSemiCondensed.txt',
  };
  for (final MapEntry(key: font, value: path) in fonts.entries) {
    yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString(path));
  }
}
