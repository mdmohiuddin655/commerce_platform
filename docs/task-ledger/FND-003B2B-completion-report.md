# FND-003B2B completion report

- **Task:** Second and final sub-slice of FND-003B2 — picker-originated rider
  assignment lifecycle
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `main` @ `741328ce14774d7c545828883e0f5bad7f991fe2`
- **Branch:** `fnd/FND-003B2B-rider-assignment-lifecycle`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.4 → **0.5**
- **Status:** **DONE**

## 1. Baseline

`main` matched the expected SHA exactly. Working tree was **clean**, so **no
`git reset --hard` was used** — the branch was created with `git switch -c`.
No accepted commit was amended, rebased or force-pushed.

## 2. Contract version

**0.4 → 0.5, additive.** `isVersionCompatibleWith` keys on major only; the
documented rule is minor-for-additive. 0.4 contained no rider assignment types,
so nothing could be reinterpreted.

**No payload-compatibility claim.** `cp_contracts` still has no serialization,
so a 0.4 build could not decode a 0.5 rider payload even in principle. The
file move described in §4 changed no name, value or behaviour — but that is a
statement about **source organisation**, deliberately not offered as decode
evidence.

## 3. Shared primitives — reused, not copied

**Reused unchanged:** `AssignmentState`, `AssignmentRole`,
`ScopeProjectionEffect`, `CustodyClassification`, `ReassignmentSafety`,
`assignmentEligibleOrderStates`, the opaque-id rules, and the
generation/revision semantics.

**Extracted into `assignment_integrity.dart`:** `AssignmentDenial` and
`reachableSlotRevisionRange`, moved from `picker_assignment.dart` **with no
change to name, value, signature or behaviour**. `cp_contracts.dart` re-exports
the new file, so no consumer import changed and no picker test needed editing
for the move. One canonical revision model now serves both evaluators instead
of two formulas that could disagree.

The role-neutrality is structural, not asserted: picker and rider run the same
pre-custody transitions — `offered`, `accepted`, `declined`, `expired`,
`revoked` — with identical mutation costs.

**Kept role-specific,** because authority and cross-aggregate facts genuinely
differ: command permissions, rider eligibility, source-picker authority, the
rider aggregate types, rider events, and the RA backend criteria.

**Deliberately not refactored:** no accepted picker request/facts/transition API
was reshaped for DRY aesthetics.

## 4. Picker regression

Shared code changed, so the picker suites were rerun as **regression coverage
for this task's extraction** — not as a new review of accepted FND-003B2A work.

| Suite | Before | After |
|---|---|---|
| `picker_assignment_test` | 24 | **24**, unmodified |
| `picker_assignment_race_test` | 20 | **20** |
| `picker_assignment_integrity_test` | 89 | **91** |

Three picker tests needed updating, all because the *shared* vocabulary
legitimately grew — none because picker behaviour changed:

1. `AssignmentRole.executableInThisSlice` was pinned to `{picker}`; it is now
   `{picker, rider}`. Split into three tests that are **stronger** than the
   original: the picker command/event surface stays picker-only, the picker
   evaluator refuses every rider command, and both roles are implemented.
2. The command-set pin was `AssignmentCommand.values`; it is now
   `AssignmentCommand.forRole(picker)`. Scoping it per role is what stops a new
   rider command being absorbed by the picker guard and escaping coverage.
3. The "every command except expiry has a permission" sweep is now
   picker-scoped, because rider expiry is also worker-driven.

## 5. Permissions

Two new, both **picker-only**:

| Permission | Roles | Scopes | Reason | Approval |
|---|---|---|---|---|
| `picker.assignment.offer_rider` | picker | `assignedResource` + `ownRegion` | no | no |
| `picker.assignment.revoke_rider` | picker | `assignedResource` + `ownRegion` | **yes** | no |

Both `active` membership only. Neither is granted to agent, admin, rider or
customer — asserted per role, per permission.

**`agent.assignment.offer_rider` was not used, deleted or renamed.** It keeps
its stable id and its matrix row, and its restriction text now records that it
is **reserved for a future direct shop-to-rider pickup and not executable**. A
test sweeps the whole command enum asserting **no** command maps to it (count
0), and that `offerRiderAssignment` maps to `pickerOfferRiderAssignment`.

