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
| FND-003B | ADMIN | Lifecycle slice: order, assignment, custody, attempt and return transitions with inventory effects | FND-003A | **PARTIAL** | parent task; pre-dispatch order/reservation (B1), the full assignment lifecycle (B2) and custody acquisition + picker→rider handoff (B3A) delivered. **Delivery attempts, refusal, returns and post-dispatch inventory restoration outstanding — rest of FND-003B3** |
| FND-003B1 | ADMIN | Pre-dispatch order + reservation lifecycle: placement, acceptance/rejection, preparing/ready, cancellation, expiry and inventory race invariants | FND-003A | **DONE** (as corrected) | Accepted state = **`697d170` + the FND-003B1-FIX-001 commit**. Reports: [FND-003B1](FND-003B1-completion-report.md) + [FIX-001](FND-003B1-FIX-001-completion-report.md) · contract **0.3**. `697d170` alone is **not** the accepted contract |
| FND-003B1-FIX-001 | ADMIN | Validate canonical order/reservation aggregate before any lifecycle effect; pair-specific release paths | FND-003B1 | **DONE** | [FND-003B1-FIX-001 report](FND-003B1-FIX-001-completion-report.md) |
| FND-003B2 | ADMIN | Assignment lifecycle: picker and rider offer/accept/decline/expire edges | FND-003B1 | **DONE** (as corrected) | both sub-slices complete: picker by FND-003B2A, rider by FND-003B2B as corrected by FND-003B2B-FIX-001. Custody, delivery and returns are **not** part of this task — they are FND-003B3 |
| FND-003B2A | ADMIN | Picker assignment offer/accept/decline/expiry/revoke and controlled reassignment lifecycle | FND-003B1 | **DONE** (as corrected) | Accepted state = **`355aaa7` + `ce44b29` + the FND-003B2A-FIX-002 commit**. Reports: [FND-003B2A](FND-003B2A-completion-report.md) + [FIX-001](FND-003B2A-FIX-001-completion-report.md) + [FIX-002](FND-003B2A-FIX-002-completion-report.md) · contract **0.4**. **No earlier commit alone is the accepted contract** |
| FND-003B2A-FIX-001 | ADMIN | Deny assignment-id reuse; enforce reachable generation/revision coherence; record ADR-0006 admin-override governance | FND-003B2A | **DONE** | [FND-003B2A-FIX-001 report](FND-003B2A-FIX-001-completion-report.md) |
| FND-003B2A-FIX-002 | ADMIN | Pin transition-closure over the aggregate validator; couple executable states to the revision model; record B3-C1 | FND-003B2A-FIX-001 | **DONE** | [FND-003B2A-FIX-002 report](FND-003B2A-FIX-002-completion-report.md) |
| FND-003B2B | ADMIN | Picker-originated rider assignment: offer/accept/decline/expiry/controlled-revoke, source-picker binding, shared revision model | FND-003B2A | **DONE** (as corrected) | Accepted state = **`9d1e262` + the FND-003B2B-FIX-001 commit**. Reports: [FND-003B2B](FND-003B2B-completion-report.md) + [FIX-001](FND-003B2B-FIX-001-completion-report.md) · [ADR-0007](../decisions/ADR-0007-admin-rider-assignment-override.md) · contract **0.5**. Adds **RA1–RA18** and **B3-C2**, all **NOT RUN**. **`9d1e262` alone is not the accepted contract** |
| FND-003B2B-FIX-001 | ADMIN | Require the canonical opaque-id rule for assignment principal identities, in eligibility **and** stored aggregates, for both roles | FND-003B2B | **DONE** | [FND-003B2B-FIX-001 report](FND-003B2B-FIX-001-completion-report.md) |
| FND-003B3 | ADMIN | Custody, delivery-attempt and return lifecycle, including post-dispatch inventory restoration | FND-003B2 | **PARTIAL** | parent; custody acquisition and the picker→rider handoff delivered by FND-003B3A. Delivery attempts, refusal, returns, customer custody and post-dispatch inventory restoration outstanding |
| FND-003B3A | ADMIN | Physical custody: shop initialisation, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion | FND-003B2B | **DONE** (as corrected) | Candidate state = **`c29df0f` + `18ad750` + the FND-003B3A-FIX-002 commit**. Reports: [FND-003B3A](FND-003B3A-completion-report.md) + [FIX-001](FND-003B3A-FIX-001-completion-report.md) + [FIX-002](FND-003B3A-FIX-002-completion-report.md) · [custody lifecycle](../contracts/custody-lifecycle.md) · contract **0.6**. Adds **CA1–CA23** (NOT RUN); **satisfies B3-C1** by contract test; **B3-C2 stays FUTURE**. **Neither `c29df0f` alone nor `c29df0f` + `18ad750` alone is the candidate contract after FINAL-REVIEW-002. FND-003B3A-FIX-002 itself still requires final read-only acceptance before merge** |
| FND-003B3A-FIX-001 | ADMIN | Bind custody to canonical resource/shop identity, add picker/rider slot-revision CAS, make custody initialisation create-once, correct exported state metadata and the test-count evidence | FND-003B3A | **DONE** | [FND-003B3A-FIX-001 report](FND-003B3A-FIX-001-completion-report.md) |
| FND-003B3A-FIX-002 | ADMIN | Reconcile contract status across the picker, rider and order documents, the package docs and source comments with what FND-003B3A actually implements | FND-003B3A-FIX-001 | **DONE** | [FND-003B3A-FIX-002 report](FND-003B3A-FIX-002-completion-report.md) · **documentation and source-comment only — zero executable Dart changed** |
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
Contract **0.2 → 0.3** (additive). Cancellation from `preparing`/`ready` is
recorded as **DECISION REQUIRED** rather than guessed — it needs O6 and
FND-003C.

