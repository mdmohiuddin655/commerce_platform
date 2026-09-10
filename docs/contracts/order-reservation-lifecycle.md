# Pre-dispatch order and reservation lifecycle

**Contract version 0.3** (FND-003B1). Implemented in `packages/contracts`,
pure Dart — no Flutter, no Firebase, no external dependency.

This slice owns the lifecycle from checkout through to goods being ready for
collection, plus the pre-dispatch terminal paths and every inventory-reservation
outcome that reaches them. **It stops before dispatch.**

## Order states

| State | Executable here | Meaning |
|---|---|---|
| `placed` | yes | Checkout succeeded and stock is reserved |
| `accepted` | yes | The shop's agent accepted the order |
| `preparing` | yes | The shop is assembling goods |
| `ready` | yes | Goods assembled, awaiting collection |
| `rejected` | yes | **Terminal.** Agent refused |
| `cancelled` | yes | **Terminal.** Cancelled before dispatch |
| `in_delivery` | **no** | Declared for enum stability; owned by a later slice |
| `delivered` | **no** | Declared for enum stability; owned by a later slice |

The last two exist in `OrderState` so that adding them later is not a breaking
enum change. **No transition into or out of them is enumerated**, and a test
proves no reachable transition produces them. A state existing in the enum is
not permission to use it.

Terminal means terminal: nothing leaves `rejected` or `cancelled` in any
direction. There is no un-reject, no reopening and no reactivation, and none
was invented.

## Reservation states

| State | Holds units? | Expirable? | Meaning |
|---|---|---|---|
| `active` | yes | **yes** | Held for a `placed` order; available stock already decremented |
| `committed` | yes | **no** | Order accepted; the allocation belongs to it |
| `released` | no | — | **Terminal.** Given back after rejection or cancellation |
| `expired` | no | — | **Terminal.** Given back by the expiry worker |

### The invariant

> **The same reserved units may be restored to available stock at most once.**

Restoration happens exactly on the transition *into* `released` or `expired`.
Both are terminal, so a duplicate cancellation, a duplicate rejection or a
retried expiry worker finds no held reservation and produces **no effect at
all**.

`released` and `expired` are distinguished for audit — "someone acted" versus
"nobody did" — but their inventory effect is identical.

## Aggregate integrity — trusted facts are validated first

The transition graph is internally consistent: it can never *create* an
impossible order/reservation combination. That says nothing about facts
arriving **from storage**. A partially loaded, mid-migration or
externally-written aggregate must not drive an inventory mutation, so
`evaluateOrderTransition` validates the aggregate **before any transition
helper can produce an effect**.

```text
trusted facts loaded
  → aggregate integrity check      ← added by FND-003B1-FIX-001
  → source state / revision / command evaluation
  → typed transition and effect
```

### Canonical order ↔ reservation pairs

| Order state | Valid reservation states |
|---|---|
| `placed` | `active` **or** `expired` |
| `accepted` | `committed` |
| `preparing` | `committed` |
| `ready` | `committed` |
| `rejected` | `released` |
| `cancelled` | `released` |

Two entries deserve comment:

- **`placed + expired` is canonical.** It is precisely the expiry-wins race
  outcome: units restored, order still `placed`, simply no longer acceptable.
  Treating it as corruption would break that outcome.
- **`rejected` and `cancelled` pair only with `released`, never `expired`** —
  the units came back because someone acted, not because time passed.

Anything else — `placed + committed`, `accepted + active`, `ready + expired`
and so on — is **corruption** and denies with `aggregateInconsistent`.

### Canonical absence

Placement acts only on an order that is absent in the exact sense:

`state == null` **and** `revision == 0` **and** `reservationState == null`
**and** `reservedUnits == 0`.

A "non-existent" order carrying a revision or a reservation record is a partial
load. Treating it as absent would place a duplicate order.

### Revision and unit integrity

- An existing order has `revision >= 1`; it has been written at least once.
- An absent order has `revision == 0` exactly.
- Any existing reservation record has `reservedUnits > 0`.

A reservation for zero units is meaningless; for **negative** units it would
produce an inventory mutation that *destroys* stock. Malformed quantities are
never clamped or absolute-valued — **the aggregate is denied**.

### This validation does not repair anything

It fails closed and stops. No corrupt aggregate is silently corrected, because
a repair without an audit trail is indistinguishable from a bug. Reconciliation
and admin tooling own repair, later.

