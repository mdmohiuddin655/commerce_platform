# FND-003B3A completion report

- **Task:** First bounded sub-slice of FND-003B3 — physical custody acquisition
  and the normal picker→rider handoff
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `main` @ `bfec4bea5dbfbc7316d10db9a898673111a4db68`
- **Branch:** `fnd/FND-003B3A-custody-handoff-contracts`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.5 → **0.6**
- **Status:** **DONE**

## 1. Baseline

`origin/main` matched the required SHA exactly. Working tree was **clean**
including untracked files, so **no `git reset --hard` was used** — the branch
was created with `git switch -c` from verified main. All required documents and
the R/L/P/RA/B3-C series were reviewed before editing.

## 2. Contract version

**0.5 → 0.6, additive.** No payload-compatibility claim: `cp_contracts` still
has no serialization, so a 0.5 build could not decode a 0.6 custody payload
even in principle.

**The one changed signature is additive.**
`reachableSlotRevisionRange(generation, state)` became
`reachableSlotRevisionRange(generation, state, {AssignmentRole? role})`, and
`role` defaults to null — which returns **exactly** the pre-0.6 answer,
`completed → null` included. Every existing call site compiles unchanged and
behaves identically; a test pins that across every state and generations 1–4.

Two states became *reachable* — `OrderState.inDelivery` and picker
`AssignmentState.completed` — but both were already declared, and **neither is
entered by any command a client may select**.

**Migration:** NOT APPLICABLE / NOT RUN — no Firestore persistence exists for
this lifecycle. **Rules: NOT IMPLEMENTED. Indexes: NOT IMPLEMENTED.
Deployment: NOT RUN.** No Firebase resource was created. Rollback is the
ordinary Git revert of this commit before any merge; **an installed binary
cannot automatically downgrade a contract**, and no such claim is made.

## 3. Custody model

**States:** `shop`, `picker`, `rider` executable; `customer` **declared and not
reachable** — it depends on delivery confirmation and proof, which no slice
defines.

**Exactly one current custodian.** `CustodyFacts.holder` is non-nullable, so
the aggregate's existence *is* the claim that someone holds the goods. There is
**no `none`, no `unknown`, and no "missing means shop"** — a test asserts no
holder id is `none`/`unknown`/`unassigned`, and a command against absent custody
denies `custodyNotInitialised`.

**Revision:** `custodyRevision` is its own concurrency control, independent of
the order revision, the picker `slotRevision` and the rider `slotRevision`.
Four aggregates change at different rates; one shared counter would make every
unrelated write look like a conflict and a real conflict undetectable.

**Identity:** a worker custodian binds `principalId` + `assignmentId` +
`assignmentGeneration`, compared together. All are validated with the canonical
opaque-id rule, as is `resourceId`. Nothing is trimmed, normalised, repaired or
substituted.

> **`shopId` is deliberately NOT opaque-validated, and I want this flagged.**
> Nothing in the repository governs shop ids that way — `ResourceScope.shopId`
> is unvalidated, and existing fixtures use `shop_alpha`, which the rule would
> **reject**. Applying it would have invented a contract rather than reused
> one. It is required non-blank; the question is recorded as **DEFERRED**.

**Initialisation:** `CustodyFacts.initialAtShop(...)` — holder `shop`, revision
**1**, following the repository convention that a written aggregate starts at 1
and 0 means never written. **No client command exists for it**; the backend
creates it atomically with the ready-for-collection boundary (**CA1**).

## 4. Shop → picker

Command `custody.record_shop_pickup`, existing permission
`picker.custody.record_pickup`, actor = the order's **current accepted picker**
named exactly.

Preconditions: custody exists, validates and is `shop`; order `ready`;
reservation `committed`; picker assignment `accepted` with matching assignee,
`assignmentId` **and** generation; all aggregates name the same `resourceId`;
both `expectedCustodyRevision` and `expectedOrderRevision` current.

Result: custody → `picker` bound to that attempt; `custodyRevision` +1;
**order stays `ready`**; reservation stays `committed`; picker assignment stays
`accepted`; rider slot untouched; **inventory NONE, financial NONE**; scope
effect **empty** — possession is not permission; event
`custody.acquired_by_picker`.

**Pickup is acquisition, not dispatch.**

## 5. Picker → rider

Command `custody.record_rider_receipt`, existing permission
`rider.custody.record_receipt`, actor = the **accepted rider** named exactly.
Receiver-side by design: the rider is the party who can attest they hold the
goods, so custody never sits in a claimed-but-unconfirmed limbo.