Matrix regenerated from code: **38 rows**, table embedded verbatim, drift check
clean.

> A note on process: I first overwrote `permission-matrix.md` with raw
> generator output, which destroyed the document's hand-written 26-line header —
> the generator emits only the table. I restored the file from git and spliced
> the generated rows into place instead. The published document is correct; the
> mistake is recorded because the report is the audit trail.

## 6. Rider model

**Slot** — one logical rider position per order, with its own `slotRevision`,
**independent of the picker slot's**.

**Attempt** — immutable history: `assignmentId`, `generation`, state,
`offerRecipientPrincipalId`, nullable `acceptedAssigneePrincipalId`,
`timeoutPolicyRef`, and a `SourcePickerBinding`.

**Source picker binding** — `pickerPrincipalId` + `pickerAssignmentId` +
`pickerGeneration`, stored rather than derived. `ResourceScope.assignedPrincipalIds`
says who is assigned **now**; it cannot say which picker assignment created a
given offer, and a projection rebuilt after a picker was replaced would answer
with the replacement. All three fields are compared together, because a
replacement attempt takes a new id *and* a new generation.

Required in **every** state including terminal ones: an attempt that lost its
origin can no longer be checked against the current picker assignment.

`generation` advances only on a new offer; `slotRevision` on every successful
mutation; `assignmentId` identifies one attempt. All three stay distinct.

## 7. Picker authority

A rider offer may be created only by the order's **current accepted picker**.
The evaluator takes `pickerAuthority` — the canonical `PickerAssignmentFacts`
for the same order — as a `required` **nullable** parameter, so every call site
must state its intent and null fails closed.

Required: valid picker aggregate; same `resourceId`; `orderRegionId` and
`orderState` agreeing with the rider slot (a disagreement means the read-set
was not consistent); a picker attempt in state `accepted`; and its
`acceptedAssigneePrincipalId` equal to the acting principal.

Not trusted and not sufficient: picker role alone, same region alone, a
client-supplied picker id, or the `assignedResource` projection alone.

**The facts object is not proof that storage or auth data was trusted.**
FND-003A's rule stands: fresh authorization on every request including replays.
**RA1** records what the backend must re-establish per request.

**Accepted picker ≠ picker holds the goods.** Offering takes no custody input.

## 8. Rider eligibility

Human principal; membership naming the same principal; `CommerceRole.rider`;
`MembershipStatus.active`; a region that exists and equals the order's —
absence is not a match on either side.

**Not invented:** workload limits, availability scores, ratings, route
distance, vehicle type, shift schedules. Those are dispatch policy.

## 9. Transition matrix

Full matrix with preconditions, revision/generation rules, projection effects
and events: [rider-assignment-lifecycle.md](../contracts/rider-assignment-lifecycle.md) §7.

**Every transition: inventory NONE, financial NONE IN THIS SLICE, custody NONE
IN THIS SLICE.** The FND-003B1 reservation is never read or written, no rider
transition changes `OrderState`, and accepting creates no COD liability,
commission or settlement.

Order must be `accepted`, `preparing` or `ready` — the picker set reused
unchanged, re-read for every command.

### One deliberate asymmetry, stated plainly

**Accept** requires the source binding to still be current. **Revoke** requires
only that the actor is the *current* accepted picker — not the original one.

Requiring the original picker on revoke would leave a rider slot permanently
unresolvable once its picker was replaced, with no in-contract way out. Revoke
only **withdraws** standing, so it is the safe direction to allow, and it is
the path a backend uses to resolve the RA17 dependency. The revoke transition
still carries the original binding unchanged — authorship is history, not a
pointer to be repaired.

**Decline** requires no source-picker currency either: it grants the rider
nothing, and requiring it would trap a rider under a replaced picker, unable to
refuse work they were never going to do.

These readings follow the task specification for each command. They are flagged
here because they are judgement calls a reviewer should confirm rather than
discover.

## 10. Expiry and the accept-versus-expiry race

