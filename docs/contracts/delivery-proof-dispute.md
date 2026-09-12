# Fallback delivery-proof dispute

**Contract version 0.9** (FND-003D2B, corrected in place by
**FND-003D2B-FIX-001**, **FND-003D2B-FIX-002** and
**FND-003D2B-FIX-003**). Source of truth: the module behind the stable barrel
`packages/contracts/lib/src/delivery_proof_dispute.dart`.

FND-003D1 gave the platform a way to *refer to* a proof policy and to protected
evidence. FND-003D2A added the trusted, immutable *result* of evaluating one.
This slice adds the **fallback for the cases a delivery could never consume**:

```text
"Fallback dispute workflow for a missing, superseded or
 `notSatisfied` assessment."   — the FND-003D2B ledger boundary
```

It is a **prerequisite contract, not a delivery slice, not a resolution slice
and not general support-case infrastructure.**

---

## 1. Successful delivery is still NOT executable

Nothing here delivers an order, confirms delivery, records an attempt, handles
refusal or failure, starts a return, moves custody to the customer, completes a
rider assignment, or touches money.

| Thing | Status after 0.9 |
|---|---|
| `OrderState.delivered` | **unreachable** — `notYetImplemented`, no canonical pairing |
| `CustodyHolderKind.customer` | **unreachable** — `notYetImplemented` |
| rider `AssignmentState.completed` | **unreachable** — B3-C2 FUTURE, no revision cost invented |
| picker `AssignmentState.completed` | unchanged from FND-003B3A |
| delivery / refusal / return commands | **none exist** |
| `Permission.values` | **38**, unchanged |
| **dispute resolution** | **not executable** — see §7 |

> **This table is the state *after 0.9*, not the state today.** FND-003B3B
> (0.10) later added the delivery-attempt and return commands and one
> permission, taking `Permission.values` to **39**. `OrderState.delivered`,
> `CustodyHolderKind.customer`, rider `completed` and dispute resolution are
> **still** unreachable.

`CONSTRAINTS.md` invariant 13 requires **both** customer proof and the fallback
dispute workflow before delivery confirmation is coded. This slice delivers the
second half. The proof-satisfaction **policy** was undefined when this slice
landed and has since been **decided** — 2026-09-12,
[ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md), owner
decision **O8**: a server-issued, single-use, resource-bound confirmation
challenge, verified server-side and fail-closed. **That is a policy decision, not
an implementation.** No challenge lifecycle, evaluator, command, event, state or
permission was added by it, so **invariant 13 is still not discharged and
delivery confirmation still may not be coded**. Nothing in this dispute contract
changes: no current command can manufacture proof satisfaction, dispute
resolution remains undecided, and `dispute.resolve_delivery_proof` is still
enumerated and always refused `resolutionPolicyDeferred`.

## 2. The situations, and why each stays distinct

Five proof-assessment situations exist, and this contract keeps all five apart.
Collapsing any two would either fabricate a verdict or hide one.

| Situation | Result | Denial / basis |
|---|---|---|
| canonical absence — *not assessed* | dispute may be raised | basis `notAssessed` |
| current canonical `notSatisfied` | dispute may be raised | basis `notSatisfied`, pinned to that assessment |
| basis **superseded** after the raise | dispute stays valid and reviewable | standing `superseded` |
| **malformed or torn** assessment facts | refused | `assessmentAggregateInconsistent` |
| current canonical `satisfied` | refused | `assessmentSatisfied` |

**Corruption is never laundered into `notSatisfied`.** A torn assessment
aggregate is a reconciliation case, not a negative result, and it can never
become a dispute basis — the single most important negative in this slice, and
one a test drives for both verdicts.

**A `satisfied` assessment is not a fallback ground.** Contesting an assessment
a trusted verifier concluded *was* satisfied is a different workflow, with
different evidence, authority and consequences, and **no slice defines it**.
Refusing it here is what keeps this contract from quietly becoming general
support-case infrastructure.

### Supersession is a standing, not a basis kind

A dispute is always raised against the **current canonical** situation — the
request pins `expectedAssessmentRevision`, so raising against a stale view is
refused. Supersession is what happens *afterwards*, and it is computed on
demand:

```dart
resolveDeliveryProofDisputeBasisStanding(basis: ..., assessment: ...)
  -> current | superseded | indeterminate
```

| Standing | Meaning |
|---|---|
| `current` | the recorded basis is still exactly what the assessment aggregate says — **same id, same revision and the same verdict** |
| `superseded` | the assessment history has moved on; the basis stays historically identifiable and is **never rewritten** |
| `indeterminate` | malformed basis, torn assessment, mixed resources, an aggregate sitting *behind* the basis, or a **same-id/same-revision verdict contradiction** |

**Corruption is never reported as `current` or `superseded`**, for the same
reason `canonicalVerdict` never downgrades a torn aggregate to `notSatisfied`.

### Identity is not meaning

