#!/usr/bin/env bash
# FND-001-FIX-001 — workspace membership is derived from configuration.
#
# The root `pubspec.yaml` `workspace:` block is the single source of truth for
# what the validation gate must cover. This script proves three things:
#
#   1. every declared member exists and opts in (`resolution: workspace`);
#   2. no on-disk Dart package under apps/ or packages/ is missing from the
#      declaration (a package added but never declared);
#   3. the declared set matches what the Dart toolchain actually resolved
#      (.dart_tool/package_config.json), so the count is proven by the
#      resolver rather than only by parsing YAML.
#
# `tools/run_checks.sh` sources the member list from here, so a newly declared
# member cannot be silently skipped by the gate.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { printf '  VIOLATION: %s\n' "$1"; fail=1; }

# --- 1. declared members, parsed from the workspace: block -------------------
workspace_members() {
  awk '
    /^workspace:[[:space:]]*$/ { inws = 1; next }
    inws && /^[^[:space:]#]/   { inws = 0 }
    inws && /^[[:space:]]*-[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' pubspec.yaml
}

# Emit the member list when asked, so run_checks.sh has one source of truth.
if [ "${1:-}" = "--list" ]; then
  workspace_members
  exit 0
fi

declared=()
while IFS= read -r m; do
  [ -n "$m" ] && declared+=("$m")
done < <(workspace_members)

echo "==> declared workspace members: ${#declared[@]}"
for m in "${declared[@]}"; do
  printf '  %s\n' "$m"
done

if [ "${#declared[@]}" -eq 0 ]; then
  report "root pubspec.yaml declares no workspace members"
fi

# --- 2. each declared member must exist and opt in --------------------------
echo "==> every declared member exists and sets 'resolution: workspace'"
for m in "${declared[@]}"; do
  if [ ! -d "$m" ]; then
    report "declared member '$m' has no directory"
    continue
  fi
  if [ ! -f "$m/pubspec.yaml" ]; then
    report "declared member '$m' has no pubspec.yaml"
    continue
  fi
  if ! grep -qE '^resolution:[[:space:]]*workspace[[:space:]]*$' "$m/pubspec.yaml"; then
    report "member '$m' is declared but does not set 'resolution: workspace'"
  fi
done

# --- 3. no undeclared Dart package under apps/ or packages/ -----------------
echo "==> no on-disk package under apps/ or packages/ is undeclared"
for d in apps/*/ packages/*/; do
  [ -f "${d}pubspec.yaml" ] || continue
  path="${d%/}"
  found=0
  for m in "${declared[@]}"; do
    [ "$m" = "$path" ] && found=1 && break
  done
  [ "$found" -eq 1 ] || report "package '$path' exists on disk but is not declared in the workspace"
done

# --- 4. declared set must match what the resolver actually produced ---------
echo "==> declared set matches the resolved package_config.json"
cfg=.dart_tool/package_config.json
if [ ! -f "$cfg" ]; then
  echo "  NOT RUN: $cfg absent — run 'flutter pub get' first"
else
  resolved=$(grep -o '"rootUri": "\.\./[^"]*"' "$cfg" \
    | sed 's/.*"\.\.\/\(.*\)"/\1/' | grep -v '^$' | sort)
  resolved_count=$(printf '%s\n' "$resolved" | grep -c . )
  declared_sorted=$(printf '%s\n' "${declared[@]}" | sort)

  # The workspace root itself is a package too; it appears as rootUri "../".
  root_pkg=$(grep -c '"rootUri": "\.\./"' "$cfg")
  echo "  resolver reports $resolved_count member package(s) + $root_pkg workspace-root package"

  if [ "$resolved" != "$declared_sorted" ]; then
    report "resolved members differ from declared members"
    diff <(printf '%s\n' "$declared_sorted") <(printf '%s\n' "$resolved") \
      | sed 's/^/    /'
    echo "    (stale resolution? re-run 'flutter pub get')"
  fi
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "WORKSPACE CHECK: FAIL"
  exit 1
fi
echo "WORKSPACE CHECK: PASS (${#declared[@]} declared members)"
