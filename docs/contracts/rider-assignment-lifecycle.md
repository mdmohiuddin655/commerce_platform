# Rider assignment lifecycle

**Contract version 0.5** (FND-003B2B). Canonical definition of the rider
assignment slot, attempt and transitions. Source of truth:
`packages/contracts/lib/src/rider_assignment.dart`; shared primitives live in
`assignment_state.dart`, `assignment_command.dart`, `assignment_effect.dart`
and `assignment_integrity.dart`.

Read [picker-assignment-lifecycle.md](picker-assignment-lifecycle.md) first —
this slice reuses its vocabulary and its revision model, and depends on its
aggregate.

---

## 1. The picker → rider flow boundary

**This slice implements exactly one flow: the order's current accepted picker
offers the delivery work to one rider.**

That is a deliberate narrowing, not the only conceivable arrangement. The
repository also carries `agent.assignment.offer_rider`, which describes a
*direct shop-to-rider pickup* — a rider collecting from the shop with no picker
involved. **FND-003B2B does not activate it** (§18).

What this slice does **not** implement, and did not guess: physical shop
pickup, picker custody, picker→rider handoff, rider custody receipt, delivery
attempts, delivery proof, returns, COD, payment, cash journal, fees,
commissions, settlement.

## 2. Slot, attempt, generation, revision

Four distinct things, exactly as in the picker lifecycle:

| Concept | Meaning |
|---|---|
| **Slot** | One logical rider position per order. Holds at most one attempt. Has its own `slotRevision`, **independent of the picker slot's**. |
| **Attempt** | Immutable history: `assignmentId`, `generation`, state, recipient, nullable accepted assignee, `timeoutPolicyRef`, source picker binding. |
| **`generation`** | Advances **only** on a new offer. |
| **`slotRevision`** | Advances on **every** successful mutation. It is the concurrency control. |
| **`assignmentId`** | Opaque, server-generated. Identifies *one* attempt. |

A decline advances the revision but not the generation. A re-offer advances
both, and takes a **new** `assignmentId`.

## 3. Source picker binding — immutable history

Every rider attempt records the picker assignment that created it:

```dart
SourcePickerBinding(
  pickerPrincipalId:   /* who offered */,
  pickerAssignmentId:  /* which picker attempt */,
  pickerGeneration:    /* that attempt's generation */,
)
```

**Why it is stored rather than derived.** `ResourceScope.assignedPrincipalIds`
says who is assigned **now**. It cannot say which picker assignment created a
given offer, and a projection rebuilt after a picker was replaced would answer
with the replacement. Historical proof has to be stored as history.

All three fields are compared together. A replacement picker attempt takes a
new id *and* a new generation, so comparing only one of them could accept a
different attempt that happened to line up.

The binding is required in **every** state, including terminal ones. An attempt
that lost its origin can no longer be checked against the current picker
assignment — which is the whole protection in §17.

## 4. Offer recipient versus accepted assignee

Separate fields, for the same reason as picker assignment.

| Point | `offerRecipientPrincipalId` | `acceptedAssigneePrincipalId` |
|---|---|---|
| after offer | the target rider | `null` |
| after accept | unchanged | the same rider |
| after decline / expiry | unchanged (history) | `null` |
| after revoke | unchanged (history) | retained (history), no longer active |

**No identity is erased when an attempt ends.** A revoked attempt still records
who held it, and still records which picker offered it.

## 5. Rider eligibility

Trusted facts loaded from **authoritative membership storage** for this
request. `RiderEligibility` is the *shape the backend fills*; constructing one
proves nothing, because a caller never reaches this evaluator.

Required, all of them:

- human principal (`isHumanPrincipal`);
- `membershipPrincipalId == principalId` — a membership naming somebody else
  grants nothing;
- `CommerceRole.rider`;
- `MembershipStatus.active`;
- a region that **exists** and equals the order's region. Absence is not a
  match on either side.

**Deliberately absent, and not invented:** workload limits, availability
scores, ratings, route distance, vehicle type, shift schedules. Those are
**dispatch policy**, not lifecycle.

## 6. Picker authority requirements

A rider offer may be created **only** by the order's *current accepted picker*.

The evaluator receives `pickerAuthority` — the canonical `PickerAssignmentFacts`
for the same order, read in the same trusted transaction — and requires:

1. it is non-null (the parameter is `required` and nullable, so every call site
   states its intent; null fails closed);
2. `validatePickerAssignmentAggregate` returns null;
3. `resourceId` equals the rider slot's;
4. `orderRegionId` and `orderState` agree with the rider slot's — if the two
   aggregates disagree, the read-set was not consistent;
