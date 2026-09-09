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
| FND-002 | ADMIN | Platform/auth/notification compatibility spikes, proven matrix and blockers | FND-001 | **PARTIAL** | parent task; documentation/static/host portion delivered by FND-002A. Device/Windows/emulator portions outstanding |
| FND-002A | ADMIN | Host-available capability spike: upstream recheck, capability contracts, dated matrix, runtime test plan | FND-001 | **DONE** | [FND-002A report](FND-002A-completion-report.md) · [evidence register](../platform-matrix/FND-002A-capability-evidence.md) |
| FND-002B | ADMIN | Device/runner execution of the runtime test plan | FND-002A, **D1–D3**, O2/O3/O5 | **BLOCKED** | needs a decision *and* hardware — see [runtime test plan](../platform-matrix/FND-002-runtime-test-plan.md) |
| FND-003 | ADMIN | Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants | FND-001 (only) | **TODO — dependencies met** | does *not* depend on FND-002 runtime evidence; see [FND-003 dependency note](#fnd-003-dependency-note) |
| FND-004 | ADMIN | CI/platform runners, emulator security tests, design system, auth, cache/queue/API shell | FND-002, FND-003 | **TODO** | needs Firebase CLI (not installed) |

### FND-002 status after FND-002A

FND-002 is a **parent** capability task, split so that the evidence not
requiring hardware could be produced immediately.

**FND-002A — DONE (2026-09-09).** Rechecked every material platform claim
against current upstream primary sources; built platform-neutral capability
contracts in `cp_notifications`, `cp_auth` and `cp_local_store` with tests;
produced a dated evidence register, an evidence-classed platform matrix and a
concrete runtime test plan. Host-runnable checks were executed, including a
browser capability probe in Chrome 152.

**FND-002B — BLOCKED.** Device, Windows-runner and emulator execution. Blocked
on hardware *and* on an owner decision, so hardware alone does not unblock it.

| Blocked check | Missing | Owner action |
|---|---|---|
| Android/iOS push behaviour | physical devices; Firebase project + APNs key | O3, O5 |
| Windows build, auth REST/PKCE, toast, Drift native | Windows machine or CI runner | O2 |
| Windows closed-app push | Azure/Entra or Store registration | **D3** |
| Firestore rules / emulator suites | Firebase CLI, FlutterFire CLI | O4 |
| Web FCM delivery | Firebase project, VAPID key, generated `web/` folders | O5, FND-004 |

**Headline finding.** The blueprint's *mandatory* `firebase_messaging` +
`awesome_notifications` coexistence is **DECISION REQUIRED**, not merely
untested: the `awesome_notifications` vendor deprecates `firebase_messaging`
support and `awesome_notifications_fcm` states users "MUST not use
`firebase_messaging`" with it. No dependency was substituted. See
[ADR-0005](../decisions/ADR-0005-notification-stack-decision-required.md).

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
| D1 | **Decide: is web push required at launch?** Settles the notification stack (ADR-0005) | FND-002B, FND-004 |
| D2 | If the Awesome path is wanted: establish `awesome_notifications_fcm`'s license — it is not stated on its package page | FND-002B |
| D3 | **Decide Windows closed-app push:** fund a WNS route (Azure/Entra or Store registration, with lead time) or accept local-toast + durable-inbox only | FND-002B (C6) |
