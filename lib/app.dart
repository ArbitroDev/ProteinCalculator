import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/daily_routines.dart';
import 'package:protein_calculator/core/hevy/shared_file.dart';
import 'package:protein_calculator/core/providers.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/core/watch/watch_sync.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

/// Messenger of the app, to tell the user about what happens outside any
/// screen, such as a file shared to the app: the message shows over whichever
/// screen is open.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ProteinCalculatorApp extends ConsumerWidget {
  const ProteinCalculatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(backgroundChangesProvider)
      ..watch(dailyRoutinesProvider)
      ..watch(sharedFileProvider)
      ..watch(watchSyncProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: appMessengerKey,
      // In landscape, the Android navigation bar and the camera cutout sit
      // on the sides: every screen keeps clear of them.
      builder: (context, child) => ColoredBox(
        color: AppColors.of(context).background,
        child: SafeArea(top: false, bottom: false, child: child!),
      ),
    );
  }
}

/// Picks the first device language the app supports, English otherwise.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return const Locale('en');
}
