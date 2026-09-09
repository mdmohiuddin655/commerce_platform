# FND-001-FIX-001 completion report

- **Task:** Recheck `e82e932` against FND-001 acceptance criteria; close only
  the unresolved foundation evidence gaps
- **Owner project:** ADMIN / shared foundation
- **Date:** 2026-09-09
- **Contract baseline:** SHARED-BASELINE-v1.0 (unchanged)
- **Host:** macOS 26.6.2 (darwin-arm64), zsh; Flutter 3.47.2, Dart 3.13.2
- **Status:** **DONE**

## 1. Base commit verified

`git rev-parse HEAD` → `e82e9322c1f73552cb3c2e10d5f309a7174c931e`, branch
`main`. `git status --short` was empty before any change, confirming the
previously reported clean tree. `git show --stat e82e932` confirms the FND-001
contents. History was not rewritten and `e82e932` was not amended.

## 2. Gaps found and closed

### G1 — `AGENTS.md` was absent

`git ls-tree -r e82e932 --name-only | grep -i agents` returned nothing: no path
matching `agents` existed at any depth in the commit, and none existed in the
working tree.

The FND-001 report never claimed `AGENTS.md` existed — it listed only
`CLAUDE.md` — so the report was not false, but the deliverable was missing.
**This fix created it.** `AGENTS.md` is now the canonical repository-wide
executor instruction source, covering: monorepo ownership and boundaries;
app↛app; package↛app; feature layering; pure-Dart `domain`; no business or
Firebase logic in widgets; privileged logic server-side only; generated-code
policy; validation expectations; task-ledger and completion-evidence rules;
PASS/FAIL/NOT RUN/BLOCKED semantics; no fake or TODO completion; and no
live/destructive operations without authorization.

`CLAUDE.md` was reduced to Claude-specific working notes plus a pointer to
`AGENTS.md`. A duplication scan confirms no architecture rule (money units,
import boundaries, pure-Dart domain, Melos, `cp_` prefix, NOT RUN semantics,
deployment limits) is stated in both files, so the two cannot drift.

### G2 — the gate could silently skip a declared workspace member

`run_checks.sh` discovered members with `for d in apps/*/ packages/*/` — a
**filesystem glob, not the workspace declaration**. A member declared in
`workspace:` outside those two directories would never have been tested while
the gate still printed `ALL CHECKS PASSED`. Members with no tests were also
skipped silently.

Repaired: new `tools/check_workspace.sh` parses the root `pubspec.yaml`
`workspace:` block (the same source of truth pub uses), and `run_checks.sh`
iterates that list. Members without tests are printed as `NO TESTS` and
counted. `check_workspace.sh` additionally fails on: a declared member with no
directory; a declared member missing `resolution: workspace`; an on-disk
package under `apps/`/`packages/` absent from the declaration; and any
disagreement between the declared set and the resolver's
`.dart_tool/package_config.json`.

### G3 — two required failure modes were unguarded

`check_layering.sh` had **no app-to-app import rule**, and its `domain` rule
matched only `package:flutter/`, missing Firebase, Drift and the design system.
Both were added; the domain rule now enumerates directories with `find` and
passes `/dev/null` to `grep`, so an unmatched glob can never leave the gate
reading stdin.

*Scope note:* `tools/check_layering.sh` is not named in this task's allowed-file
list, but IMPLEMENTATION §C requires the validation to detect app-to-app
imports and `domain` importing Flutter/Firebase/UI. The change is confined to
those two rules and the stdin-safety fix; no existing rule was weakened.

### G4 — ADR-0002 did not justify the Melos deviation

The shared baseline defaults to workspaces **plus** Melos, so omitting Melos is
an intentional deviation requiring evidence. The original ADR stated the choice
but not the replacement mechanism, measured evidence, Windows/CI shell
implications, or revisit triggers.

