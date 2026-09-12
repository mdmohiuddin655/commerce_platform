# ADR-0012 — Delivery proof satisfaction: a server-issued, single-use, resource-bound confirmation challenge, verified server-side and fail-closed

- **Status:** Accepted
- **Date:** 2026-09-12
- **Task:** FND-003D3-PROOF-SATISFACTION-POLICY-001, under the ADMIN standing
  delegation for the previously untracked owner decision **O8**
- **Contract:** **0.11 — unchanged.** This ADR adds no type, command, event,
  state, permission or version bump
- **Resolves:** **O8** — what a delivery-proof policy actually requires, and
  whether customer participation is optional, mandatory, sufficient or a veto
- **Supersedes:** nothing. **Extends:**
  [ADR-0008](ADR-0008-bounded-delivery-proof-policy-reference.md),
  [ADR-0009](ADR-0009-trusted-immutable-proof-assessment.md)
- **Decides policy only.** Successful delivery remains **not executable**; see
  **Consequences**

## Context

Three slices have now built everything around this decision and deliberately
stopped short of it:

| Slice | What it gave | What it refused to decide |
|---|---|---|
| FND-003D1 (0.7) | `DeliveryProofPolicyRef`, `DeliveryEvidenceRef` — *which* policy, *which* protected evidence | what a policy requires; any mechanism |
| FND-003D2A (0.8) | `DeliveryProofAssessmentRecord` — a trusted, immutable *result* stating `satisfied` / `notSatisfied` | what makes a policy satisfied; who the customer is in it |
| FND-003D2B (0.9) | the fallback dispute for a missing, superseded or `notSatisfied` assessment | how a dispute resolves |

`CONSTRAINTS.md` invariant 13 requires **both** customer proof and the fallback
dispute workflow to be defined before delivery confirmation is coded. The second
half has been done since 0.9. The first half — *what a proof policy actually
requires* — has been carried as **DEFERRED** in four documents, and every one of
them says the same thing in a different place: nobody has decided it, and
defaulting it would be worse than leaving it open.

That position has run out of road. `OrderState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` are all
unreachable **because** of this gap, and every later slice — delivery
confirmation, remittance, settlement, dispute resolution — is stacked behind it.

The decision is genuinely hard in one specific way: **every cheap answer fails
open.** A rider photograph, a GPS fix, a timestamp, a tap on "delivered" — each
is easy to capture, easy to produce without delivering anything, and impossible
to distinguish after the fact from the real thing. Baking any of them in as
sufficient would make the highest-value status in the system assertable by the
party it exists to check.

This ADR decides the policy. It does not implement it.

## Decision — canonical definitions

These names are used throughout this ADR and are binding on the implementing
slice. Where an existing contract already owns the concept, the existing name is
used and **no parallel term is introduced**.

| Term | Meaning |
|---|---|
| **Proof satisfaction** | The trusted backend's conclusion that the policy named by the order's `DeliveryProofPolicyRef` was met for that order, by that rider, on that delivery attempt. It is recorded **only** as `DeliveryProofAssessmentVerdict.satisfied` on a `DeliveryProofAssessmentRecord`, by the authorized verifier, exactly as ADR-0009 requires. |
| **Confirmation challenge** | A server-generated, short-lived, single-use secret issued for **one** order, **one** delivery attempt, **one** customer and **one** assigned rider. It is **backend policy state**, not wire-contract vocabulary — no contract type, field, command, event or enum represents it. |
| **Challenge fulfilment** | A customer-side act that redeems a live challenge: the customer reads the challenge value to the rider, who submits it, **or** the customer confirms in an authenticated User-app session. Both are *inputs*. Neither is proof satisfaction. |
| **Evidence capture** | Anything recorded at the doorstep — a submitted value, an authenticated confirmation, an optional photograph. Reaches the platform as a `DeliveryEvidenceRef`. **Capture is never satisfaction**; capture happens at the edge, satisfaction is concluded by the server. |
| **Fail closed** | The absence, expiry, reuse, mis-binding, staleness or corruption of any required fact yields **not satisfied** — never satisfied, and never a silent pass. Absence is `DeliveryProofAssessmentFacts.absent`, exactly as ADR-0009 defines; it is not a third verdict. |
| **Exception review** | A separately authorized, separately audited ADMIN path that may conclude satisfaction where the primary method is impossible. It is a **different, recorded route to the same verdict**, never a waiver of the requirement. |

