import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/features/scan/scan_page.dart';
import 'package:protein_calculator/l10n/app_localizations.dart';

void main() {
  /// The barcode the scan page gave back, once closed.
  String? result;
  late bool closed;

  setUp(() {
    result = null;
    closed = false;
  });

  /// Opens the scan page over a blank page.
  Future<void> openScan(WidgetTester tester) async {
    // A blinking cursor would keep pumpAndSettle waiting forever.
    EditableText.debugDeterministicCursor = true;
    addTearDown(() => EditableText.debugDeterministicCursor = false);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/scan', builder: (context, state) => const ScanPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    unawaited(
      router.push<String>('/scan').then((barcode) {
        result = barcode;
        closed = true;
      }),
    );
    await tester.pumpAndSettle();
  }

  /// The camera reading [text], as a barcode of [format].
  Future<void> read(WidgetTester tester, String text, int format) async {
    tester.widget<ReaderWidget>(find.byType(ReaderWidget)).onScan!(
      Code(text: text, format: format, isValid: true),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('closes on the first code read, a UPC-E as the EAN-13 of its '
      'UPC-A', (tester) async {
    await openScan(tester);

    await read(tester, '04252614', Format.upce);

    expect(closed, isTrue);
    expect(result, '0042100005264');
  });

  testWidgets('ignores the camera while the code is typed', (tester) async {
    await openScan(tester);
    await tester.tap(find.text('Type the code'));
    await tester.pumpAndSettle();

    await read(tester, '3017620422003', Format.ean13);

    expect(closed, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), '04252614');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, '0042100005264');
  });

  testWidgets('reads the camera again once the typing is cancelled', (
    tester,
  ) async {
    await openScan(tester);
    await tester.tap(find.text('Type the code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await read(tester, '3017620422003', Format.ean13);

    expect(result, '3017620422003');
  });

  testWidgets('refuses a code typed with a wrong check digit', (tester) async {
    await openScan(tester);
    await tester.tap(find.text('Type the code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '04252615');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.text("This code isn't valid: check the digits."), findsOne);
  });
}
