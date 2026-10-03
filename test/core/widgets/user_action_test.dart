import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/widgets/user_action.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

void main() {
  late BuildContext context;

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (pageContext) {
            context = pageContext;
            return const SizedBox();
          },
        ),
      ),
    ),
  );

  Future<T?> run<T>(Future<T> Function() action) => runUserAction(
    ScaffoldMessenger.of(context),
    AppLocalizations.of(context),
    action,
  );

  testWidgets('returns the result of the action', (tester) async {
    await pumpPage(tester);

    expect(await run(() async => 42), 42);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports a failure and tells the user', (tester) async {
    await pumpPage(tester);

    final result = await run<int>(() async => throw StateError('disk full'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Something went wrong, please try again.'), findsOne);
  });
}