*(Corrected by FND-003D2B-FIX-001.)* Matching the assessment id and revision was
originally treated as enough to report `current`. **It is not.** ADR-0009 gives
every reassessment a **new opaque id and the next revision**, so assessment A at
revision 1 can never legitimately change verdict. A basis recorded as
`notSatisfied` against A/1, compared with a *structurally canonical* A/1 that now
reads `satisfied`, is a self-contradictory history — and was being certified as
"still current".

At the same revision the standing therefore requires **all three** to agree:

```text
assessment id       exact match
assessment revision exact match
canonical verdict   still notSatisfied
```

A mismatch answers `indeterminate`. It is **not** converted to `superseded` —
nothing superseded it, the revision never moved — **not** converted to
`notSatisfied`, and the basis is **not** rewritten. The contradiction is a
reconciliation case, exactly like a torn aggregate.

### An id is never reusable, at any revision

*(Corrected by FND-003D2B-FIX-002.)* The same rule binds a **higher** revision.
Advancing the revision was originally enough to report `superseded`; it is not,
because ADR-0009 gives every reassessment a **new opaque id**. A revision-2
record that carries the id this basis pinned would mean the contested identity
exists twice, and certifying it as a legitimate supersession would let a reused
id quietly erase which assessment was actually contested.

```text
basis   notSatisfied / A / rev 1
current              / A / rev 2   -> indeterminate   (impossible history)
current              / B / rev 2   -> superseded      (a real reassessment)
```

That aggregate is **structurally canonical** — the shape validator passes and
`canonicalVerdict` answers — which is exactly why no shape check could catch it.
It is a *relationship* contradiction between the basis and the history.

The comparison uses the **current record only**. It invents no in-memory history
array and needs no global uniqueness lookup: uniqueness across records that are
no longer current is a storage guarantee (**DPA11**, NOT RUN), and this is the
part a pure aggregate genuinely can check.

**A later `satisfied` assessment does not dismiss the dispute.** Deciding that
would be deciding the outcome.

## 3. The public surface

| Type / function | Purpose |
|---|---|
| `DeliveryProofDisputeState` | `open` / `underReview`, plus unreachable `resolved` |
| `reachableDisputeRevisionFor` | the exact revision each state may carry; **null for `resolved`** |
| `DeliveryProofDisputeBasisKind` | `notAssessed` / `notSatisfied` |
| `DeliveryProofDisputeBasis` | the immutable audit identity of what was disputed |
| `DeliveryProofDisputeBasisStanding` | `current` / `superseded` / `indeterminate` |
| `resolveDeliveryProofDisputeBasisStanding` | the standing calculation |
| `DeliveryProofDisputeCommand` | three named operations; **one is deliberately not executable** |
| `DeliveryProofDisputeEventType` | two event ids |
| `DeliveryProofDisputeRecord` | one dispute as currently recorded |
| `DeliveryProofDisputeFacts` | the aggregate: current record + its own revision |
| `DeliveryProofDisputeOrderRead` | order lifecycle facts **bound to the order they were read from** |
| `DeliveryProofDisputeRaiseRequest` | what a raise pins: dispute, assessment and order revisions |
| `DeliveryProofDisputeReviewRequest` | what review pins: **the dispute revision, and nothing else** |
| `DeliveryProofDisputeTransition` | the record to store, and every effect as NONE |
| `DeliveryProofDisputeOutcome` | allow or deny, with `isPolicyDeferred` |
| `DeliveryProofDisputeDenial` | 20 refusal reasons — internal, never returned verbatim |
| `validateDeliveryProofDisputeAggregate` | canonical stored shape |
| `canonicalState` / `canonicalBasis` | trusted access, canonical aggregates only |
| `checkDisputeAuthorization` | binds an operation to a canonical authorization success |
| `evaluateRaiseDeliveryProofDispute` | the raise evaluator |
| `evaluateRecordDeliveryProofDisputeReview` | the review evaluator |
| `evaluateResolveDeliveryProofDispute` | **takes no arguments**; always refuses |

### One evaluator per operation, one read-set per evaluator

*(Restructured by FND-003D2B-FIX-001.)* These were a single
`evaluateDeliveryProofDispute` taking every aggregate for every operation, and
that is exactly the trap: **a shared read-set silently becomes a shared
precondition.**

| Operation | Reads |
|---|---|
| `evaluateRaiseDeliveryProofDispute` | **grant**, dispute, **assessment**, **resource-bound order read** |
| `evaluateRecordDeliveryProofDisputeReview` | **grant**, dispute |
| `evaluateResolveDeliveryProofDispute` | **nothing at all** |

The read-set is now part of the contract rather than a convention, and a test
that tries to hand review an assessment or an order **does not compile**.

### Module layout

Split by responsibility behind a **stable barrel**, so `cp_contracts.dart` and
every consumer keep one import path:

