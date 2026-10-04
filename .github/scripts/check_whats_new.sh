#!/usr/bin/env bash
# Checks the "What's new" texts of Google Play before a release: one file per
# language, not empty, 500 characters at most, and written for this version
# (changed since the previous version tag).
set -euo pipefail

dir=store/whatsnew
languages=(fr-FR en-US)
max_length=500
errors=0

previous=$(git describe --tags --abbrev=0 --match 'v*' HEAD 2>/dev/null || true)

for language in "${languages[@]}"; do
  file="${dir}/whatsnew-${language}"
  if [[ ! -s "$file" ]]; then
    echo "::error file=${file}::Missing or empty What's new text for ${language}."
    errors=$((errors + 1))
    continue
  fi
  length=$(tr -d '\r' <"$file" | wc -m)
  if ((length > max_length)); then
    echo "::error file=${file}::What's new text for ${language} has ${length} characters, ${max_length} at most."
    errors=$((errors + 1))
  fi
  if [[ -n "$previous" ]] && git diff --quiet "$previous" HEAD -- "$file"; then
    echo "::error file=${file}::What's new text for ${language} is unchanged since ${previous}: write it for this version."
    errors=$((errors + 1))
  fi
  echo "${language}: ${length} characters"
done

exit $((errors > 0))