### It is a second line of defence, not a substitute

The backend must still maintain the canonical pair **atomically** in one
transaction, and must never intentionally persist an intermediate combination
such as `accepted + active` or `placed + committed`. This check exists for when
that guarantee has already failed.

## Transition matrix

Every executable edge. **Anything not listed fails closed** with
`unknownTransition`.

| Command | From | To | Permission | Lifecycle preconditions | Revision | Inventory effect | Financial | Event |
|---|---|---|---|---|---|---|---|---|
| `order.place` | *(none)* | `placed` | `customer.checkout.submit` | order does not exist; `expectedRevision == 0`; `requestedUnits > 0`; **stock reservable** | `0 → 1` | **reserve** *n* (available −*n*) | none in this slice | `order.placed` |
| `order.accept` | `placed` | `accepted` | `agent.order.accept` | reservation `active` | `r → r+1` | **commit** (available **0**) | none in this slice | `order.accepted` |
| `order.reject` | `placed` | `rejected` | `agent.order.reject` (reason required) | reservation holds units | `r → r+1` | **restore** *n* (available +*n*) | **deferred** | `order.rejected` |
| `order.start_preparing` | `accepted` | `preparing` | `agent.fulfillment.record_progress` | reservation `committed` | `r → r+1` | **none** | none in this slice | `order.preparing` |
| `order.mark_ready` | `preparing` | `ready` | `agent.fulfillment.record_progress` | reservation `committed` | `r → r+1` | **none** | none in this slice | `order.ready` |
| `order.cancel` | `placed` | `cancelled` | `customer.order.request_cancellation` (reason required) | reservation holds units | `r → r+1` | **restore** *n* | **deferred** | `order.cancelled` |
| `order.cancel` | `accepted` | `cancelled` | as above | reservation holds units | `r → r+1` | **restore** *n* | **deferred** | `order.cancelled` |
| `reservation.expire` | `placed` | `placed` | **none — trusted worker** | reservation `active` | `r → r+1` | **restore** *n* | none in this slice | `reservation.expired` |

Notes:

- **Acceptance never decrements stock twice.** The decrement happened at
  placement; committing moves ownership, with an available-stock delta of
  exactly `0`.
- **Becoming `ready` releases nothing.** The preparation edges have no
  inventory effect.
- **Expiry leaves the order `placed`.** It is the *reservation* that ends. The
  order simply becomes unacceptable, because acceptance requires an `active`
  reservation.
- Every applied transition advances the order revision, which is what makes a
  stale `expectedRevision` detectable.
- **Release paths are pair-specific.** `order.reject` and `order.cancel` from
  `placed` require exactly `placed + active`; `order.cancel` from `accepted`
  requires exactly `accepted + committed`. A generic "still holds units" test
  would let an impossible pair through, which is the defect FND-003B1-FIX-001
  closed.

## Reservation transition table

| Trigger | From | To | Available stock |
|---|---|---|---|
| `order.place` | *(none)* | `active` | −*n* |
| `order.accept` | `active` | `committed` | **0** |
| `order.reject` | `active` | `released` | +*n* |
| `order.cancel` | `active` or `committed` | `released` | +*n* |
| `reservation.expire` | `active` | `expired` | +*n* |

No transition leaves `released` or `expired`.

## Cancellation policy boundary

The blueprint says: *"Before dispatch, a permitted cancellation releases
reservation once."* **Permitted** is the operative word — the lifecycle
decides, never the client. `customer.order.request_cancellation` is a *request*
permission by design.

| Source state | Status |
|---|---|
| `placed` | **executable** |
| `accepted` | **executable** |
| `preparing` | **DECISION REQUIRED** — denies with `policyDeferred` |
| `ready` | **DECISION REQUIRED** — denies with `policyDeferred` |

Up to and including acceptance, no physical shop work has been committed, so
releasing the reservation is the entire effect and no undecided policy is
needed.

From `preparing` onward the shop is assembling or has assembled goods. Whether
a customer may cancel unilaterally, whether shop or admin approval is required,
and who bears the cost are **business questions this repository does not
answer**. They need owner decision **O6** and the fee policy owned by
**FND-003C**.

Those two edges deny with `policyDeferred` rather than `unknownTransition`, so
a backend can tell *"not decided yet"* from *"never allowed"* — and so nobody
is tempted to fill the gap with a guessed rule.

**No cancellation, refusal or rejection fee amount exists anywhere in this
slice.** See below.

