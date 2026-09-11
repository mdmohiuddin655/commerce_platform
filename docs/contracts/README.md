# docs/contracts

Canonical shared contract. Owner: **FND-003**, delivered in slices.

**Current contract version: 0.11** (FND-003C1).
**Contract baseline: SHARED-BASELINE-v1.0.**

## Delivered — FND-003A

| Document | Covers |
|---|---|
| [command-and-event-envelopes.md](command-and-event-envelopes.md) | Command envelope, the actor rule, idempotency semantics, event envelope, transport separation |
| [identity-membership-and-scope.md](identity-membership-and-scope.md) | Principal vs role vs membership vs scope |
| [permission-matrix.md](permission-matrix.md) | The one canonical least-privilege matrix (generated from code) |
| [authorization-invariants.md](authorization-invariants.md) | Evaluation order, deny reasons, App Check boundary |
| [privacy-and-security-boundaries.md](privacy-and-security-boundaries.md) | PII scope, push payload limits, FND-004 Rules checklist |
| [version-history.md](version-history.md) | 0.1 → 0.2 → 0.3 → 0.4 → 0.5 → 0.6 → 0.7 → 0.8 → 0.9 → 0.10 → 0.11, compatibility and migration status |

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
| [custody-lifecycle.md](custody-lifecycle.md) | Physical custody: the shop/picker/rider/customer vocabulary, create-once shop initialisation, canonical resource/shop binding, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion, the role-aware revision model discharging B3-C1, compare-and-set across all four aggregate revisions, custody-derived reassignment safety, and the **CA1–CA23** backend checklist |

**FND-003B3 is PARTIAL**: custody acquisition and the picker→rider handoff are
done. Delivery attempts, refusal, returns and customer custody are not.

Corrected in place by **FND-003B3A-FIX-001** (canonical resource/shop binding,
picker and rider slot-revision compare-and-set, create-once initialisation,
honest state metadata) and **FND-003B3A-FIX-002** (contract-status
reconciliation). **Accepted and integrated** into `main` at `e8dacfc`.

## Delivered — FND-003D1

| Document | Covers |
|---|---|
| [delivery-proof-boundary.md](delivery-proof-boundary.md) | Mechanism-neutral delivery-proof **references**: which policy applies (never whether it is satisfied), resource-bound evidence references carrying no material, the event/notification privacy boundary, the deferred retention/visibility/dispute decisions, and what the eventual delivery slice must reconcile |

FND-003D1 added references only — no proof mechanism, no satisfaction rule, no
command, state, event or permission. Corrected in place by **FIX-001** and
**FIX-002**; **accepted and integrated** into `main` at `f03fc99`.

## Delivered — FND-003D2A

| Document | Covers |
|---|---|
| [delivery-proof-assessment.md](delivery-proof-assessment.md) | The trusted-server-produced, immutable proof **assessment**: two verdicts (`satisfied` / `notSatisfied`), absence as *not assessed*, the immutable record and its exact resource/policy/evidence/rider binding, an independent `assessmentRevision` with four-way compare-and-set, append-only reassessment, all-NONE commercial effects, one privacy-minimal event, the trust boundary, and the **DPA1–DPA16** backend checklist |

