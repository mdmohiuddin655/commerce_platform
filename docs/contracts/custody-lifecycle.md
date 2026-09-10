# Custody lifecycle — acquisition and picker→rider handoff

**Contract version 0.6** (FND-003B3A). Canonical definition of physical custody
from the shop to a rider. Source of truth:
`packages/contracts/lib/src/custody_lifecycle.dart`, with the vocabulary in
`custody_state.dart`, commands and events in `custody_command.dart` and typed
cross-aggregate effects in `custody_effect.dart`.

Read [order-reservation-lifecycle.md](order-reservation-lifecycle.md),
[picker-assignment-lifecycle.md](picker-assignment-lifecycle.md) and
[rider-assignment-lifecycle.md](rider-assignment-lifecycle.md) first — this
slice depends on all three aggregates and changes two of them.

---

## 1. What this slice owns, and what it does not

**Owns:** custody at the shop, `shop → picker` pickup, `picker → rider`
receipt, the `ready → in_delivery` dispatch boundary, and picker assignment
completion as a consequence of that receipt.

**Does not own, and did not guess:** delivery attempts, customer delivery,
refusal or failure, returns, COD, payment, fees, commissions, settlement,
customer proof and disputes, direct shop→rider pickup, and admin overrides.
Those are later FND-003B3 slices, FND-003C and FND-003D.

## 2. Custody vocabulary

| Holder | Status |
|---|---|
| `shop` | **executable** — the canonical starting custodian |
| `picker` | **executable** |
| `rider` | **executable** — the dispatch boundary |
| `customer` | **declared, NOT reachable.** Depends on delivery confirmation and proof, which no slice defines. No transition enters it and none was guessed. |

**Custody is not assignment.** An accepted assignment says a worker agreed to
do the work; custody says the goods are in their hands. Keeping those apart was
deliberate in FND-003B2A/B2B, and this slice is what finally makes the second
one explicit.

**There is no `none` and no `unknown`.** Once an order has a custody aggregate
there is exactly one current custodian. A test asserts no holder id is
`none`/`unknown`/`unassigned`.

## 3. Initialisation — absence is never "the shop has it"

An order-specific custody aggregate must become explicit **no later than the
order reaching `ready`**, with `CustodyFacts.initialAtShop(...)`:
holder `shop`, `custodyRevision` **1** (the repository's existing convention
that a written aggregate starts at 1, and that 0 means "never written").

**A missing aggregate is missing, not "still at the shop".** Reading absence as
shop custody is exactly how goods go untracked between the counter and a
rider's bag: it makes "we never wrote the record" indistinguishable from "we
know where it is". A command against absent custody denies
`custodyNotInitialised`.

There is **no client command for initialisation** — custody at the shop is not
something a caller asserts, it is what is true once the shop has assembled the
goods. The backend creates it **atomically with** the transition that
establishes the ready-for-collection boundary: criterion **CA1**.

## 4. Revisions are independent

`custodyRevision` is its own concurrency control, deliberately separate from
the order revision, the picker `slotRevision` and the rider `slotRevision`.
Four aggregates change at different rates; sharing one counter would make every
unrelated write look like a conflict and a genuine conflict undetectable.

## 5. Identity

A worker custodian is bound to **immutable assignment identity** —
`principalId` + `assignmentId` + `assignmentGeneration` — not merely to a
principal. `ResourceScope.assignedPrincipalIds` is a projection of who is
assigned *now*; it cannot say which attempt was holding the goods, and after a
reassignment it would answer with the replacement. Same reasoning as
`SourcePickerBinding`.

All three facts are compared together (`CustodyHolder.isHeldBy`). A replacement
attempt takes a new id **and** a new generation, so comparing one alone could
match a different attempt that happened to line up.

Principal ids, assignment ids and the `resourceId` are validated with the
repository's **canonical opaque-id rule** — the same one `Principal`,
`CommandEnvelope` and `EventEnvelope` apply. **Nothing is trimmed, normalised,
repaired or substituted.**

> **`shopId` is deliberately NOT opaque-validated.** Nothing in this repository
> governs shop ids that way: `ResourceScope.shopId` is unvalidated and existing
> fixtures use values like `shop_alpha` that the rule would reject. Applying it
> here would invent a contract rather than reuse one. It is required non-blank
> only. **Whether shop ids should carry the opaque-id contract is DEFERRED** to
> whichever task owns shop identity.

