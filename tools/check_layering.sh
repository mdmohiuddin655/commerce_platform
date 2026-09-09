#!/usr/bin/env bash
# FND-001 — structural guard rails.
#
# Fails when an import crosses a boundary the architecture forbids. This is a
# grep-level check, not a type-system guarantee; it exists so a violation is
# caught in review/CI instead of after a feature ships.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { printf '  %s\n' "$1"; fail=1; }

echo "==> packages must not import apps"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "package:[a-z_]+_app/" packages/ 2>/dev/null)

echo "==> an app must not import another app"
for appdir in apps/*/; do
  app=$(basename "$appdir")
  # Every *_app package import inside this app, except the app's own package.
  while IFS= read -r hit; do
    report "$hit"
  done < <(grep -rn --include='*.dart' -E "package:[a-z_]+_app/" "$appdir" 2>/dev/null \
    | grep -vE "package:${app}_app/")
done

echo "==> backend must not be imported by client code"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "['\"](\.\./)*\.\./backend/" apps/ packages/ 2>/dev/null)

echo "==> feature domain/ must not import Flutter, Firebase or UI packages"
# domain is pure Dart: no widgets, no SDK clients, no design system.
# Directories are enumerated with find so an unmatched glob can never leave
# grep reading stdin (which would hang the gate).
domain_dirs=$(find apps packages -type d -name domain -path '*/lib/*' 2>/dev/null)
if [ -n "$domain_dirs" ]; then
  while IFS= read -r hit; do
    report "$hit"
  done < <(echo "$domain_dirs" | tr '\n' '\0' | xargs -0 grep -rn --include='*.dart' \
    -E "package:(flutter|flutter_[a-z_]+|firebase_[a-z_]+|cloud_firestore|cloud_functions|drift|cp_design_system)/" \
    /dev/null 2>/dev/null)
fi

echo "==> feature presentation/ must not import data/"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "features/[a-z_]+/data/" /dev/null apps/*/lib/features/*/presentation/ 2>/dev/null)

echo "==> feature application/ must not import presentation/"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "features/[a-z_]+/presentation/" /dev/null apps/*/lib/features/*/application/ 2>/dev/null)

echo "==> no committed secrets in tracked source"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' --include='*.yaml' --include='*.json' \
  -E "(AIza[0-9A-Za-z_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" \
  apps/ packages/ backend/ infra/ 2>/dev/null)

if [ "$fail" -ne 0 ]; then
  echo
  echo "LAYERING CHECK: FAIL"
  exit 1
fi
echo
echo "LAYERING CHECK: PASS"