**Successful delivery is still NOT executable.** FND-003D2A adds the *result* of
evaluating a policy — **not the policy**, and **not a proof mechanism**. It adds
**no command and no permission** — `Permission.values` was **38** at the end of
FND-003D2A, and is **39** today only because FND-003B3B later added
`agent.return.record_receipt`, which changed nothing about D2A —
`OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable.

## Delivered — FND-003D2B

| Document | Covers |
|---|---|
| [delivery-proof-dispute.md](delivery-proof-dispute.md) | The **fallback dispute workflow** for a missing, superseded or `notSatisfied` assessment: the two fallback grounds, the immutable dispute basis and its `current` / `superseded` / `indeterminate` standing, one live dispute per order, two named operations under the accepted `customer.dispute.raise` and `admin.dispute.administer` rules, **one evaluator per operation with its own read-set**, an independent dispute revision with compare-and-set, all-NONE effects including the assessment, two privacy-minimal events, the deliberately **non-executable** resolution edge, and the **DPD1–DPD12** backend checklist |

Corrected in place by **FND-003D2B-FIX-001**: the basis standing now requires the
**verdict** to still agree, not just the assessment id and revision; an invented
`reviewerIsRaiser` separation-of-duties denial was removed; and recording that
review started no longer depends on current assessment or order facts it never
reads.

Corrected again by **FND-003D2B-FIX-002**: a higher assessment revision that
**reuses the basis's assessment id** is impossible history and now answers
`indeterminate` rather than `superseded`; and both executable operations now
require FND-003A's unforgeable **`AuthorizationGrant`**, so a direct evaluator
call can no longer bypass the canonical authorization decision. *(At the time that was written the corrected three-commit candidate was not yet
accepted. **FND-003D2B was subsequently accepted as a seven-commit chain and
integrated into `main`** — see the task ledger.)*

Corrected a third time by **FND-003D2B-FIX-003**: the raise read-set now binds
its **order lifecycle read to a resource** — the accepted `OrderLifecycleFacts`
carries no resource id, so an order-B read with matching scalars was previously
indistinguishable from order A's — and the grant-binding helper no longer
compares the grant's resource against itself.

**Successful delivery is still NOT executable, and no dispute resolves.**
FND-003D2B records *that* the proof situation is contested and *that* review
started. It decides **no outcome, fault, fee, refund, compensation, liability,
return or delivery consequence**, adds **no permission** — `Permission.values` was **38** across
the whole of FND-003D2B, and is **39** today only because FND-003B3B later
added `agent.return.record_receipt` — mutates **no assessment**, and leaves `OrderState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` unreachable.

**FND-003D is PARTIAL**: the proof-satisfaction *policy itself* is still
undefined, so `CONSTRAINTS.md` invariant 13 is **not discharged** and delivery
confirmation may not be coded. **How a dispute resolves** is a separate
undecided question, blocked on **O6** and **FND-003C**. *(FND-003B3B has since
been accepted and integrated; it defines the refused-order return and decides
**no** dispute outcome, fault or money.)*

## Delivered — FND-003B3B

| Document | Covers |
|---|---|
| [delivery-attempt-return-lifecycle.md](delivery-attempt-return-lifecycle.md) | The **delivery attempt** and **return** lifecycles for the bounded non-success path: `pending → out_for_delivery → refused | failed` with `delivered` enumerated and **never executable**, a refusal that atomically opens a required return, a failed attempt that invents **no** retry or return policy, the direct `rider → shop` return `required → in_transit → received → inspected → closed`, shop receipt as the second receiver-side custody edge (`rider → shop`, exactly once), stock restored **only** after receipt **and** a `restockable` inspection, the terminal `ReservationState.returned` kept distinct from `released`, one new permission `agent.return.record_receipt`, **one evaluator per operation with its own read-set**, and the **ATT1–ATT9 / RET1–RET8** backend checklist |

**Accepted and integrated.** The accepted contract is the **two-commit** chain
**`8ccb5aa8` + `cdb5f35b`** — `8ccb5aa8` alone is **not** accepted, because
FND-003B3B-FINAL-REVIEW-001 found two material documentation defects in it that
FND-003B3B-FIX-001 (`cdb5f35b`) corrected with **zero executable change**.

Contract **0.9 → 0.10**, additive. `Permission.values` and `permissionMatrix`
go **38 → 39** — the one addition is `agent.return.record_receipt`, because
shop-side receipt authority did not exist and
`agent.fulfillment.record_progress` was deliberately not widened into a custody
or stock lever.

**The return is whole-order only.** One `ReturnDisposition` covers the entire
committed reservation, a caller cannot choose the quantity, and a **mixed**
return is **not representable** — see
[ADR-0010](../decisions/ADR-0010-direct-rider-to-shop-return-route.md).

**Successful delivery is still NOT executable.** `recordDelivered` is
enumerated and always refused with `deliveryProofPolicyDeferred`, a `satisfied`
assessment is **not** consumed as authority for it, and `OrderState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` all remain
unreachable — **B3-C2 stays FUTURE** and `CONSTRAINTS.md` invariant 13 is **not
discharged**. The failed-attempt retry/return consequence, the via-picker return
route, dispute resolution and every fee/refund/liability/commission/settlement
rule remain **undecided**.

## Delivered — FND-003C1

| Document | Covers |
|---|---|
| [cash-and-payments.md](cash-and-payments.md) | The first **money** slice: the normal-path **COD collection** contract and its balanced cash journal — `cp_core.Money` integer minor units with an explicit currency, **BDT-only v1 with no FX**, the immutable `OrderFinancialSnapshot` where **absence is never zero**, `PaymentState` (`due` / `partiallyCollected` / `collected`, with `disputed` declared and **not producible**), the `CashJournalEntry` model with one currency, a unique business reference and postings summing to **exactly zero**, reversal-only correction, a closed server-chosen account set, one operation under the **unchanged** `rider.cash.report_collection`, and the **CJ1–CJ12** backend checklist |

**Owner action O6 is resolved** — see
[ADR-0011](../decisions/ADR-0011-o6-currency-fees-commission-and-cash-custody.md):
BDT-only v1 with the currency still explicit on every value, the customer price
an immutable quoted snapshot, **platform commission an allocation out of
merchandise proceeds and never a customer charge**, the voluntary-refusal
default the order's quoted delivery charge with **nonpayment representable** and
fault cases left unresolved rather than charged or waived, and **rider cash as
custody, not ownership**.

**No permission was added** — `Permission.values` and `permissionMatrix` stay
at **39**.

**Collecting cash is not delivering.** The transition has no field for an
order, custody, attempt, assignment, inventory or proof effect, so
`OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable, **B3-C2 stays FUTURE** and
`CONSTRAINTS.md` invariant 13 is **not discharged**. Remittance, settlement,
reconciliation, refusal-fee collection, refunds, compensation, commission
payout, worker pay, dispute resolution and FX are all **absent** — not stubbed,
simply not expressible.