## 6. `shop → picker` — pickup

| | |
|---|---|
| Command | `custody.record_shop_pickup` |
| Permission | **existing** `picker.custody.record_pickup` |
| Actor | the order's **current accepted picker**, named exactly |

Preconditions — all of them, checked before any effect:

- custody exists, validates, and is `shop`;
- order is `ready`;
- reservation is `committed`;
- picker assignment is `accepted`, its assignee is the acting principal, and
  its `assignmentId` **and** generation match the request;
- every aggregate names the same `resourceId`;
- `expectedCustodyRevision` **and** `expectedOrderRevision` are current.

Effects:

- custody → `picker`, bound to that exact attempt;
- `custodyRevision` **+1**;
- **order stays `ready`** — `CustodyOrderEffect.unchanged()`;
- reservation stays `committed`;
- picker assignment stays `accepted`; rider slot untouched;
- **inventory NONE, financial NONE**;
- scope effect **empty** — possession is not permission. The picker already
  holds `assignedResource` from accepting.
- event: `custody.acquired_by_picker`

**Pickup is physical acquisition, NOT dispatch.** Nothing downstream may read a
collected order as an out-for-delivery one.

## 7. `picker → rider` — receipt, and the dispatch boundary

| | |
|---|---|
| Command | `custody.record_rider_receipt` |
| Permission | **existing** `rider.custody.record_receipt` |
| Actor | the order's **accepted rider**, named exactly |

**Receiver-side by design.** The rider is the party who can attest they are
holding the goods, so making receipt the authoritative edge means custody never
sits in a claimed-but-unconfirmed limbo between two workers.

Preconditions:

- custody exists, validates, and is `picker`;
- the custody holder binding matches the **currently accepted** picker attempt
  (principal, id, generation) — else `custodyHolderBindingMismatch`;
- picker assignment is still `accepted`;
- order is `ready`; reservation is `committed`;
- rider assignment exists, is `accepted`, its assignee is the acting principal,
  and its id and generation match;
- the rider attempt's `SourcePickerBinding` still identifies the picker
  attempt holding custody — else `sourcePickerAssignmentMismatch`;
- resource identities agree; both expected revisions are current.

Effects — **one command, one causation, one transaction**:

| # | Effect |
|---|---|
| 1 | custody `picker → rider` |
| 2 | `custodyRevision` +1 |
| 3 | order `ready → in_delivery` |
| 4 | order revision +1 |
| 5 | reservation stays `committed` |
| 6 | inventory **NONE** |
| 7 | financial **NONE** |
| 8 | picker assignment `accepted → completed` |
| 9 | picker `slotRevision` +1 |
| 10 | picker recipient/assignee identities retained |
| 11 | picker `assignedResource` **removed** |
| 12 | rider assignment stays `accepted` |
| 13 | rider `assignedResource` stays active |
| 14 | `SourcePickerBinding` unchanged |
| 15 | events `custody.transferred_to_rider`, `picker.assignment.completed`, `order.in_delivery` share one `causedByCommandId` |

`OrderState.inDelivery` has always been documented as *"reached once a rider
holds custody"*. This is the edge that finally produces it. **`delivered` is not
entered.**

## 8. Picker completion — a consequence, never a command

There is deliberately **no `completePickerAssignment` command**. Completion is
not a target state a client may select; it is what it *means* for the goods to
have left the picker's hands. Modelling it as a command would create exactly
the arbitrary status patch this contract forbids — a test asserts no custody
command type contains `set_`, `status`, `patch`, `force`, `transfer_to` or
`assign`.

A completed attempt **retains** `offerRecipientPrincipalId`,
`acceptedAssigneePrincipalId`, `assignmentId` and `generation`: finished work
stays attributable. It no longer occupies the slot
(`AssignmentState.completed.occupiesSlot == false`) and **no longer grants
`assignedResource`** — a stale projection must not keep granting
post-acceptance authority (**CA14**).

No command may act **from** `completed` either: a test drives every picker
command against a canonical completed attempt and requires
`unknownTransition` with no transition.

## 9. Role-aware revision model — B3-C1

`reachableSlotRevisionRange(generation, state, {role})` gained an **optional**
`role`. This is additive and preserves the old behaviour exactly:

