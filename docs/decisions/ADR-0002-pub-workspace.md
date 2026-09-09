# ADR-0002 — Dart/Flutter native pub workspaces without Melos

- **Status:** **Accepted**
- **Date:** 2026-09-09 (original decision, FND-001)
- **Amended:** 2026-09-09 (FND-001-FIX-001) — added the explicit deviation
  statement, the replacement mechanism, measured evidence, Windows/CI
  implications and revisit triggers. No prior review history is claimed beyond
  these two same-day entries.
- **Task:** FND-001, amended by FND-001-FIX-001
- **Contract baseline:** SHARED-BASELINE-v1.0

## Context

This repository holds five Flutter role applications (`admin`, `user`, `agent`,
`picker`, `rider`), ten shared `cp_*` packages, and a `backend/` tree that is
not a Dart package. All of it must resolve to **one** consistent dependency set:
if two apps drifted onto different versions of `cp_contracts`, the shared
commerce contract would silently fork, which is the specific failure this
monorepo exists to prevent.

Workspace orchestration is therefore required for four jobs:

1. **Resolution** — one dependency graph, one lockfile, no per-app skew.
2. **Discovery** — an authoritative list of members, so tooling can act on all
   of them.
3. **Fan-out execution** — analyze and test every member with one command.
4. **Coverage integrity** — a newly added member must not be able to slip past
   the validation gate unnoticed.

**The shared baseline defaults to Flutter/Dart workspaces *plus* Melos.**
Omitting Melos is therefore an intentional deviation from the baseline and
requires this ADR to justify it with evidence, not preference.

Melos historically supplied (1)–(3) because pub had no native workspace
support. Dart 3.6 introduced native pub workspaces; this repository pins Dart
**3.13.2**, well above that.

## Decision

**Use native Dart pub workspaces. Melos is intentionally not adopted at this
stage.** The deviation is deliberate and bounded by the revisit triggers below.

Mechanism, per responsibility:

| Responsibility | Melos would provide | Replacement here | Evidence |
|---|---|---|---|
| Resolution | `melos bootstrap` | `workspace:` members in root `pubspec.yaml` + `resolution: workspace` in each member; `flutter pub get` at the root | E1, E3 |
| Discovery | `melos list` | `tools/check_workspace.sh --list`, parsing the `workspace:` block — the same source of truth pub itself uses | E2 |
| Fan-out execution | `melos exec` / `melos run` | `tools/run_checks.sh`, iterating the discovered member list | E4 |
| Coverage integrity | (not provided by Melos either) | `tools/check_workspace.sh` cross-checks declared ↔ on-disk ↔ resolver, and `run_checks.sh` prints `NO TESTS` members | E5, E6 |
| Versioning / changelogs / publishing | `melos version`, `melos publish` | **not replaced — not needed.** Every package is `publish_to: "none"`; nothing is released to a registry | — |

## Evidence

All measured on the bootstrap host (macOS 26.6.2, darwin-arm64) on 2026-09-09.

**E1 — toolchain supports native workspaces.** Flutter 3.47.2 (stable), Dart
3.13.2. Native pub workspaces require Dart ≥ 3.6.

**E2 — member discovery from configuration.**
`./tools/check_workspace.sh --list` returns **15 declared members**: the five
apps `apps/{admin,agent,picker,rider,user}` and the ten packages
`packages/{auth,contracts,core,design_system,feature_flags,local_store,networking,notifications,observability,sync}`.

**E3 — resolution covers every member.** `flutter pub get` at the root
produced one root `pubspec.lock` and a `.dart_tool/package_config.json`
listing **16 local packages** — the 15 members plus the workspace-root package
`commerce_platform`. No `cp_*` package appears as a locked hosted entry,
confirming members resolve from the workspace rather than pub.dev.
`check_workspace.sh` fails if the declared set and the resolver's set differ.

**E4 — whole-repository orchestration.** `./tools/run_checks.sh` performs, in
one command: root `flutter pub get` → workspace membership check → root
`flutter analyze` (no issues across all members) → per-member `dart test` /
`flutter test` → `tools/check_layering.sh`. Result on a clean tree: **ALL
CHECKS PASSED**, exit 0, 17 tests across 7 members with tests, 8 members
reported `NO TESTS` (they carry no implementation at FND-001).