## Financial classification — why "deferred" is not "zero"

Every transition carries a `FinancialClassification`, never a number:

- `noneInThisSlice` — this transition moves no money and never will
  (placement, acceptance, the preparation edges, expiry).
- `deferredToFinancialSlice` — this transition **may** have a financial
  consequence and it is **not yet defined** (rejection, cancellation).

The failure this prevents is a later implementer reading "no fee recorded" as
"the fee is zero". A cancellation whose fee policy has not been decided is not
a free cancellation. A backend must refuse to derive an amount from
`deferredToFinancialSlice`.

No amount, currency, rate, refund, commission, settlement or posting appears in
this slice. Money is **FND-003C**, blocked on **O6**.

## Reservation expiry

Expiry is a **trusted server worker transition**. It is explicitly **not**:

- a client command — `LifecycleCommand.expireReservation.requiredPermission`
  is `null`, and `evaluateAuthorization` denies a `systemWorker` principal
  every human-role permission, so a worker cannot borrow one; it runs its own
  audited path;
- a TTL deletion — **a TTL deletion alone must never restore stock**. Deleting
  a reservation document is not an inventory transaction. Restoration happens
  only through this transition, inside the same transaction as the stock
  mutation;
- a mobile timer, or anything a notification triggers.

**No expiry duration is invented here.** How long a reservation may live is
configuration and policy outside this state machine. The state machine only
says what happens *when* expiry is applied.

Repeated expiry processing is deterministic: a retried worker finds the
reservation already terminal and is denied with `reservationAlreadyFinal`,
producing no effect.

## Acceptance versus expiry — the race

Both outcomes are serialized by the server transaction and revision ordering.
**Wall-clock time and client arrival order play no part.**

**Case 1 — acceptance commits first.** The reservation becomes `committed`,
which is not expirable, and the order is no longer `placed`. A later expiry
attempt is denied (`wrongSourceState`) and restores nothing.

**Case 2 — expiry commits first.** The reservation becomes `expired` and the
units are restored once. A later acceptance attempt is denied
(`reservationAlreadyFinal`); the order cannot become `accepted` without a new
reservation path, which this slice does not define.

> **An accepted order and restored inventory from the same reservation cannot
> coexist.** Precisely, this means two things:
>
> 1. **The transition graph cannot produce that combination.** Reaching
>    `accepted` requires an `active` reservation, and acceptance moves it to
>    `committed`, after which expiry has no source state to act from. Tested in
>    both orderings, asserting stock conservation each way.
> 2. **Facts loaded from storage claiming that combination are rejected**
>    before any effect, as a non-canonical pair (FND-003B1-FIX-001).
>
> What this does **not** claim: Dart types cannot make corrupt persistence
> impossible. If the backend writes `accepted + active`, the type system will
> not have prevented it — the evaluator will merely refuse to act on it. Atomic
> persistence remains a backend obligation.

## Denial reasons

`wrongSourceState` · `revisionConflict` · `reservationAlreadyFinal` ·
`alreadyTerminal` · `policyDeferred` · `reservationUnavailable` ·
`unknownTransition` · `aggregateInconsistent`

`aggregateInconsistent` means **corruption, not a race**: the facts could not
have been produced by this lifecycle. `reservationMissing` and
`reservationNotActive` were removed by FND-003B1-FIX-001 — aggregate validation
subsumes both, and a denial reason a backend can never observe is worse than
none.

**Internal.** For backend logs, tests and audit — not returned verbatim to an
untrusted caller, for the same reason `DenyReason` is not.

## Events

`order.placed` · `order.accepted` · `order.rejected` · `order.preparing` ·
`order.ready` · `order.cancelled` · `reservation.expired`

Emitted through `EventEnvelope`: server-assigned `eventId`, `resourceId`,
resulting `resourceRevision`, `causedByCommandId` where command-driven (**null
for worker-driven expiry**), and server UTC time.

An event is a **fact the server recorded**. Receiving one authorizes nothing —
a client re-reads server state. A transport message id is never the business
event id. Payloads carry routing identifiers only: no customer address,
contact detail, order contents or amount, because a copy may travel through a
push transport.

## Integration order — where this evaluator sits

Lifecycle evaluation is the **last** step, and it does not re-implement what
comes before it:

