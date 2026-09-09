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
| FND-001-FIX-001 | ADMIN | Recheck `e82e932`; close foundation evidence gaps (AGENTS.md, ADR-0002, workspace coverage, ledger accuracy) | FND-001 | **DONE** | [FND-001-FIX-001 report](FND-001-FIX-001-completion-report.md) |
| FND-002 | ADMIN | Platform/auth/notification compatibility spikes, proven matrix and blockers | FND-001 | **PARTIALLY ELIGIBLE** | host-runnable portion is *not* blocked — see [FND-002 scope split](#fnd-002-is-not-wholly-blocked) |
| FND-003 | ADMIN | Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants | FND-001 (only) | **TODO — dependencies met** | does *not* depend on FND-002 runtime evidence; see [FND-003 dependency note](#fnd-003-dependency-note) |
| FND-004 | ADMIN | CI/platform runners, emulator security tests, design system, auth, cache/queue/API shell | FND-002, FND-003 | **TODO** | needs Firebase CLI (not installed) |

### FND-002 is not wholly blocked

Correction (FND-001-FIX-001). FND-002 was previously marked **BLOCKED** in
full. That was wrong: only specific *checks* are unavailable, not the whole
task. Blockage is recorded per capability, not per task.

**Blocked checks — require hardware or a CLI this host does not have:**

| Check | Blocker | Owner action |
|---|---|---|
| Windows runtime validation (Auth REST + PKCE, notification transport, Drift SQLite on Windows) | no Windows machine or CI runner; host is macOS | O2 |
| Physical-device push delivery, Android and iOS | no physical device attached; simulators are not push evidence | O3 |
| Firebase emulator / Firestore rules and security tests | Firebase CLI and FlutterFire CLI not installed | O4 |

**Still executable now, on this host — eligible for a later bounded task:**

- Package and API compatibility investigation: whether `firebase_messaging`
  and `awesome_notifications` can coexist, read from current package sources,
  changelogs, issue trackers and platform metadata — recorded as *desk
  evidence*, explicitly not as a runtime pass.
- Confirming `firebase_messaging` platform support declarations, and the
  documented status of the Firebase Windows SDK.
- Web-target checks that need only Chrome, which is present: Drift WASM
  behaviour, service-worker notification display, browser storage eviction and
  private-browsing behaviour.
- macOS/Chrome-target auth and navigation semantics.
- Designing the Windows OAuth PKCE flow and its test plan, so the work is ready
  the moment a Windows runner exists.

Rule: desk evidence never becomes a **PROVEN** row in the platform matrix. It
narrows risk and sequences the spikes; a runtime row still needs a runtime run.

### FND-003 dependency note

FND-003 (shared schemas, exhaustive transitions, permissions, policies,
money/custody invariants) depends on **FND-001 only**. It does **not** require
FND-002's physical, Windows or emulator evidence to be complete: defining the
contract is a design and specification activity, and its own prerequisites are
met.

Two constraints on that freedom:

- FND-003 must not encode a platform capability as settled when FND-002 has not
  proven it. Where a contract decision depends on notification or Windows
  behaviour, it records the open question rather than assuming an answer.
- FND-003 needs owner decision **O6** (currency, fee policy, commission
  ownership) before the money and settlement invariants can be finalised.

FND-003 must **not** be selected as next merely because part of FND-002 is
blocked. The ADMIN scheduler chooses the next bounded task.

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
| Wire contract (`cp_contracts`) | **0.1** | FND-003 | Baseline **SHARED-BASELINE-v1.0**. Only `ContractVersion` exists. No schemas, no transition tables yet. |

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