Review of `697d170` found one hole, fixed by **FND-003B1-FIX-001**: the
transition graph never *creates* an impossible order/reservation pair, but the
evaluator did not validate the facts it was **given**. Malformed trusted
aggregates — `placed + committed`, `accepted + active`, or a reservation with
zero or negative units — could reach inventory-producing paths; a negative
count produced a stock-*destroying* mutation. An aggregate-integrity boundary
now runs before any effect, and release paths are pair-specific. **Cite both
commits.**

**FND-003B2B — DONE (2026-09-10).** Picker-originated rider assignment: the
order's **current accepted picker** offers delivery work to one rider, with
accept, decline, worker-driven expiry and controlled revoke. Contract
**0.4 → 0.5** (additive).

The distinctive risk in this slice is **cross-aggregate**, and it is the first
time a lifecycle has had one. A rider attempt is meaningless except relative to
the picker assignment that created it, so each attempt stores an immutable
`SourcePickerBinding` (picker principal + picker assignment id + picker
generation). Acceptance re-checks that the binding is still the order's current
accepted picker assignment, which closes this hole:

```text
picker A offers rider R -> A is revoked -> picker B becomes accepted
                        -> R's stale offer accepted as though B created it
```

That is denied `sourcePickerAssignmentMismatch`. Revoke deliberately does
**not** require the *original* picker — only the current one — so a
replacement picker can resolve a rider slot that would otherwise be
permanently orphaned; the binding is still never rewritten.

Shared, not copied: `AssignmentState`, `AssignmentRole`,
`ScopeProjectionEffect`, `CustodyClassification`, `ReassignmentSafety`,
`assignmentEligibleOrderStates`, and the role-neutral `AssignmentDenial` and
`reachableSlotRevisionRange`, which moved into `assignment_integrity.dart`
unchanged. A negative control proved the sharing is real: breaking the helper
fails the picker **and** rider closure suites.

`agent.assignment.offer_rider` was **not** used, deleted or renamed. It stays
reserved for a future direct shop-to-rider pickup — a different custody source
— and a test asserts no command maps to it.
[ADR-0007](../decisions/ADR-0007-admin-rider-assignment-override.md) records
that admin rider intervention must be a separate audited override;
`admin.assignment.override_rider` is RESERVED and absent from
`Permission.values`, `permissionMatrix` and `AssignmentCommand`.

New backend criteria **RA1–RA18** and contract criterion **B3-C2** — all
**NOT RUN**. **FND-003B2 is now DONE**; FND-003B stays **PARTIAL** because
custody, delivery and returns (FND-003B3) are outstanding.

**FND-003B2B-FIX-001 — DONE (2026-09-10).** Final review of `9d1e262` found one
identity-integrity defect, reproduced before any change was made: rider target
eligibility qualified on presence and equality but never on the repository's
canonical opaque-id rule, so an empty or sequential principal id could qualify,
produce a **successful** offer transition with `offerRecipientPrincipalId = ''`,
and yield an aggregate the validator refuses — breaking transition closure for
malformed trusted facts.

