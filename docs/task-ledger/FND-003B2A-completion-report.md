# FND-003B2A completion report

- **Task:** First bounded sub-slice of FND-003B2 — picker assignment lifecycle
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `main` @ `d14c9e12690b2b2deced752309437f516ac7375a`
- **Branch:** `fnd/FND-003B2A-picker-assignment-lifecycle`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.3 → **0.4**
- **Status:** **DONE**

## 1. Baseline

`main` matched the expected SHA exactly. Working tree was **clean**, so **no
`git reset --hard` was used** — the branch was created with `git switch -c`.

## 2. Contract version

**0.3 → 0.4.** `isVersionCompatibleWith` keys on major only; the documented
rule is minor-for-additive. 0.3 contained no assignment types, so nothing could
be reinterpreted.

**No payload-compatibility claim.** `cp_contracts` still has no serialization,
so a 0.3 build could not decode a 0.4 assignment payload even in principle.
Version policy and payload decoding remain separate.

## 3. Assignment model

**Slot** — one logical picker position per order, holding at most one attempt,
with `slotRevision` as concurrency control (increments on **every** mutation).

**Attempt** — immutable history: opaque `assignmentId`, `generation`, state,
offer recipient, nullable accepted assignee, `timeoutPolicyRef`.

`generation` and `slotRevision` do different jobs: a decline advances the
revision but not the generation; a re-offer advances both.

Executable states: `offered`, `accepted`, `declined`, `expired`, `revoked`.
**Declared but unreachable:** `AssignmentState.completed` (depends on custody —
FND-003B3) and `AssignmentRole.rider` (FND-003B2B). Tests prove no transition
produces `completed`, no command names a rider, and every event starts
`picker.`.

## 4. Offer eligibility

Order must be `accepted`, `preparing` or `ready` — re-read for **every**
command, so a stale offer cannot be accepted after the order goes terminal.
`placed`, `rejected`, `cancelled`, `inDelivery`, `delivered` are all ineligible.

Target must be a human principal whose membership names *them*, role `picker`,
status `active`, region matching the order's — absence is not a match on either
side. Agent shop scope stays with FND-003A's `ownShop`.

`PickerEligibility` is documented as **the shape the backend fills from trusted
storage, not itself proof of trust**. Deliberately not modelled: workload,
ratings, distance, availability scoring, shift rules — dispatch policy, not
lifecycle.

## 5. Offer recipient versus accepted assignee

Separate fields. Offering populates `offeredPrincipalIds` and **never**
`assignedPrincipalIds`. Accepting moves offered→assigned. Decline and expiry
remove offered without assigning. Revoke removes assigned.

**No identity is erased when an attempt ends** — a revoked attempt still
records who held it. `ScopeProjectionEffect` is typed, so a test asserts an
offer never grants assigned scope. The projections are documented as **derived
authorization facts**, rebuilt from the record, never a replacement for it.

## 6. Transition matrix

Full matrix with preconditions, revision/generation rules, projection effects
and events: [picker-assignment-lifecycle.md](../contracts/picker-assignment-lifecycle.md).

**Every transition: inventory NONE, financial NONE IN THIS SLICE, custody
NONE.** The FND-003B1 reservation is untouched, and accepting creates no COD
liability, commission or settlement.

## 7. Expiry

Offers carry `timeoutPolicyRef` — an immutable versioned reference. **No
numeric duration exists anywhere.** The backend resolves it against server UTC
and supplies `expiryDue`, which **defaults to `false`** so expiry fails closed;
a client cannot force an early expiry. Worker-driven: `requiredPermission` is
`null`, and a system principal is denied every human-role permission.

## 8. Accept versus expiry race

**Accept first** → later expiry denied (`wrongAssignmentState`); assignment
stands. **Expiry first** → later accept denied; no active accepted picker, and
the agent may offer a new generation. The loser holding the pre-race revision
gets `slotRevisionConflict`. Tested in both orderings with an
`activeAcceptedCount` assertion each way.

## 9. Controlled reassignment

Two explicit transitions — `accepted → revoked`, then a **new** offer with a
new opaque `assignmentId` and `generation + 1`. **No assignee overwrite exists**;
a test asserts no command type contains `set_`, `status`, `replace` or
`assignee`.

New permission `agent.assignment.revoke_picker`: agent only, active membership,
`ownShop` scope, **reason required**, approval not required. Its restriction
text states it cannot override custody safety.

**The no-custody gate:** revocation requires `ReassignmentSafety.provenNoCustody`.
`blockedOrUnknown` — the **default** — denies with `reassignmentUnsafe`.
**Unknown is not safe.** No custody state is implemented here; FND-003B3 will
map real facts onto this.

## 10. Exactly-one invariants

At most one live offer (`liveOfferExists`) and at most one active accepted
picker (`activeAcceptedAssignmentExists`) per order. A full cycle test walks
offer → accept → revoke asserting `activeAcceptedCount` never exceeds 1, and
that a second accept creates nothing.

Documented as an **initial foundation invariant**, not a claim that
parallel-offer dispatch can never exist: supporting it later needs an explicit
ADR, and `expired`/`declined` must not be repurposed to simulate it.

## 11. Aggregate integrity

