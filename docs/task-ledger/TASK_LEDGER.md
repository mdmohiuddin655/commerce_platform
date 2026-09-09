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
| FND-003 | ADMIN | Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants | FND-001 | **PARTIAL** | parent task; command/authorization slice delivered by FND-003A. Lifecycle, inventory, money and proof slices outstanding |
| FND-003A | ADMIN | Command and event envelopes, identity/membership/scope, permission matrix, authorization invariants | FND-001 | **DONE** (as corrected three times) | Accepted state = **`de19dc9` + `228409d` + `25e6186` + the FND-003A-FIX-003 commit**. Reports: [FND-003A](FND-003A-completion-report.md) + [FIX-001](FND-003A-FIX-001-completion-report.md) + [FIX-002](FND-003A-FIX-002-completion-report.md) + [FIX-003](FND-003A-FIX-003-completion-report.md) · contract **0.2**. **No earlier commit alone is the accepted contract.** |
| FND-003A-FIX-003 | ADMIN | Require fresh authorization before replay; separate type/trust/request-lifetime boundaries; command-router and stale-grant backend tests (R33–R40) | FND-003A-FIX-002 | **DONE** | [FND-003A-FIX-003 report](FND-003A-FIX-003-completion-report.md) |
| FND-003A-FIX-002 | ADMIN | Make successful authorization unforgeable and request-bound before idempotency replay | FND-003A-FIX-001 | **DONE** | [FND-003A-FIX-002 report](FND-003A-FIX-002-completion-report.md) |
| FND-003A-FIX-001 | ADMIN | Fix offer-vs-assignment scope, approval binding, idempotency principal isolation, version-compatibility semantics | FND-003A | **DONE** | [FND-003A-FIX-001 report](FND-003A-FIX-001-completion-report.md) |
| FND-003B | ADMIN | Lifecycle slice: order, assignment, custody, attempt and return transitions with inventory effects | FND-003A | **PARTIAL** | parent task; pre-dispatch order/reservation lifecycle delivered by FND-003B1. Assignment, custody, delivery and return lifecycles outstanding |
| FND-003B1 | ADMIN | Pre-dispatch order + reservation lifecycle: placement, acceptance/rejection, preparing/ready, cancellation, expiry and inventory race invariants | FND-003A | **DONE** | [FND-003B1 report](FND-003B1-completion-report.md) · contract **0.3** |
| FND-003B2 | ADMIN | Assignment lifecycle: picker and rider offer/accept/decline/expire edges | FND-003B1 | **TODO — NOT STARTED** | not blocked by hardware or O6 |
| FND-003B3 | ADMIN | Custody, delivery-attempt and return lifecycle, including post-dispatch inventory restoration | FND-003B2 | **TODO — NOT STARTED** | — |
| FND-003C | ADMIN | Money slice: payment/COD, cash journal, fees, refusal policy, commissions, settlement | FND-003A, FND-003B | **BLOCKED** | needs owner decision **O6** |
| FND-003D | ADMIN | Proof and dispute slice: customer OTP/proof format and fallback workflow | FND-003B | **TODO** | required before delivery confirmation is coded |
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

### FND-003 status after FND-003A

FND-003 is a **parent** contract task, split into slices so the work not
needing owner decisions could land immediately.

**FND-003A — DONE (2026-09-09), as corrected by FND-003A-FIX-001
(2026-09-10).** Command and event envelopes, idempotency semantics,
identity/membership/scope vocabulary, 35 stable permission ids, one canonical
least-privilege matrix, and a pure-Dart authorization evaluator with deny-path
tests. Contract version **0.1 → 0.2** (additive), corrected **in place**.

Review of `de19dc9` found four defects, all fixed by `228409d`: assignment accept/decline
was authorized by region alone (any same-region worker could take another's
offer); `ApprovalEvidence` was not bound to requester/permission/resource;
idempotency replay was not principal-isolated; and version-number
compatibility was being presented as proof of payload readability.

A further review of `228409d` found a fifth defect, fixed by
**FND-003A-FIX-002**: `AuthorizationDecision.allow()` was public and the class
was not `final`, so the documented "authorization cannot be skipped" guarantee
did not exist — callers, including the contract's own tests, could fabricate
success, and an allow carried no binding to what had been authorized.
Successful authorization is now an unforgeable, request-bound
`AuthorizationGrant`.

A third review of `25e6186` found the remaining gap, fixed by
**FND-003A-FIX-003**: unforgeable is not the same as *current*. The grant's
private constructor proves only that `evaluateAuthorization` allowed the inputs
it was given — not that those inputs were verified, authoritative or fresh —
and nothing stopped an application retaining a grant across requests, so a
revoked actor's earlier success could still replay. The contract now requires
**fresh authorization on every request including replays**, forbids caching or
reusing a grant, assigns command-type → permission mapping to the trusted
backend router, and adds backend checklist items **R33–R40** (all NOT RUN).

**Cite all three commits; no earlier one alone is the accepted contract.** No
lifecycle, inventory or money rule was guessed at any point.

**FND-003B1 — DONE (2026-09-10).** Pre-dispatch order and reservation
lifecycle: six executable order states, four reservation states, seven named
commands, a deterministic transition evaluator, typed inventory effects and a
financial classification that makes "undecided" impossible to read as zero.
Contract **0.2 → 0.3** (additive). The acceptance-versus-expiry race is closed
structurally, and cancellation from `preparing`/`ready` is recorded as
**DECISION REQUIRED** rather than guessed — it needs O6 and FND-003C.

**Remaining slices:**

| Slice | Owns | Status |
|---|---|---|
| FND-003B lifecycle | Order, assignment, custody, attempt, return transitions; inventory effects per edge | **PARTIAL** — B1 done; B2/B3 not started |
| FND-003C money | Payment/COD, cash journal, fees, refusal policy, commissions, settlement | **BLOCKED on O6** |
| FND-003D proof/dispute | Customer OTP/proof format and fallback workflow | **TODO** — needed before delivery confirmation is coded |

FND-003A depended on FND-001 only. It did **not** require FND-002 runtime
evidence, notification decisions D1–D3, devices, a Windows runner, Firebase
credentials or the emulator — and none were used.

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
| Wire contract (`cp_contracts`) | **0.3** | FND-003 | Baseline **SHARED-BASELINE-v1.0**. 0.2 (FND-003A) added command/event envelopes, identity, membership, scope, 35 permissions and the authorization model. 0.3 (FND-003B1) adds the pre-dispatch order and reservation lifecycle with typed inventory effects. Both additive, so minor only. No assignment, custody, delivery, return or money rules yet. See [version history](../contracts/version-history.md). |

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
| O7 | **Configure branch protection / CI governance** on `main`. The remote and hosting are settled: `github.com/mdmohiuddin655/commerce_platform`, pushed 2026-09-09. Branch protection itself is **unverified** — no GitHub evidence was gathered, so it must not be assumed configured. | CI in FND-004 |
| D1 | **Decide: is web push required at launch?** Settles the notification stack (ADR-0005) | FND-002B, FND-004 |
| D2 | If the Awesome path is wanted: establish `awesome_notifications_fcm`'s license — it is not stated on its package page | FND-002B |
| D3 | **Decide Windows closed-app push:** fund a WNS route (Azure/Entra or Store registration, with lead time) or accept local-toast + durable-inbox only | FND-002B (C6) |
