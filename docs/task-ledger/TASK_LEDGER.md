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
| FND-003B3A | ADMIN | Physical custody: shop initialisation, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion | FND-003B2B | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = **`c29df0f` + `18ad750` + `e8dacfc`**, on `main` since FND-003B3A was merged. Reports: [FND-003B3A](FND-003B3A-completion-report.md) + [FIX-001](FND-003B3A-FIX-001-completion-report.md) + [FIX-002](FND-003B3A-FIX-002-completion-report.md) · [custody lifecycle](../contracts/custody-lifecycle.md) · contract **0.6**. Adds **CA1–CA23** (NOT RUN); **satisfies B3-C1** by contract test; **B3-C2 stays FUTURE**. **No earlier commit alone is the accepted contract** |
| FND-003B3A-FIX-001 | ADMIN | Bind custody to canonical resource/shop identity, add picker/rider slot-revision CAS, make custody initialisation create-once, correct exported state metadata and the test-count evidence | FND-003B3A | **DONE** | [FND-003B3A-FIX-001 report](FND-003B3A-FIX-001-completion-report.md) |
| FND-003B3A-FIX-002 | ADMIN | Reconcile contract status across the picker, rider and order documents, the package docs and source comments with what FND-003B3A actually implements | FND-003B3A-FIX-001 | **DONE** | [FND-003B3A-FIX-002 report](FND-003B3A-FIX-002-completion-report.md) · **documentation and source-comment only — zero executable Dart changed** |
| FND-003D1-FIX-001 | ADMIN | Bound the proof-policy reference at 64, stop its `toString` reproducing the raw value, make evidence `belongsTo` fail closed, and correct the stale package version header | FND-003D1 | **DONE** | [FND-003D1-FIX-001 report](FND-003D1-FIX-001-completion-report.md) · [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md) |
| FND-003D1-FIX-002 | ADMIN | Alias the proof-policy ceiling to the canonical `maxIdLength` instead of repeating its literal, and make `DeliveryEvidenceRef.toString` fail safe for malformed instances | FND-003D1-FIX-001 | **DONE** | [FND-003D1-FIX-002 report](FND-003D1-FIX-002-completion-report.md) · [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md) amended |
| FND-003D2A | ADMIN | Mechanism-neutral, trusted-server-produced delivery-proof **assessment** result | FND-003D1 | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = **`6bb23710` + `03c71d0`**, and `main` is now **`03c71d0`** — the FND-003D2A-FIX-001 commit. *(Reconciled by FND-003D2B: the wording below described the pre-merge candidate and was stale. No historical report was rewritten, and the process exception stands unchanged.)* **`6bb23710` alone is NOT accepted**: FND-003D2A-FINAL-REVIEW-001 found technical, maintainability, security and process-evidence defects, all corrected by FND-003D2A-FIX-001. **Known process exception, recorded separately and NOT part of the accepted chain:** a local-only commit `a9f3db98` was amended into `6bb23710` before first publication, so FND-003D2A acceptance criterion 48 (no amend) = **FAIL**; no shared history or CI result was rewritten, and it is a one-time pre-publication exception only — see the process-correction section of the [FND-003D2A report](FND-003D2A-completion-report.md). Reports: [FND-003D2A](FND-003D2A-completion-report.md) + [FIX-001](FND-003D2A-FIX-001-completion-report.md) · [delivery-proof assessment](../contracts/delivery-proof-assessment.md) · [ADR-0009](../decisions/ADR-0009-trusted-immutable-proof-assessment.md) · contract **0.8**. Adds **DPA1–DPA18**, all **NOT RUN** (DPA17 verifier authorization, DPA18 reassessment audit basis, both added by FIX-001). **No command and no permission added** (`Permission.values` stays 38); every order/reservation/inventory/financial/custody/assignment effect is **NONE**. Successful delivery remains **not executable** |
| FND-003D2B | ADMIN | Fallback dispute workflow for a missing, superseded or `notSatisfied` assessment | FND-003D2A | **PARTIAL — FIX REQUIRED / NOT ACCEPTED** | **Neither `b94e5424` nor `ded1aa79` alone is acceptable, and the chain is still not accepted.** FND-003D2B-FINAL-REVIEW-001 found three material defects — a basis standing that certified a **verdict contradiction** as `current`, an **invented `reviewerIsRaiser`** separation-of-duties denial with no accepted contract behind it, and a **record-review-started path coupled to current assessment/order facts it never reads**, which could freeze a validly raised dispute out of review. All three are corrected by **FND-003D2B-FIX-001** (`ded1aa79`). **FND-003D2B-FINAL-REVIEW-002 then found two more**: a basis standing that reported **`superseded` for a higher revision reusing the basis's assessment id** — impossible history under ADR-0009, on a structurally canonical aggregate — and executable evaluators that took a bare `Principal` while only *documenting* that authorization had run, so a **non-owner customer could raise** and a **customer-only principal could review** by calling them directly. Both are corrected by **FND-003D2B-FIX-002** (`f04d453`). **FND-003D2B-FINAL-REVIEW-003 then found one more**: `evaluateRaiseDeliveryProofDispute` could not structurally prove its `OrderLifecycleFacts` belonged to the same order as the grant, dispute and assessment — that accepted type carries **no resource id** — so an order-B read with matching scalars was indistinguishable from order A's. Corrected by **FND-003D2B-FIX-003** (`202a8a9`), whose publication was then **correctly blocked** by FND-003D2B-FIX-003-PUSH-001 over two obsolete current-tense statements about the resource anchor — corrected, documentation-only, by **FND-003D2B-FIX-004** (`45d21e9`). **FND-003D2B-FINAL-REVIEW-004 then found one more**: a current-tense evaluator doc comment still saying the canonical resource *comes from the grant* — missed because the FIX-004 sweep was line-based and the sentence wraps. Corrected, documentation-only, by **FND-003D2B-FIX-005**. Candidate chain = **`b94e5424` + `ded1aa79` + `f04d453` + `202a8a9` + `45d21e9` + the FND-003D2B-FIX-005 commit** on `fnd/FND-003D2B-fallback-proof-dispute-contract`, branched from `main` @ `03c71d0`. **The corrected six-commit candidate requires a new, separate read-only final acceptance review before merge.** Reports: [FND-003D2B](FND-003D2B-completion-report.md) + [FIX-001](FND-003D2B-FIX-001-completion-report.md) + [FIX-002](FND-003D2B-FIX-002-completion-report.md) + [FIX-003](FND-003D2B-FIX-003-completion-report.md) + [FIX-004](FND-003D2B-FIX-004-completion-report.md) + [FIX-005](FND-003D2B-FIX-005-completion-report.md) · [delivery-proof dispute](../contracts/delivery-proof-dispute.md) · contract **0.9** (unchanged by the fix — an in-place correction to an unreleased candidate, not a release event). Adds **DPD1–DPD12**, all **NOT RUN**. **No permission added** (`Permission.values` stays 38); both executable operations use the accepted `customer.dispute.raise` and `admin.dispute.administer` rules unchanged. **No dispute outcome, fault, fee, refund, compensation, liability, return or delivery consequence is decided** — `resolve` is enumerated and always refused `resolutionPolicyDeferred`. Every order/reservation/inventory/financial/custody/assignment **and assessment** effect is **NONE**. Successful delivery remains **not executable** |
| FND-003C | ADMIN | Money slice: payment/COD, cash journal, fees, refusal policy, commissions, settlement | FND-003A, FND-003B | **BLOCKED** | needs owner decision **O6** |
| FND-003D | ADMIN | Proof and dispute slice: proof-satisfaction contract and fallback dispute workflow | FND-003B | **PARTIAL** | parent; the mechanism-neutral proof/evidence **reference** boundary delivered by FND-003D1, the trusted immutable proof **assessment result** by FND-003D2A, and the **fallback dispute workflow** by FND-003D2B (**as corrected by FND-003D2B-FIX-001 through FIX-005, and not yet accepted**). **The proof-satisfaction policy itself is still undone**, so CONSTRAINTS invariant 13 is **not discharged** and delivery confirmation may not be coded. **How a dispute resolves** is separately undecided — blocked on **O6**, FND-003C and FND-003B3B |
| FND-003D1 | ADMIN | Mechanism-neutral delivery-proof policy reference, resource-bound evidence reference and the privacy boundary | FND-003B3A | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = **`913b1ac` + `f615ea6` + `f03fc99`**, fast-forwarded onto `main` by FND-003D1-MERGE-001 (2026-09-10) with no merge, squash, rebase or amend commit. `main` is now **`f03fc99`**. Reports: [FND-003D1](FND-003D1-completion-report.md) + [FIX-001](FND-003D1-FIX-001-completion-report.md) + [FIX-002](FND-003D1-FIX-002-completion-report.md) · [delivery-proof boundary](../contracts/delivery-proof-boundary.md) · [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md) · contract **0.7**. **No earlier commit alone is the accepted contract.** **References only** — no proof mechanism, no satisfaction rule, no command, state, event or permission. Successful delivery remains **not executable** |
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