**E5 — a newly declared member cannot be silently skipped.** Negative control:
a member `tools/_probe_member` was declared in `workspace:` — deliberately
placed **outside** `apps/*` and `packages/*` — carrying one failing test.

- The previous glob-based loop (`for d in apps/*/ packages/*/`) visited 15
  directories and **did not see it**: it would have been silently skipped.
- The repaired gate discovered it from configuration (16 declared members),
  executed its test, and exited **1** with `CHECKS FAILED`.

The probe was then removed and the workspace restored to 15 members.

**E6 — membership drift is detected.** Further negative controls, each
producing `WORKSPACE CHECK: FAIL` and exit 1: a declared member with no
directory; a package present under `packages/` but absent from `workspace:`;
and a declared member missing `resolution: workspace`.

**Dependencies added by this decision: none.** No new third-party package or
version was introduced, so no additional compatibility or licence verification
is required. Adopting Melos later *would* require both, recorded in the
superseding ADR.

## Consequences and trade-offs

**Gained**

- One committed root `pubspec.lock`. Version skew between apps is impossible
  by construction rather than by discipline.
- One fewer tool to install, pin, and keep working in CI.
- Discovery uses the same declaration pub itself consumes, so tooling and
  resolver cannot disagree without the gate failing (E6).

**Given up**

- Melos conveniences: `melos exec` with package filters
  (`--scope`, `--diff`, `--depends-on`), `melos version` / changelog
  generation and Conventional-Commit release automation, `melos publish`,
  scripted lifecycle hooks, and its IDE integration. None of these has a
  current consumer: nothing here is published, and FND-001 has no release
  automation.
- Selective execution. `run_checks.sh` runs everything; there is no
  "only what changed" mode. Acceptable at 15 members and 17 tests
  (whole gate ≈ seconds), and a real cost to revisit as the suite grows.
- **Maintenance burden moves to us.** `check_workspace.sh` and
  `run_checks.sh` are custom shell we own, review and must keep correct. Their
  guard rules are only trustworthy while the negative controls are re-run after
  any change to them — that obligation is written into `AGENTS.md` §6.

**Cross-platform limitation — the significant one**

Both scripts are `#!/usr/bin/env bash` and use bash-only constructs (process
substitution `< <(...)`, arrays). They run on macOS and Linux. **They do not
run on Windows `cmd` or PowerShell without a POSIX shell** (Git Bash, WSL, or a
`bash`-shelled CI step).

This matters here because the blueprint requires Windows as a *target
platform*. The distinction, stated explicitly so it is not confused later:

- Building and testing a **Windows app artifact** needs a Windows runner —
  that is missing today for reasons unrelated to this ADR (task-ledger owner
  action O2), and every Windows row in the platform matrix is BLOCKED.
- Running **this validation gate** on a Windows *developer machine* requires
  Git Bash or WSL. Melos would not have removed this constraint for
  `check_layering.sh` / `check_workspace.sh`, which are shell either way — but
  Melos's own fan-out would have been Dart, hence portable, so this is a real
  (if partial) cost of the deviation.

**CI implications (FND-004 must honour these)**

- CI invokes `./tools/run_checks.sh` — the same script developers run. CI must
  not define a second, drifting check list.
- Every job that runs it declares a bash shell explicitly
  (`shell: bash` on GitHub Actions, which supplies Git Bash on Windows
  runners). A Windows job that ran the gate under PowerShell would fail on
  syntax, not on a real defect.
- If a future Windows CI job cannot provide bash, the fan-out must be ported to
  a Dart script (`dart run tools/...`) before that job is trusted — see
  revisit trigger R3.

## Revisit triggers

Supersede this ADR with a new one — adopting Melos or porting the fan-out to
Dart — if any of these becomes true:

- **R1** Packages must be published to a registry, or need independent
  versioning and changelogs.
- **R2** The gate becomes slow enough that selective, dependency-aware
  execution (`--diff` / `--depends-on`) is needed rather than a full run.
- **R3** A Windows runner must execute the gate and cannot provide a POSIX
  shell.
- **R4** The custom shell grows beyond a small, reviewable size, or a coverage
  defect reaches `main` despite the negative controls.
- **R5** Native pub workspaces prove insufficient for a concrete requirement,
  with the failing case recorded.

Until one of these holds, adding Melos would introduce a dependency and a
second orchestration layer for no demonstrated benefit, so it is not adopted.
