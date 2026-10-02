import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/core/router.dart';
import 'package:protein_calculator/core/theme.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

class ProteinCalculatorApp extends ConsumerWidget {
  const ProteinCalculatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
      routerConfig: ref.watch(routerProvider),
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