**FND-003D1 — DONE (2026-09-10).** The smallest dependency-safe prerequisite for
delivery confirmation: a way to *refer to* proof policy and protected evidence
without embedding proof material in events, treating a reference as proof, or
committing the platform to a method. Contract **0.6 → 0.7** (additive).

`DeliveryProofPolicyRef` says **which** immutable policy applies, never that it
was satisfied, and imposes **no grammar** — the repository has no policy
vocabulary to reuse, and inventing one would be inventing a contract.
`DeliveryEvidenceRef` carries an opaque evidence id **bound to its order**, so
evidence cannot be presented against a different one; it holds **no material**
and is not a storage locator. Both preserve exact values and repair nothing.

**Nothing became executable.** No command, state, transition, event or
permission was added; `OrderState.delivered`, `CustodyHolderKind.customer` and
rider `AssignmentState.completed` all remain unreachable, re-pinned by
regression test. A source-level test strips doc comments and asserts no proof
mechanism — OTP, QR, barcode, signature, photo, video, GPS, biometric,
attestation — and no material, locator or status vocabulary appears in the code.

**Dependency note.** FND-003D was previously recorded as depending on the whole
of FND-003B, which was a coarser dependency than the work requires: this
reference boundary needs only the accepted FND-003B3A custody contract, so the
slice was safely taken now rather than waiting on delivery/refusal/return.
**FND-003D is now PARTIAL, not complete** — proof satisfaction and the fallback
dispute workflow are still undone and remain required by `CONSTRAINTS.md`
invariant 13 before delivery confirmation may be coded.