`PickerEligibility` carried the identical weakness and was corrected at the same
boundary rather than leaving the two assignment roles with different identity
guarantees. The aggregate validators now apply the canonical rule to stored
recipients, the rider source-picker principal and `resourceId` — the same rule
`Principal`, `CommandEnvelope` and `EventEnvelope` already enforce, reused, not
reinvented.

Contract stays **0.5**: a correctness tightening of an existing invariant on an
unmerged, unreleased slice. No state, transition, revision formula, command
mapping, permission or ADR changed.

**FND-003B3A — DONE (2026-09-10).** Physical custody made explicit from shop to
rider. Contract **0.5 → 0.6** (additive).

Custody is its own aggregate with its own revision, and **absence is never read
as "the shop still has it"** — that shortcut is how goods go untracked between
the counter and a rider's bag. A worker custodian is bound to an assignment
*attempt* (principal + assignment id + generation), not to a projection of who
is assigned now, for the same reason `SourcePickerBinding` is.

Two transitions only. `shop → picker` pickup is physical acquisition and
**leaves the order `ready`** — collection is not dispatch. `picker → rider`
receipt is the **dispatch boundary**: one command atomically moves custody,
takes the order `ready → in_delivery`, completes the picker assignment and
removes its `assignedResource`, while the rider assignment stays accepted.

Picker completion is a **consequence, never a command** — there is no
`completePickerAssignment`, because a target state a client can select is
exactly the arbitrary status patch this contract forbids. **B3-C1 is satisfied
by contract tests**, proven from real evaluator output across generations 1–3.
**B3-C2 stays FUTURE**: rider `completed` remains unreachable and no cost for
it was invented.

`reachableSlotRevisionRange` gained an **optional** `role` that defaults to the
pre-0.6 answer, so no existing caller changed behaviour.
`reassignmentSafetyFor` finally derives `ReassignmentSafety` from real custody
without weakening it — unknown and corrupt custody stay unsafe.

Deferred deliberately: `picker.custody.record_handoff` keeps its id but stays
**non-executable**, because making it transfer custody would need a proof
protocol and **no QR, OTP, signature or photo was invented**. Direct
agent→rider pickup remains deferred and RA18 is unreinterpreted. Shop ids were
**not** opaque-validated — nothing in the repository governs them that way, and
existing fixtures use `shop_alpha`, which the rule would reject.

New backend criteria **CA1–CA23**, all **NOT RUN** (CA19–CA23 added by
FND-003B3A-FIX-001).

**FND-003B3A-FIX-001 — DONE (2026-09-10).** Final review of `c29df0f` found five
real gaps and one evidence error, all closed here without redesigning the
accepted custody model. The evaluator compared the three aggregates against each
other but nothing bound them to a **canonical** order, and shop custody was never
bound to the order's shop; the picker and rider **slot revisions** were not
compare-and-set; initialisation was create-once only by documentation; receipt
provenance was under-specified; and exported metadata still called `in_delivery`
and picker `completed` unimplemented after both became reachable. The B3A
report's *"was 522 at branch point"* is corrected to the accepted **520** — 522
was a real mid-task number taken after two tests had already been added, never
the branch point, and no rerun was invented to explain it.

**Remaining slices:**

| Slice | Owns | Status |
|---|---|---|
| FND-003B lifecycle | Order, assignment, custody, attempt, return transitions; inventory effects per edge | **PARTIAL** — B1, **all of B2** and **B3A** done; delivery/refusal/return outstanding |
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
| Wire contract (`cp_contracts`) | **0.6** | FND-003 | Baseline **SHARED-BASELINE-v1.0**. 0.2 (FND-003A) added command/event envelopes, identity, membership, scope, 35 permissions and the authorization model. 0.3 (FND-003B1) adds the pre-dispatch order and reservation lifecycle with typed inventory effects. 0.4 (FND-003B2A) adds the picker assignment lifecycle and the `agent.assignment.revoke_picker` permission. 0.5 (FND-003B2B) adds the picker-originated rider assignment lifecycle, the source-picker binding, the `picker.assignment.offer_rider` and `picker.assignment.revoke_rider` permissions, and moves the role-neutral `AssignmentDenial` and `reachableSlotRevisionRange` into a shared `assignment_integrity.dart` with no name, value or behaviour change. All additive, so minor only. 0.6 (FND-003B3A) adds physical custody — the shop/picker/rider/customer vocabulary, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion, a role-aware `reachableSlotRevisionRange` and custody-derived reassignment safety. All additive, so minor only. **No delivery, refusal, return, customer custody, direct agent-to-rider pickup or money rules yet.** See [version history](../contracts/version-history.md). |

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
