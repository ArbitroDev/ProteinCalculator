# Contributing to Protein Calculator

Contributions are welcome! Please read this guide before opening a pull
request.

## Before you start

- This project is **source-available, not open source**. Read the
  [LICENSE](LICENSE.md): you may fork, clone and modify the code **only** to
  contribute to this repository. Redistribution and republication are
  prohibited.
- Every contribution requires agreement to the
  [Contributor License Agreement](CLA.md).

## Workflow

1. Open an issue describing the bug or feature, or comment on an existing one.
2. Fork the repository and create a branch from `develop`.
3. Make your changes and make sure that:
   - `flutter analyze` reports no issues;
   - `flutter test` passes;
   - the code is formatted with `dart format .`.
4. Open a pull request **against `develop`** and check the CLA box in the
   template.

Every pull request runs the automated checks (formatting, analysis, tests,
commit messages). A pull request can only be merged once all checks pass.

### Branches and releases

- `develop` gathers the accepted pull requests. It is the default branch.
- `main` holds released versions only. It accepts pull requests from
  `develop` alone, opened by the maintainer when a version is ready.
- Every merge into `main` runs the release workflow: it runs the automated
  checks again on the merged commit and, only if they pass, builds the
  signed app bundle, sends it to the closed testing track of Google Play
  and tags the version (`v1.2.3`). The version in `pubspec.yaml` must therefore be
  increased in `develop` before each release.
- The publishing job uses the `release` environment of the repository: its
  secrets (signing key, Google Play service account, Sentry address) are
  stored there only, and each release waits for the maintainer's approval.

### Actions used by the workflows

Every action is pinned to a commit, its version kept in a comment: a tag can
be moved to other code, a commit cannot. Dependabot proposes updates once a
week, a week after their release, in a single pull request against
`develop`. These pull requests are never merged automatically. Before
merging one, the maintainer:

- reads the release notes and the comparison between the two versions, and
  looks for changes that do not match them, such as new network calls;
- checks that each new commit is the one the version tag points to in the
  official repository of the action, not a commit from a fork.

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

## Crash reports

Crash reports go to [Sentry](https://sentry.io), and only when the user opts
in. The project address (DSN) is not part of the source code: it is given at
build time. Without it, crash reporting is left out entirely and the option
does not show in the app, which is the case for the automated checks and for
contributions. You do not need a DSN to work on the app.

Release builds read it from a local `sentry.json` file, ignored by git:

```bash
flutter build apk --release --dart-define-from-file=sentry.json
```

```json
{ "SENTRY_DSN": "https://...@....ingest.de.sentry.io/..." }
```

Never commit a DSN. Reports must hold no personal data: keep
`sendDefaultPii` off and never attach entries, products or the goal to an
event (`lib/core/crash_reporting.dart`).

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

The web version, used for development, runs the database with two files
committed in `web/`: `sqlite3.wasm` and `drift_worker.js`. They must match
the versions of the `sqlite3` and `drift` packages in `pubspec.lock`. When
upgrading these packages, replace them with the files of the same versions:
`sqlite3.wasm` from the
[sqlite3 releases](https://github.com/simolus3/sqlite3.dart/releases) and
`drift_worker.js` from the
[drift releases](https://github.com/simolus3/drift/releases).

## Translations

The app is available in French and English. User-facing text lives in
`lib/l10n/app_fr.arb` (reference file) and `lib/l10n/app_en.arb`: every key
must exist in both files. Never hard-code user-facing text in widgets.