```text
incoming commandType
  → trusted backend command router      (maps to the required Permission)
  → fresh authorization                 (FND-003A, current server facts)
  → principal-scoped idempotency        (FND-003A, (principalId, commandId))
  → load current order + reservation state and revision
  → evaluateOrderTransition             ← this slice
  → atomic commit
```

`LifecycleRequest` deliberately carries no principal, no grant and no payload.
Duplicating FND-003A's checks here would create a second place for them to
drift.

## Required backend transaction boundary

**Not implemented in FND-003B1.** For every transition above, the future
backend must commit atomically:

- the order document and its new revision;
- the reservation state;
- the inventory mutation;
- the command dedupe result;
- the outbox event.

**No push notification is sent inside the retryable transaction.** Delivery
happens from the outbox after commit.

### Future backend test cases

All **NOT RUN** — no backend implementation exists. Owned by FND-004 or the
bounded backend slice that implements the command pipeline, alongside the
existing R33–R40 in `privacy-and-security-boundaries.md`.

- [ ] L1 — Two concurrent checkouts for the last unit: exactly one reaches
      `placed`, the other is refused; available stock never goes negative.
- [ ] L2 — Rejection releases stock exactly once.
- [ ] L3 — Cancellation releases stock exactly once.
- [ ] L4 — Duplicate cancellation restores nothing further.
- [ ] L5 — Duplicate rejection restores nothing further.
- [ ] L6 — Acceptance wins the expiry race: order accepted, stock still held.
- [ ] L7 — Expiry wins the race: stock restored once, later acceptance denied.
- [ ] L8 — A retried expiry worker is a no-op.
- [ ] L9 — A stale `expectedRevision` is refused and mutates nothing.
- [ ] L10 — The same `commandId` retried returns the stored result without
      re-applying the inventory effect.
- [ ] L11 — Reordered commands cannot duplicate an inventory effect.
- [ ] L12 — A TTL deletion of a reservation document does **not** restore
      stock on its own.
- [ ] L13 — Persisted order/reservation aggregates are reconciled for canonical
      pair consistency, and an invalid pair never drives an inventory mutation.
      The backend must never intentionally persist `accepted + active`,
      `placed + committed` or any other non-canonical pair.

## The dispatch boundary (FND-003B3A)

`in_delivery` is **reachable since contract 0.6**, but not from this evaluator.
It is produced by rider custody receipt — see
[custody-lifecycle.md](custody-lifecycle.md) §7 — and this slice invents no
delivery transition: every pre-dispatch command acting from `in_delivery` is
refused `unknownTransition`, asserted by test.

Two sets now exist, and the difference is the point:

| Set | Means |
|---|---|
| `OrderState.executableInThisSlice` | states this evaluator may **act from**. Unchanged. |
| `OrderState.outsideThisSliceEvaluator` | states it may **not** act from — `in_delivery` and `delivered`. Together with the set above this partitions the enum. |
| `OrderState.aggregateShapeKnown` | states whose order/reservation pairing is **defined** — the six executable ones **plus `in_delivery`**. |
| `OrderState.notYetImplemented` | states **no slice implements** — now `{delivered}` only. |

> **Corrected by FND-003B3A-FIX-001.** `notYetImplemented` previously also
> listed `in_delivery`, which stopped being true the moment custody receipt
> could produce it. Exported metadata that says a reachable state is
> unimplemented is a claim a later reader will believe, so the "this evaluator
> cannot act from it" concept got its own name instead.

`canonicalAggregatePairs` gained `in_delivery: {committed}`, and
`validateAggregate` now checks against `aggregateShapeKnown`. Previously it
skipped any state the evaluator did not own, so an `in_delivery` order whose
reservation was `released` or `expired` would have **passed**; it fails closed
now. **Dispatch restores no stock** — the reservation stays `committed`, and
stock cannot become available again until the return lifecycle proves shop
receipt *and* inspection.

`delivered` still has no defined pairing and did not acquire one.

Cancellation policy is **unchanged**: cancellation from `ready` remains
`policyDeferred`, and FND-003B3A decided nothing about who pays or whether
post-pickup cancellation is allowed.

## Out of scope — next FND-003B slices

None of the following is defined, guessed or partially implemented here:

- picker assignment lifecycle;
- rider assignment lifecycle;
- custody;
- delivery attempts;
- returns;
- delivery confirmation;
- proof and dispute workflows;
- payment and COD;
- fees;
- commissions;
- settlement and the cash journal.

`in_delivery` and `delivered` are declared but unreachable. No feature may
guess an edge into them.
