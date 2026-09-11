# Delivery attempt and return lifecycle (FND-003B3B)

**Contract 0.10. Additive.** Shared, pure Dart, in `packages/contracts`. No
Flutter, no Firebase, no serialization, no persistence.

FND-003B3A ended at the **dispatch boundary**: a rider holds the goods and the
order is `in_delivery`. Everything after that was undefined. This slice defines
the **bounded non-success path** — and only that.

> **Successful delivery is still not executable, and this task did not make it
> so.** `CONSTRAINTS.md` invariant 13 is **not discharged**.

## 1. Two dimensions, neither of them the order

```text
what happened at the door?   ->  DeliveryAttemptState
where did the goods end up?  ->  ReturnState
what is the order doing?     ->  OrderState, unchanged at in_delivery
```

Folding either into `OrderState` would make *"refused once, back at the shop,
inspected and unsellable"* indistinguishable from *"cancelled before it ever
left"*, and would force a post-dispatch order state to be invented — which is
inventing the commercial outcome. The order does not move in this slice at all.

## 2. The attempt

```text
pending ──▶ out_for_delivery ──▶ refused
                             └─▶ failed

                             ✗─▶ delivered        (enumerated, never executable)
```

The first attempt is written by the trusted server at dispatch, in `pending`,
with its **own opaque attempt id** and **its own revision**. There is no command
and no permission for that: a client command whose only purpose is to
manufacture trusted server state is exactly the arbitrary status patch this
contract forbids. The precedent is `initialiseCustodyAtShop`.

| Edge | Command | Permission |
|---|---|---|
| `pending → out_for_delivery` | `delivery.record_out_for_delivery` | `rider.delivery.record_attempt` |
| `out_for_delivery → refused` | `delivery.record_refusal` | `rider.delivery.record_attempt` |
| `out_for_delivery → failed` | `delivery.record_failure` | `rider.delivery.record_attempt` |
| *(none)* → `delivered` | `delivery.record_delivered` | **always refused** |

### Why `delivered` is refused

`evaluateRecordDelivered()` takes **no arguments at all** and always returns
`deliveryProofPolicyDeferred`. The missing piece is the **proof-satisfaction
policy**, not data — so a signature accepting facts would be misleading and
would invite a later reader to "just add the obvious edge".

**A `satisfied` `DeliveryProofAssessmentRecord` is not consumed as authority.**
*"A proof result exists"* and *"the policy is satisfied"* are different claims,
and only the first is true today. No B3B source references the assessment
verdict at all — asserted by a source scan, not by a comment.

## 3. Refusal opens the return, atomically

A canonical refusal after dispatch produces **one** transition carrying both
halves:

```text
attempt:      out_for_delivery -> refused        (attempt revision +1)
return:       not_required     -> required      (return revision +1)
order:        unchanged
custody:      unchanged, still the rider's
rider assignment: unchanged, NOT completed
reservation:  still committed
inventory:    NONE
financial:    deferredToFinancialSlice  ← UNKNOWN, never zero
events:       delivery.attempt_refused, return.required
```

Splitting the two would allow a refusal with nothing saying the goods must come
back, and a return nobody asked for.

**`deferredToFinancialSlice` means unknown.** Whether a refusal fee, a refund, a
redelivery charge or any liability follows is **FND-003C**'s — **O6 is resolved**
(ADR-0011), and the remaining money lifecycle work is still unimplemented.
Reading it as "free" is the misreading the type exists to prevent.

## 4. Failure decides nothing

A failed attempt is recorded and **stops**.

The blueprint says a failed attempt *may* require a return. Nothing accepted
says **when**, who decides, how many retries are allowed, or who bears the cost.
So:

- `evaluateRecordDeliveryFailure` **does not take the return facts as a
  parameter at all**. It structurally cannot open a return — a future edit would
  have to change the signature, which is a reviewable event;
- `evaluateFailedAttemptReturnDecision()` is enumerated and always refused with
  `failureReturnPolicyDeferred`.

Depends on a delivery retry/failure policy, FND-003C and **O6**.

## 5. The return, direct route only

```text
not_required ──(refusal)──▶ required ──▶ in_transit ──▶ received ──▶ inspected ──▶ closed
```

| Edge | Command | Permission | Custody | Stock |
|---|---|---|---|---|
| `required → in_transit` | `return.begin_transit` | `admin.return.administer` | unchanged | none |
| `in_transit → received` | `return.record_shop_receipt` | **`agent.return.record_receipt`** | **rider → shop, once** | none |
| `received → inspected` | `return.record_inspection` | `admin.return.administer` | unchanged | **restore, once, if restockable** |
| `inspected → closed` | `return.close` | `admin.return.administer` | unchanged | none |

The return aggregate is created **with the attempt**, in `not_required`, so that
"no return is needed" is a **written fact** rather than a missing record.
Absence is never converted into a state.