**One sentence carries the whole decision:** *evidence capture is an input to a
server-side verification; only that verification produces proof satisfaction.*

## Decision 1 — the primary proof method is a server-issued confirmation challenge

**The v1 delivery-proof policy is satisfied when, and only when, the trusted
backend verifies that a live confirmation challenge issued for that exact order,
attempt, customer and assigned rider was correctly fulfilled by the customer
side.**

The challenge is:

- **server-generated** — the value originates in trusted backend state. Neither
  the rider app, the customer app nor any client proposes, derives or predicts
  it;
- **short-lived** — it has a server-side validity window, measured against
  **server time**. An expired challenge fails closed;
- **single-use** — the first successful fulfilment consumes it. A second
  presentation of the same value fails closed, whatever the outcome of the
  first;
- **bound** — to the order (`resourceId`), the specific delivery attempt, the
  customer who owns that order, the currently assigned rider
  (`riderPrincipalId`, `riderAssignmentId`, `riderAssignmentGeneration`) and the
  current order, custody and rider-slot revisions.

**Two fulfilment routes are accepted, and they are equivalent in strength
because both terminate in the same server-side check:**

1. **Customer-to-rider transfer.** The customer receives the challenge value
   through a channel the platform controls and reads it to the rider, who
   submits it under `rider.delivery.submit_proof`. The rider transports a value;
   the rider does not certify it.
2. **Authenticated customer confirmation.** The customer confirms in an
   authenticated User-app session bound to the same order and attempt, under
   `customer.delivery.confirm_proof`.

Route 2 exists because route 1 degrades badly in exactly the conditions this
marketplace operates in — a customer without their phone to hand, a shared
handset, a doorstep with no signal on the customer side. Making route 1 the only
route would push real deliveries into exception review, and an exception path
that carries ordinary traffic stops being an exception.

### The permission question ADR-0009 left open, answered

ADR-0009 recorded **POLICY-DEFINED / DEFERRED**: *"whether customer
participation is optional, mandatory, sufficient or a veto"*. This ADR answers
it:

**Customer participation is MANDATORY and NOT SUFFICIENT.**

- **Mandatory** — the customer side must fulfil a live challenge. There is no
  route to satisfaction in which the customer side does nothing. Silence,
  unavailability and non-response are **not** fulfilment (Decision 4).
- **Not sufficient** — fulfilment is an *input*. The server still verifies the
  challenge is live, unconsumed, correctly bound and current before concluding
  satisfaction. A customer cannot make an order delivered by asserting it any
  more than a rider can.
- **Not a veto in the sense of ending the order** — a customer who refuses to
  participate produces **no** satisfaction, which is not the same as producing a
  refusal, a failure, a fee or a fault finding. What that costs anyone, if
  anything, is not decided here (Decision 7).

**`customer.delivery.confirm_proof` keeps its exact accepted meaning.** The
matrix restriction stands verbatim: *participation in proof only; confirming
does not settle cash and does not close a dispute.* This ADR makes that
participation **required**; it does not widen what the permission does, and it
does not make the permission holder an authority on the verdict.

**No permission is added, widened or reinterpreted.**
`rider.delivery.submit_proof` and `customer.delivery.confirm_proof` already
exist with the right shape and scope. `Permission.values` and `permissionMatrix`
stay **39**.

## Decision 2 — only the trusted backend may conclude satisfaction

This is ADR-0009's rule, and this ADR neither weakens nor restates it loosely:

- the canonical verdict is produced **only** by the authorized proof verifier —
  `assessor.kind` in `executableProofAssessorKinds` **and** `assessor.id`
  exactly equal to `context.authorizedAssessorPrincipalId`;
- **a rider assertion is never authoritative**, and neither is a customer
  assertion. Both are inputs to the verification, not substitutes for it;
