#!/usr/bin/env bash
# FND-001 — the full local gate. CI (FND-004) runs the same script.
set -uo pipefail
cd "$(dirname "$0")/.."

status=0
step() {
  echo
  echo "======================================================"
  echo "==> $1"
  echo "======================================================"
}

step "flutter pub get (workspace root)"
flutter pub get || status=1

step "flutter analyze (all apps + packages)"
flutter analyze || status=1

step "dart test (pure Dart packages)"
for p in packages/*/; do
  name=$(basename "$p")
  [ -d "$p/test" ] || continue
  ls "$p"/test/*_test.dart >/dev/null 2>&1 || continue
  if grep -q "sdk: flutter" "$p/pubspec.yaml"; then continue; fi
  echo "--- $name ---"
  (cd "$p" && dart test) || status=1
done

step "flutter test (apps + flutter packages)"
for d in apps/*/ packages/*/; do
  [ -d "$d/test" ] || continue
  ls "$d"/test/*_test.dart >/dev/null 2>&1 || continue
  grep -q "sdk: flutter" "$d/pubspec.yaml" || continue
  echo "--- $(basename "$d") ---"
  (cd "$d" && flutter test) || status=1
done

step "layering + secret guard rails"
./tools/check_layering.sh || status=1

echo
if [ "$status" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "CHECKS FAILED"
fi
exit "$status"