## Not yet defined — later FND-003 slices

**No feature may guess any of these.** If it is not written down, the work is
blocked, and saying so is the correct outcome.

| Slice | Owns | Blocked on |
|---|---|---|
| **Lifecycle — successful delivery** (FND-003B3, remaining) | Delivery **confirmation**, customer custody, and rider assignment `completed` (**B3-C2**). Delivery attempts, refusal, failure and the direct `rider → shop` return are **done** (FND-003B3B) — but a *successful* delivery needs the proof-satisfaction policy, which is undefined. The **failed-attempt** retry/return consequence and the **via-picker** return route are also still undecided: B3B enumerates and refuses both rather than guessing. | FND-003B3A (**done**), FND-003B3B (**done**), **Proof policy** |
| **Lifecycle — direct agent→rider pickup** | Shop-to-rider pickup with no picker: router mapping, order stage, shop authority, shop→rider handoff and custody proof. `agent.assignment.offer_rider` is reserved for it and is **not executable**. | FND-003B3 |
| **Inventory — post-dispatch cancellation** | The stock consequence of a **cancellation** after dispatch. Return-path restoration is **done** (FND-003B3B) — stock becomes available again only after shop receipt **and** a `restockable` inspection, exactly once, with `damaged` / `quarantined` restoring zero — and pre-dispatch reservation, expiry and restoration are **done** (FND-003B1). What a *cancellation* after dispatch does to stock is **not decided**: FND-003B3A recorded that no post-pickup cancellation behaviour was invented, and FND-003B3B lists it among the consequences it does not decide. | The cancellation policy itself, deferred by FND-003B3A and FND-003B3B; its fee/liability half is **Owner decision O6** and FND-003C |
| **Money — remaining** | Remittance, settlement, reconciliation, refusal-fee collection, refunds, compensation, commission payout and worker pay. The **normal-path COD collection** and its balanced cash journal are **done** (FND-003C1), and **O6 is resolved** (ADR-0011): currency, the quoted customer price, commission ownership and rider cash custody are all decided. | FND-003C1 (**done**); the remaining lifecycles await their own slices |
| **Proof policy** (FND-003D, remaining) | The proof-**satisfaction policy itself** — what a policy requires, which mechanism captures evidence, whether customer participation is needed. Required **before** delivery confirmation is coded. The reference/privacy boundary is **done** (FND-003D1), the assessment **result** is **done** (FND-003D2A) and the fallback dispute workflow is **done** (FND-003D2B). | — |
| **Dispute resolution** | How a fallback dispute resolves: who prevails, and whether any delivery, refusal, return, fee, refund, compensation or liability follows. Enumerated and refused `resolutionPolicyDeferred` by FND-003D2B; **never guessed**. | **Owner decision O6**, FND-003C. FND-003B3B (**done**) defines the refused-order return and decides **no** dispute outcome, fault or money |

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