- there is no client-selectable "declare proof satisfied" operation, no status
  setter and no override verdict. The names ADR-0009 forbids —
  `customer.proof.accept`, `rider.proof.mark_satisfied`, `admin.proof.override`,
  any generic proof-status setter — remain forbidden, and this ADR creates none
  of them;
- **the client clock is not trusted.** Challenge issuance, validity and
  consumption are measured against server time. A client-supplied timestamp is
  evidence of what a device believed, never of when something happened.

**A Dart object is not runtime trust**, exactly as ADR-0009 says: any client can
construct a record that says `satisfied`, and the backend must treat only
records loaded from trusted state as authoritative.

## Decision 3 — offline and unreliable networks

Bangladeshi doorstep delivery routinely has no usable connectivity at the moment
of handover. The policy must survive that without weakening.

- **Local capture is permitted. Local satisfaction is not.** A rider device may
  capture a submitted value offline and queue it. Until the server verifies it,
  the order has **no** assessment — `DeliveryProofAssessmentFacts.absent`, which
  ADR-0009 already defines as canonical absence. There is no `pending` verdict,
  and none is introduced here.
- **Queued capture does not extend a challenge's life.** Validity is measured
  against server time at verification. A value captured inside the window but
  submitted after it expires **fails closed**. Making the window elastic on
  device evidence would let a device grant itself unlimited time.
- **Nothing downstream moves on queued capture.** No order state, custody,
  assignment, reservation, inventory or financial consequence follows from a
  local capture, because none follows from an assessment at all (ADR-0009: every
  effect is NONE).
- **Duplicate submission is expected, not exceptional.** A flaky network makes
  retries normal, so the implementing slice must make submission idempotent
  (Decision 8), not discourage retrying.

A rider who cannot reach the server has not failed the delivery and has not
completed it. The attempt vocabulary already distinguishes `refused` and
`failed` from `delivered`; **no new attempt state is invented here**, and
connectivity is not an attempt outcome.

## Decision 4 — insufficient by itself, permanently

**None of the following, alone or in any combination with each other, satisfies
a delivery-proof policy:**

| Signal | Why it is not proof |
|---|---|
| Rider photograph | Proves an image was captured. Not that this customer received this order. Trivially reproducible. |
| GPS / location fix | Proves a device reported a coordinate. Proximity is not handover, and the report is client-supplied. |
| Timestamp | Proves a clock was read. Client clocks are not trusted (Decision 2). |
| Signature image without authenticated binding | An unauthenticated mark. Nothing ties it to the customer of record. |
| Rider statement or a "delivered" tap | The party being checked asserting the result of the check. |
| Cash collection | A payment fact, not a handover fact. Explicitly separated in Decision 7. |
| Customer non-response | Absence of evidence. Fails closed (Decision 6). |
| Delivery-attempt completion | An attempt reaching a terminal state says the attempt ended, not that it succeeded. |
| Possession or custody assertion | `CustodyHolderKind.rider` says the rider holds the goods — the state that exists *before* delivery, not evidence of it. |

**These may be captured as supporting context where policy permits, and they may
be shown in an exception review.** They never *substitute* for a fulfilled
challenge, and a policy version that made any of them sufficient would not be a
configuration change — it would require superseding this ADR (the Supersession rule).

**Optional stays optional.** This ADR does **not** make photograph or location
capture mandatory, and does not authorize any slice to make them mandatory on
the strength of this decision alone (Decision 5).

## Decision 5 — privacy and data minimization

- **The raw challenge value is never stored in an event, an event payload, a
  notification, a log, a crash report or an audit record.** `EventEnvelope`
  payloads remain routing-and-display only, exactly as the D1 boundary requires,
  and a copy of a payload may be rendered on a lock screen and cached by an OS.
  A challenge value in that path would be a credential in a cache.
- **What may be recorded** is the verification *outcome* and the safe references
  that already exist: the `DeliveryEvidenceRef` handle, the
  `DeliveryProofPolicyRef`, the verdict, the assessor identity, the bound rider
  and assignment identifiers, the revisions checked, and server timestamps. All
  are opaque identifiers or enumerated values — the class of value the payload
  rules already permit.
- **Comparison is server-side.** A challenge value is never returned to a client
  for local comparison, because a value a client can read is a value a client
  can replay.
