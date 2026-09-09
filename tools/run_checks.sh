#!/usr/bin/env bash
# FND-001 — the full local gate. CI (FND-004) runs this same script.
#
# FND-001-FIX-001: member discovery now comes from the root pubspec.yaml
# `workspace:` block via tools/check_workspace.sh, not from an apps/*
# packages/* filesystem glob. A member declared outside those two directories
# used to be silently skipped by the test steps; it no longer can be.
#
# Members with no tests are reported as NO TESTS and counted, so a member that
# is covered by nothing is visible in the summary instead of invisible.
set -uo pipefail
cd "$(dirname "$0")/.."

status=0
tested=0
untested=()

step() {
  echo
  echo "======================================================"
  echo "==> $1"
  echo "======================================================"
}

step "flutter pub get (workspace root)"
flutter pub get || status=1

step "workspace membership (source of truth: pubspec.yaml workspace:)"
./tools/check_workspace.sh || status=1

# Discover members from configuration, after resolution so the cross-check is
# against a fresh package_config.json.
members=()
while IFS= read -r m; do
  [ -n "$m" ] && members+=("$m")
done < <(./tools/check_workspace.sh --list)

if [ "${#members[@]}" -eq 0 ]; then
  echo "FATAL: no workspace members discovered — gate would test nothing"
  exit 1
fi

step "flutter analyze (workspace root, covers every member)"
flutter analyze || status=1

step "tests for each of the ${#members[@]} declared workspace members"
for m in "${members[@]}"; do
  if [ ! -d "$m/test" ] || ! ls "$m"/test/*_test.dart >/dev/null 2>&1; then
    echo "--- $m: NO TESTS ---"
    untested+=("$m")
    continue
  fi
  echo "--- $m ---"
  tested=$((tested + 1))
  if grep -q "sdk: flutter" "$m/pubspec.yaml"; then
    (cd "$m" && flutter test) || status=1
  else
    (cd "$m" && dart test) || status=1
  fi
done

step "layering + secret guard rails"
./tools/check_layering.sh || status=1

step "summary"
echo "workspace members declared : ${#members[@]}"
echo "members with tests run     : $tested"
echo "members with NO TESTS      : ${#untested[@]}"
for m in ${untested+"${untested[@]}"}; do
  echo "    - $m"
done
echo
echo "NOTE: members listed as NO TESTS carry no implementation at FND-001."
echo "      Any task adding code to one of them must add tests with it."

echo
if [ "$status" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "CHECKS FAILED"
fi
exit "$status"
