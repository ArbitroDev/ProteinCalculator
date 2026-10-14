import 'package:flutter_test/flutter_test.dart';
import 'package:protein_calculator/core/crash_reporting.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('crash reports leave barcodes out', () {
    test('of the error and the message', () {
      final event = SentryEvent(
        message: SentryMessage(
          'Lookup of 3017620422003 failed',
          template: 'Lookup of 3017620422003 failed',
        ),
        exceptions: [
          SentryException(
            type: 'DuplicateBarcodeException',
            value: 'DuplicateBarcodeException: 96385074',
          ),
        ],
      );

      final cleaned = hideBarcodes(event, Hint());

      expect(cleaned.message!.formatted, 'Lookup of [barcode] failed');
      expect(cleaned.message!.template, 'Lookup of [barcode] failed');
      expect(
        cleaned.exceptions!.single.value,
        'DuplicateBarcodeException: [barcode]',
      );
    });

    test('of the events before the error', () {
      final breadcrumb = Breadcrumb(
        message: 'GET /api/v3/product/0049000028911',
        data: {'url': 'https://example.org/0049000028911', 'status': 200},
      );

      final cleaned = hideBarcodesInBreadcrumb(breadcrumb, Hint())!;

      expect(cleaned.message, 'GET /api/v3/product/[barcode]');
      expect(cleaned.data, {
        'url': 'https://example.org/[barcode]',
        'status': 200,
      });
    });

    test('but keep shorter and longer numbers', () {
      final breadcrumb = Breadcrumb(
        message: 'Entry 1234567 at 123456789012345',
      );

      final cleaned = hideBarcodesInBreadcrumb(breadcrumb, Hint())!;

      expect(cleaned.message, 'Entry 1234567 at 123456789012345');
    });
  });
}