- **Photograph and location material, where captured at all, stays behind the
  authenticated protected path** the D1 boundary describes. This ADR implements
  no such path and makes no claim about storage rules, encryption, signed URLs
  or access policy.
- **Retention, visibility, deletion and legal hold remain DEFERRED** to the
  privacy/retention slice, unchanged by this ADR. Deciding what satisfies a
  policy is not deciding how long its evidence is kept.

## Decision 6 — failure behaviour, exhaustively fail-closed

**Every one of these yields not satisfied:**

- no challenge was issued, or none is live;
- the challenge expired against server time;
- the challenge was already consumed (replay);
- the submitted value does not match;
- the challenge belongs to a different order, a different delivery attempt, a
  different customer or a different rider;
- the rider submitting is not the currently assigned rider, or the assignment
  generation has moved;
- the order, custody, rider-slot or assessment revision presented is stale;
- the aggregate is malformed or internally inconsistent.

**Corruption is never downgraded to a verdict.** ADR-0009's `canonicalVerdict`
rule stands: a torn aggregate yields *no* verdict, not `notSatisfied` and
certainly not `satisfied`.

**These do not create satisfaction, and none of them is a proxy for it:**

- a **refused** or **failed** delivery attempt;
- customer non-response or unavailability;
- a raised dispute — **a dispute does not imply delivered**, and disputing a
  `satisfied` assessment stays refused `assessmentSatisfied` as D2B defines;
- a cash collection — see Decision 7;
- the passage of time. **There is no timeout that ripens into delivery.** No
  auto-satisfaction, no deemed delivery, no silent acceptance window.

**And satisfaction does not imply the converse consequences.** A `satisfied`
verdict does not settle cash, trigger remittance, drive settlement, close a
reconciliation, resolve a dispute, assign fault or create any fee, refund,
compensation or liability. `CONSTRAINTS.md` invariant 7 stands: delivered is not
equivalent to rider cash settled.

## Decision 7 — cash collection is a separate fact in both directions

FND-003C1 (0.11) made COD collection executable under
`rider.cash.report_collection`, with its own balanced journal entry. That slice
changes no order, custody, attempt, assignment, reservation or inventory state,
and this ADR does not connect the two:

- **collecting cash does not satisfy a proof policy** — money changing hands is
  not evidence the right person received the right order;
- **satisfying a proof policy collects no cash, and settles none** —
  remittance, settlement, reconciliation, refusal-fee collection, refunds,
  compensation and commission payout are FND-003C's remaining work and are
  untouched here;
- **neither ordering is mandated.** This ADR does not require collection before
  confirmation or confirmation before collection. Sequencing is an operational
  question no contract has decided, and inventing one here would be inventing a
  money rule.

`CONSTRAINTS.md` invariant 11 stands unchanged: **nonpayment on refusal remains
representable, no payment is ever fabricated to permit a cancellation, and
delivery failure does not automatically justify a customer fee.**

## Decision 8 — replay, idempotency and recovery

- **Single use is enforced at the server, atomically with consumption.** The
  check and the consumption are one operation; a check that passes and then
  consumes in a second step is a race.
- **One proof satisfies exactly one resource and one attempt.** A challenge is
  bound at issuance; it can never be redeemed against a second order, a second
  attempt, or the same order after reassignment to a different rider generation.
- **Duplicate submissions are idempotent.** Re-submitting the same fulfilment
  for the same order and attempt yields the same outcome and creates no second
  assessment, no second event and no second consumption. This follows the
  repository's existing principal-scoped dedupe convention; **no new idempotency
  vocabulary is invented.**
- **Regeneration invalidates.** Issuing a replacement challenge immediately
  invalidates every superseded one for that order and attempt. There is never
  more than one live challenge for a given (order, attempt) pair.
- **Regeneration and submission are rate-limited**, per order, per attempt and
  per rider, against server time. Unlimited regeneration is an oracle; unlimited
  submission is a brute-force surface against a short value. The specific limits
  are operational configuration, not contract, but **their existence is part of
  this decision** and a policy version may not set them to unlimited.