Validation runs **before any effect**, following the FND-003B1 lesson.
Canonical shapes per state, plus opaque id, `generation >= 1`, non-blank
`timeoutPolicyRef`, non-empty recipient, and slot-revision coherence. 14
malformed shapes tested — including `accepted` with no assignee and `accepted`
by someone other than the recipient — each producing **no transition** for
**every** command. The validator **does not repair**; a test asserts the facts
are unchanged after refusal.

## 12. Stale, duplicate and reordered

Identity is checked before generation, both before state, so a command is never
applied to whatever is in the slot just because the order id matched. The
worked case from the spec — delayed *"accept generation 1"* arriving after
generation 2 was offered — denies with `assignmentIdMismatch` and mutates
nothing.

Ten duplicate/reordered scenarios tested, plus stale `slotRevision` against
every mutating command and every command with no attempt present. All produce
`transition == null`. Command idempotency remains **FND-003A's**.

## 13. Validation

| Command | Result |
|---|---|
| baseline branch / SHA / clean tree | **PASS** — `d14c9e1`, clean, no reset |
| `dart test test/picker_assignment_test.dart` | **PASS** — **24** |
| `dart test test/picker_assignment_race_test.dart` | **PASS** — **20** |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **36** |
| `dart test` permission matrix + authorization | **PASS** — **66** |
| `dart run tool/print_permission_matrix.dart` + drift check | **PASS** — 36 rows, **no drift** |
| `dart test` all `cp_contracts` | **PASS** — **306** (was 225) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **347 across 10 of 15 members** (was 266) |

No FND-002 platform/device check was rerun. No accepted FND-003A or FND-003B1
review suite was rerun for reassurance — the repository gate naturally
re-executes them, and that is **not** offered as fresh verification of
previously accepted work.

Two pre-existing tests pinned `'0.3'` and were updated for the deliberate bump,
plus a new 0.3 ↔ 0.4 policy test that still makes no payload claim.

## 14. Future backend acceptance

**R33–R40 remain NOT RUN. L1–L13 remain NOT RUN.** Neither was treated as a
blocker.

Added **P1–P16** for picker assignment, all **NOT RUN**: target eligibility from
trusted storage, ineligible targets, region, recipient-only accept/decline,
one-live-offer, one-active-accepted, the race, stale id/generation/revision,
new-id-and-generation after terminal, delayed old-generation commands,
revoke requirements, custody-unknown failing closed, atomic projection+outbox,
aggregate reconciliation, order-cancellation serialization, and concurrent
one-accepted-picker.

## 15. Order / custody boundary

The evaluator **reads** the current trusted order state but implements no order
transitions. Recorded rather than guessed: FND-003B1 permits cancellation from
`accepted`, so an order cancellation can race an assignment operation. Once
custody exists, that safety is decided by **FND-003B3** and later policy; no
backend may assume "accepted assignment means custody" or the reverse. This is
backend serialization requirement **P15** and does not block this task.

## 16. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/assignment_state.dart` | **new** — states and roles, executable vs declared-future |
| `packages/contracts/lib/src/assignment_effect.dart` | **new** — `ScopeProjectionEffect`, `CustodyClassification`, `ReassignmentSafety` |
| `packages/contracts/lib/src/assignment_command.dart` | **new** — named commands and event ids |
| `packages/contracts/lib/src/picker_assignment.dart` | **new** — attempt/slot/eligibility model, aggregate validator, evaluator |
| `packages/contracts/lib/src/permission.dart`, `permission_matrix.dart` | `agent.assignment.revoke_picker` |
| `packages/contracts/lib/src/contract_version.dart` | 0.3 → 0.4 |
| `packages/contracts/lib/cp_contracts.dart` | export the new surface |
| `packages/contracts/test/support/picker_assignment_fixtures.dart` | **new** — fixtures |
| `packages/contracts/test/picker_assignment{,_race,_integrity}_test.dart` | **new** — 24 / 20 / 36 |
| `packages/contracts/test/{contract_version,command_envelope}_test.dart` | version pin 0.3 → 0.4 |
| `docs/contracts/picker-assignment-lifecycle.md` | **new** — canonical doc |
| `docs/contracts/permission-matrix.md` | regenerated from the canonical generator |
| `docs/contracts/README.md`, `version-history.md` | index and 0.4 history |
| `docs/task-ledger/TASK_LEDGER.md` | FND-003B2A/B2B entries |
| `docs/task-ledger/FND-003B2A-completion-report.md` | this report |

Untouched: apps, backend, infra, notification/auth adapters, order-reservation
lifecycle semantics, `pubspec.yaml`, `pubspec.lock`. **No dependency added.**

## 17. Ledger

FND-003B2A **DONE**. **FND-003B2 parent PARTIAL** (not done). **FND-003B2B
(rider) recorded, NOT STARTED.** FND-003B parent stays PARTIAL; FND-003B3 NOT
STARTED; FND-003C **BLOCKED on O6**; FND-003D unchanged; FND-004 unchanged.

## 18. Out of scope

Rider assignment lifecycle, physical custody, pickup/handoff, rider receipt,
delivery attempts, returns, delivery confirmation, proof/dispute, payment/COD,
cash journal, fees, commissions, settlement — none defined or guessed. No
timeout duration invented.

## 19. Scope statement

Contract and tests only. No backend handler, no Firestore rule, no application
feature, no platform dependency. Nothing merged to `main`, pushed or deployed.
**FND-003B2B and FND-003B3 not started.**
