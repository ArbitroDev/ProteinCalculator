#!/usr/bin/env bash
# Prepares a release on its branch, release/<version>, before its pull
# request against develop: sets the version, renders the screenshots of the
# phone and of the watch, lays out the images of the Google Play listing and
# checks its texts. What is left to write by hand comes last.
#
# Usage, from the root of the repository: tool/prepare_release.sh 1.4.0
# Needs Flutter, the Android SDK and Python with Pillow (pip install pillow).
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: tool/prepare_release.sh <version>, as in 1.4.0" >&2
  exit 2
fi
name=$1

current=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *//' | tr -d '\r')
current_name=${current%%+*}
if [[ ! "$current" =~ \+([0-9]+)$ ]]; then
  echo "The version of pubspec.yaml, $current, has no build number." >&2
  exit 1
fi
build=${BASH_REMATCH[1]}
newer=$(printf '%s\n%s\n' "$current_name" "$name" | sort -V | tail -n 1)
if [[ "$name" == "$current_name" || "$newer" != "$name" ]]; then
  echo "Version $name must be greater than the current one, $current_name." >&2
  exit 1
fi
branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" != "release/$name" ]]; then
  echo "Warning: on $branch, not release/$name." >&2
fi

echo "== Version $name+$((build + 1))"
sed -i -E "s/^version: .*/version: $name+$((build + 1))/" pubspec.yaml

echo "== Screenshots of the phone app"
flutter test tool/store_screenshots --update-goldens

echo "== Screenshots of the watch app"
(cd android && ./gradlew --no-daemon -q :wear:testDebugUnitTest -PstoreScreenshots \
  --tests '*StoreScreenshotsTest')

echo "== Images of the Google Play listing"
python tool/store_screenshots/compose.py

echo "== Texts of the Google Play listing"
python .github/scripts/update_store_listing.py --plan

cat <<EOF

Left to do by hand, before the pull request of release/$name against develop:
- store/whatsnew/whatsnew-fr-FR and whatsnew-en-US: what is new for users,
  500 characters at most;
- store/fr and store/en: the descriptions, if the new features belong there;
- README.md: the features;
- a look at the images in store/, then a commit and the pull request.
Once released, the Store listing workflow sends the listing to Google Play.
EOF