- **Reassessment stays append-only.** ADR-0009's rule is unchanged: a new
  verdict is a new record with a new `assessmentId`, the next
  `assessmentRevision` and a `supersedesAssessmentId` back-pointer. **Nothing in
  this ADR mutates or erases history.**

## Decision 9 — the exception path is authorized and audited, never a waiver

Some deliveries genuinely cannot use the primary method: a customer with a
visual or motor impairment who cannot read or enter a value, a lost or dead
customer handset, a language barrier, a legitimate delivery to an authorized
recipient who is not the account holder.

**An ADMIN exception review may conclude satisfaction for such a case**, subject
to all of the following:

- it is **separately authorized** — it is not reachable through
  `rider.delivery.submit_proof` or `customer.delivery.confirm_proof`, and no
  rider or customer can invoke it;
- it **requires a recorded reason and a reference**, and produces an immutable
  audit record naming the deciding principal and server time;
- it is **bound exactly as the primary method is** — same order, same attempt,
  same assigned rider, same current revisions. An exception relaxes *which
  evidence is acceptable*, never *which resource it applies to*;
- it **cannot mutate history**. It produces a new append-only assessment, never
  an edit to an existing one;
- it is **visible as an exception** — a satisfaction reached this way is
  distinguishable in the audit trail from one reached through a fulfilled
  challenge. An exception that is indistinguishable afterwards is a waiver.

**It must not silently waive missing proof.** "The rider says it arrived and
nobody objected" is not an exception case; it is the absence of proof, and Decision 6
governs it.

**This ADR does not create that workflow.** ADR-0009 already records that manual
assessment, if ever needed, must be *"a separate audited workflow with its own
permission, scoped authority, a recorded reason, approval or dual control where
policy requires it, and immutable audit history — never an arbitrary status
patch"*, and that `executableProofAssessorKinds` is the single place a later task
would widen **deliberately**. That remains true: the exception path needs its own
permission and its own bounded slice, and **no permission for it exists today**.

## Decision 10 — configurable, but not silently weakenable

The governing policy is named per order by its `DeliveryProofPolicyRef`, which
ADR-0008 keeps deliberately mechanism-neutral and bounded at 64 characters.
Policy versions are published under `admin.policy.publish_version`, whose
accepted restriction already says: *publishes a new immutable policy version;
never edits a published one — orders keep the policy version they were quoted
under.*

**What a policy version may configure:**

- the challenge validity window and its length/alphabet;
- which fulfilment routes are enabled (either, or both);
- rate limits, within non-unlimited bounds;
- which supporting context is captured alongside;
- whether an exception path is available for that policy.

**What no policy version may configure, because doing so would weaken the
invariant rather than parameterize it:**

- making any Decision 4 signal sufficient on its own;
- removing the customer-side fulfilment requirement entirely;
- allowing client-side verification, client-proposed challenges or client clocks
  as authority;
- disabling single-use, binding or expiry;
- making an exception path unaudited, unauthorized or indistinguishable;
- setting a rate limit to unlimited.

Any of those requires **superseding this ADR** (the Supersession rule), not publishing a policy
version. The distinction is the entire point of separating configuration from
decision: a knob that can turn the invariant off is not a knob.

**Orders keep the policy version they were quoted under.** A later policy change
does not retroactively re-decide an order already assessed.

## Consequences

- **Invariant 13's policy half is decided.** `CONSTRAINTS.md` invariant 13 now
  has a named, accepted answer for *what customer proof requires*. The fallback
  dispute workflow half has been done since 0.9.
- **The invariant is NOT discharged.** Nothing executable changed. The
  implementing slice must still build the challenge lifecycle, the verifier's
  evaluation against this policy, and the delivery transaction that consumes a
  `satisfied` verdict. **Until then, delivery confirmation still may not be
  coded**, and marking invariant 13 discharged on the strength of this document
  would be exactly the silent downgrade `CONSTRAINTS.md` forbids.
- **`O8` is resolved**, and is registered in the ledger's owner-decision table
  as resolved by this ADR.
- **Every unreachable state stays unreachable.** `OrderState.delivered`,
  `DeliveryAttemptState.delivered`, `CustodyHolderKind.customer` and rider
  `AssignmentState.completed` are all exactly as unreachable after this ADR as
  before it, because no evaluator, transition, command or event was added.