### Shop receipt is an assertion, not proof

It follows FND-003B3A's receiver-side pattern: the party who can attest to
holding the goods records it. It is an **authorized business assertion** — there
is no OTP, QR code, signature, photo, GPS fix or biometric anywhere in this
slice, and choosing one is not this task's to make.

Custody moves `rider → shop` with the custody revision incremented **exactly
once**, and only after the custody holder is proven to be the **exact accepted
rider attempt** (principal + assignment id + generation, all three).

### The via-picker route is not implemented

`rider → picker → shop` is in the blueprint and is enumerated as
`ReturnRoute.riderToPickerToShop`, but `evaluateReturnViaPicker()` always
refuses with `returnRouteNotImplemented`.

**The gap is authority, not a state machine.** The accepted picker assignment is
`completed` at dispatch — that is exactly what FND-003B3A made rider custody
receipt do — and completion also removes the picker's `assignedResource` scope.
So when a return begins, no picker holds any authority over the order, and no
accepted permission would give one back. See **ADR-0010**.

## 6. The restock invariant

> **Reserved units may become available stock again only after the shop has the
> goods back AND has looked at them, and then exactly once.**

Neither fact alone is enough: receipt without inspection cannot tell a sellable
item from a broken one, and inspection without receipt is a claim about goods
nobody at the shop is holding. Both are checked independently — the return must
be `received` **and** custody must actually be at the canonical shop.

Stock is **never** restored:

- on a refused attempt;
- on a failed attempt;
- when the return becomes required;
- when the return enters transit;
- merely because shop receipt happened;
- on close;
- for a `damaged` or `quarantined` disposition.

| Disposition | Reservation | `availableStockDelta` |
|---|---|---|
| `restockable` | → `returned` | **+units** |
| `damaged` | → `returned` | **0** |
| `quarantined` | → `returned` | **0** |

A source-swept test enumerates **all nine** executable transitions and asserts
exactly one increases available stock and exactly one moves custody.

### Scope: whole-order returns only

**B3B models a WHOLE-ORDER return, and nothing smaller.** This is a normative
limit of the contract, not a rule a backend enforces — the API simply cannot
represent anything else.

- One `ReturnDisposition` applies to the **entire committed reservation** for
  that order.
- **Partial returns are not modelled.** Neither are per-line, per-item or
  per-quantity dispositions.
- **A caller cannot choose the quantity restored.** No request type in this
  slice carries a `units`, `quantity`, `returnedUnits` or line-item field; the
  inspection request carries only revisions, one disposition and a timestamp.
- A `restockable` inspection restores **exactly** the canonical
  `order.reservedUnits`, read from the validated order aggregate.
- A `damaged` or `quarantined` inspection restores **zero**.
- A **mixed** outcome — *"three of the five items are fine, two are broken"* —
  is **not representable**. There is no way to express it, and no disposition
  combination means it.

That last point is the reason for the limit. If mixed returns were silently
squeezed into a single disposition, the only two available answers would be
*over-restock the whole order* or *write off goods that were perfectly
sellable*. Both are wrong, and the first one puts damaged stock back on the
shelf — exactly the failure this slice exists to prevent. Refusing to represent
the case is safer than representing it badly.

**Future partial-return support requires its own additive contract** with
explicit per-line or per-quantity semantics, and **must not reinterpret this
API**: `ReturnDisposition` must not be overloaded to mean "the disposition of
some unspecified subset", and `InventoryEffect.restore` here must keep meaning
the whole canonical reserved quantity.

### Disposition decides inventory, never fault

`ReturnDisposition` answers exactly one question — *may these units be sold
again?* It deliberately cannot express who damaged them, who owes for them,
whether a refund or replacement is due, or what commission applies. Those belong
to **FND-003C** (**O6 resolved** by ADR-0011; the remaining money lifecycle work
is still unimplemented) and to a dispute-resolution slice that does
not exist.

`quarantined` is kept distinct from `damaged` — inventory-identical — because
*"we know it is unsellable"* and *"we are not yet willing to say it is
sellable"* are reviewed by different people.

## 7. `ReservationState.returned`, and why it is not `released`

`released` carries a promise: **its units were restored to available stock**.
That promise holds for every path into it, and both code and audit rely on it.

A returned reservation cannot make that promise — a damaged or quarantined
return restores nothing. Overloading `released` would either make its promise
false for damaged goods, silently turning breakage into sellable stock in every
downstream reader, or force every reader to re-derive the disposition before
trusting a state name.

So `returned` says only: *the reservation is over and the goods are physically
back*. The stock consequence travels separately, in the transition's
`InventoryEffect`.