Retention, visibility, deletion/legal-hold, satisfaction policy, the dispute
workflow and whether customer participation is required are all recorded
**DEFERRED, never defaulted**. Financial consequences remain **UNKNOWN /
DEFERRED TO FND-003C**, blocked on **O6**.

**FND-003D1 — ACCEPTED AND INTEGRATED (2026-09-10).** FND-003D1-MERGE-001
fast-forwarded `main` from `e8dacfc` to **`f03fc99`**, preserving the reviewed
three-commit linear history — no merge, squash, rebase or amend commit exists,
and the feature branch was preserved. Live GitHub inspection at merge time found
`main` **unprotected with no rulesets**, which is why a direct fast-forward was
permitted; that is not a substitute for **O7**, which stays outstanding.

**FND-003D2A — DONE (2026-09-10).** The missing half of the proof prerequisite:
somewhere to record **whether** the referenced policy was satisfied. Contract
**0.7 → 0.8** (additive).

An assessment is a **trusted-server-produced, immutable result**, not a claim.
`executableProofAssessorKinds` is exactly `{PrincipalKind.systemWorker}`, and
**no command and no permission was added** — `Permission.values` stays at 38.
There is no `customer.proof.accept`, no `rider.proof.mark_satisfied`, no
`admin.proof.override` and no generic proof-status setter, because a
client-selectable "declare proof satisfied" operation would be exactly the
arbitrary status patch this contract forbids, aimed at the one status that gates
delivery, custody handover and eventually money. The precedent is
`initialiseCustodyAtShop`, which has no command either.