- **`role` omitted** → `completed` returns null, the pre-0.6 answer. Existing
  callers asking a purely pre-custody question are unaffected.
- **`role: picker`** → `completed` is reachable. Offer + accept + completion is
  **three** mutations for that generation — the same per-generation cost as the
  accept-then-revoke path, asserted by test for generations 1–4.
- **`role: rider`** → still null. **No cost for rider completion was invented.**

The five pre-custody ranges are **identical for both roles and do not depend on
`role` at all**; a test asserts that across every state and generation 1–4.

`AssignmentState.executableForRole(role)` is the matching addition: it is what
an **aggregate validator may check the shape of**, and is deliberately distinct
from `executableInThisSlice`, which is what an **evaluator may act from**.
`completed` is in the picker's shape set and in neither evaluator's action set.

**B3-C1 is satisfied by contract tests in this task.** Picker completion closure
is proven from **real evaluator output**, not arithmetic asserted against
itself: the picker evaluator produces offer → accept (and revoke → re-offer for
higher generations), the custody evaluator produces pickup and receipt, and the
resulting completed aggregate must satisfy `validatePickerAssignmentAggregate`.
Generations 1, 2 and 3 are exercised, ending at revisions 3, 6 and 9.

> That is **contract-test evidence, not backend persistence evidence.** The
> `apply*` fixtures are test infrastructure; **CA9** owns the real transaction.

**B3-C2 remains NOT RUN / FUTURE** — rider `completed` is still unreachable.

## 10. Order aggregate — shape known versus evaluator-owned

`in_delivery + committed` is now canonical, and `OrderState.aggregateShapeKnown`
is the new set the order validator checks against.

The split matters. Previously the validator skipped any state its evaluator did
not own, so an `in_delivery` order whose reservation was `released` or
`expired` would have **passed** validation. It now fails closed, while the
pre-dispatch evaluator still refuses to act from `in_delivery`
(`unknownTransition`) and invents no delivery transition.

`delivered` has no defined pairing and did not acquire one.

## 11. Reassignment safety, derived from real custody

`reassignmentSafetyFor({role, custody})` connects `ReassignmentSafety` — which
FND-003B2A/B2B could only accept from the backend — to something the contract
computes. Its fail-closed meaning is **not weakened**:

| Custody | Picker revoke | Rider revoke |
|---|---|---|
| missing | **blocked** | **blocked** |
| corrupt | **blocked** | **blocked** |
| `shop` | provenNoCustody | provenNoCustody |
| `picker` | **blocked** | provenNoCustody |
| `rider` | **blocked** | **blocked** |
| `customer` | **blocked** | **blocked** |

"The aggregate does not name this worker" is **never** proof they hold nothing.
Unknown is unknown, and a missing record is unknown.

While custody is with the picker, an accepted rider has received nothing, so a
rider revoke may still proceed **if every existing rider-authority precondition
passes** — this changes none of them. After rider receipt the picker assignment
is `completed`, so there is no active picker assignment to revoke at all.

**ADR-0006 and ADR-0007 are unchanged**: no admin shortcut may bypass custody
safety.

## 12. Cancellation — unchanged, and deliberately not extended

FND-003B1's policy boundary stands. Cancellation from `ready` remains
**policyDeferred**, and this slice does **not** decide who pays or whether
unilateral cancellation is allowed.

- **After pickup** the order is still `ready`, but custody now proves physical
  collection happened. A cancellation must **not** release the committed
  reservation through a guessed pre-dispatch path.
- **After receipt** the order is `in_delivery` and the pre-dispatch cancellation
  path cannot act on it at all.

**Stock is never restored on pickup or handoff, and no post-pickup cancellation
behaviour was invented.** Restoration after physical pickup stays deferred until
the return lifecycle proves shop receipt **and** inspection —
`CONSTRAINTS.md` invariant 12. Serialisation is **CA15**.

## 13. `picker.custody.record_handoff` — kept, not executable

The permission keeps its id, roles and scope. It is **not** re-scoped, widened
or deleted, and **no custody command maps to it**.

**A picker-side record alone does not transfer custody in this slice.** Making
it do so would need a sender/receiver proof protocol, and **no token, QR, OTP,
signature, photo, biometric or GPS proof was invented**. The authoritative edge
is the rider's receipt.

