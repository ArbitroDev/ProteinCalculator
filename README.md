<div align="center">

# Protein Calculator

**Track your daily protein intake, simply.**

Log the protein you eat each day and see how much is left to reach your goal.
No account, no ads, and your data stays on your phone.

<a href="https://play.google.com/store/apps/details?id=arbitro.android.protein_calculator"><img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="60"></a>

[![Checks](https://github.com/ArbitroDev/ProteinCalculator/actions/workflows/checks.yml/badge.svg?branch=develop)](https://github.com/ArbitroDev/ProteinCalculator/actions/workflows/checks.yml)
[![Release](https://img.shields.io/github/v/release/ArbitroDev/ProteinCalculator)](https://github.com/ArbitroDev/ProteinCalculator/releases)
[![License: source-available](https://img.shields.io/badge/license-source--available-lightgrey)](LICENSE.md)

<img src="store/en/screenshots/1.png" alt="The day, its goal and its entries in a shaker" width="240">
<img src="store/en/screenshots/3.png" alt="The calendar of the history" width="240">
<img src="store/en/screenshots/5.png" alt="Scanning the barcode of a product" width="240">

<img src="store/en/wear/1.png" alt="The day on the watch" width="180">
<img src="store/en/wear/3.png" alt="The products on the watch" width="180">
<img src="store/en/wear/4.png" alt="The tile of the watch" width="180">

</div>

## Table of contents

- [Features](#features)
- [Platforms](#platforms)
- [Privacy](#privacy)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [Contributing](#contributing)
- [License](#license)

## Features

**Your day**
- Set a daily goal in grams and see at a glance what you have eaten and what
  is left.
- Add an entry with its grams of protein, or with the amount eaten and the
  content shown on the package (for example 26 g per 100 g): the app does the
  math, in grams or milliliters.
- Edit or delete any entry, undo a deletion, and add an entry afterwards by
  picking its day and time.
- A day starts at 3 a.m. by default (you can change it): what you eat after
  midnight counts for the day before.
- A home screen widget shows the progress of the day toward the goal.

**Creatine**
- Turn creatine tracking on in the menu and set the grams of one dose.
- Add a dose in one tap from the main screen, or with an entry or a product
  that holds some.
- The days creatine was taken are marked in the history, the calendar, the
  widget and the watch tile.

**Products**
- Save the foods you eat often and add them in one tap, from a list sorted
  alphabetically, by use or by date, or from the suggestions while typing.
- Save an entry as a product when adding or editing it, or long press a
  product to create a new one from its values.
- Set a favorite product to add it straight from the main screen.
- Scan a barcode to fill in a product from
  [Open Food Facts](https://world.openfoodfacts.org), or type the code by
  hand. The app tells you when Open Food Facts updates its values.

**Routines and reminders**
- For a product you take every day, get a daily reminder with an *Add*
  button, or have it added on its own at a set time.
- Optional missed entry reminders, at 11 a.m., 4 p.m. and 10 p.m., when
  nothing is logged in the morning, afternoon or evening.

**History**
- Every day with its total, as a list or as a calendar colored by progress
  toward the goal, by creatine taken, or by Hevy workouts.
- The detail of each day, split into morning, afternoon and evening.

**Statistics**
- A week, a month or a year at a glance: daily protein average against the
  goal, days reaching it and streaks, creatine taken and workouts.
- What they tell together: protein on workout and rest days and after a
  workout, the days of the week, the parts of the day, the rhythm of your
  entries and the products you use most.

**Hevy workouts**
- Import the workouts exported from [Hevy](https://www.hevy.com), by sharing
  the file from Hevy or picking it in the menu, to see your workout days in
  the history, the statistics and on the watch.
- Only the date, the name and the length of each workout are kept, on the
  phone. Hevy is a trademark of Hevy Studios; Protein Calculator is not
  affiliated with it.

**Your data**
- Export all your data to a backup file and import it again, on the same
  phone or another one.
- If the data ever cannot be opened at launch, the app offers to try again or
  to start over from a backup: the unreadable data is set aside, never erased.

The app is available in **English** and **French**.

> Protein Calculator does not give medical advice. To set a goal that suits
> you, ask a health professional.

## Platforms

| Platform | Status |
|---|---|
| **Android** (7.0 and later) | Main platform, published on [Google Play](https://play.google.com/store/apps/details?id=arbitro.android.protein_calculator). |
| **Wear OS** (3 and later) | Companion app for the watch, installed from Google Play along with the phone app: the day and its entries, a tile telling the progress, the creatine doses and the Hevy workouts of the day, a complication, quick additions of saved products or of protein grams, and deletions of entries, even away from the phone. The phone stays the only source of truth. |
| **Web** | Used for development and debugging only. |

## Privacy

Entries, products and settings stay on the device: the app needs no account
and has no server. Only two things can leave the phone:

- **crash reports**, sent to [Sentry](https://sentry.io) (EU region) only if
  you turn them on, on the first launch screen or in *Data and privacy*. A
  report holds the error, the app version, the phone model and its Android
  version, never your entries, products, goal or barcodes;
- **the barcode of a scanned product**, sent to
  [Open Food Facts](https://world.openfoodfacts.org) to look it up when the
  phone does not know it yet, or knows its values from more than 30 days ago.
  The camera picture is read on the phone by
  [zxing-cpp](https://github.com/zxing-cpp/zxing-cpp), with no Google
  service, and never leaves it.

With a Wear OS watch, the phone and the watch exchange the day, its entries
and the saved products directly, over Bluetooth or the same Wi-Fi network,
never through a server. The watch app has no Internet access.

Hevy workouts are read from the file you share or pick, and only their date,
name and length are kept on the phone; the watch only gets how many there are
on the current day.

The full privacy policy is in [PRIVACY.md](PRIVACY.md).

## Tech stack

| Area | Tools |
|---|---|
| Phone app | [Flutter](https://flutter.dev) and Dart, [Riverpod](https://riverpod.dev), [go_router](https://pub.dev/packages/go_router) |
| Storage | SQLite through [Drift](https://drift.simonbinder.eu), with versioned schemas and migrations |
| Barcode scanning | [flutter_zxing](https://pub.dev/packages/flutter_zxing) (zxing-cpp), [Open Food Facts](https://world.openfoodfacts.org) API |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| Crash reports | [Sentry](https://sentry.io), opt-in |
| Watch app | Kotlin, Compose for Wear OS, Tiles, Complications, Wearable Data Layer (`MessageClient`) |
| CI/CD | GitHub Actions: format, analysis, tests, watch app build, and release to Google Play |

## Project structure

| Path | Content |
|---|---|
| `lib/features` | Screens of the phone app: today, products, history, statistics, scan, entry form, menu, onboarding, startup error |
| `lib/core` | Database, domain rules, statistics, Open Food Facts client, Hevy import, link with the watch, shared widgets |
| `lib/l10n` | English and French translations |
| `test` | Tests of the phone app |
| `android/app` | Android project of the phone app |
| `android/wear` | Wear OS watch app (Gradle module `:wear`) |
| `android/wear/protocol` | Messages exchanged between the phone and the watch: see [PROTOCOL.md](android/wear/protocol/PROTOCOL.md) |
| `packages/watch_link` | Local Flutter plugin linking the phone app with the watch |
| `drift_schemas` | Saved database schemas, used to test the migrations |
| `store` | Google Play release notes |

## Getting started

Requirements: Flutter 3.47.5 (stable channel), the Android SDK, and JDK 17
for the Gradle build of the watch app.

```bash
git clone https://github.com/ArbitroDev/ProteinCalculator.git
cd ProteinCalculator
flutter pub get
dart run build_runner build   # generates the database code
flutter run                   # Android device or emulator
flutter run -d chrome         # web (debug)
```

Debug builds are named *Protein Calculator Dev* and install next to the app
from Google Play, with their own data. Crash reporting is off in these
builds: see [Crash reports](CONTRIBUTING.md#crash-reports).

Before opening a pull request:

```bash
dart format .
flutter analyze
flutter test
```

The watch app is built with Gradle, not with the Flutter tool: see
[Wear OS watch app](CONTRIBUTING.md#wear-os-watch-app).

## Contributing

Contributions are welcome: bug reports, ideas and pull requests. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) first. In short:

1. Open an issue, or comment on an existing one.
2. Fork the repository and create a branch from `develop`.
3. Open a pull request against `develop`, with a
   [Conventional Commits](https://www.conventionalcommits.org) title.
4. Agree to the [Contributor License Agreement](CLA.md).

## License

**Source-available, not open source.** Copyright (c) 2026 ArbitroDev. All
rights reserved.

The source code is public so that you can read it and contribute to it.
Copying, redistribution and republication are not allowed. See
[LICENSE.md](LICENSE.md) for details.

Product data come from Open Food Facts, under the
[Open Database License](https://opendatacommons.org/licenses/odbl/1-0/).
Google Play and the Google Play logo are trademarks of Google LLC.
