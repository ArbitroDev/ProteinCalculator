# Contributing to Protein Calculator

Contributions are welcome! Please read this guide before opening a pull
request.

## Before you start

- This project is **source-available, not open source**. Read the
  [LICENSE](LICENSE): you may fork, clone and modify the code **only** to
  contribute to this repository. Redistribution and republication are
  prohibited.
- Every contribution requires agreement to the
  [Contributor License Agreement](CLA.md).

## Workflow

1. Open an issue describing the bug or feature, or comment on an existing one.
2. Fork the repository and create a branch from `main`.
3. Make your changes and make sure that:
   - `flutter analyze` reports no issues;
   - `flutter test` passes;
   - the code is formatted with `dart format .`.
4. Open a pull request and check the CLA box in the template.

Every pull request runs the automated checks (formatting, analysis, tests).
A pull request can only be merged once all checks pass.

## Development setup

- Flutter 3.47.5 (stable channel), the version used by the automated checks
- Android SDK for Android builds
- Chrome for web debugging: `flutter run -d chrome`

Generated files (such as localizations) are not committed: `flutter pub get`
regenerates them.

## Translations

The app is available in French and English. User-facing text lives in
`lib/l10n/app_fr.arb` (reference file) and `lib/l10n/app_en.arb`: every key
must exist in both files. Never hard-code user-facing text in widgets.
