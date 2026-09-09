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

echo "==> backend must not be imported by client code"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "['\"](\.\./)*\.\./backend/" apps/ packages/ 2>/dev/null)

echo "==> feature domain/ must not import Flutter"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "package:flutter/" apps/*/lib/features/*/domain/ 2>/dev/null)

echo "==> feature presentation/ must not import data/"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "features/[a-z_]+/data/" apps/*/lib/features/*/presentation/ 2>/dev/null)

echo "==> feature application/ must not import presentation/"
while IFS= read -r hit; do
  report "$hit"
done < <(grep -rn --include='*.dart' -E "features/[a-z_]+/presentation/" apps/*/lib/features/*/application/ 2>/dev/null)

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
