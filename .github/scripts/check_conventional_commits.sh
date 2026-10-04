#!/usr/bin/env bash
# Checks that the pull request title and every commit title of the pull
# request follow Conventional Commits (https://www.conventionalcommits.org).
#
# Required environment variables: PR_TITLE, BASE_SHA, HEAD_SHA.
set -euo pipefail

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
pattern="^(${types})(\([a-z0-9._/-]+\))?!?: [^ ].*$"
max_length=100
errors=0

check() {
  local kind="$1" title="$2"
  if ! grep -Eq "$pattern" <<<"$title"; then
    echo "::error::${kind} does not follow Conventional Commits: ${title}"
    errors=$((errors + 1))
  elif ((${#title} > max_length)); then
    echo "::error::${kind} is longer than ${max_length} characters: ${title}"
    errors=$((errors + 1))
  fi
}

check "Pull request title" "$PR_TITLE"

while IFS= read -r title; do
  case "$title" in
    "Merge "*) continue ;;
  esac
  check "Commit title" "$title"
done < <(git log --format=%s "${BASE_SHA}..${HEAD_SHA}")

if ((errors > 0)); then
  echo "Expected format: <type>(<optional scope>)!: <description>"
  echo "Allowed types: ${types//|/, }"
  echo "Example: feat(today): show daily protein total"
  exit 1
fi

echo "Pull request title and commit titles follow Conventional Commits."