| File | Responsibility |
|---|---|
| `…_state.dart` | handling states and the reachable revision per state |
| `…_authorization.dart` | binding an operation to a canonical authorization success |
| `…_basis.dart` | what was disputed, and how that basis stands today |
| `…_command.dart` | named operations, their permissions, and the events |
| `…_denial.dart` | refusal vocabulary |
| `…_record.dart` | one dispute as currently recorded |
| `…_facts.dart` | the aggregate, the per-operation requests and the resource-bound order read |
| `…_validation.dart` | canonical aggregate shape and trusted access |
| `…_transition.dart` | the permitted operation and its all-NONE effects |
| `…_evaluator.dart` | one pure evaluator per operation, each with its own read-set |

The graph is **acyclic** and flows one way: vocabulary → model → shapes →
validation → evaluator. **No validation rule is duplicated** — identifier rules
come from `ids.dart`, the assessment's canonical shape and verdict access from
the FND-003D2A module, and the order's from its own canonical validator. No file
imports an app or the backend.

## 4. What one dispute record binds

```dart
disputeId                    // opaque, server-generated, immutable
resourceId                   // the order
disputeRevision              // this aggregate's own revision
basis                        // WHAT was disputed — immutable, never rewritten
raisedByPrincipalId          // the verified customer principal
raisedAtUtc                  // server UTC
state                        // open | underReview — never an outcome
reviewStartedByPrincipalId   // null while open
reviewStartedAtUtc           // null while open
```

The basis carries an **assessment id and revision, and nothing else**:

```dart
kind                 // notAssessed | notSatisfied
assessmentId         // null exactly when notAssessed
assessmentRevision   // 0 exactly when notAssessed
resourceId           // the order
```

### What the record deliberately does not hold

**No free text.** There is no `reason`, `note`, `comment`, `description`,
`message` or `attachment` field anywhere in the module:

- the reason is **already captured** — `customer.dispute.raise` and
  `admin.dispute.administer` both carry `reasonRequired: true`, and FND-003A
  stores that justification with the audited command. A second copy here would
  be a second place for it to drift;
- a customer-supplied string on a **wire-facing value object** is an
  amplification and log-injection surface, and it is the one field through which
  a description of proof material could reach an event payload. A free-text
  field would be the hole in this contract's "no proof material" claim.

**No copy of the assessment.** No policy reference, no evidence reference, no
verdict copy, no rider identity, no verifier identity. A copied field is a
projection free to drift from the append-only record that owns it — the same
reason `CustodyHolder` binds an assignment *attempt* rather than projecting who
is assigned now. **No raw proof material can be here, because nothing about the
evidence is here at all.**

**No outcome.** No `upheld`, `rejected`, `resolution`, `fault`, `liable`,
`refund`, `compensation` or `charge` field — see §7.

## 5. Integrity — fail closed

Each operation checks **only what it reads**, in order, and every check fails
closed.

**Raise** — pins the whole read-set its basis comes from:

| # | Check | Denial |
|---|---|---|
| 1 | canonical authorization grant for `customer.dispute.raise`, this principal, **the stored dispute's resource** | `authorizationGrantMismatch` |
| 2 | the **dispute** aggregate validates | `disputeAggregateInconsistent` |
| 2 | the **assessment** aggregate validates | `assessmentAggregateInconsistent` |
| 2 | the **order** aggregate validates | `orderAggregateInconsistent` |
| 3 | the assessment **and the order read** name the canonical order | `resourceBindingMismatch` |
| 4 | dispute revision compare-and-set | `disputeRevisionConflict` |
| 4 | assessment revision compare-and-set | `assessmentRevisionConflict` |
| 4 | order revision compare-and-set | `orderRevisionConflict` |
| 5 | the actor is a human principal | `actorNotHumanPrincipal` |
| 5 | the timestamp is UTC | `timestampNotUtc` |
| 6 | order is `in_delivery` | `orderNotInDelivery` |
| 6 | reservation is `committed` | `reservationNotCommitted` |
| 7 | `disputeId` is a valid opaque id | `disputeIdInvalid` |
| 8 | no dispute already exists | `disputeAlreadyOpen` |
| 9 | the assessment is a fallback ground | `assessmentSatisfied` |

**Record review started** — the dispute, and nothing else:

| # | Check | Denial |
|---|---|---|
| 1 | canonical authorization grant for `admin.dispute.administer`, this principal, **covering the stored dispute's resource** | `authorizationGrantMismatch` |
| 2 | the **dispute** aggregate validates | `disputeAggregateInconsistent` |
| 3 | dispute revision compare-and-set | `disputeRevisionConflict` |
| 4 | the actor is a human principal | `actorNotHumanPrincipal` |
| 4 | the timestamp is UTC | `timestampNotUtc` |
| 5 | `disputeId` is a valid opaque id | `disputeIdInvalid` |
| 5 | a dispute exists | `disputeNotFound` |
| 5 | it is the named dispute | `disputeIdMismatch` |
| 6 | it is still `open` | `disputeNotOpen` |
| 7 | review does not precede the raise | `reviewTimestampPrecedesRaise` |