**A pure Dart record cannot authenticate its own origin**, and a test proves a
forged `satisfied` record is structurally well formed — because it is. The
backend must ignore client-supplied assessments; only one loaded from trusted
state may later authorize progression. That honesty is criteria **DPA1**/**DPA2**,
NOT RUN.

Two verdicts, `satisfied` and `notSatisfied`, and **no `pending`**: absence
already means *not assessed*, and a verifier's job queue is backend operational
state rather than domain truth. `notSatisfied` means only that the policy was
not satisfied — **not** fraud, refusal, cancellation, delivery failure, a lost
dispute, a fee, a refund or financial default.

Reassessment is **append-only**: a new opaque `assessmentId`, revision `r → r+1`,
and a `supersedesAssessmentId` backward pointer. Nothing is mutated, relabelled
or erased — there is no `setAssessmentStatus`, `overrideVerdict` or `copyWith` —
because FND-003D2B has to be able to point at "the assessment that was current
when X happened" and have that mean something.

The assessment has its **own** `assessmentRevision`, and the request pins four
revisions (assessment, order, custody, rider slot) because the decision depends
on all four. **Correct revisions never bypass identity, state, reference or
binding checks** — a test supplies every correct revision alongside the wrong
rider and still gets a denial.

**Every commercial effect is NONE, structurally**: the transition type has no
order, custody or assignment effect field, so one that moves them cannot be
constructed. `OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable, and **no rider completion
cost was invented** — **B3-C2** stays FUTURE. The financial classification
describes the *recording*; whether a `notSatisfied` outcome ever costs anyone
anything is **UNKNOWN and deferred to FND-003C**, blocked on **O6**, never zero.

**No proof mechanism was selected** — no OTP, QR, barcode, signature,
photograph, video, GPS, biometric or attestation — and **no evidence cardinality
was invented**: the record carries the single D1 `DeliveryEvidenceRef`. Customer
participation stays **POLICY-DEFINED / DEFERRED**, with no `customerConfirmed`
flag that would default the answer, and `customer.delivery.confirm_proof` keeps
its exact participation-only meaning.

New backend criteria **DPA1–DPA16**, all **NOT RUN**. **FND-003D stays PARTIAL**
— the satisfaction *policy* and the dispute workflow (**FND-003D2B**) are
undone, so `CONSTRAINTS.md` invariant 13 is **not** discharged and delivery
confirmation still may not be coded.

**FND-003D2A-FIX-001 — DONE (2026-09-10).** FND-003D2A-FINAL-REVIEW-001 found
five real defects in the unreleased 0.8 candidate plus one process-evidence
failure. All are corrected in one follow-up commit; **the contract stays at
0.8**, because this is an in-place correction to an unmerged, unreleased
candidate, not a release event.

The security defect was the important one. **`PrincipalKind.systemWorker` is a
broad infrastructure class** — the outbox drain, reservation expiry and
scheduled reconciliation all hold it — and the evaluator accepted *any*
structurally valid system worker. That made the verdict which later gates
delivery mintable by an unrelated job. The evaluator now takes the assessor as a
**separate server-derived `Principal`** and requires it to equal the resource's
`authorizedAssessorPrincipalId`, resolved from trusted state, with a distinct
`assessorAuthorityMismatch` denial. The request's assessor fields were
**removed** rather than kept for compatibility: a payload that names its own
authorizer is not a check.

Three public accessors failed **open** and now fail closed: `bindsRiderAttempt`
matched identically-malformed values; `currentVerdict` read straight off raw
facts so a **torn aggregate could expose `satisfied`** (replaced by
`canonicalVerdict`, which requires the validator to accept the facts, and which
never downgrades corruption to `notSatisfied`); and `toString` echoed raw fields
of malformed values before validation. `events` was a caller-supplied list and
is now a fixed `const` single-element getter. Each fix carries a **negative
control** — reverting it makes a specific named test fail.

The 980-line module and 1455-line test file were split by responsibility behind
a **stable barrel**, so the public `cp_contracts` surface is unchanged. New
criteria **DPA17** (backend must authorize an explicit proof-verifier service
identity; generic worker status insufficient) and **DPA18** (a verdict-changing
reassessment retains an immutable audit basis) are both **NOT RUN**.

**Process exception, recorded and not repeated.** Before this branch was first
published, a local-only commit `a9f3db98` was amended into `6bb23710` to remove
a `<D2A>` ledger placeholder. FND-003D2A acceptance criterion 48 (no amend) is
therefore **FAIL** and must never be cited as PASS. No shared history, reviewer
history or CI result was rewritten — `a9f3db98` was never pushed. It is accepted
as a **one-time, pre-publication** exception and grants no licence to amend
anything else; FIX-001 itself used one new normal commit.

**FND-003D2B — DONE (2026-09-11).** The other half of `CONSTRAINTS.md`
invariant 13: what happens when the assessment a delivery would need is
**missing, superseded or `notSatisfied`**. Contract **0.8 → 0.9** (additive).

A dispute is raised by the order's customer against the **current canonical**
proof situation, and pins an **immutable basis** — an assessment id and revision,
or canonical absence — that is never rewritten afterwards. That is exactly what
ADR-0009 made append-only history for: `resolveDeliveryProofDisputeBasis
Standing` can then report `current`, `superseded` or `indeterminate` **without
touching anything**, so a reassessment makes supersession *observable* rather
than making the disputed verdict unfindable. A later `satisfied` assessment does
**not** dismiss the dispute — deciding that would be deciding the outcome.

**The five proof situations stay distinct**, and that is the slice's central
negative: canonical absence, current `notSatisfied`, a superseded basis, a
**torn** aggregate and current `satisfied` each have their own answer.
Corruption denies `assessmentAggregateInconsistent` and is **never** laundered
into `notSatisfied` or into a valid dispute basis; a `satisfied` assessment
denies `assessmentSatisfied`, because contesting a satisfied verdict is a
different workflow no slice defines — refusing it is what keeps this from
becoming general support-case infrastructure.

**Nothing resolves.** `DeliveryProofDisputeCommand.resolve` is enumerated and
always refused `resolutionPolicyDeferred` **before any fact is read**, and
`DeliveryProofDisputeState.resolved` is unreachable with **no revision cost
invented** — the same discipline as rider `completed` and **B3-C2**. Resolution
would mean deciding who prevails, whether the order is delivered, refused or
returned, whether a fee, refund, compensation or liability follows and who bears
it, whether stock is restored, and whether customer participation is optional,
mandatory, sufficient or a veto. **None of those is decided anywhere**, so none
was guessed. Withdrawal, closure, expiry, escalation and SLAs are equally absent.

**No permission was added** — `Permission.values` stays **38**. Both executable
operations map to the accepted `customer.dispute.raise` (`ownResource`, reason
required) and `admin.dispute.administer` (`ownRegion`, reason required) rules,
unchanged, and `customer.delivery.confirm_proof` is **not** reinterpreted. The
dispute record holds **no free text**: the required reason stays with the
audited command in FND-003A, because a second copy is a second place to drift
and a customer-supplied string on a wire-facing value is the one route by which
a description of proof material could reach an event payload.

Custody and the rider assignment are deliberately **not** in the read-set. A
dispute asserts nothing about a rider, and requiring current custody would make
the fallback unavailable exactly when custody has gone wrong — the opposite of a
fallback. Possession is not an authorization source in either direction.

Every order, reservation, inventory, financial, custody, assignment **and
assessment** effect is **NONE**, structurally: the transition type has no field
for any of them. `OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable. New backend criteria
**DPD1–DPD12**, all **NOT RUN**.

**FND-003D stays PARTIAL**: the proof-satisfaction **policy itself** is still
undone, so invariant 13 is **not** discharged and delivery confirmation still
may not be coded.

**FND-003D2B-FIX-001 — DONE (2026-09-11).** FND-003D2B-FINAL-REVIEW-001 found
three material defects in the unreleased 0.9 candidate. All are corrected in one
follow-up commit; **the contract stays at 0.9**, because this is an in-place
correction to an unmerged, unaccepted candidate rather than a release event.

**Two of the three were the contract asserting more than it had been told.**

The first was a fail-open. `resolveDeliveryProofDisputeBasisStanding` compared
only the assessment **id and revision**, so a basis recorded as `notSatisfied`
against assessment A revision 1 was reported as **`current`** even when the
canonical A/1 now read `satisfied`. ADR-0009 gives every reassessment a new id
and the next revision, so that pairing is a contradiction the history cannot
produce — and certifying it as current is exactly the wrong direction to fail on
the value a dispute is anchored to. The same-revision comparison now also
requires the canonical verdict to still be `notSatisfied`; a mismatch is
`indeterminate`, is **not** converted to `superseded` (nothing superseded it) or
to `notSatisfied` (nobody reached that verdict), and the basis is not rewritten.

The second was an **invented rule**. The candidate denied `reviewerIsRaiser`
when the reviewing principal had earlier raised the dispute, and the D2B report
flagged it as a "deliberate tightening" with the dual-control precedent. That
reasoning does not survive contact with the accepted matrix:
`admin.dispute.administer` requires an active admin membership, `ownRegion`
scope and a stored reason, and carries **`approvalRequired: false`**. Nothing
asks for separation of duties, so refusing on identity alone was a policy
decided nowhere — precisely what this repository forbids. It is removed from the
evaluator, the record validator, the denial vocabulary (**20 → 19**), the tests
and the documentation, and recorded as **DEFERRED**: if separation of duties is
ever wanted it needs its own permission and ADR.

The third was **hidden coupling**. A single evaluator took every aggregate for
every operation, and a shared read-set silently becomes a shared *precondition*:
recording that review started required a canonical current assessment, a
canonical current order, the order revision, `in_delivery` and `committed` —
**none of which it reads or changes**. A reassessment or a torn assessment read
after a validly raised dispute could therefore freeze it out of review, which is
the opposite of what a fallback is for. There is now **one evaluator per
operation, each taking only its own read-set**: raise (resource, dispute,
assessment, order), review (resource, dispute) and resolve (**no arguments at
all** — a deferred edge consumes nothing). The independence is enforced by the
type system: a call that hands review an assessment or an order does not
compile. **Nothing about delivery, refusal or return may be inferred from it.**

The test helper `basisFrom` was also removed: it mirrored production eligibility
logic and would manufacture a `notSatisfied` basis from a **satisfied**
assessment — a state the evaluator can never produce, and the very contradiction
the standing calculation now rejects. Canonical positive bases come from a real
evaluator-produced raise.

Each correction carries a negative control, and all evidence classifications are
unchanged: **DPD1–DPD12 remain NOT RUN**, `Permission.values` stays **38**,
resolution stays non-executable, every effect stays NONE, and `delivered`,
customer custody and rider `completed` stay unreachable. **The corrected
two-commit candidate is not accepted for merge** — it requires a new, separate
read-only final acceptance review.

**FND-003D2B-FIX-002 — DONE (2026-09-11).** FND-003D2B-FINAL-REVIEW-002 found
two further defects in the same unreleased 0.9 candidate. Both are corrected in
one follow-up commit; **the contract stays at 0.9**.

**The second one is the serious one, and it was a real bypass.** The executable
evaluators took a server-derived `Principal` and *documented* that
`evaluateAuthorization` had already run — but a pure function cannot assert
anything about its caller. Nothing in either signature distinguished an
authorized call from one that skipped the check, so a customer who owned nothing
could reach a raise transition, and a customer-only principal could reach a
review transition. A FIX-001 test had even *asserted* that bypass as intended
behaviour ("authorization already ran, and re-running it here would create a
second place for it to drift") — the reasoning was right about policy and wrong
about proof.

FND-003A had already built the artifact that closes this, for exactly this
purpose: `AuthorizationGrant` is `final`, has a library-private constructor and
is obtainable **only** from a successful `evaluateAuthorization`. Both operations
now require one, and `checkDisputeAuthorization` verifies it is bound to **this
principal, this permission and this resource** — the same three bindings
`ApprovalEvidence` needs. **No policy is re-decided**: role, membership status,
scope and reason stay in `permissionMatrix`, which is neither copied nor
changed, and an out-of-region admin or one with no reason simply never obtains a
grant to present. One generic `authorizationGrantMismatch` denial (19 → **20**)
keeps refusals unprobeable. **Raising confers no admin authority** — the
historical raiser reaches review only by independently holding an admin grant,
and no separation-of-duties rule returned. Freshness remains **R33–R40**, NOT
RUN: a grant proves the decision was made, not that it is still current.

`DeliveryProofDisputeContext` was **removed** rather than kept alongside it: the
grant already names the canonical resource, and two sources of resource truth
could disagree.

The first defect was the standing calculation again, in the other direction.
FIX-001 stopped a same-revision **verdict** contradiction; this stops a
**higher-revision identity** one. Any revision above the basis was reported
`superseded`, including a revision-2 record that reused the exact assessment id
the basis pinned. ADR-0009 gives every reassessment a new opaque id, so that is
impossible history — and the aggregate is **structurally canonical**, which is
why no shape check caught it. It now answers `indeterminate`, using the current
record only: no in-memory history array and no global uniqueness lookup, because
uniqueness across superseded records is **DPA11**, NOT RUN.

Both corrections carry negative controls (**NC4**, **NC5**), and the earlier
NC1–NC3 protections were re-verified after the restructure. All evidence
classifications are unchanged: **DPD1–DPD12 remain NOT RUN**,
`Permission.values` stays **38**, resolution stays non-executable and
zero-argument, every effect stays NONE, and `delivered`, customer custody and
rider `completed` stay unreachable. **The corrected three-commit candidate is
not accepted for merge.**

**FND-003D2B-FIX-003 — DONE (2026-09-11).** One material defect, plus the
documentation drift FIX-002 left behind. **Contract stays 0.9.**

**The accepted `OrderLifecycleFacts` carries no resource id.** That is correct
for the pre-dispatch evaluator, which is handed one order and asked about that
order — but a dispute raise must prove that *four* independently supplied things
describe the **same** delivery, and the order read was the one that could not
say which order it was for. An order-B read whose scalars matched order A —
`in_delivery`, revision 5, reservation `committed` — was indistinguishable from
A's own facts, so a dispute could be recorded against A on the strength of B's
lifecycle. **Numeric equality is not identity**, and this is the third time this
slice has had to learn that identity must be checked in every direction.

A small D2B-scoped `DeliveryProofDisputeOrderRead` binds the facts to the order
they were read for. It is a **read, not a second order aggregate**: no state, no
transition, no revision arithmetic, no lifecycle rule, and **the accepted
`OrderLifecycleFacts` contract is untouched** — changing it would have been a
far larger, ADR-bearing decision than this correction needs.

The same commit removes a **tautology**: `checkDisputeAuthorization` compared
the grant's resource against a value the grant itself supplied, while being
documented as proving the resource binding. The helper now takes an
`expectedResourceId` from the read-set, and the canonical anchor is the **stored
dispute aggregate's** resource, which the grant must cover.

Review is untouched and still reads only the grant and the dispute; resolve is
untouched and still takes zero arguments. **Binding is not provenance** — that
the backend loads every aggregate for one resource in one consistent transaction
is **DPD3**/**DPD4**, both **NOT RUN**. `Permission.values` stays **38**, every
effect stays NONE, and `delivered`, customer custody and rider `completed` stay
unreachable. **NC6** proves the new binding can fail; **NC1–NC5** were
re-verified. **The corrected four-commit candidate is not accepted for merge.**