Prerequisites include the two cross-aggregate ones that matter: the custody
holder binding must match the **currently accepted** picker attempt
(`custodyHolderBindingMismatch`), and the rider's `SourcePickerBinding` must
still identify that same attempt (`sourcePickerAssignmentMismatch`).

All fifteen required effects are represented: custody `picker→rider`, revision
+1, order `ready→in_delivery` with revision +1, reservation stays `committed`,
inventory NONE, financial NONE, picker `accepted→completed` with `slotRevision`
+1 and both identities retained, picker `assignedResource` removed, rider stays
`accepted` and assigned, `SourcePickerBinding` unchanged, and three events
(`custody.transferred_to_rider`, `picker.assignment.completed`,
`order.in_delivery`) carried on one transition so they share one causation.
**`delivered` is not entered.**

## 6. Picker completion and the revision model

**No `completePickerAssignment` command exists.** Completion is a typed
cross-aggregate *consequence* (`PickerAssignmentCompletionEffect`), never a
client-selected target state — a target state a client can choose is exactly
the arbitrary status patch this contract forbids. A test asserts no custody
command type contains `set_`, `status`, `patch`, `force`, `transfer_to` or
`assign`.

A completed attempt retains recipient, assignee, id and generation; it no
longer occupies the slot and no longer grants `assignedResource` (**CA14**). No
command may act *from* `completed` either — every picker command against a
canonical completed attempt returns `unknownTransition`.

**Role-aware, minimally.** Two additive mechanisms:

- `reachableSlotRevisionRange(..., {role})` — `role: picker` gives `completed`
  the same per-generation cost as `revoked` (offer + accept + completion = 3),
  asserted equal for generations 1–4; `role: rider` and the default stay null.
- `AssignmentState.executableForRole(role)` — what a **validator may check the
  shape of**, deliberately distinct from `executableInThisSlice`, which is what
  an **evaluator may act from**. `completed` is in the picker's shape set and in
  neither action set.

`executableInThisSlice` is unchanged, and the five pre-custody ranges are
identical for both roles.

**B3-C1 — SATISFIED BY CONTRACT TESTS.** Proven from **real evaluator output**,
not arithmetic asserted against itself: the picker evaluator produces
offer → accept (plus revoke → re-offer for higher generations), the custody
evaluator produces pickup and receipt, and the resulting completed aggregate
must satisfy `validatePickerAssignmentAggregate`. Generations 1, 2 and 3 end at
revisions 3, 6 and 9. **This is contract-test evidence, explicitly not backend
persistence evidence** — **CA9** owns the real transaction.

**B3-C2 — NOT RUN / FUTURE.** Rider `completed` remains unreachable, excluded
from `executableForRole(rider)`, still null in the range helper, and the rider
evaluator still refuses to act on one. **No rider completion cost was
invented.**

## 7. Cross-aggregate races

**Pickup vs picker revoke.** `reassignmentSafetyFor` derives safety from real
custody: at `shop` both roles are `provenNoCustody`; once the picker holds the
goods, picker revoke is `blockedOrUnknown`. A test drives the *real* picker
evaluator with the derived value and shows `reassignmentUnsafe` after pickup
and an allowed revoke before it. Serialisation of the two writes is **CA5**.

**Receipt vs rider revoke.** While custody is with the picker, an accepted
rider has received nothing, so rider revoke stays possible — every existing
rider-authority precondition is unchanged. After receipt, rider revoke is
blocked and the picker assignment is `completed`, so there is no active picker
assignment to revoke.

**Unknown stays unsafe.** Missing or corrupt custody is `blockedOrUnknown` for
both roles. "The record does not name this worker" is never turned into proof
they hold nothing.

**Cancellation — unchanged and deliberately not extended.** `ready` cancellation
remains `policyDeferred`; this slice decided nothing about who pays. After
pickup the order is still `ready` but custody proves collection happened, so a
cancellation must not release the committed reservation through a guessed
pre-dispatch path; after receipt the pre-dispatch path cannot act at all.
**Stock is never restored on pickup or handoff** — `CONSTRAINTS.md` invariant
12 stands. Serialisation is **CA15**.

**Stale / reordered:** duplicate pickup, duplicate receipt, stale custody
revision and stale order revision on every command, receipt before pickup,
wrong picker, wrong rider, stale assignment id, stale generation, pickup after
picker revoke, receipt after rider revoke, reordered receipt after picker
reassignment, corrupt holder identity and corrupt cross-aggregate resource
identity — all denied with `transition == null`, therefore no custody, order,
assignment, projection, inventory or financial change and no event.

