import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/app.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ProteinCalculatorApp()));
  await tester.pumpAndSettle();
}

Finder pageTitle(String text) => find.widgetWithText(AppBar, text);

void main() {
  group('navigation', () {
    testWidgets('starts on the today tab', (tester) async {
      await pumpApp(tester);

      expect(pageTitle('Today'), findsOneWidget);
    });

    testWidgets('switches between the four tabs', (tester) async {
      await pumpApp(tester);

      for (final tab in ['History', 'Products', 'Menu', 'Today']) {
        await tester.tap(find.widgetWithText(NavigationDestination, tab));
        await tester.pumpAndSettle();

        expect(pageTitle(tab), findsOneWidget);
      }
    });
  });

  group('localization', () {
    testWidgets('uses French when the device is in French', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpApp(tester);

      expect(pageTitle("Aujourd'hui"), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
    });

    test('picks the first supported device language', () {
      const supported = [Locale('en'), Locale('fr')];

      expect(
        resolveLocale(const [Locale('de'), Locale('fr', 'CA')], supported),
        const Locale('fr'),
      );
    });

    test('falls back to English for unsupported languages', () {
      const supported = [Locale('en'), Locale('fr')];

      expect(
        resolveLocale(const [Locale('de')], supported),
        const Locale('en'),
      );
      expect(resolveLocale(null, supported), const Locale('en'));
    });
  });
}