5. a picker attempt exists and its state is `accepted`;
6. its `acceptedAssigneePrincipalId` equals the acting principal.

Not trusted, and not sufficient: holding the picker role, being in the same
region, a client-supplied picker id, or the `assignedResource` projection alone.

**Passing this object is not proof that the picker facts were trusted.** It is
the shape the backend fills from canonical storage. FND-003A's rule stands:
authorization is established **freshly on every request, including replays**.
The backend must re-establish, per request, the authenticated picker principal,
active membership, `assignedResource` authorization, `ownRegion`, and the
current canonical accepted picker assignment — see **RA1**.

**Accepted picker ≠ picker holds the goods.** Offering requires no custody
input at all; custody does not exist in this contract.

## 7. Transition matrix

Every transition: **inventory NONE**, **financial NONE IN THIS SLICE**,
**custody NONE IN THIS SLICE**. The FND-003B1 reservation is never read or
written, and no rider transition changes `OrderState`.

Order must be `accepted`, `preparing` or `ready` (§ reused
`assignmentEligibleOrderStates`), re-read for **every** command.

| Command | Permission | From | To | Source-picker prerequisite | Rider prerequisite | gen / rev | Scope effect | Event |
|---|---|---|---|---|---|---|---|---|
| `assignment.offer_rider` | `picker.assignment.offer_rider` | none or terminal | `offered` | acting = **current accepted picker** | target is active rider, region matches; no live offer; no accepted rider; new opaque id ≠ terminal id; policy ref non-blank | gen +1, rev +1 | `+offered{rider}` | `rider.assignment.offered` |
| `assignment.accept_rider` | `rider.assignment.accept` | `offered` | `accepted` | binding **still current** | actor = offer recipient; exact id + generation + revision | gen same, rev +1 | `−offered{rider}`, `+assigned{rider}` | `rider.assignment.accepted` |
| `assignment.decline_rider` | `rider.assignment.decline` | `offered` | `declined` | **none** (§ below) | actor = offer recipient; exact id + generation + revision | gen same, rev +1 | `−offered{rider}` | `rider.assignment.declined` |
| `assignment.expire_rider_offer` | **worker** (`null`) | `offered` | `expired` | **none** | `expiryDue` true; exact id + generation + revision | gen same, rev +1 | `−offered{rider}` | `rider.assignment.expired` |
| `assignment.revoke_rider` | `picker.assignment.revoke_rider` | `accepted` | `revoked` | acting = **current accepted picker** (not necessarily the original) | `provenNoCustody`; exact id + generation + revision | gen same, rev +1 | `−assigned{rider}` | `rider.assignment.revoked` |

There is no `setRiderAssignmentState`, no `replaceRider`, no `patchAssignee`,
no `forceAssignment`. A test asserts no command type contains `set_`, `status`,
`replace`, `assignee`, `patch` or `force`.

### Why decline requires no current source picker

Declining only **releases** the offer: it grants the rider nothing, moves no
goods and creates no assignment. Requiring a current source picker would trap a
rider under a replaced picker — unable to refuse work they were never going to
do — with no safety gained. Accept is the asymmetric case, because accept
*grants* standing.

## 8. Expiry and the timeout policy reference

Each offer carries `timeoutPolicyRef`: an immutable, versioned reference such
as `policy/assignment_offer_timeout@v1`.

**No numeric duration exists anywhere in this contract.** A test reads
`rider_assignment.dart` and asserts it contains no `Duration(`, `inSeconds`,
`inMinutes` or `DateTime`.

The backend resolves the reference against **server UTC** and supplies
`expiryDue`, which **defaults to `false`** so expiry fails closed. A client
cannot make an offer due. Expiry is worker-driven: `requiredPermission` is
`null`, and `evaluateAuthorization` denies a `PrincipalKind.systemWorker` every
human-role permission, so a worker cannot borrow one.

Expiry is **not** a device timer, a notification callback or a TTL deletion.

## 9. Accept versus expiry race

| Case | Sequence | Result |
|---|---|---|
| **Accept wins** | `offered` → `accepted` (rev 2) → later expiry | expiry denied `wrongAssignmentState`; `activeAcceptedCount == 1` |
| **Expiry wins** | `offered` → `expired` (rev 2) → later accept | accept denied `wrongAssignmentState`; `activeAcceptedCount == 0` |

The loser still holding the pre-race revision gets `slotRevisionConflict`.
Tested in **both** orderings with an `activeAcceptedCount` assertion each way.

**Wall-clock time and client arrival order are not concurrency control.** The
server transaction and slot-revision ordering decide.

