# Protein Calculator

A Flutter application to calculate protein intake.

> 🚧 Early development - not yet available on Google Play.

## Platforms

- **Android**: target platform, to be published on Google Play.
- **Wear OS**: companion app for the watch, written in Kotlin (Compose for
  Wear OS): the day and its entries, a tile, a complication, quick
  additions of saved products or of protein grams, and deletions of
  entries. The phone stays the only source of truth.
- **Web**: used for development and debugging only.

## Getting started

```bash
flutter pub get
dart run build_runner build   # generates the database code
flutter run -d chrome         # web (debug)
flutter run                   # Android device or emulator
```

Crash reporting is off in these builds: see
[Crash reports](CONTRIBUTING.md#crash-reports). The watch app is built with
Gradle: see [Wear OS watch app](CONTRIBUTING.md#wear-os-watch-app).

## Privacy

Entries, products and settings stay on the device: the app needs no account
and has no server. Only two things can leave the phone:

- crash reports, sent to [Sentry](https://sentry.io) (EU region) only if the
  user turns them on, on the first launch screen or in *Data and privacy*. A
  report holds the error, the app version, the phone model and its Android
  version, never the user's entries, products, goal or barcodes;
- the barcode of a product scanned, sent to
  [Open Food Facts](https://world.openfoodfacts.org) to look it up when the
  phone does not know it yet. The camera picture is read on the phone by
  [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp), with no Google service,
  and never leaves it.

Product data come from Open Food Facts, under the
[Open Database License](https://opendatacommons.org/licenses/odbl/1-0/).

With a Wear OS watch, the phone and the watch exchange the day, its entries
and the saved products directly, over Bluetooth or the same Wi-Fi network,
never through a server. The watch app has no Internet access.

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
