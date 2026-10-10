#!/usr/bin/env bash
# Checks the version of pubspec.yaml before a release: its tag must not exist
# yet, and its build number must be greater than the one of the previous
# version, as Google Play refuses a build number it has already received.
# The watch app takes the build number plus an offset as version code: the
# build number must stay below the offset, so the two never collide.
set -euo pipefail

read_version() { grep -E '^version:' | sed -E 's/version: *//' | tr -d '\r'; }

version=$(read_version <pubspec.yaml)
name=${version%%+*}
build=${version#*+}
errors=0

if [[ "$version" != *+* || ! "$build" =~ ^[0-9]+$ ]]; then
  echo "::error file=pubspec.yaml::Version ${version} needs a build number, as in 1.2.3+4."
  exit 1
fi

if git rev-parse --verify --quiet "refs/tags/v${name}" >/dev/null; then
  echo "::error file=pubspec.yaml::Tag v${name} already exists: increase the version."
  errors=$((errors + 1))
fi

previous=$(git describe --tags --abbrev=0 --match 'v*' HEAD 2>/dev/null || true)
if [[ -n "$previous" ]]; then
  previous_version=$(git show "${previous}:pubspec.yaml" | read_version)
  previous_build=${previous_version#*+}
  if ((build <= previous_build)); then
    echo "::error file=pubspec.yaml::Build number ${build} must be greater than ${previous_build}, the one of ${previous}."
    errors=$((errors + 1))
  fi
fi

# Version code of the watch app, see android/wear/build.gradle.kts.
offset=$(grep -E '^wear\.versionCodeOffset=' android/gradle.properties | cut -d= -f2 | tr -d '\r')
if [[ ! "$offset" =~ ^[0-9]+$ ]]; then
  echo "::error file=android/gradle.properties::wear.versionCodeOffset is missing."
  errors=$((errors + 1))
elif ((build >= offset)); then
  echo "::error file=pubspec.yaml::Build number ${build} reaches the offset of the watch app (${offset}): their version codes would collide."
  errors=$((errors + 1))
elif ((offset + build > 2100000000)); then
  echo "::error file=pubspec.yaml::Version code $((offset + build)) of the watch app exceeds the maximum of Google Play."
  errors=$((errors + 1))
fi

echo "Version ${name}, build ${build}${previous:+, after ${previous}}, watch app $((offset + build))."
exit $((errors > 0))