- **`ContractVersion.current` stays 0.11** and no contract document gains an
  executable specification. A policy decision is not a contract change.
- **`Permission.values` and `permissionMatrix` stay 39.** The primary method
  reuses two accepted permissions unchanged; the exception path's permission is
  deliberately **not** created here.
- **Dispute resolution stays undecided.** This ADR gives a dispute something
  concrete to be about — whether a challenge was genuinely fulfilled — but
  decides no outcome, no fault, no fee and no liability. `dispute.resolve_delivery_proof`
  remains enumerated and always refused `resolutionPolicyDeferred`.
- **The proof-mechanism sweep in the contract package is unaffected.** The
  challenge is backend policy state, and this ADR adds **no** code, so the test
  asserting that no proof-mechanism term appears in the *source* continues to
  pass unchanged. Naming a mechanism in a decision document is not declaring one
  in a contract.

## Intentionally deferred — not defaulted by this ADR

| Question | Status | Owner |
|---|---|---|
| The executable challenge lifecycle — issuance, storage, consumption, its types and events | **DEFERRED** | the implementing proof-satisfaction slice |
| The successful-delivery transaction (`in_delivery → delivered`, custody `rider → customer`, rider completion and **B3-C2**) | **DEFERRED** | a separately reviewed delivery slice |
| The exception-review workflow and **its permission** | **DEFERRED** — bounded, audited, its own slice | future slice + this ADR's Decision 9 |
| Concrete challenge length, alphabet, window and rate-limit values | **DEFERRED** — operational configuration within Decision 10's bounds | policy configuration |
| Evidence retention, visibility, deletion, legal hold | **DEFERRED** (unchanged) | privacy/retention slice |
| How a dispute resolves, and any fault, fee, refund, compensation or liability | **DEFERRED** (unchanged) | resolution slice, FND-003C |
| Remittance, settlement, reconciliation, commission payout, worker pay | **DEFERRED** (unchanged) | FND-003C |
| Notification transport for delivering a challenge to a customer | **DEFERRED** — ADR-0005 is still *Proposed, blocked on an owner decision* | notification slice |
| Whether an authorized recipient other than the account holder may ever fulfil | **DEFERRED** — Decision 9 treats it as an exception case, and decides no delegation rule | future slice |

**Zero is never used as a substitute for undecided policy**, and neither is
`false`. No flag is added here whose default would quietly answer any row above.

## Migration and versioning impact

- **No contract migration.** 0.11 is unchanged; no type, field, enum value,
  command, event, permission or denial is added, removed or re-meaninged, so
  there is nothing to migrate and no compatibility question to answer.
- **No stored data is affected**, because no stored shape changes and no
  serialization exists in the contract package at all.
- **The implementing slice will be a minor bump** — additive challenge and
  delivery vocabulary on top of 0.11 — and must record its own version-history
  entry. **This ADR does not pre-authorize that bump**; the slice is separately
  scoped and separately reviewed.
- **Published policy versions are immutable.** Existing
  `DeliveryProofPolicyRef` values keep their meaning; this ADR defines what a v1
  policy *requires*, and does not redefine any reference already issued.

## Alternatives considered and rejected