From FND-003D1 and FND-003D2A:

- A **reference is not a result**: naming a policy never asserts it was
  satisfied, and an evidence reference proves neither authenticity nor delivery.
- Only **trusted server authority** may produce a proof assessment. No customer,
  rider, picker, agent or admin permission can self-declare proof satisfied, and
  no client command exists for it.
- A pure Dart record **cannot authenticate its own origin**. The backend must
  ignore client-supplied assessments and trust only what it loaded.
- Assessment history is **append-only**: a reassessment takes a new opaque id
  and the next revision, and never rewrites, relabels or erases the previous
  record.
- **Absence of an assessment means *not assessed*** — never "not satisfied", and
  never a `pending` business state.
- A `satisfied` verdict **delivers nothing**: every order, reservation,
  inventory, financial, custody and assignment effect is NONE, structurally.
- `notSatisfied` means only that the policy was not satisfied. It is not fraud,
  refusal, cancellation, a lost dispute, a fee or a refund, and no financial
  consequence may be derived from it.

From FND-003D2B:

- A **missing, superseded or `notSatisfied`** assessment has one defined
  fallback: a dispute, raised by the order's customer, bound to the canonical
  order and to an **immutable basis** naming exactly what was contested.
- **Corruption is never a fallback ground.** A torn assessment aggregate denies;
  it never becomes `notSatisfied`, and it never becomes a dispute basis.
- A **`satisfied`** assessment is not a fallback ground either — that is a
  different workflow, and no slice defines it.
- **Supersession is a standing, not a rewrite.** A reassessment never alters or
  invalidates a dispute's basis, and a later `satisfied` verdict does not
  dismiss the dispute.
- **A dispute decides nothing.** Resolution is enumerated and deliberately not
  executable; no outcome, fault, fee, refund, compensation, liability, return or
  delivery consequence exists, and none may be derived.
- **At most one live dispute per order**, with its own revision and
  compare-and-set. Duplicate and reordered intent writes nothing.
- **An operation reads only what it changes or depends on.** Raising pins the
  assessment and order it derives its basis from; recording that review started
  depends on the dispute alone, so a later reassessment or a torn assessment
  read cannot freeze a validly raised dispute out of review.
- **Identity is not meaning.** A basis is still `current` only when the
  assessment id, the revision **and the verdict** all still agree — and an
  assessment id is **never reusable at another revision**, so a later revision
  carrying the basis's id is impossible history, not a supersession.
- **Numeric equality is not identity.** Every member of a raise read-set —
  grant, dispute, assessment and order read — must name the same order, and the
  order read carries its own resource id because `OrderLifecycleFacts` does not.
- **An executable dispute operation requires canonical authorization success.**
  Both take FND-003A's unforgeable `AuthorizationGrant`, bound to the acting
  principal, the operation's permission and the resource. The permission matrix
  stays the single policy source and is never copied; raising confers no admin
  authority.
- A dispute record holds **no free text** — the required reason lives with the
  audited command, in FND-003A.

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