## 10. Controlled reassignment

Reassignment is two explicit transitions: `accepted → revoked`, then a **new**
offer with a new opaque `assignmentId` and `generation + 1`. There is no
assignee overwrite.

`picker.assignment.revoke_rider`: picker only, active membership,
`assignedResource + ownRegion`, **reason required**, approval not required.

**The no-custody gate.** Revocation requires
`ReassignmentSafety.provenNoCustody`. `blockedOrUnknown` — the **default** —
denies with `reassignmentUnsafe`. **Unknown is not safe.** No custody state is
implemented here; FND-003B3 will map real facts onto it.

**Current-terminal id reuse is denied** (`assignmentIdReuse`), tested for
`declined`, `expired` and `revoked`. Uniqueness against **archived** attempts
is a storage guarantee — **RA11**, NOT RUN.

### A replacement picker may revoke

Revoke requires the *current* accepted picker, **not** the original one.
Requiring the original would leave a rider slot permanently unresolvable once
its picker was replaced. Revoke only **withdraws** standing, so it is the safe
direction to allow — and it is the in-contract path a backend uses to resolve
the dependency in §17. The revoke transition still carries the original
`SourcePickerBinding` unchanged: authorship is history, not a pointer to be
repaired.

## 11. Exactly-one invariants

Per order: `liveRiderOfferCount <= 1` and `activeAcceptedRiderCount <= 1`.

A second offer while one is live denies `liveOfferExists`; an offer while a
rider is accepted denies `activeAcceptedAssignmentExists`. A second accept —
by the same rider or a different one — creates nothing. A full
offer → accept → revoke → re-offer cycle asserts both counts at every step.

These are an **initial foundation invariant**, not a claim that parallel-offer
dispatch can never exist. Supporting it later needs an explicit ADR, and
`expired`/`declined` must **not** be repurposed to simulate it.

## 12. Stale, duplicate and reordered commands

Identity is checked **before** generation, both **before** state, so a command
is never applied to whatever is in the slot just because the order id matched.

Tested: wrong id; wrong generation; old id + old generation; old id carrying the
**new** generation; new id carrying the old generation; stale `slotRevision` on
every mutating command; every command with no attempt present; duplicate
accept/decline/expiry/revoke; decline after accept; accept after decline;
accept after expiry; expiry after accept; expiry after decline; revoke before
accept; second offer while live; offer while accepted; delayed generation-1
accept and decline after a generation-2 offer; current-terminal id reuse;
reordered revoke versus re-offer.

Every denied outcome yields `transition == null`, and therefore **no scope
projection change, no event, no inventory effect, no financial effect and no
custody effect**.

Command **idempotency** is not reimplemented here — it remains FND-003A's.

## 13. Aggregate integrity

`validateRiderAssignmentAggregate` runs **before any effect**, following the
FND-003B1 lesson: the transition graph never *creates* an impossible aggregate,
but facts arrive from **storage**.

Canonical shapes:

| State | Recipient | Assignee | Source binding |
|---|---|---|---|
| `offered` | present | **null** | present |
| `accepted` | present | present, **== recipient** | present |
| `declined` | present | **null** | present |
| `expired` | present | **null** | present |
| `revoked` | present | present (history), **== recipient** | present |

Also validated: non-empty `resourceId`; opaque `assignmentId`;
`generation >= 1`; reachable `slotRevision` (§14); non-empty recipient;
non-blank `timeoutPolicyRef`; non-empty source picker principal; opaque source
picker assignment id; source picker generation `>= 1`; a slot with no attempt
must be at revision 0; a slot holding an attempt must be at revision `>= 1`.

**The validator never repairs.** A test asserts the facts are unchanged, and
identical by reference, after refusal. Repair without an audit trail is
indistinguishable from a bug, and belongs to reconciliation tooling —
**RA15**.

## 14. Revision range — one shared model

`reachableSlotRevisionRange(generation, state)` lives in
`assignment_integrity.dart` and is used by **both** evaluators. It was moved
there unchanged from `picker_assignment.dart`; its name, behaviour and export
path are identical.

It is role-neutral **by construction**: picker and rider run the same
pre-custody transitions with the same mutation costs.

| State | Reachable `slotRevision` |
|---|---|
| `offered` | `2g-1` … `3g-2` |
| `accepted` / `declined` / `expired` | `2g` … `3g-1` |
| `revoked` | `2g+1` … `3g` |

Derivation: every attempt costs at least two mutations (offer + decline or
expiry) and at most three (offer + accept + revoke), so the `g-1` prior
attempts consumed `2(g-1)`…`3(g-1)` revisions and the current attempt adds one,
two or three.

