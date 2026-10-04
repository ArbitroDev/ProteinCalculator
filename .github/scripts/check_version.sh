#!/usr/bin/env bash
# Checks the version of pubspec.yaml before a release: its tag must not exist
# yet, and its build number must be greater than the one of the previous
# version, as Google Play refuses a build number it has already received.
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

echo "Version ${name}, build ${build}${previous:+, after ${previous}}."
exit $((errors > 0))
