# ADR-0003 — `cp_` prefix on shared Dart package names

- **Status:** Accepted
- **Date:** 2026-09-09
- **Task:** FND-001

## Context

The blueprint fixes the *directory* names: `packages/core`, `packages/auth`,
`packages/sync`, `packages/contracts`, `packages/networking`,
`packages/notifications`. Every one of those is also the name of a real,
unrelated package published on pub.dev.

A Dart package's name is independent of its directory. If a shared package were
literally named `core` and a path dependency were ever dropped or mistyped, pub
would resolve `core` from pub.dev — a stranger's code, silently, with no error.

## Decision

Directories keep the blueprint names exactly. Dart package names take a `cp_`
prefix: `packages/core` declares `name: cp_core`, imported as
`package:cp_core/cp_core.dart`. Apps are `<role>_app`.

Sibling dependencies are declared as **path** dependencies, never hosted
version constraints, so resolution cannot reach pub.dev for them at all.

## Consequences

- The blueprint's folder hierarchy is followed literally, as required.
- Import lines are unambiguous about what is first-party.
- Directory name and package name differ, which is slightly unconventional;
  documented here and in `docs/architecture/repository-structure.md`.