**Maintenance invariant.** This is arithmetic over the currently executable
transitions, not an independent rule. Any change that makes `completed`
executable, adds an executable state, alters a per-generation mutation cost, or
changes whether a transition increments `slotRevision` **must in the same
change**: update the helper, update this derivation and table, update the
canonical/impossible range tests, and update **both** closure suites. The
symptom of drift is *valid* histories failing closed as
`aggregateInconsistent`. See **B3-C1** (picker) and **B3-C2** (rider).

## 15. Transition closure

The invariant pinned by the rider integrity suite:

> `applyRider(successful transition)` → `validateRiderAssignmentAggregate` →
> **null**

Every fact comes from a **real evaluator transition**; nothing is
hand-fabricated, because a fabricated pair could accidentally satisfy a rule
the lifecycle no longer produces.

| Case | History | Ends at |
|---|---|---|
| initial offer | empty slot | gen 1, rev 1 |
| accept | offer → accept | gen 1, rev 2 |
| decline | offer → decline | gen 1, rev 2 |
| expiry | offer → expire | gen 1, rev 2 |
| revoke | offer → accept → revoke | gen 1, rev 3 |
| re-offer after decline | + offer | gen 2, rev 3 |
| re-offer after expiry | + offer | gen 2, rev 3 |
| re-offer after revoke | + offer | gen 2, **rev 4** |
| **generation 3, MINIMUM** | g1 declined (2) → g2 declined (2) → offer | gen 3, **rev 5** |
| **generation 3, MAXIMUM** | g1 accept+revoke (3) → g2 accept+revoke (3) → offer | gen 3, **rev 7** |

Both generation-3 boundaries are reached **through the evaluator**, not
asserted.

> **`applyRider` is test infrastructure only.** It is *not* evidence that real
> persistence is correct. The canonical record, the scope projection, the
> outbox event and the revision must commit in one transaction — **RA14** — and
> stored aggregates must be reconciled — **RA15**. Both remain NOT RUN. The
> picker equivalents **P13/P14** likewise remain real backend acceptance and
> are not replaced by a fixture.

### Coverage guards

- Rider command coverage is pinned to `AssignmentCommand.forRole(rider)`, so a
  new rider command fails the rider closure guard until its successful
  transition is exercised.
- Picker command coverage is pinned to `AssignmentCommand.forRole(picker)` and
  is **unchanged in strength** by the enum growing.
- Every state in `AssignmentState.executableInThisSlice` must have a non-null
  reachable range.
- `completed` stays outside the executable set and returns `null`; **no
  mutation cost for it was invented**.
- A sweep asserts no rider transition can produce `completed`.
- The rider evaluator refuses every picker command, and the picker evaluator
  refuses every rider command — both with `unknownTransition`.

## 16. Order cancellation race

FND-003B1 permits cancellation from `placed` and `accepted`. **The rider
evaluator implements no cancellation**; it only re-reads the current trusted
order state and refuses ineligible ones.

The backend must resolve, from **one consistent transaction/read-set**, before
any mutation: the current order state, the current picker assignment, the
current rider assignment, and — once FND-003B3 exists — custody facts. This
covers cancellation versus rider offer, versus accept, versus revoke, and
versus expiry.

- If **cancellation wins**, a stale rider operation must not revive or continue
  a cancelled order.
- If the **rider operation wins**, a later cancellation evaluates against the
  resulting assignment state and, once FND-003B3 exists, custody.

Recorded as **RA16**. Cancellation fees and post-custody cancellation policy
are **not guessed** — they need O6 and FND-003C.

## 17. Picker reassignment while a rider slot is active

Rider assignment creates a **cross-aggregate dependency the picker evaluator
does not implement**, and FND-003B2A was deliberately **not** redesigned here.

The requirement, for the backend: an accepted picker assignment must not be
revoked or replaced while a dependent **live rider offer** or **active accepted
rider** would be orphaned. The backend must serialize the picker-revocation
transaction with the rider assignment slot, and either fail closed or resolve
the rider slot first through an explicitly permitted lifecycle path.

No generic "cancel rider assignment" state was invented for this. The in-
contract resolution path is the ordinary one: the current accepted picker
revokes the rider attempt (§10), which a *replacement* picker may do.

What this contract already prevents, mechanically, is the **acceptance** half of
the hazard:

```text
picker A offers rider R  →  A revoked  →  picker B accepted
                         →  R's stale offer accepted as though B created it
```

That is denied `sourcePickerAssignmentMismatch`. Recorded as **RA17**.