Offers carry `timeoutPolicyRef` — an immutable versioned reference. **No
numeric duration exists.** A test reads `rider_assignment.dart` and asserts it
contains no `Duration(`, `inSeconds`, `inMinutes` or `DateTime`.

The backend resolves the reference against server UTC and supplies
`expiryDue`, which **defaults to false** so expiry fails closed. Worker-driven:
`requiredPermission` is null.

**Accept first** → later expiry denied (`wrongAssignmentState`);
`activeAcceptedCount == 1`. **Expiry first** → later accept denied;
`activeAcceptedCount == 0`. The loser holding the pre-race revision gets
`slotRevisionConflict`. Tested in both orderings with a count assertion each
way. Wall-clock order is not concurrency control.

## 11. Controlled reassignment

`accepted → revoked`, then a **new** offer with a new opaque `assignmentId` and
`generation + 1`. No assignee overwrite exists; a test asserts no command type
contains `set_`, `status`, `replace`, `assignee`, `patch` or `force`.

Revocation requires `ReassignmentSafety.provenNoCustody`. `blockedOrUnknown` —
the **default** — denies with `reassignmentUnsafe`. **Unknown is not safe.**

Current-terminal id reuse denies `assignmentIdReuse`, tested for `declined`,
`expired` and `revoked`, with a genuinely new id still allowed each time.
Historical uniqueness across **archived** attempts is a storage guarantee —
**RA11**, NOT RUN.

## 12. Stale, duplicate and reordered

Identity before generation, both before state. Twenty-plus scenarios tested:
wrong id; wrong generation; old id + old generation; old id carrying the new
generation; new id carrying the old generation; stale revision on every
mutating command; every command with no attempt; duplicate
accept/decline/expiry/revoke; decline-after-accept; accept-after-decline;
accept-after-expiry; expiry-after-accept; expiry-after-decline; revoke-before-
accept; second offer while live; offer while accepted; delayed generation-1
accept and decline after a generation-2 offer; terminal id reuse; reordered
revoke versus re-offer.

Every denial yields `transition == null` — therefore no projection change, no
event, no inventory, financial or custody effect. Command idempotency remains
FND-003A's and was not reimplemented.

## 13. Aggregate integrity

Validation runs **before any effect**. Canonical shapes per state, plus
non-empty `resourceId`, opaque `assignmentId`, `generation >= 1`, reachable
`slotRevision`, non-empty recipient, non-blank `timeoutPolicyRef`, and full
source-binding validity (non-empty picker principal, opaque picker assignment
id, picker generation `>= 1`) **in every state**.

Ten impossible generation/revision pairs fail closed — including four **above**
the maximum, not merely below the minimum. **The validator does not repair**: a
test asserts the facts are unchanged and `identical` by reference after
refusal.

## 14. Revision model and transition closure

One shared helper (§3). Closure invariant pinned:

> `applyRider(successful transition)` → `validateRiderAssignmentAggregate` →
> **null**

Every fact comes from a real evaluator transition; nothing hand-fabricated.
Covered: initial offer, accept, decline, expiry, revoke, re-offer after each
terminal outcome, and both generation-3 boundaries built through the evaluator:

- **MIN rev 5** — g1 declined (2) + g2 declined (2) + g3 offer
- **MAX rev 7** — g1 accept+revoke (3) + g2 accept+revoke (3) + g3 offer

Coverage guards: rider command coverage pinned to
`AssignmentCommand.forRole(rider)`; picker coverage pinned to
`forRole(picker)` and unchanged in strength; every executable state has a
non-null range; `completed` stays non-executable with **no invented cost**; a
sweep proves no rider transition produces `completed`; each evaluator refuses
the other role's commands.

**`applyRider` is test infrastructure only** and is explicitly not offered as
persistence evidence. **RA14/RA15** own that, and **P13/P14** remain the picker
equivalents — neither is replaced by a fixture.

**B3-C2** recorded as **NOT RUN / FUTURE**. **B3-C1 status unchanged.**

## 15. Negative controls — all three fired

A guard that has never failed proves nothing.

