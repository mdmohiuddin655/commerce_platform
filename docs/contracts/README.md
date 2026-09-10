# docs/contracts

Canonical shared contract. Owner: **FND-003**, delivered in slices.

**Current contract version: 0.6** (FND-003B3A).
**Contract baseline: SHARED-BASELINE-v1.0.**

## Delivered — FND-003A

| Document | Covers |
|---|---|
| [command-and-event-envelopes.md](command-and-event-envelopes.md) | Command envelope, the actor rule, idempotency semantics, event envelope, transport separation |
| [identity-membership-and-scope.md](identity-membership-and-scope.md) | Principal vs role vs membership vs scope |
| [permission-matrix.md](permission-matrix.md) | The one canonical least-privilege matrix (generated from code) |
| [authorization-invariants.md](authorization-invariants.md) | Evaluation order, deny reasons, App Check boundary |
| [privacy-and-security-boundaries.md](privacy-and-security-boundaries.md) | PII scope, push payload limits, FND-004 Rules checklist |
| [version-history.md](version-history.md) | 0.1 → 0.2 → 0.3, compatibility and migration status |

## Delivered — FND-003B1

| Document | Covers |
|---|---|
| [order-reservation-lifecycle.md](order-reservation-lifecycle.md) | Pre-dispatch order states, reservation states, the full transition matrix, cancellation policy boundary, expiry, the acceptance-versus-expiry race, and the required backend transaction boundary |

## Delivered — FND-003B2A

| Document | Covers |
|---|---|
| [picker-assignment-lifecycle.md](picker-assignment-lifecycle.md) | Picker assignment slot/attempt model, offer/accept/decline/expiry/controlled-revoke matrix, offer-recipient vs accepted-assignee separation, exactly-one invariants, accept-vs-expiry race, timeout-policy boundary, aggregate integrity, and the P1–P16 backend checklist |

Implemented in `packages/contracts`, pure Dart, no Flutter or Firebase
dependency.

## Delivered — FND-003B2B

| Document | Covers |
|---|---|
| [rider-assignment-lifecycle.md](rider-assignment-lifecycle.md) | Picker-originated rider assignment: the source-picker binding, picker-authority prerequisite, rider eligibility, offer/accept/decline/expiry/controlled-revoke matrix, exactly-one invariants, accept-vs-expiry race, aggregate integrity, the shared revision model and transition closure, the cancellation and picker-reassignment cross-aggregate requirements, the deferred direct agent→rider boundary, and the RA1–RA18 backend checklist |

**FND-003B2 (assignment) is complete**: picker by FND-003B2A, rider by
FND-003B2B.

## Delivered — FND-003B3A

| Document | Covers |
|---|---|
| [custody-lifecycle.md](custody-lifecycle.md) | Physical custody: the shop/picker/rider/customer vocabulary, explicit shop initialisation, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion, the role-aware revision model and B3-C1, custody-derived reassignment safety, and the CA1–CA18 backend checklist |

**FND-003B3 is PARTIAL**: custody acquisition and the picker→rider handoff are
done. Delivery attempts, refusal, returns and customer custody are not.

## Not yet defined — later FND-003 slices

**No feature may guess any of these.** If it is not written down, the work is
blocked, and saying so is the correct outcome.

| Slice | Owns | Blocked on |
|---|---|---|
| **Lifecycle — delivery, refusal, returns** (FND-003B3, remaining) | Delivery attempts, delivery confirmation, refusal/failure, return processing, customer custody, and rider assignment `completed` | FND-003B3A (**done**) |
| **Lifecycle — direct agent→rider pickup** | Shop-to-rider pickup with no picker: router mapping, order stage, shop authority, shop→rider handoff and custody proof. `agent.assignment.offer_rider` is reserved for it and is **not executable**. | FND-003B3 |
| **Inventory — post-dispatch** | Return-path restoration: stock cannot become available again until shop receipt **and** inspection. Pre-dispatch reservation, expiry and restoration are **done** (FND-003B1). | FND-003B3 |
| **Money** | Payment/COD lifecycle, cash journal postings, fee amounts, refusal fee policy and versioning, commission ownership, settlement and remittance. | **Owner decision O6** (currency, fee policy, commission ownership) |
| **Proof and dispute** | Customer OTP/proof format and the fallback dispute workflow — required **before** delivery confirmation is coded. | Lifecycle slice |

## Rules that already bind every later slice

From FND-003A, tested in `packages/contracts/test/`:

- Commands are **named operations**, never a status to write. No
  patch-to-status endpoint exists and no permission grants one.
- The server derives the actor from verified authentication. A client-supplied
  actor, role or permission is inert.
- Command ids are idempotency keys: identical intent replays the stored result,
  changed intent is rejected as key reuse.
- Event ids are server-assigned. A transport id is never a business event id.
- An event is a hint; it never authorizes a transition.
- Role alone authorizes nothing — active membership **and** scope are required.
- No permission may grant arbitrary status overwrite, balance edit, journal
  edit, or unaudited impersonation.

From FND-003B1, tested in `packages/contracts/test/`:

- Lifecycle commands are **named operations**; no command takes a target state,
  so there is no status setter.
- An order cannot reach `placed` without stock actually being reserved.
- The same reserved units are restored to available stock **at most once**.
- Acceptance does not decrement available stock a second time.
- An accepted order and restored inventory from the same reservation cannot
  coexist — structurally, not by a runtime check.
- A transition's financial effect is `deferredToFinancialSlice`, never zero,
  wherever money policy is undecided.
- Any edge not enumerated fails closed.

From FND-003B2A:

- Being offered work is not holding it: offer recipient and accepted assignee
  are separate, and neither identity is erased when an attempt ends.
- At most one live picker offer and one active accepted picker per order.
- Reassignment is revoke-then-new-offer with a new opaque id and the next
  generation — never an assignee overwrite.
- Controlled revocation is refused unless custody is **proven** absent;
  unknown is not safe.
- No timeout duration exists; offers carry an immutable policy reference the
  backend resolves against server time.
- Assignment transitions have inventory NONE, financial NONE and custody NONE.

From FND-003B3A:

- Custody is explicit: once an order has a custody aggregate there is exactly
  one current custodian, and a **missing record is never read as "the shop
  still has it"**.
- A worker custodian is bound to an assignment **attempt** — principal id,
  assignment id and generation — not to a projection of who is assigned now.
- Pickup is physical acquisition, **not** dispatch: the order stays `ready`.
- The order reaches `in_delivery` only when a rider records receipt, and that
  one command also completes the picker assignment and removes its
  `assignedResource`.
- Picker completion is a **consequence**, never a client-selected target state.
- Custody never touches stock: pickup, handoff and dispatch have inventory
  NONE, and stock cannot become available again until the return lifecycle
  proves shop receipt **and** inspection.
- Unknown or corrupt custody is **unsafe** for reassignment. "The record does
  not name this worker" is not proof they hold nothing.

From FND-003B2B:

- Rider work is offered by the order's **current accepted picker**, never by
  role or region alone, and never from a client-supplied picker id.
- A rider attempt records the picker assignment that created it, as immutable
  history. A replaced picker cannot inherit another picker's live offer.
- Accepting a rider offer is **not** custody, dispatch, or COD liability.
- `agent.assignment.offer_rider` is reserved for a future direct shop-to-rider
  pickup and is **not executable**; no command maps to it.
- The reachable slot-revision model is **one shared helper** used by both
  assignment roles, not two formulas that can disagree.