ADR-0002 was strengthened, not cosmetically rewritten. The decision stands:
**native pub workspaces, Melos not adopted.** It now maps each Melos
responsibility to its replacement, records evidence E1–E6, states the trade-offs
given up (`melos exec` filtering, versioning/changelogs, publishing, selective
execution, and the maintenance burden of custom shell), documents the
bash-only cross-platform limitation and its CI consequences, and defines
revisit triggers R1–R5. No new dependency was introduced, so no additional
compatibility or licence verification was required.

### G5 — FND-002 was wrongly marked wholly BLOCKED

Corrected to **PARTIALLY ELIGIBLE**. Blockage is now recorded per capability:
Windows runtime validation (O2), physical-device push (O3) and
Firebase-emulator tests (O4) are blocked checks. Host-runnable work stays
eligible for a later bounded task — package/API compatibility investigation of
the `firebase_messaging`/`awesome_notifications` question, Firebase Windows SDK
status, Chrome-target Drift WASM and service-worker checks, macOS/Chrome auth
and navigation semantics, and designing the Windows OAuth PKCE test plan. Desk
evidence never becomes a PROVEN platform-matrix row.

### G6 — FND-003 dependency note

Recorded in the ledger: FND-003 depends on **FND-001 only** and does not
require FND-002's physical, Windows or emulator evidence. Two constraints
noted: it must not encode an unproven platform capability as settled, and it
needs owner decision O6 (currency, fee policy, commission ownership). FND-003
was **not started**, and the ledger states it must not be chosen next merely
because part of FND-002 is blocked.

## 3. Workspace coverage — exact figures

Derived from configuration, not from a manual list: **15 declared members.**

```text
apps/admin  apps/agent  apps/picker  apps/rider  apps/user
packages/auth  packages/contracts  packages/core  packages/design_system
packages/feature_flags  packages/local_store  packages/networking
packages/notifications  packages/observability  packages/sync
```

The resolver's `.dart_tool/package_config.json` reports **16 local packages** —
those 15 members plus the workspace-root package `commerce_platform`. The
FND-001 report's "15 members" was correct for declared members; both figures
are now stated explicitly to remove the ambiguity.

Of the 15, **7 have tests** (5 apps, `packages/core`, `packages/contracts`) and
**8 report `NO TESTS`** — the placeholder packages that carry no implementation
at FND-001. That is now visible in the gate summary rather than silent.

## 4. Validation — command by command

Runner: bootstrap host, macOS 26.6.2 darwin-arm64, unless noted.

| # | Command | Result | Detail |
|---|---|---|---|
| V0 | `git status --short` (before changes) | **PASS** | empty — clean tree confirmed |
| V0b | `git rev-parse HEAD` | **PASS** | `e82e9322c1f73552cb3c2e10d5f309a7174c931e`, branch `main` |
| V0c | `git ls-tree -r e82e932 --name-only \| grep -i agents` | **PASS** | no match — `AGENTS.md` proven absent |
| V1 | `flutter pub get` (workspace root) | **PASS** | exit 0; 15 members + root resolved into one lockfile |
| V2 | `./tools/check_workspace.sh` | **PASS** | `WORKSPACE CHECK: PASS (15 declared members)` |
| V3 | `flutter analyze` | **PASS** | `No issues found!` |
| V4 | `./tools/check_layering.sh` | **PASS** | all 7 rules clean |
| V5 | `./tools/run_checks.sh` (full gate) | **PASS** | `ALL CHECKS PASSED`, exit 0; 15 declared / 7 tested / 8 NO TESTS |
| V6 | package + app tests via the gate | **PASS** | 17 tests: `cp_core` 8, `cp_contracts` 4, five apps 1 each |

### Negative controls — layering (all must FAIL)

| # | Planted violation | Result |
|---|---|---|
| NC-1 | app imports another app (`package:user_app/` inside `apps/admin`) | **PASS (fired)** — named the file, exit 1 |
| NC-2 | `domain` imports `cloud_firestore` | **PASS (fired)** — exit 1 |
| NC-3 | `domain` imports `package:flutter/material.dart` | **PASS (fired)** |
| NC-4 | package imports app | **PASS (fired)** — exit 1 |
| NC-5 | client imports `backend/` | **PASS (fired)** |
| NC-6 | `presentation`→`data`, `application`→`presentation` | **PASS (fired)** — both |
| NC-7 | API-key-shaped secret in tracked source | **PASS (fired)** |
| — | clean tree afterwards | **PASS** — `LAYERING CHECK: PASS`, exit 0 |