| Control | Result |
|---|---|
| Shared range helper broken (`revoked` cost 3 → 4) | **FIRED** — rider closure failed with *"reachableSlotRevisionRange and the rider evaluator have drifted apart"* **and** picker closure failed with its own message, proving the helper is genuinely shared rather than duplicated |
| Accept skips `source.matchesCurrentPicker` | **FIRED** — *"the source picker assignment must still be current"* failed |
| Revoke drops the current-accepted-picker check | **FIRED** — both *"a picker who is not the current accepted picker cannot revoke"* and *"an agent cannot revoke a rider assignment"* failed |

Production code restored **byte-for-byte** afterwards: the `lib/` checksum
returned to its pre-control value `225699741be417dd…`.

## 16. Cross-aggregate races — future backend

**RA16 (cancellation).** The rider evaluator implements no cancellation. The
backend must resolve current order state, current picker assignment, current
rider assignment and — once FND-003B3 exists — custody from **one consistent
read-set** before mutating, covering cancellation versus offer, accept, revoke
and expiry. Cancellation fees and post-custody policy were **not guessed**.

**RA17 (picker reassignment).** FND-003B2A was **not** redesigned. An accepted
picker assignment must not be revoked or replaced while a dependent live rider
offer or active accepted rider would be orphaned; the backend serializes both
aggregates and resolves the rider dependency first. No generic "cancel rider
assignment" state was invented. The **acceptance** half of the hazard is
already closed mechanically by the source-binding check.

## 17. Governance

[ADR-0007](../decisions/ADR-0007-admin-rider-assignment-override.md) — admin
rider intervention is a **separate audited override workflow**: distinct
permission and command family, scoped admin authority, reason, approval / dual
control, audit record, no arbitrary status or assignee patch, preserved
history, **an unrewritten source picker binding**, and no bypass of custody
safety.

It records one argument ADR-0006 could not: these permissions are scoped by
`assignedResource`, which an admin never holds — so adding `admin` would either
be inert or force `assignedResource` to be loosened platform-wide, weakening
every permission that uses it.

`admin.assignment.override_rider` is **RESERVED / PROPOSED** — absent from
`Permission.values`, `permissionMatrix` **and** `AssignmentCommand`, with tests
pinning all three. **No admin override was implemented.** ADR-0006 unmodified.

## 18. Future backend acceptance

**R33–R40 NOT RUN. L1–L13 NOT RUN. P1–P17 NOT RUN. B3-C1 NOT RUN / FUTURE.**
All unchanged.

**Added: RA1–RA18, all NOT RUN**, covering fresh picker authority, trusted
rider eligibility, region matching, recipient-only accept/decline, one-live-
offer, one-active-accepted, the race, stale identity, next-generation re-offer,
delayed old-generation commands, historical id uniqueness, revoke requirements,
custody fail-closed, atomic projection + outbox, aggregate reconciliation,
cancellation serialization, the picker-reassignment dependency, and router
separation from the future direct agent→rider route.

**Added: B3-C2, NOT RUN / FUTURE.**

None was treated as a blocker. Nothing is marked PASS.

## 19. Validation

| Command | Result |
|---|---|
| baseline branch / SHA / clean tree | **PASS** — `741328c`, clean, no reset |
| `dart test test/rider_assignment_test.dart` | **PASS** — **49** |
| `dart test test/rider_assignment_race_test.dart` | **PASS** — **23** |
| `dart test test/rider_assignment_integrity_test.dart` | **PASS** — **65** |
| `dart test test/picker_assignment_test.dart` | **PASS** — **24**, unmodified |
| `dart test test/picker_assignment_race_test.dart` | **PASS** — **20** |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **91** (was 89) |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unchanged |
| `dart test test/authorization_test.dart` | **PASS** — **46**, unmodified |
| `dart test test/contract_version_test.dart` | **PASS** — **10** (was 9) |
| `dart test test/command_envelope_test.dart` | **PASS** — **8** |
| negative control — shared range helper | **PASS (fired)** — picker *and* rider |
| negative control — source-binding check removed | **PASS (fired)** |
| negative control — revoke authority removed | **PASS (fired)** |
| `dart run tool/print_permission_matrix.dart` + drift check | **PASS** — 38 rows, no drift |
| `dart test` all `cp_contracts` | **PASS** — **502** (was 362) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **543 across 10 of 15 members** (was 403) |