> **There is no separate resource-binding step here, and there must not be.**
> *(Corrected by FND-003D2B-FIX-006.)* This table previously carried a row
> *"it names the canonical order → `resourceBindingMismatch`"*. **No such check
> exists in `evaluateRecordDeliveryProofDisputeReview`, and the denial is
> unreachable from it.**
>
> That is by design rather than by omission. The stored dispute *supplies* the
> anchor, and step 1 already requires the grant to **cover** exactly it — so a
> second comparison would only ever compare `dispute.resourceId` against itself,
> which is the same tautology FND-003D2B-FIX-003 removed from
> `checkDisputeAuthorization`. Raise needs the check because it has other,
> independently supplied read-set members (the assessment and the order read) to
> bind; review has none.
>
> The row was removed rather than satisfied: **stale prose is not a reason to
> add a runtime check.**

**Resolve** — no table, because it reads nothing: always
`resolutionPolicyDeferred`.

### Authorization is required, and is still FND-003A's

*(Added by FND-003D2B-FIX-002.)* Both executable operations take an
**`AuthorizationGrant`** — the artifact FND-003A made unforgeable (`final`,
library-private constructor) precisely so downstream steps could rely on it,
and obtainable **only** from a successful `evaluateAuthorization`.

The previous signatures took a bare `Principal` and *documented* that
authorization had already run. **A pure function cannot assert that about its
caller.** Nothing distinguished an authorized call from one that skipped the
check, so a **non-owner customer could reach a raise transition** and a
**customer-only principal could reach a review transition**.

What is verified here is only that the grant in hand **is the right grant**:

```text
grant.permission  == the operation's requiredPermission
grant.principalId == the acting principal
grant.resourceId  == the canonical resource, and a valid opaque id
```

Role, membership status, scope and reason are **not** re-checked: they live in
`permissionMatrix` and are decided in exactly one place. An out-of-region admin,
an inactive member, a wrong-role principal or an admin who supplied no reason
simply never obtains the grant, so there is nothing for them to present. The
matrix is not copied, and FND-003D2B added no permission of its own —
`Permission.values` was **38** throughout that slice, and is **39** today only
because FND-003B3B later added `agent.return.record_receipt`.

One **generic** denial covers every failure — `authorizationGrantMismatch` —
because a caller must not be able to probe for a resource's existence, owner or
scope by comparing refusals, exactly as `AuthorizationDecision.publicMessage` is
uniform. There is no forgeable `isAuthorized` boolean, no client-supplied role
or permission, and no authorization data on any command payload.

> **Freshness is still the backend's.** FND-003A-FIX-003 requires fresh
> authorization on every request including replays and forbids caching or
> reusing a grant. A grant proves `evaluateAuthorization` allowed *those
> inputs*; that they were current is **R33–R40**, NOT RUN.

**Raising confers no admin authority.** The historical raiser reaches review
only by independently holding an admin grant of their own — which is a fact
about that principal's membership, not about the dispute.

**The persisted dispute aggregate supplies the canonical resource anchor.** The
`AuthorizationGrant` must **cover** that exact, independently anchored resource
— it is not itself the source used to choose it. For a raise, the assessment
aggregate and the resource-bound order read must identify the same resource
before any order fact can produce a transition.

```text
dispute.resourceId                 <- the anchor
  == AuthorizationGrant.resourceId (grant.covers, checked first)
  == assessment.resourceId
  == DeliveryProofDisputeOrderRead.resourceId
```

That direction matters: comparing the grant against a value the grant itself
supplied would prove nothing, which is exactly the tautology
FND-003D2B-FIX-003 removed from `checkDisputeAuthorization`.

> **Historical.** FND-003D2B-FIX-002 deleted `DeliveryProofDisputeContext`
> because two sources of resource truth could disagree, and at that point took
> the resource from the grant. FND-003D2B-FIX-003 moved the anchor to the stored
> dispute aggregate and made the grant prove coverage of it instead. The type is
> gone either way; only the anchor changed.

### Every member of the raise read-set names one order

*(Completed by FND-003D2B-FIX-003.)* The accepted `OrderLifecycleFacts` carries
a state, a revision, a reservation state and a unit count — and **no resource
id**. That is right for the pre-dispatch evaluator, which is handed one order
and asked about that order. It is not enough here, where a raise must prove that
four independently supplied things describe the **same** delivery.

Until this correction an order-B read whose scalars matched order A —
`in_delivery`, revision 5, reservation `committed` — was **indistinguishable**
from A's own facts, so a dispute could be recorded against A on the strength of
B's lifecycle. **Numeric equality is not identity.**

`DeliveryProofDisputeOrderRead` binds the facts to the order they were read for,
and the raise now requires:

