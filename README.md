# Protein Calculator

A Flutter application to calculate protein intake.

> 🚧 Early development - not yet available on Google Play.

## Platforms

- **Android**: target platform, to be published on Google Play.
- **Web**: used for development and debugging only.

## Getting started

```bash
flutter pub get
dart run build_runner build   # generates the database code
flutter run -d chrome         # web (debug)
flutter run                   # Android device or emulator
```

Crash reporting is off in these builds: see
[Crash reports](CONTRIBUTING.md#crash-reports).

## Privacy

Entries, products and settings stay on the device: the app needs no account
and has no server. The only data that can leave the phone is crash reports,
sent to [Sentry](https://sentry.io) (EU region) only if the user turns them
on, on the first launch screen or in *Data and privacy*. A report holds the
error, the app version, the phone model and its Android version, never the
user's entries, products or goal.

The user can export all their data to a backup file and import it again, on
the same phone or another one, from *Data and privacy*. If the data ever
cannot be opened at launch, the app offers to try again or to start over
from a backup: the unreadable data is set aside on the phone, never erased.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

**Source-available, not open source.** Copyright (c) 2026 ArbitroDev.
All rights reserved.

The source code is public so that you can read it and contribute to it.
Copying, redistribution and republication are not allowed. See
[LICENSE](LICENSE.md) for details.