**NOT RUN:** every FND-002 platform/device check — irrelevant to a pure
contract task and not rerun. R33–R40, L1–L13, P1–P17, RA1–RA18, B3-C1, B3-C2 —
no backend exists.

The full gate ran because **AGENTS.md §6 requires it**. It naturally
re-executes accepted FND-002/FND-003A/FND-003B1 suites; that is **not** offered
as new evidence for those completed tasks. The picker suites in §4 *are*
offered as regression evidence for this task's extraction, which is a different
claim.

## 20. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/assignment_integrity.dart` | **new** — shared `AssignmentDenial` (+4 cross-aggregate values) and `reachableSlotRevisionRange` |
| `packages/contracts/lib/src/rider_assignment.dart` | **new** — source binding, attempt/slot/eligibility, aggregate validator, evaluator |
| `packages/contracts/lib/src/picker_assignment.dart` | two declarations moved out; rider commands added to the command switch (fail closed) |
| `packages/contracts/lib/src/assignment_state.dart` | `AssignmentRole.executableInThisSlice` now both roles; doc comments corrected |
| `packages/contracts/lib/src/assignment_command.dart` | 5 rider commands, `role` field, `forRole`, 5 rider event ids, `picker`/`rider` lists |
| `packages/contracts/lib/src/permission.dart`, `permission_matrix.dart` | 2 picker permissions; `agent.assignment.offer_rider` restriction documents its reserved status |
| `packages/contracts/lib/src/contract_version.dart` | 0.4 → 0.5 |
| `packages/contracts/lib/cp_contracts.dart` | export the new files |
| `packages/contracts/test/support/rider_assignment_fixtures.dart` | **new** |
| `packages/contracts/test/rider_assignment{,_race,_integrity}_test.dart` | **new** — 49 / 23 / 65 |
| `packages/contracts/test/picker_assignment_{integrity,race}_test.dart` | role-scoped guards (§4) |
| `packages/contracts/test/{contract_version,command_envelope}_test.dart` | version pin 0.4 → 0.5, plus a new 0.4 ↔ 0.5 policy test |
| `docs/contracts/rider-assignment-lifecycle.md` | **new** — canonical doc, 22 sections |
| `docs/contracts/picker-assignment-lifecycle.md` | shared-primitive cross-references; stale "rider not executable" wording corrected |
| `docs/contracts/permission-matrix.md` | regenerated table + reserved-permission section |
| `docs/contracts/README.md`, `version-history.md` | index and 0.5 history |
| `docs/decisions/ADR-0007-admin-rider-assignment-override.md` | **new** |
| `docs/task-ledger/TASK_LEDGER.md` | FND-003B2B DONE, FND-003B2 DONE, 0.5, RA/B3-C2 |
| `docs/task-ledger/FND-003B2B-completion-report.md` | this report |

Untouched: apps, backend, infra, notification/auth adapters, order-reservation
lifecycle semantics, ADR-0006, `pubspec.yaml`, `pubspec.lock`. **No dependency
added.**

## 21. Ledger

FND-003B2B **DONE**. **FND-003B2 DONE** — both sub-slices complete.
**FND-003B stays PARTIAL** because custody, delivery and returns remain.
**FND-003B3 NOT STARTED.** FND-003C **BLOCKED on O6**. FND-003D unchanged.
FND-004 unchanged.

## 22. Out of scope

Physical shop pickup, picker custody, picker→rider handoff, rider custody
receipt, delivery attempts, delivery proof, returns, COD, payment, cash
journal, fees, commissions, settlement, remittance, direct agent→rider pickup
implementation, admin rider override implementation, parallel rider dispatch —
none defined or guessed. No timeout duration, workload limit, rating threshold,
distance threshold, shift policy or dispatch scoring invented.

## 23. Scope statement

Contract and tests only. No backend handler, no Firestore rule, no application
feature, no platform dependency. Nothing merged to `main`, pushed,
force-pushed or deployed. **FND-003B3 not started.**