`canonicalAggregatePairs[in_delivery]` is now `{committed, returned}`: after an
inspected return the order is still `in_delivery` — no accepted slice defines a
post-dispatch order state for "came back" — while its reservation has ended.

## 8. Double-restore is impossible, not merely unlikely

Three independent guards:

1. inspection requires the return to be exactly `received`; a replay finds
   `inspected` and is refused;
2. inspection requires the reservation to be `committed`; after the first
   inspection it is `returned`, so even a forged `received` return cannot
   restore again;
3. `return.close` requires the reservation to be **already** `returned`, so
   closing can never be the transition that ends a live reservation and can
   never carry an inventory effect.

## 9. Authorization

Every executable operation requires FND-003A's unforgeable
`AuthorizationGrant`, checked by `checkAttemptReturnAuthorization` against:

```text
expectedResourceId is a valid opaque id      (taken from the READ-SET, not the grant)
grant.permission == the operation's requiredPermission
grant.covers(principalId: actor.id, resourceId: expectedResourceId)
```

`expectedResourceId` comes from the stored aggregate, never from
`grant.resourceId` — passing the grant's own resource back to itself is the
tautology FND-003D2B-FIX-003 removed, and it proves nothing.

**Freshness remains the backend's**: criteria **R33–R40**, **NOT RUN**.

### One new permission

`agent.return.record_receipt` — agent role, `ownShop` scope, reason required.
Shop-side receipt authority did not exist, and
`agent.fulfillment.record_progress` was deliberately **not** widened: its own
rule says it never writes trusted stock, order status or cash fields, and a
return receipt is the fact the whole restock invariant hangs from. No arbitrary
admin custody override was added.

`Permission.values` and `permissionMatrix`: **38 → 39**.

## 10. Per-operation read-sets

Each operation is its own function, and the split is enforced by the **type
system**:

| Operation | attempt | return | order | custody | rider assignment |
|---|:-:|:-:|:-:|:-:|:-:|
| out for delivery | ✓ | — | ✓ | ✓ | ✓ |
| refusal | ✓ | ✓ | ✓ | ✓ | ✓ |
| **failure** | ✓ | **—** | ✓ | ✓ | ✓ |
| begin transit | ✓ | ✓ | ✓ | ✓ | — |
| shop receipt | — | ✓ | ✓ | ✓ | ✓ |
| inspection | — | ✓ | ✓ | ✓ | — |
| close | — | ✓ | ✓ | — | — |

FND-003D2B shipped one evaluator with a shared read-set, and
FND-003D2B-FIX-001 had to split it because **a shared read-set silently becomes
a shared precondition** — a torn read of an aggregate an operation never used
could freeze a valid operation out. This slice starts split.

## 11. What stays unavailable

- `OrderState.delivered` — unreachable, and has no canonical reservation pairing;
- `CustodyHolderKind.customer` — unreachable; no B3B code references it;
- rider `AssignmentState.completed` — unreachable, **B3-C2 stays FUTURE**, and
  its revision cost is still not invented;
- dispute resolution — still deferred (FND-003D2B);
- post-dispatch cancellation consequence, COD, fee, refund, commission,
  settlement — none decided;
- any proof mechanism — none chosen.

## 12. Backend criteria — all NOT RUN

Pure Dart tests are **contract** evidence, not persistence evidence. None of
these is satisfied by this task.

| ID | Criterion |
|---|---|
| **ATT1** | First attempt created create-if-absent, atomically with or causally bound to the dispatch boundary |
| **ATT2** | Authoritative transaction read-set: attempt, return, order, reservation, custody, rider slot in one consistent read |
| **ATT3** | Fresh authorization before new execution **and** before replay |
| **ATT4** | Principal-scoped idempotency on every attempt command |
| **ATT5** | Attempt state, return state and outbox written in one atomic transaction |
| **ATT6** | Duplicate and reordered attempt commands produce no second effect |
| **ATT7** | Refusal vs. rider-revocation race resolves without losing custody attribution |
| **ATT8** | Refusal vs. cancellation race resolves deterministically |
| **ATT9** | A second attempt cannot be initialised over a terminal one |
| **RET1** | Shop receipt moves custody exactly once under concurrent submission |
| **RET2** | Receipt vs. another attempt command race is serialised |
| **RET3** | Inspection replay cannot restore stock twice **in storage** |
| **RET4** | Damaged/quarantined disposition persists with zero stock delta |
| **RET5** | Cross-resource isolation: a return command cannot touch another order |
| **RET6** | Current membership and scope re-read at execution time |
| **RET7** | Audit reason persisted for every `admin.return.administer` command |
| **RET8** | Close cannot run before inspection has been committed |

**Migration: NOT APPLICABLE / NOT RUN.** Rules and indexes: **NOT
IMPLEMENTED / NOT RUN.** Deployment: **NOT RUN.** GitHub CI: **NONE.**
