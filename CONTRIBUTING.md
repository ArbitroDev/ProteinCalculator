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

Every pull request runs the automated checks (formatting, analysis, tests,
commit messages). A pull request can only be merged once all checks pass.

## Commit messages

Commit titles and pull request titles follow
[Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<optional scope>)!: <description>
```

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
  `ci`, `chore`, `revert`.
- Add `!` for a breaking change.
- Write the description in English, in the imperative mood, without a capital
  first letter, 100 characters maximum for the whole title.
- Leave a blank line between the title and the body.

Examples: `feat(today): show daily protein total`,
`fix(history): count 1 a.m. entries in the previous day`.

## Development setup

- Flutter 3.47.5 (stable channel), the version used by the automated checks
- Android SDK for Android builds
- Chrome for web debugging: `flutter run -d chrome`

Generated files are not committed. After cloning or pulling, run:

```bash
flutter pub get
dart run build_runner build
```

`flutter pub get` generates the localizations, `build_runner` generates the
database code (`*.g.dart`).

## Database changes

The local database uses [Drift](https://drift.simonbinder.eu). When changing
its schema:

1. Increase `schemaVersion` in `lib/core/database/app_database.dart` and write
   the migration.
2. Run `dart run drift_dev make-migrations`: it saves the new schema in
   `drift_schemas/` and generates tests checking that existing data survives
   the migration.
3. Make sure these tests pass. A schema change without migration tests will
   not be merged.

## Translations

The app is available in French and English. User-facing text lives in
`lib/l10n/app_fr.arb` (reference file) and `lib/l10n/app_en.arb`: every key
must exist in both files. Never hard-code user-facing text in widgets.