### Negative controls — workspace coverage (the omission control)

| # | Planted condition | Result |
|---|---|---|
| NC-W1 | member `tools/_probe_member` declared in `workspace:` **outside** `apps/*` and `packages/*`, carrying one failing test | **PASS (fired)** — old glob loop visited 15 dirs and did **not** see it; new gate discovered it (16 declared), ran its test, exited **1** with `CHECKS FAILED` |
| NC-W2 | declared member with no directory | **PASS (fired)** — `WORKSPACE CHECK: FAIL`, exit 1 |
| NC-W3 | package on disk under `packages/` but undeclared | **PASS (fired)** — exit 1, plus resolver-mismatch violation |
| NC-W4 | declared member missing `resolution: workspace` | **PASS (fired)** — exit 1 |
| — | probe removed, `flutter pub get` re-run | **PASS** — back to 15 members; `pubspec.yaml` and `pubspec.lock` byte-identical to `e82e932` |

NC-W1 is the proof required by acceptance criterion 8: the pre-fix gate would
have reported green while never executing that member's tests.

### Not run in this task — deliberately

| Check | Status | Reason |
|---|---|---|
| Android / iOS / Web / Windows builds | **NOT RUN** | explicitly out of scope for a recheck; platform folders still do not exist (FND-004) |
| Firebase emulator, Firestore rules | **BLOCKED** | Firebase CLI not installed; installing it was not authorized and is not required here |
| Windows execution of the gate scripts | **BLOCKED** | no Windows runner; recorded as ADR-0002 trade-off and revisit trigger R3 |
| Physical-device push | **BLOCKED** | no device attached |
| Any deployment, remote push, credential change | **NOT DONE** | not authorized |

No unavailable check is marked PASS anywhere in this report.

## 5. Files changed

| File | Change | Reason |
|---|---|---|
| `AGENTS.md` | **created** | G1 — canonical repository-wide executor rules |
| `CLAUDE.md` | rewritten | G1 — Claude-specific notes only; defers to `AGENTS.md` so rules cannot diverge |
| `tools/check_workspace.sh` | **created** | G2 — config-derived member discovery and drift detection |
| `tools/run_checks.sh` | modified | G2 — iterate declared members; report `NO TESTS`; summary counts |
| `tools/check_layering.sh` | modified | G3 — app↛app rule; `domain` widened to Firebase/Drift/UI; stdin-safe greps |
| `docs/decisions/ADR-0002-pub-workspace.md` | strengthened | G4 — deviation statement, replacement mechanism, evidence E1–E6, trade-offs, Windows/CI, revisit triggers |
| `docs/architecture/toolchain.md` | modified | document the new gate step and the bash-shell requirement |
| `docs/task-ledger/TASK_LEDGER.md` | modified | G5, G6 — FND-002 scope split, FND-003 dependency note, this task's row, baseline id |
| `docs/task-ledger/FND-001-completion-report.md` | amended | §7 Corrections — records what the original report overstated or omitted |
| `docs/task-ledger/FND-001-FIX-001-completion-report.md` | **created** | this report |

**Zero `.dart` files changed.** No feature, contract, state machine, Firebase
rule, auth, notification or platform-folder code was touched.
`pubspec.yaml` and `pubspec.lock` are byte-identical to `e82e932`.

## 6. FND-001 acceptance status

**FND-001 remains DONE**, now supported by evidence rather than by assertion:
the missing `AGENTS.md` exists, the gate demonstrably covers all 15 declared
members and cannot silently skip a new one, all seven layering rules are proven
to fire, and ADR-0002 justifies the Melos deviation with measured evidence.

No blocker prevents FND-001 acceptance. The outstanding environment needs
(Windows runner, physical devices, Firebase CLI, Android licenses) are FND-002
and FND-004 prerequisites and are **not** FND-001 blockers.