## 8. Effects

**Inventory NONE** for both transitions. **Reservation** stays `committed`
throughout — dispatch restores nothing. **Financial NONE** — no COD, payment,
fee, commission, refund or settlement rule was invented. **Order** unchanged on
pickup, `ready → in_delivery` on receipt. **Projections** — pickup grants
nothing; receipt removes the completed picker's `assignedResource` and leaves
the rider's. **Events** as listed in §5.

## 9. Security and privacy

Authorization remains FND-003A's and the backend's: this evaluator carries no
grant, and **fresh authorization on every request including replays** is
unchanged (**CA18**). The facts objects are shapes the backend fills; passing
one proves nothing about trust.

Custody events carry routing and identity only — no customer address, phone
number, order contents, money amount or proof material.

**Notification delivery does not authorize pickup or receipt, does not prove
custody, does not change state, and may be missed.** No notification
dependency or platform code was added.

No admin custody shortcut exists; a test asserts no `admin.*` permission
contains `custody`. **ADR-0006 and ADR-0007 are byte-for-byte unmodified.**

## 10. Deferred, explicitly

- **`picker.custody.record_handoff`** keeps its id, roles and scope and is
  **not executable**: no custody command maps to it. A picker-side record alone
  does not transfer custody. Making it do so needs a sender/receiver proof
  protocol, and **no QR, OTP, signature, photo, biometric or GPS proof was
  invented**. Any handoff-proof expiry contract is likewise deferred, not
  guessed.
- **Direct shop→rider pickup** — no such custody transition, no direct
  agent→rider command. `agent.assignment.offer_rider` keeps its stable id,
  remains non-executable and authorizes no custody command. **RA18 unchanged.**
- **No numeric timeout or TTL** — custody acquisition is not time-driven, and
  assignment `timeoutPolicyRef` behaviour is untouched.

## 11. Future acceptance

**Added: CA1–CA18, all NOT RUN** — no trusted backend persistence exists, and
none is marked PASS from Dart fixtures.

**Unchanged and still NOT RUN:** R33–R40, L1–L13, P1–P17, RA1–RA18.
**B3-C1: SATISFIED BY CONTRACT TESTS** (not persistence evidence).
**B3-C2: NOT RUN / FUTURE.**

**P13/P14 and RA14/RA15 remain real backend persistence and reconciliation
evidence.** The `apply*` fixtures are test infrastructure and do not satisfy
them, and neither does **CA9**.

## 12. Validation

| Command | Result |
|---|---|
| baseline `origin/main` / branch / clean tree | **PASS** — `bfec4be`, clean, no reset |
| `dart test test/custody_lifecycle_test.dart` | **PASS** — **42** |
| `dart test test/custody_integrity_test.dart` | **PASS** — **37** |
| `dart test test/order_lifecycle_test.dart` | **PASS** — **22** |
| `dart test test/order_lifecycle_race_test.dart` | **PASS** — **17** |
| `dart test test/order_lifecycle_forbidden_test.dart` | **PASS** — **18** |
| `dart test test/order_lifecycle_aggregate_test.dart` | **PASS** — **41** |
| `dart test test/picker_assignment_test.dart` | **PASS** — **28** |
| `dart test test/picker_assignment_race_test.dart` | **PASS** — **20** |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **96** (was 95) |
| `dart test test/rider_assignment_test.dart` | **PASS** — **53** |
| `dart test test/rider_assignment_race_test.dart` | **PASS** — **23** |
| `dart test test/rider_assignment_integrity_test.dart` | **PASS** — **71** |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unmodified |
| `dart test test/authorization_test.dart` | **PASS** — **46**, unmodified |
| `dart test test/command_envelope_test.dart` | **PASS** — **8** |
| `dart test test/event_envelope_test.dart` | **PASS** — **9**, unmodified |
| `dart test test/contract_version_test.dart` | **PASS** — **11** (was 10) |
| negative control — picker completed cost 3 → 4 | **PASS (fired)** |
| negative control — receipt without custody/source binding | **PASS (fired)** |
| permission-matrix drift check | **PASS** — verbatim, **not regenerated** (no permission code changed) |
| `dart test` all `cp_contracts` | **PASS** — **601** (was 522 at branch point) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **642 across 10 of 15 members** (was 561) |

