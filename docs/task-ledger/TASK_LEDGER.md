# Task ledger

Single source of truth for task status across all five ChatGPT Projects. The
Projects cannot see each other's conversations, so this file — not a chat
history — records what is actually done.

**Update rule:** a task moves to DONE only when an executor completion report
with real command output exists in `docs/task-ledger/`. Sending a task prompt
is not completion. If a check could not be run, it is recorded **NOT RUN**, and
the task stays BLOCKED or PARTIAL.

Legend: `DONE` · `IN PROGRESS` · `BLOCKED` · `TODO` · `PARTIAL`

## Foundation

| ID | Owner | Deliverable | Depends on | Status | Evidence |
|---|---|---|---|---|---|
| FND-001 | ADMIN | Inspect/bootstrap repository, task ledger, pinned toolchain and constraints | — | **DONE** | [FND-001 report](FND-001-completion-report.md) |
| FND-002 | ADMIN | Platform/auth/notification compatibility spikes, proven matrix and blockers | FND-001 | **BLOCKED** | needs Windows runner + physical device; see [platform matrix](../platform-matrix/platform-matrix.md) |
| FND-003 | ADMIN | Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants | FND-001 | **TODO** | — |
| FND-004 | ADMIN | CI/platform runners, emulator security tests, design system, auth, cache/queue/API shell | FND-002, FND-003 | **TODO** | needs Firebase CLI (not installed) |

## End-to-end proof

| ID | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| E2E-001 | ADMIN coordinates all | One seeded shop/SKU: checkout → assignment → handoff → COD → settlement, plus the refusal/return branch | FND-003, FND-004 | **TODO** |

## Role features

Each ROLE-* task is owned by its own ChatGPT Project and is gated on tested
shared contracts. None may begin before FND-003 lands.

| ID | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| ROLE-ADMIN-* | ADMIN | Admin role features | FND-003, FND-004 | **TODO** |
| ROLE-USER-* | USER | Customer role features | FND-003, FND-004 | **TODO** |
| ROLE-AGENT-* | AGENT | Shop agent role features | FND-003, FND-004 | **TODO** |
| ROLE-PICKER-* | PICKER | Picker role features | FND-003, FND-004 | **TODO** |
| ROLE-RIDER-* | RIDER | Rider role features | FND-003, FND-004 | **TODO** |

## Hardening and release

| ID | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| HARD-* | ADMIN coordinates | Concurrency, auth/revocation, offline/restart, notifications, adaptive UI, profiling | E2E-001 | **TODO** |
| REL-* | ADMIN coordinates | Capacity/cost evidence, recovery drills, signing/distribution, runbooks, launch gates | HARD-* | **TODO** |

## Contract version

| Contract | Version | Owner task | Notes |
|---|---|---|---|
| Wire contract (`cp_contracts`) | **0.1** | FND-003 | Only `ContractVersion` exists. No schemas, no transition tables yet. |

Bump the minor version for additive, backward-readable changes; bump the major
version for a breaking one and update every Project before any app ships
against it.

## Owner actions outstanding

These need a human; no executor can do them.

| # | Action | Blocks |
|---|---|---|
| O1 | Run `flutter doctor --android-licenses` and accept | first Android build |
| O2 | Provide a Windows machine or CI runner | FND-002 (C2, C3, C4) |
| O3 | Attach a physical Android and iOS device | FND-002 (C6), push evidence |
| O4 | Install Firebase CLI + FlutterFire CLI | FND-004 emulator/security tests |
| O5 | Create Firebase projects per environment and supply config | FND-004 |
| O6 | Decide currency, fee policy and commission ownership | FND-003 money invariants |
| O7 | Decide the git remote / hosting and branch protection | CI in FND-004 |