| Alternative | Why rejected |
|---|---|
| **Rider taps "delivered"** | The party being audited asserting the audit result. Makes the delivery gate free to forge and gives a dispute nothing to examine. |
| **Photograph at the doorstep as sufficient** | Proves an image exists. Says nothing about *who* received *which* order, and is reproducible at zero cost. Retained as optional supporting context only (Decision 4). |
| **GPS fence as sufficient** | Client-reported, spoofable, and proximity is not handover. A rider standing outside the right building has proved nothing. |
| **Unauthenticated signature capture** | An unbound mark on a screen. Without authenticated binding to the customer of record it is a drawing. |
| **Cash collection as implicit proof** | Conflates a money fact with a handover fact and would couple the delivery gate to COD, breaking on every prepaid order. Explicitly separated (Decision 7). |
| **Timeout that ripens into delivered** | The single most dangerous option: it makes *doing nothing* succeed, and it fails open at exactly the moment something went wrong. Explicitly forbidden (Decision 6). |
| **Customer confirmation as sufficient without server verification** | Moves authority to a client. A confirmation a client can produce is a confirmation a compromised client can produce. |
| **Customer participation optional** | Would leave a route to satisfaction with no customer-side act at all, which is every rejected option above wearing a different label. |
| **Customer participation as an absolute veto ending the order** | Over-decides: it turns non-participation into an order outcome with fee and fault consequences this ADR has no authority to decide (Decision 7). Non-participation yields no satisfaction, and stops there. |
| **Client-side challenge comparison** | A value the client can compare is a value the client can read and replay. Comparison stays server-side (Decision 5). |
| **Long-lived or reusable challenge** | A reusable secret is a credential, and a long window is an offline attack surface against a short value. |
| **A `pending` verdict for offline capture** | ADR-0009 already rejected `pending`: absence means it, and two representations of one fact drift. Reconfirmed here (Decision 3). |
| **Storing the challenge value for audit** | Would put a credential in exactly the caches, logs and notification payloads the D1 privacy boundary exists to keep clean. The outcome and safe references are audited instead (Decision 5). |
| **No exception path at all** | Would make the policy inaccessible to customers with impairments and push real deliveries into permanent non-satisfaction. Rejected as both an accessibility failure and a pressure toward dishonest workarounds. |
| **Unaudited admin override** | The arbitrary status patch `ProhibitedCapability` forbids, aimed at the highest-value status in the system. Decision 9 requires authorization, reason, reference and immutable audit. |
| **Biometric or device attestation as the primary method** | Adds a hardware and privacy dependency, excludes low-end devices that dominate this market, and buys no binding the challenge does not already give. |
| **Deciding the executable contract in this task** | Would merge a policy decision with a cross-aggregate delivery transaction touching order, custody, assignment, reservation and money — the exact combination the boundary documents require to be reviewed on its own. |

## Supersession rule

**This ADR may be changed only by a later ADR that supersedes it explicitly**,
names this one, and states what changed and why. In particular, any of the
following requires a superseding ADR **and** a contract migration plan — never a
policy-version edit, a configuration change or an in-place amendment:

- making any Decision 4 signal sufficient on its own;
- removing or downgrading the mandatory customer-side fulfilment;
- moving verification authority off the trusted backend;
- weakening single-use, binding, expiry or fail-closed behaviour;
- making the exception path unaudited or indistinguishable;
- adding a permission that can assert proof satisfaction directly.

Because orders keep the policy version they were quoted under, a superseding ADR
must also say what happens to orders already assessed under this one. Silence on
that point is not an answer.

## Legal and regulatory scope

This ADR is a **product and architecture decision**. It is written to be neutral
across jurisdictions and **makes no claim of compliance with any law, regulation
or standard** — not consumer-protection, e-commerce, data-protection,
accessibility, evidentiary or payment rules. It does not assert that a fulfilled
challenge constitutes legal proof of delivery anywhere.

Whether any jurisdiction the platform operates in imposes a specific proof,
record-keeping, retention or accessibility requirement is **an owner question
that this ADR does not answer and does not foreclose**. Nothing here prevents a
stricter requirement being added; the Supersession rule is the route.

## References

- [ADR-0008](ADR-0008-bounded-delivery-proof-policy-reference.md) — the policy
  reference is bounded and mechanism-neutral
- [ADR-0009](ADR-0009-trusted-immutable-proof-assessment.md) — the assessment is
  trusted, immutable and append-only; **this ADR answers its deferred customer-participation question**
- [ADR-0011](ADR-0011-o6-currency-fees-commission-and-cash-custody.md) — O6:
  currency, fees, commission and cash custody
- [delivery-proof-boundary.md](../contracts/delivery-proof-boundary.md)
- [delivery-proof-assessment.md](../contracts/delivery-proof-assessment.md)
- [delivery-proof-dispute.md](../contracts/delivery-proof-dispute.md)
- [permission-matrix.md](../contracts/permission-matrix.md) —
  `rider.delivery.submit_proof`, `customer.delivery.confirm_proof`,
  `admin.policy.publish_version`
- `CONSTRAINTS.md` invariants **7**, **11** and **13**