**FND-003D2B-FIX-004 — DONE (2026-09-11). Documentation and source-comment
only; zero executable Dart changed.** FND-003D2B-FIX-003-PUSH-001 refused to
publish `202a8a9`, and it was right to: the push task gated publication on a
documentation check, and that check failed. Two current-tense statements still
said the **authorization grant** supplies the canonical resource — wording
FIX-002 had been correct to write and FIX-003 had already superseded, because
comparing a grant against a value the grant itself supplied proves nothing.

The shipped code says `final String resourceId = dispute.resourceId;` in both
evaluators: **the persisted dispute aggregate anchors the canonical operation
resource, and the grant must cover it.** For a raise the assessment aggregate
and the resource-bound order read must identify that same anchor before any
order fact can produce a transition. The two statements — in
`docs/contracts/delivery-proof-dispute.md` and the
`delivery_proof_dispute_facts.dart` doc comment — now say that, and the
superseded framing is retained only where explicitly labelled **Historical**.

**No behaviour changed.** A comment-stripped diff of the one modified Dart file
is byte-identical, and `ContractVersion.current` stays **0.9**. Every accepted
invariant is untouched: `Permission.values` **38**, review still grant +
dispute, resolve still zero-argument, all effects NONE, two events, and
`delivered`, customer custody and rider `completed` unreachable. All
DPD/DPA/CA/R/L/P/RA criteria remain **NOT RUN**. **The five-commit candidate is
still not accepted for merge.**

