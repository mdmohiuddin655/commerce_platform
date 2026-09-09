# ADR-0004 — Strict analysis and mechanical guard rails from day one

- **Status:** Accepted
- **Date:** 2026-09-09
- **Task:** FND-001

## Context

The blueprint's invariants are mostly *structural*: money as integer minor
units, exhaustive state transitions, no arbitrary status patching, packages not
importing apps. Structural rules that live only in prose erode.

## Decision

1. One root `analysis_options.yaml` applying to every app and package, with
   `strict-casts`, `strict-inference` and `strict-raw-types`, and
   `missing_required_param` / `missing_return` raised to **error**.
2. `tools/check_layering.sh` greps for the boundary violations the analyzer
   cannot see, and fails the build on any hit — including committed secrets.
3. `tools/run_checks.sh` is the single local gate: resolve, analyze, test,
   guard. FND-004's CI runs the same script rather than a parallel definition
   that can drift.
4. Sealed `Result`/`Failure` and a `Money` type with no `double` surface, so
   that "integer minor units" is enforced by the type system rather than by
   reviewer memory.

## Consequences

- Strictness is cheapest now, before there is feature code to retrofit.
- A grep-level guard is not a proof. It was validated by planting a deliberate
  violation of each rule and confirming a non-zero exit; that validation must
  be repeated whenever the script changes.
- Lint set may need tuning as real code arrives; changes go through review, not
  by silently deleting a rule to make a build green.
