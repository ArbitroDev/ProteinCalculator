import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Address of the Sentry project, given at build time with
/// `--dart-define=SENTRY_DSN=...` so it stays out of the source code.
const _dsn = String.fromEnvironment('SENTRY_DSN');

/// Whether this build can send crash reports: without an address, the
/// option is not offered at all.
const crashReportingAvailable = _dsn != '';

/// Starts or stops sending crash reports, following the user's choice.
///
/// Reports hold the error, its stack trace, the app version and the phone
/// model and system: no personal data, no screenshot, no entry or product.
Future<void> setCrashReporting(bool enabled) async {
  if (!crashReportingAvailable || enabled == Sentry.isEnabled) return;
  if (!enabled) return Sentry.close();
  await SentryFlutter.init((options) {
    options
      ..dsn = _dsn
      ..environment = kReleaseMode ? 'production' : 'debug'
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..enableAutoSessionTracking = false
      ..enableAutoPerformanceTracing = false
      ..tracesSampleRate = null;
  });
}
