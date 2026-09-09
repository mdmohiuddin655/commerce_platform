# ADR-0002 — Dart pub workspaces instead of melos

- **Status:** Accepted
- **Date:** 2026-09-09
- **Task:** FND-001

## Context

Fifteen Dart/Flutter packages (5 apps + 10 shared) must resolve to one
consistent dependency set. The usual monorepo answer has been `melos`, which
bootstraps per-package lockfiles and adds a tool to install and pin.

## Decision

Use the Dart SDK's native **pub workspaces**: `workspace:` members listed in the
root `pubspec.yaml`, `resolution: workspace` in each member. Dart 3.13.2 is
pinned, well above the 3.6 minimum. `melos` is not adopted.

## Consequences

- One `pubspec.lock` at the root, committed. Version skew between apps becomes
  impossible rather than merely discouraged.
- `flutter pub get` and `flutter analyze` run once at the root for everything.
- One fewer tool to install, pin and keep working in CI.
- Per-package commands still work by `cd`-ing into the package.
- If a future need appears that workspaces cannot cover (complex versioned
  publishing, for example), revisit with a superseding ADR. None of these
  packages is published (`publish_to: none`), so that need is not present.

## Verification

`flutter pub get`, `flutter analyze` (no issues) and the full test suite were
run against this layout on 2026-09-09.