**Negative control detail.** Raising the picker-completed cost 3 → 4 failed the
B3-C1 suite with *"a real completed history must validate — the role-aware
reachableSlotRevisionRange and the completion effect have drifted apart"*.
Removing the custody-holder binding **and** `SourcePickerBinding` checks failed
*"custody bound to a replaced picker attempt is refused"*, *"a stale
SourcePickerBinding is refused"* and *"reordered old receipt after picker
reassignment"*. Production was restored **byte-for-byte** after each —
`lib/` checksum returned to `431febdccda607a7…`.

**NOT RUN:** every FND-002 platform/device check, all Firebase/emulator work,
Firestore rules and indexes, and CA1–CA18 / R / L / P / RA. **BLOCKED:** none.
No platform, device, Firebase or backend test is labelled PASS.

## 13. Files

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/custody_state.dart` | **new** — `CustodyHolderKind`, `CustodyHolder` |
| `packages/contracts/lib/src/custody_effect.dart` | **new** — `CustodyOrderEffect`, `PickerAssignmentCompletionEffect` |
| `packages/contracts/lib/src/custody_command.dart` | **new** — two named commands, custody events |
| `packages/contracts/lib/src/custody_lifecycle.dart` | **new** — denials, facts, request, transition, validator, evaluator, `reassignmentSafetyFor` |
| `packages/contracts/lib/src/assignment_integrity.dart` | additive optional `role` on `reachableSlotRevisionRange` |
| `packages/contracts/lib/src/assignment_state.dart` | `executableForRole`; corrected `notYetImplemented` doc |
| `packages/contracts/lib/src/picker_assignment.dart` | validator role-aware; `completed` shape defined |
| `packages/contracts/lib/src/rider_assignment.dart` | validator role-aware; rider `completed` still undefined |
| `packages/contracts/lib/src/order_state.dart` | `aggregateShapeKnown` |
| `packages/contracts/lib/src/order_lifecycle.dart` | `in_delivery: {committed}`; validator uses `aggregateShapeKnown` |
| `packages/contracts/lib/src/assignment_command.dart` | `AssignmentEventType.pickerCompleted` |
| `packages/contracts/lib/src/lifecycle_command.dart` | `LifecycleEventType.orderInDelivery` |
| `packages/contracts/lib/src/contract_version.dart` | 0.5 → 0.6 |
| `packages/contracts/lib/cp_contracts.dart` | export the four custody files |
| `packages/contracts/test/support/custody_fixtures.dart` | **new** |
| `packages/contracts/test/custody_lifecycle_test.dart` | **new** — 42 |
| `packages/contracts/test/custody_integrity_test.dart` | **new** — 37 |
| `packages/contracts/test/order_lifecycle_aggregate_test.dart` | table now keyed on `aggregateShapeKnown` |
| `packages/contracts/test/picker_assignment_integrity_test.dart` | canonical vs malformed `completed`; event count |
| `packages/contracts/test/rider_assignment_integrity_test.dart` | event counts |
| `packages/contracts/test/{contract_version,command_envelope}_test.dart` | 0.5 → 0.6 pin, plus a 0.5 ↔ 0.6 policy test |
| `docs/contracts/custody-lifecycle.md` | **new** — canonical doc, 18 sections |
| `docs/contracts/{order-reservation,picker-assignment,rider-assignment}-lifecycle.md` | dispatch boundary, role-aware range, custody note |
| `docs/contracts/README.md`, `version-history.md` | index and 0.6 history |
| `docs/task-ledger/TASK_LEDGER.md` | B3A DONE, B3 PARTIAL, 0.6, CA series |
| `docs/task-ledger/FND-003B3A-completion-report.md` | this report |

**Untouched:** `apps/`, `backend/`, `infra/`, Firebase configuration,
notification and auth adapters, `permission.dart`, `permission_matrix.dart`,
the generated permission matrix, ADR-0006, ADR-0007, `ids.dart`,
`pubspec.yaml`, `pubspec.lock`. **No dependency added.**

## 14. Ledger

**FND-003B3A DONE.** **FND-003B3 PARTIAL** — delivery attempts, refusal,
returns, customer custody and post-dispatch inventory restoration outstanding.
**FND-003B PARTIAL.** **FND-003C BLOCKED on O6.** FND-003D unchanged. FND-004
unchanged. Contract **0.6**.

## 15. Blockers

**None** for this bounded task.

## 16. Scope statement

Contract and tests only. No backend handler, no Firestore rule, no index, no
application feature, no platform dependency. Nothing merged to `main`, pushed,
force-pushed or deployed. **No PR created. The delivery/refusal/return slice is
not started.**