Whether a handoff-proof contract (and any expiry for it) should exist is
**DEFERRED**, not answered here.

## 14. Direct shop → rider — still deferred

No `shop → rider` custody transition exists. `agent.assignment.offer_rider`
keeps its stable id, remains **non-executable**, and authorizes no custody
command — asserted by test. **RA18 is unchanged and not reinterpreted.**

## 15. Time, privacy and notifications

**Custody acquisition is not time-driven.** No pickup timeout, handoff timeout,
proof TTL or numeric duration was invented. Assignment `timeoutPolicyRef`
behaviour is untouched. Timestamps come from server UTC through the existing
event contract.

Custody events carry routing and identity only — resource id, custody revision,
assignment identity, server time. **No customer address, phone number, order
contents, money amount or proof material.**

Notification delivery **does not** authorize pickup, **does not** authorize
receipt, **does not** prove custody and **does not** change state. It may be
missed; clients re-read authorized server state. No notification dependency or
platform code was added.

## 16. Storage requirements — future

Contract-only task. **Live data migration: NOT APPLICABLE / NOT RUN. Firestore
rules: NOT IMPLEMENTED. Indexes: NOT IMPLEMENTED. Deployment: NOT RUN.** No
Firebase resource was created.

The future storage must provide: an explicit current custody aggregate; a
**bounded/paginated** immutable history and outbox rather than an unbounded
array; one atomic cross-aggregate transaction; and reconciliation for invalid
stored states.

Rollback for this contract is the ordinary Git revert of this commit before any
merge or deployment. **An installed binary cannot automatically downgrade a
contract**, and no such claim is made.

## 17. Backend acceptance criteria — CA1–CA18

**All NOT RUN.** No trusted backend persistence exists. None is a blocker to
this contract task, and **none may be marked PASS from Dart fixtures**.

| # | Criterion |
|---|---|
| CA1 | Ready-order custody is explicitly initialised at shop; absence is not interpreted as shop. |
| CA2 | Shop pickup uses fresh picker authorization and the exact current accepted picker assignment for the resource. |
| CA3 | Wrong-role, inactive, suspended, revoked, non-recipient or stale picker facts cannot acquire custody. |
| CA4 | Duplicate/stale pickup changes custody exactly zero additional times. |
| CA5 | Pickup and picker revoke are serialised; if pickup wins, a later revoke fails custody safety, and if revoke wins, pickup cannot use that stale assignment. |
| CA6 | Pickup leaves order `ready`, reservation `committed`, available inventory unchanged and financial effect NONE. |
| CA7 | Rider receipt requires the exact accepted rider, current picker custody, exact picker/rider assignment identities and the immutable `SourcePickerBinding`. |
| CA8 | Wrong rider, stale assignment, source-picker mismatch or malformed custody aggregate produces no mutation. |
| CA9 | Rider receipt **atomically** commits custody `picker→rider`, order `ready→in_delivery`, picker `accepted→completed`, projection changes, the dedupe result and all required outbox events. |
| CA10 | Rider receipt leaves the rider assignment accepted/active; rider `completed` remains future. |
| CA11 | No direct shop→rider custody path or `agent.assignment.offer_rider` execution exists in this slice. |
| CA12 | Duplicate, stale and reordered rider receipt mutates nothing. |
| CA13 | Picker custody makes picker reassignment unsafe; rider custody makes rider reassignment unsafe; unknown/corrupt custody fails closed. |
| CA14 | After picker completion, a stale picker `assignedResource` projection cannot continue granting authority. |
| CA15 | Cancellation races are serialised with current order/custody/assignment facts, and no post-pickup stock restoration is invented. |
| CA16 | Invalid persisted custody/order/assignment combinations never drive mutation and are surfaced for reconciliation. |
| CA17 | Domain events are server-assigned, private-data-minimal, committed via outbox, and notification delivery never acts as authorization. |
| CA18 | All command retries/replays still obey R33–R40 fresh authorization and principal-scoped idempotency before any stored result is returned. |

## 18. Out of scope

Not implemented, and **not guessed**: delivery attempts · customer delivery ·
refusal and failure · returns · post-pickup stock restoration · COD · payment ·
fees · commissions · settlement · remittance · customer proof and disputes ·
handoff proof protocols · direct agent→rider pickup · admin custody override ·
customer custody · rider completion · pickup/handoff timeouts.
