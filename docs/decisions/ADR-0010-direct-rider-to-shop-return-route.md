# ADR-0010 — The first executable return route is direct rider→shop, and returned stock is separate from liability

- **Status:** Accepted
- **Date:** 2026-09-11
- **Task:** FND-003B3B
- **Contract:** 0.9 → 0.10 (additive)
- **Supersedes:** nothing. **Extends:**
  [ADR-0006](ADR-0006-admin-picker-assignment-override.md),
  [ADR-0007](ADR-0007-admin-rider-assignment-override.md)

## Context

FND-003B3A ended at the dispatch boundary: a rider holds the goods and the order
is `in_delivery`. FND-003B3B has to define what happens when delivery does **not**
succeed — a refusal, and the journey the goods then make.

Three decisions in that slice are durable, are expensive to reverse because they
would be baked into stored inventory and custody history, and are each easy to
get wrong in a way that looks reasonable:

1. **Which return route is executable first?** The blueprint allows both
   `rider → shop` and `rider → picker → shop`.
2. **What terminal state does the reservation reach**, given that a returned
   item may be unsellable?
3. **Does the inspection outcome say anything about who is at fault?**

## Decision 1 — only `rider → shop` is executable

`ReturnRoute.riderToShop` is implemented. `ReturnRoute.riderToPickerToShop` is
enumerated and always refused with `returnRouteNotImplemented`.

### Why the via-picker route is deferred

**The gap is authority, not a state machine.** Writing the extra states would
have been trivial; that is precisely why it would have been the wrong thing to
do.

FND-003B3A made rider custody receipt **complete the picker assignment** — that
is what dispatch *means* — and completion also removes the picker's
`assignedResource` scope so that a stale projection cannot keep granting
post-acceptance authority (criterion **CA14**).

So at the moment a return begins:

```text
picker assignment state = completed
picker's assignedResource scope = removed
permission representing post-dispatch picker return authority = none exists
```

Making the route executable therefore requires **inventing** three things: a
concept of post-dispatch picker work, a permission for it, and a scope
projection that re-grants a *completed* worker access to a resource. That last
one is not a small addition — it reopens an authority the custody slice closed
deliberately.

The accepted picker-assignment contract does not decide any of it, so this slice
does not either. Reusing `picker.custody.record_pickup` or
`picker.custody.record_handoff` to fake it was rejected: those are pre-dispatch
permissions, and repurposing a permission to avoid adding one is how a
permission vocabulary stops describing what it grants.

### Expansion path, without history rewrite

The route is already a **stored field** on the return aggregate, validated
against `ReturnRoute.executableInThisSlice`. A future slice can:

1. define post-dispatch picker return authority and its permission;
2. add the intermediate custody leg;
3. widen `executableInThisSlice`.

Existing `riderToShop` returns keep their recorded route and need no migration,
and a stored `riderToPickerToShop` return **fails closed today** rather than
being walked as if it were the direct route — asserted by a test.

## Decision 2 — returned stock terminates as `ReservationState.returned`, never `released`

### Why not reuse `released`

`released` carries a promise: **its units were restored to available stock**.
Every path into it honours that, and both code and audit rely on it —
`holdsUnits == false` plus the name has always meant the shelf count went back
up.

A returned reservation cannot make that promise, because whether the units
became available again depends on the inspection outcome. Overloading `released`
would force one of two bad outcomes:

- its promise becomes **false for damaged goods**, silently turning breakage
  into sellable stock in every downstream reader; or
- every reader must re-derive the disposition before trusting a state name,
  which defeats the point of having one.

So `returned` says only: *the reservation is over and the goods are physically
back*. The stock consequence travels separately and explicitly, in the
transition's `InventoryEffect` — `restore(units)` exactly once for a
`restockable` disposition, `none()` otherwise.

### Post-return reservation semantics

```text
committed --(inspection)--> returned      terminal, reached exactly once
```

`canonicalAggregatePairs[in_delivery]` becomes `{committed, returned}`. The
order stays `in_delivery` after an inspected return: **no accepted slice defines
a post-dispatch order state for "came back"**, and inventing one would be
inventing the commercial outcome — which is exactly what this slice must not do.

That the reservation must be `committed` to reach `returned` is also what makes
a double restore **impossible rather than unlikely**: a replayed inspection
finds it already terminal.

## Decision 3 — disposition is inventory only, never liability

`ReturnDisposition` has three values — `restockable`, `damaged`, `quarantined` —
and answers exactly one question: **may these units be sold again?**

It deliberately cannot express who damaged the goods, who owes for them, whether
a refund, replacement or compensation is due, whether a refusal fee applies, or
what commission follows.

### Why they must stay separate

The tempting shortcut is "damaged ⇒ somebody pays". It is wrong here for a
concrete reason: **the party who inspects is not the party who decides
liability**, and the inspection happens *now* while the liability decision
depends on policy that does not exist. Encoding a fault hint in an inventory
field would bake a guess into stored history, and the guess would be read as a
finding by every later consumer.

Money is **FND-003C**'s, blocked on owner decision **O6** (currency, fee policy,
commission ownership). A refusal therefore carries
`FinancialClassification.deferredToFinancialSlice` — **unknown, never zero** —
and no B3B source contains a money, fee, refund, commission, settlement or
liability token at all.

`quarantined` is kept distinct from `damaged` despite being
inventory-identical, because *"we know it is unsellable"* and *"we are not yet
willing to say it is sellable"* are different claims reviewed by different
people, and merging them loses that permanently.

## Consequences

- The refused-order path is executable end to end: `required → in_transit →
  received → inspected → closed`, with custody moving `rider → shop` exactly
  once and stock restored at most once.
- One permission was added, `agent.return.record_receipt`, because shop-side
  receipt authority did not exist. `agent.fulfillment.record_progress` was not
  widened into a custody or stock lever.
- **Successful delivery remains non-executable** — the proof-satisfaction policy
  is still undefined and `CONSTRAINTS.md` invariant 13 is **not discharged**.
- A failed attempt creates no return: the blueprint permits one but no accepted
  contract says when, so the consequence is enumerated and refused rather than
  defaulted.
- Rider `completed`, customer custody and dispute resolution all remain
  unreachable. **B3-C2 stays FUTURE.**

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Implement `rider → picker → shop` now | Requires inventing post-dispatch picker authority and re-granting scope to a completed worker — a decision no accepted contract makes |
| Reuse `ReservationState.released` | Breaks its standing promise that units returned to available stock, for damaged goods |
| Add a post-dispatch `OrderState` such as `returned` | Invents the commercial outcome; the order's fate after a refusal is undecided |
| Let inspection record fault or a fee | Liability is FND-003C's and is blocked on **O6**; a guess would be stored as a finding |
| Reuse `agent.fulfillment.record_progress` for receipt | Its rule says it never writes trusted stock or status; receipt is the fact the restock invariant hangs from |
| Restore stock at shop receipt | Cannot distinguish a sellable item from a broken one; this is the invariant the slice exists to protect |