```text
dispute.resourceId            <- the canonical anchor, from the read-set
  == grant                    (grant.covers, checked first)
  == assessment.resourceId
  == orderRead.resourceId
```

The anchor is the **stored dispute aggregate's** resource, never the grant's:
comparing the grant against a value the grant itself supplied would be a
tautology, which is exactly the self-referential call FIX-003 also removed from
`checkDisputeAuthorization`. That helper now takes an `expectedResourceId` from
the read-set.

`DeliveryProofDisputeOrderRead` is a **read, not a second order aggregate**: no
state, no transition, no revision arithmetic, no lifecycle rule, and the
accepted `OrderLifecycleFacts` contract is untouched. It says only *which order
these facts were loaded for*.

> **Binding is not provenance.** That the backend loads every aggregate for one
> canonical resource in a single consistent transaction remains **DPD3**, and
> revalidation inside it **DPD4** — both **NOT RUN**.

### Why review does not check the assessment or the order

*(Corrected by FND-003D2B-FIX-001.)* It used to. The shared evaluator validated
the current assessment, validated the current order, compared the order's
revision, and required `in_delivery` and `committed` before it would record that
review started — **none of which that operation reads or changes.**

An open dispute is already canonical and already carries its immutable basis.
Beginning to review it moves no order, no custody, no assignment, no assessment,
no stock and no money. Requiring the surrounding lifecycle to be unchanged meant
a reassessment, a torn assessment read, or an unrelated order write **after a
validly raised dispute** could freeze it out of review. A fallback that stops
working when the thing it is a fallback for changes is not a fallback.

**Nothing about a delivery, refusal or return may be inferred from that
independence.** It says only that review may begin.

**There is also no separation-of-duties rule.** The candidate denied
`reviewerIsRaiser` when the reviewing principal had earlier raised the dispute.
No accepted contract asks for that: `admin.dispute.administer` requires an
active admin membership, `ownRegion` scope and a stored reason, and carries
`approvalRequired: false`. A denial nobody decided is an invented authorization
policy, so it was removed from the evaluator, the record validator, the denial
vocabulary and the tests. **If separation of duties is ever wanted it needs its
own permission and ADR** — it is not smuggled in here.

Each aggregate keeps **its own** corruption denial, so a log never has to guess
which one was torn — and, critically, so a torn *assessment* can never be
confused with a negative *verdict*.