## 18. Future direct agent → rider pickup

`agent.assignment.offer_rider` **exists, keeps its id, and is not executable.**
No implemented command maps to it, and a test asserts that across the whole
`AssignmentCommand` enum.

It is reserved for a materially different flow: **agent/shop → rider → direct
physical pickup from the shop**, where custody passes from the shop rather than
from a picker. It must not silently reuse the picker-originated command route.

A future bounded task must define: a distinct trusted router command mapping;
whether a picker must be absent; the exact order stage; shop authority; rider
eligibility; the shop→rider handoff; custody proof; and race behaviour.

**None of that was decided here**, and no future command type was reserved,
because the repository design does not yet require one. Recorded as **RA18**.

## 19. Future admin rider override

[ADR-0007](../decisions/ADR-0007-admin-rider-assignment-override.md).

`CommerceRole.admin` is **not** added to `picker.assignment.offer_rider` or
`picker.assignment.revoke_rider`. Admin intervention, if ever needed, is a
separate audited override workflow requiring a distinct permission and command
family, scoped admin authority, reason, **approval / dual control**, an audit
record, no arbitrary status or assignee patch, preserved history, an unrewritten
source picker binding, and no bypass of custody safety.

`admin.assignment.override_rider` is **RESERVED / PROPOSED** — absent from
`Permission.values`, `permissionMatrix` and `AssignmentCommand`. Tests pin its
absence in all three.

## 20. Backend acceptance criteria — RA1–RA18

**All NOT RUN.** No backend implementation exists. None is a blocker to this
contract task, and none is marked PASS.

| # | Criterion |
|---|---|
| RA1 | Picker-originated rider offer uses the **fresh** current accepted-picker assignment and current picker authorization for the same resource. |
| RA2 | Target rider eligibility is loaded from trusted current membership; wrong-role, inactive, suspended, revoked and non-human targets are denied. |
| RA3 | Target rider region and resource region must match. |
| RA4 | Only the exact offer recipient may accept or decline; a same-region other rider is denied. |
| RA5 | One live rider offer maximum under concurrent commands. |
| RA6 | One active accepted rider maximum under concurrent commands. |
| RA7 | Accept-versus-expiry commits exactly one outcome. |
| RA8 | Stale `assignmentId` / `generation` / `slotRevision` mutates nothing. |
| RA9 | A new offer after decline/expiry/revoke gets the next generation and a new `assignmentId`. |
| RA10 | Delayed older-generation commands cannot affect the new rider attempt. |
| RA11 | Historical rider assignment ids are server-generated and create-if-absent; no archived id can be reused or overwritten. |
| RA12 | Rider controlled revoke requires current accepted-picker authority, a reason, and proven-no-custody safety. |
| RA13 | Unknown or started custody fails rider reassignment closed. |
| RA14 | Rider record + `ResourceScope` offered/assigned projections + command result + outbox event commit **atomically**. |
| RA15 | Invalid persisted rider aggregates never drive a mutation and are surfaced for reconciliation. |
| RA16 | Order cancellation and rider offer/accept/revoke are serialized against the current order, the source-picker assignment and later custody facts. |
| RA17 | Accepted-picker revoke/reassignment cannot orphan a dependent live or accepted rider slot; the backend serializes both assignment aggregates and resolves the rider dependency first. |
| RA18 | The trusted command router keeps the picker-originated rider offer distinct from the future direct agent→rider route; the current command cannot be authorized by `agent.assignment.offer_rider`. |

## 21. Future contract acceptance criteria

Checked by whoever **changes the contract**, not by a deployment — kept
separate from the RA/P backend series for that reason.

> **B3-C1** *(picker, from FND-003B2A-FIX-002)* — unchanged, **NOT RUN /
> FUTURE**.
>
> **B3-C2** — If rider `completed` becomes executable, FND-003B3 must update
> the shared reachable slot-revision model if required, update its derivation
> and range tests, and prove every newly successful rider transition closes
> over `validateRiderAssignmentAggregate`.

**B3-C2 status: NOT RUN / FUTURE.** FND-003B3 has not started.

## 22. Out of scope

Not implemented, and **not guessed**:

physical shop pickup · picker custody · picker→rider physical handoff · rider
custody receipt · delivery attempts · delivery proof · returns · COD ·
payment · cash journal · fees · commissions · settlement · remittance ·
direct agent→rider pickup · admin rider override · parallel rider dispatch ·
timeout durations · workload limits · rider rating thresholds · distance
thresholds · shift policy · dispatch scoring.

Those belong to FND-003B3, FND-003C, FND-003D, or a future bounded task.