**FND-003D2B-FIX-005 — DONE (2026-09-11). Documentation, source-comment and
evidence only; zero executable Dart changed.** FND-003D2B-FINAL-REVIEW-004 found
one surviving current-tense doc comment in
`delivery_proof_dispute_evaluator.dart` — *"The canonical resource comes from
the grant."* — under the review evaluator's own **"What it does check"** heading,
directly above an implementation that reads `final String resourceId =
dispute.resourceId;`.

**The interesting part is why FIX-004's sweep missed it.** Not a file it forgot:
FIX-004 listed that very file. Its sweep was a **line-based `grep`**, and the
sentence **wraps across two lines**. Its own regex matches the sentence when
unwrapped and cannot match it across a newline — demonstrated mechanically, 0
matches line-based versus 1 unwrapped. A prose sweep that cannot see past a line
break will keep missing wrapped prose, which is most prose. FIX-005 therefore
re-ran the sweep with comment markers stripped and whitespace collapsed, and
against **semantic ideas** — *comes from / supplies / provides / chooses /
anchors / selects / determines the resource*, *resource identity from the
grant*, *grant is the source of resource truth* — rather than two literal
strings.

That broader sweep found **six** remaining matches across the sixteen current
D2B locations, **all** in explicitly historical or descriptive material: two
under `**Historical.**` markers, three inside dated FIX-002/FIX-003/FIX-004
changelog blocks in `version-history.md`, and none in a current API description.
The evaluator now states that the **stored dispute aggregate anchors** the
canonical resource and the grant must **cover** it.

