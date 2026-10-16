import 'package:flutter/foundation.dart';
import 'package:protein_calculator/core/domain/barcode.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Address of the Sentry project, given at build time with
/// `--dart-define=SENTRY_DSN=...` so it stays out of the source code.
const _dsn = String.fromEnvironment('SENTRY_DSN');

/// Whether this build can send crash reports: without an address, the
/// option is not offered at all.
const crashReportingAvailable = _dsn != '';

/// Numbers as long as barcodes in a text: an error about a product scanned
/// may name its barcode, which tells what the user scanned.
final _barcodeLike = RegExp(r'\b\d{8}(?:\d{4,5})?\b');

/// [text] with its barcodes hidden: only the numbers whose check digit is
/// right, so that most other numbers, such as days (20261015), stay.
String _withoutBarcodes(String text) => text.replaceAllMapped(
  _barcodeLike,
  (match) => normalizeTypedBarcode(match[0]!) == null ? match[0]! : '[barcode]',
);

/// [values] with the barcodes of their texts hidden.
Map<String, dynamic> _mapWithoutBarcodes(Map<String, dynamic> values) => {
  for (final MapEntry(:key, :value) in values.entries)
    key: value is String ? _withoutBarcodes(value) : value,
};

/// [event] without the barcodes its message, its exceptions and the
/// details of its Flutter error may hold.
@visibleForTesting
SentryEvent hideBarcodes(SentryEvent event, Hint hint) {
  if (event.message case final message?) {
    message.formatted = _withoutBarcodes(message.formatted);
    if (message.template case final template?) {
      message.template = _withoutBarcodes(template);
    }
    if (message.params case final params?) {
      message.params = [
        for (final param in params)
          param is String ? _withoutBarcodes(param) : param,
      ];
    }
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.value case final value?) {
      exception.value = _withoutBarcodes(value);
    }
  }
  // The device and the system are objects; the details of a Flutter error
  // ("flutter_error_details") are a map of texts.
  for (final MapEntry(:key, :value) in event.contexts.entries.toList()) {
    if (value is Map<String, dynamic>) {
      event.contexts[key] = _mapWithoutBarcodes(value);
    }
  }
  return event;
}

/// [breadcrumb] without the barcodes its message and data may hold.
@visibleForTesting
Breadcrumb? hideBarcodesInBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  if (breadcrumb.message case final message?) {
    breadcrumb.message = _withoutBarcodes(message);
  }
  if (breadcrumb.data case final data?) {
    breadcrumb.data = _mapWithoutBarcodes(data);
  }
  return breadcrumb;
}

/// Starts or stops sending crash reports, following the user's choice.
///
/// Reports hold the error, its stack trace, the app version and the phone
/// model and system: no personal data, no screenshot, no entry or product,
/// and no barcode, see [hideBarcodes].
///
/// Never throws: if Sentry fails to start or stop, the error is only
/// reported locally and the app goes on.
Future<void> setCrashReporting(bool enabled) async {
  if (!crashReportingAvailable || enabled == Sentry.isEnabled) return;
  try {
    if (!enabled) {
      await Sentry.close();
      return;
    }
    await SentryFlutter.init((options) {
      options
        ..dsn = _dsn
        ..environment = kReleaseMode ? 'production' : 'debug'
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..enableAutoSessionTracking = false
        ..enableAutoPerformanceTracing = false
        ..tracesSampleRate = null
        ..beforeSend = hideBarcodes
        ..beforeBreadcrumb = hideBarcodesInBreadcrumb;
    });
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'crash reporting',
      ),
    );
  }
}