**Three distinct denials, three distinct meanings**: `assessmentAggregate
Inconsistent` ("we could not read it"), `assessmentSatisfied` ("we read it and
it says satisfied"), and a `notAssessed` basis ("we read it and there is
nothing"). Collapsing any two would hide which happened.

### What is deliberately **not** in the read-set

**Custody and the rider assignment.** They are central to
`evaluateDeliveryProofAssessment`, which decides something *about* a rider's
delivery, and they are absent here on purpose:

- a dispute asserts nothing about a rider, so it needs no rider binding. The
  immutable audit identity of the rider attempt that *was* assessed already
  lives on the assessment record the basis points at, where FND-003D2A put it;
- requiring current custody would make the fallback **unavailable exactly when
  something has gone wrong with custody** — a mid-flight reassignment, a corrupt
  holder record — which is the opposite of a fallback.

**Possession is never an authorization source**, in either contract.

### The evaluator is not the authorization boundary

`evaluateAuthorization` has already run against the canonical matrix, with
`customer.dispute.raise`'s `ownResource` scope, `admin.dispute.administer`'s
`ownRegion` scope, and both permissions' `reasonRequired`. Repeating any of that
in the state machine would create a second place for it to drift. What the
evaluator adds is **context integrity**: one canonical order, current facts, and
an operation coherent with them.

The one actor property it *does* check is structural rather than authorizing:
the acting principal must be a **human**, because a background job recorded as
the raiser or reviewer is an unattributable audit trail. That is the exact
inverse of `assessorNotSystemWorker`, and both fail closed.

## 6. Revisions and compare-and-set

The dispute aggregate has **its own** `disputeRevision`, independent of the
order, custody, rider-slot and assessment revisions. Five aggregates change at
different rates; one shared counter would make every unrelated write look like a
conflict and a genuine conflict undetectable.

```text
no dispute            -> disputeRevision == 0
raise                 -> 0 -> 1   -> open
record review started -> 1 -> 2   -> underReview
```

`reachableDisputeRevisionFor` pins that arithmetic, in the same shape as
`reachableSlotRevisionRange` — and with the same discipline: **a state with no
defined cost returns null**, so every aggregate holding it fails closed.

**Recording review pins the dispute revision, and only that.**
`DeliveryProofDisputeReviewRequest` has **no assessment revision and no order
revision**, because the operation reads neither aggregate and a compare-and-set
on something you never read is meaningless. Making those fields structurally
absent is stronger than documenting that they are ignored — and it is what stops
a reassessment freezing a validly raised dispute out of review.

**Correct revisions never bypass identity, state or eligibility checks.** They
run in addition, not instead, and tests pin that.

**At most one live dispute per order.** A second would fork the audit trail: two
records, two bases, and no way to say which was *the* dispute when anything
happened. Duplicate and reordered raises land on `disputeRevisionConflict` or
`disputeAlreadyOpen`, and neither writes anything.

## 7. Resolution is a real edge whose policy is undecided

`DeliveryProofDisputeCommand.resolve` is **enumerated and always refused**
with `resolutionPolicyDeferred`, **before any fact is read** — so a deferred
edge cannot leak a partial evaluation of itself, and the denial is identical
whatever the facts look like.

`DeliveryProofDisputeState.resolved` is declared for enum stability and is
**unreachable**: no command enters it, `reachableDisputeRevisionFor` gives it no
revision, and a stored record claiming it is **corruption**.

This follows two precedents exactly:

- `LifecycleDenial.policyDeferred` for cancellation from `preparing`/`ready` —
  a backend must be able to tell **"not decided yet"** from **"never allowed"**,
  so nobody fills the gap with a guessed rule or a zero fee.
  `DeliveryProofDisputeOutcome.isPolicyDeferred` exposes that distinction;
- `OrderState.delivered` and rider `AssignmentState.completed` — a state nobody
  implements gets **no revision arithmetic invented for it**.

Resolving a dispute would require deciding, at minimum:

- **who prevails**, and on what standard of evidence;
- whether the order becomes **delivered, refused or returned**, and where a
  return goes;
- whether a **fee, refund, compensation or liability** follows, and who bears
  it — `CONSTRAINTS.md` invariant 11 stands: delivery failure does not
  automatically justify a customer fee, and nonpayment must remain
  representable;
- whether **stock is restored** — invariant 12 stands: not until shop receipt
  **and** inspection;
- whether **customer participation** is optional, mandatory, sufficient or a
  veto.

**Not one of those is decided anywhere in this repository.** They belong to
owner decision **O6** and **FND-003C**. *(FND-003D2B also pointed at
FND-003B3B, which has since run: it defines the refused-order return and
decides none of these questions, so they remain open.)* Guessing one here would
bake it into stored history.

**Withdrawal, closure, expiry, escalation and reassignment of a dispute are
equally undecided and equally absent.** No `withdraw` command exists, no SLA,
deadline, escalation timer or response window is derived from any timestamp, and
none is invented.

## 8. Effects — all NONE, structurally

| Effect | Value |
|---|---|
| Order | **NONE** — `changesOrderState == false` |
| Reservation | **NONE** |
| Inventory | **NONE** — `InventoryEffect.none()`, `availableStockDelta == 0` |
| Financial | **NONE** — `FinancialClassification.noneInThisSlice` |
| Custody | **NONE** — `changesCustody == false` |
| Assignment | **NONE** — `changesRiderAssignment == false` |
| **Assessment** | **NONE** — `changesAssessment == false` |
| Scope projection | **NONE** — `ScopeProjectionEffect.none()` |

`DeliveryProofDisputeTransition` has **no order, custody, assignment or
assessment effect field**, so a transition that moves one cannot be constructed.
That is a stronger statement than a runtime check.

> **A dispute is not permission to do anything.** Raising or reviewing one does
> not permit delivering the order, transferring custody to the customer,
> completing the rider assignment, restoring stock, charging a fee, issuing
> compensation or settling money — and neither would an outcome, if one existed.

> **The financial classification describes the *recording*.** Writing a dispute
> record posts nothing. Whether a dispute — or the `notSatisfied` assessment
> under it — eventually has a financial consequence is **UNKNOWN and deferred to
> FND-003C**, blocked on owner decision **O6**. It must never be read as zero.

### The assessment stays immutable and append-only

A dispute **never** mutates, relabels, erases, supersedes or reassesses the
record it points at. ADR-0009's append-only history is what makes the basis
meaningful in the first place; a dispute that could edit its own basis would
destroy exactly the audit trail it relies on.

The one forward edge, `DeliveryProofDisputeRecord.reviewStarted`, **does not
accept** a basis, a raiser or a raise time — it carries all three forward from
the previous record by construction. A caller cannot advance a dispute while
quietly changing what it was about or who raised it.

## 9. The events

Two ids, and neither is a resolution:

```text
delivery.proof_dispute_raised
delivery.proof_dispute_review_started
```

There is no `delivery.proof_dispute_resolved`, `…_upheld`, `…_rejected`,
`…_refunded` or `…_closed`, because no slice defines what any of them would
mean.

**They are structural, not supplied.** The transition takes only the record and
the command; `events` is a getter returning a `const` — therefore deeply
immutable — single-element list, and `events.add(...)` throws
`UnsupportedError`. There is no constructor parameter through which a caller
could pass an extra, missing or fabricated event id.

Payloads carry routing and identity only — resource id, dispute id, dispute
revision, server UTC. **Never** raw proof or evidence material, policy contents,
a verdict copy, reason text, customer contact detail, address, order contents,
money, storage paths or signed URLs. Authorized clients re-read protected state;
a notification is a **hint, never proof, authority or an outcome**.

## 10. Server time

`raisedAtUtc` and `reviewStartedAtUtc` must be UTC, supplied by trusted server
execution — never a client clock, a mobile clock, a notification timestamp or a
device timezone.

The only relationship derived between them is **ordering**: review cannot
precede the raise, because that pair is incoherent and would store a record the
validator refuses. **No expiry, TTL, deadline, SLA, escalation timer, maximum
age, response window or retry interval is derived from either, and none is
invented.** A test proves it by accepting both a year-2000 and a year-2099
dispute.

A pure Dart UTC value **cannot prove it came from a server**. That it is
authoritative is criterion **DPD9**, NOT RUN.

## 11. Debug and log renderings are fail safe

The public constructors intentionally permit malformed objects — that is what
lets the validators be tested — so a `toString` that echoed raw fields would be
a log-injection and amplification surface reachable **before** validation.

| Value | Well formed | Malformed |
|---|---|---|
| `DeliveryProofDisputeBasis` | kind + bounded canonical ids | `DeliveryProofDisputeBasis(invalid)` |
| `DeliveryProofDisputeRecord` | bounded canonical ids + state | `DeliveryProofDisputeRecord(invalid)` |
| `DeliveryProofDisputeTransition` | command, state, revision, id | `DeliveryProofDisputeTransition(invalid)` |
| `DeliveryProofDisputeOutcome` | delegates to the above | delegates — cannot reintroduce a raw field |

**One bad field suppresses the whole rendering**, including the fields that
happen to be sound. Denials render enum names only. Tests drive the same hostile
inputs the assessment suites use — newline and tab, a URL, a filesystem path, a
fake secret marker and an oversized string — and assert no fragment survives,
plus the guard that every hostile fixture really is a malformed id.

## 12. Trust boundary — read this before consuming a dispute

Any client can construct a `DeliveryProofDisputeRecord`, and a test asserts such
a forgery **is** structurally well formed, because it is. The type carries no
signature, no attestation and no provenance, and **cannot authenticate its own
origin**.

Therefore:

- clients may construct equivalent Dart data locally;
- **the backend must ignore client-supplied dispute records**;
- only a dispute **loaded from trusted backend state** may be acted on;
- backend provenance remains **future acceptance evidence**, not something this
  contract establishes.

## 13. Deliberately deferred — never defaulted

| Decision | Status | Owner |
|---|---|---|
| **How a dispute resolves** — who prevails, on what standard | **DEFERRED** — enumerated and refused | resolution slice + **O6** |
| Delivery, refusal or return consequence of a dispute | **DEFERRED** — FND-003B3B (**done**) defines the refused-order return but decides no *dispute* consequence | resolution slice + **O6** |
| Any fee, refund, compensation, liability or settlement | **UNKNOWN / DEFERRED** | **FND-003C** — **O6 resolved** (ADR-0011); the remaining money lifecycle work is unimplemented |
| Withdrawal, closure, expiry, escalation, reassignment of a dispute | **NOT INVENTED** | resolution slice |
| **Separation of duties** between raiser and reviewer | **NOT DECIDED** — an invented `reviewerIsRaiser` denial was removed by FND-003D2B-FIX-001; the accepted permission requires no approval | future permission + ADR |
| SLA, deadline or response window | **NOT INVENTED** | operational policy |
| Proof mechanism (OTP/QR/signature/photo/GPS/biometric/attestation) | **POLICY DECIDED** 2026-09-12 — [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) selects a server-issued, single-use, resource-bound confirmation challenge. **None is selected, named or implied *in any contract***: no type, field, enum or event represents one | decided; **executable form DEFERRED** |
| What a proof policy actually requires | **DECIDED** 2026-09-12 — [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md): a live, bound challenge fulfilled by the customer side and **verified server-side**, fail-closed; photo, GPS, timestamp, unbound signature, rider assertion, cash collection, non-response, attempt completion and custody possession are each **insufficient alone** | ADR-0012; **implementation DEFERRED** |
| **Customer participation requirement** | **DECIDED** 2026-09-12 — [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md): **MANDATORY and NOT SUFFICIENT**, and not a veto that ends the order. **Raising a dispute is still not participation in proof**. **No administrative act may supply the customer's part** — an ADMIN exception review records and audits an unresolved case and **cannot conclude satisfaction** ([ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) Decision 9) | ADR-0012; **implementation DEFERRED** |
| Disputing a **satisfied** assessment | **NOT DEFINED** — refused `assessmentSatisfied` | future slice, if ever needed |
| Whether a dispute may be raised after delivery, refusal, return or post-dispatch cancellation | **DEFERRED** — refusal and return became reachable in FND-003B3B (**done**), which decided nothing about disputing them; delivery and post-dispatch cancellation remain unreachable | resolution slice + **O6** |
| Manual/admin proof override | **STILL NOT INVENTED** — none exists, and none was added. [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) sets the boundary for an exception review — separately authorized, reason- and reference-bearing, audited, resource-bound, append-only and **distinguishable afterwards**, never a silent waiver — and **creates neither the workflow nor a permission for it**. Its authority is bounded to **recording, classifying and auditing** an unresolved case: it **cannot mark proof satisfied, cannot mark an order delivered, cannot waive the proof requirement, cannot assign customer fault, cannot create a fee and cannot resolve a dispute**, and it may not substitute a photograph, GPS fix, signature, rider statement, cash collection or administrator judgement for a customer-side act. Any future policy allowing satisfaction **without** a customer-side act requires a **superseding ADR and contract migration, accepted before implementation** | future bounded slice, under ADR-0012 |
| **Governing policy version missing / unknown / unresolvable / unsupported / unverifiable** | **FAILS CLOSED — no satisfaction** ([ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) Decision 11). **No default policy is inferred**: no built-in fallback, and no silent substitution of the latest or a previous version — an order keeps the version it was quoted under | ADR-0012; **implementation DEFERRED** |
| Dispute visibility, retention and deletion | **DEFERRED** (as for evidence, unchanged from D1) | privacy/retention slice |

`customer.delivery.confirm_proof` keeps its exact accepted meaning:
**participation only**, settling no cash and closing no dispute. **Raising a
dispute is not participation in proof**, and no `customerConfirmed` flag was
added here either.

## 14. Backend acceptance checklist — DPD1–DPD12

**Every item is NOT RUN.** No backend, no persistence, no Firebase project and
no emulator exists. Contract tests in `packages/contracts` are **not** evidence
that any of this is implemented.

| # | Requirement | Status |
|---|---|---|
| **DPD1** | The backend constructs the dispute context from trusted current records; a client cannot supply authoritative context. | **NOT RUN** |
| **DPD2** | The backend ignores client-supplied dispute records; only a record loaded from trusted state is authoritative. | **NOT RUN** |
| **DPD3** | Dispute, assessment and order facts are loaded for one canonical resource in one consistent read-set. | **NOT RUN** |
| **DPD4** | Dispute, assessment and order revisions are revalidated **inside** the transaction, and concurrent raises from one expected revision commit at most one next revision. | **NOT RUN** |
| **DPD5** | An exact retry returns one stored result without applying the operation twice; changed content under the same dedupe identity rejects. | **NOT RUN** |
| **DPD6** | The dispute record, current pointer/projection, dedupe result and outbox event commit atomically; **no raw evidence, verdict copy or reason text enters the event or push**. | **NOT RUN** |
| **DPD7** | Each applied dispute revision is retained in bounded, paginated, **append-only** form, and **the basis is never rewritten** — including after the assessment it names is superseded. | **NOT RUN** |
| **DPD8** | Dispute ids are server-generated create-if-absent; historical ids cannot be reused or overwritten. | **NOT RUN** |
| **DPD9** | `raisedAtUtc` and `reviewStartedAtUtc` come from authoritative server time; no client timestamp is commercial truth. | **NOT RUN** |
| **DPD10** | Raising or reviewing a dispute produces **no** order, custody, assignment, inventory or financial effect anywhere in the backend, and **no automatic cancellation, fee, refund, compensation, return or delivery consequence is derived** from a dispute or from a `notSatisfied` assessment. | **NOT RUN** |
| **DPD11** | The reason both permissions require is captured and stored with the **audited command** (the FND-003A path) and is **never** copied into the dispute record, a projection or an event payload. | **NOT RUN** |
| **DPD12** | `admin.dispute.administer`'s region scope and `customer.dispute.raise`'s ownership scope are enforced **server-side** on every request including replays, with fresh authorization each time (R33–R40). | **NOT RUN** |

Earlier series are **unchanged** by this slice: **DPA1–DPA18**, **CA1–CA23**,
**R33–R40**, **L1–L13**, **P1–P17** and **RA1–RA18** all remain **NOT RUN**.
**B3-C1** stays satisfied by contract tests **for the picker only** — not
persistence evidence. **B3-C2** stays **NOT RUN / FUTURE**.

## 15. Related

- [delivery-proof-assessment.md](delivery-proof-assessment.md) — the assessment this disputes
- [delivery-proof-boundary.md](delivery-proof-boundary.md) — the D1 references
- [custody-lifecycle.md](custody-lifecycle.md) — the dispatch boundary
- [permission-matrix.md](permission-matrix.md) — the two permissions, unchanged
- [privacy-and-security-boundaries.md](privacy-and-security-boundaries.md)
- [ADR-0009](../decisions/ADR-0009-trusted-immutable-proof-assessment.md) — the append-only history this relies on
- `CONSTRAINTS.md` invariants 11, 12 and 13