The FIX-004 report's sweep claim is **annotated, not rewritten**: its assertion
was true of the two literal strings it searched and incomplete as a general
claim, and that is recorded in place.

**No behaviour changed.** The comment-stripped source of the one modified Dart
file has an **identical SHA-256** before and after, and `ContractVersion.current`
stays **0.9**. Every accepted invariant holds: `Permission.values` **38**, the
four-way raise binding, review as grant + dispute only, resolve zero-argument,
all effects NONE, two events, and `delivered`, customer custody and rider
`completed` unreachable. All DPD/DPA/CA/R/L/P/RA criteria remain **NOT RUN**.
**The six-commit candidate is still not accepted for merge.**

**Remaining slices:**

| Slice | Owns | Status |
|---|---|---|
| FND-003B lifecycle | Order, assignment, custody, attempt, return transitions; inventory effects per edge | **PARTIAL** — B1, **all of B2** and **B3A** done; delivery/refusal/return outstanding |
| FND-003C money | Payment/COD, cash journal, fees, refusal policy, commissions, settlement | **BLOCKED on O6** |
| FND-003D proof/dispute | Proof-satisfaction policy and fallback dispute workflow | **PARTIAL** — the reference/privacy boundary (FND-003D1), the trusted assessment **result** (FND-003D2A) and the **fallback dispute workflow** (FND-003D2B) are done; the **proof-satisfaction policy itself** is **not**, and is still needed before delivery confirmation is coded |
| Dispute resolution | How a fallback dispute resolves, and any delivery/refusal/return/money consequence | **NOT STARTED / DEFERRED** — enumerated and refused by FND-003D2B; needs **O6**, FND-003C and FND-003B3B |

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
| Wire contract (`cp_contracts`) | **0.9** | FND-003 | Baseline **SHARED-BASELINE-v1.0**. 0.2 (FND-003A) added command/event envelopes, identity, membership, scope, 35 permissions and the authorization model. 0.3 (FND-003B1) adds the pre-dispatch order and reservation lifecycle with typed inventory effects. 0.4 (FND-003B2A) adds the picker assignment lifecycle and the `agent.assignment.revoke_picker` permission. 0.5 (FND-003B2B) adds the picker-originated rider assignment lifecycle, the source-picker binding, the `picker.assignment.offer_rider` and `picker.assignment.revoke_rider` permissions, and moves the role-neutral `AssignmentDenial` and `reachableSlotRevisionRange` into a shared `assignment_integrity.dart` with no name, value or behaviour change. All additive, so minor only. 0.6 (FND-003B3A) adds physical custody — the shop/picker/rider/customer vocabulary, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion, a role-aware `reachableSlotRevisionRange` and custody-derived reassignment safety. All additive, so minor only. 0.7 (FND-003D1) adds mechanism-neutral delivery-proof **references** — `DeliveryProofPolicyRef`, `DeliveryEvidenceRef`, their structural validators and `DeliveryProofDenial`. 0.8 (FND-003D2A) adds the delivery-proof **assessment result** — `DeliveryProofAssessmentVerdict` (`satisfied` / `notSatisfied` only), the immutable `DeliveryProofAssessmentRecord`, its aggregate, context, request, transition, outcome and denial vocabulary, `validateDeliveryProofAssessmentAggregate`, `evaluateDeliveryProofAssessment`, `executableProofAssessorKinds` and one event id. All additive, so minor only. 0.9 (FND-003D2B) adds the **fallback delivery-proof dispute** — `DeliveryProofDisputeState` and `reachableDisputeRevisionFor`, the immutable `DeliveryProofDisputeBasis` with its `current`/`superseded`/`indeterminate` standing, three named commands of which `resolve` is **never executable**, two event ids, the record, aggregate, context, request, transition, outcome and denial vocabulary, `validateDeliveryProofDisputeAggregate`, `canonicalState`/`canonicalBasis` and `evaluateDeliveryProofDispute`. Additive: nothing defined at 0.8 changed meaning, and **no permission was added**. **No delivery, refusal, return, customer custody, direct agent-to-rider pickup, proof mechanism, proof-satisfaction policy, dispute outcome or money rules yet.** See [version history](../contracts/version-history.md). |

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
