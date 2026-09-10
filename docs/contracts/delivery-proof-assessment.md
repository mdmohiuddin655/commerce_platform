# Delivery-proof assessment

**Contract version 0.8** (FND-003D2A). Source of truth:
`packages/contracts/lib/src/delivery_proof_assessment.dart`.

FND-003D1 gave the platform a way to *refer to* a proof policy and to protected
evidence. This slice adds the missing half: a **trusted-server-produced,
immutable result** stating whether the referenced policy was satisfied — without
selecting a proof mechanism, and without making successful delivery executable.

It is a **prerequisite contract, not a delivery slice.**

---

## 1. Successful delivery is still NOT executable

Nothing here delivers an order, confirms delivery, records an attempt, handles
refusal or failure, starts a return, moves custody to the customer, completes a
rider assignment, or touches money.

| Thing | Status after 0.8 |
|---|---|
| `OrderState.delivered` | **unreachable** — `notYetImplemented`, no canonical pairing |
| `CustodyHolderKind.customer` | **unreachable** — `notYetImplemented` |
| rider `AssignmentState.completed` | **unreachable** — B3-C2 FUTURE, no revision cost invented |
| picker `AssignmentState.completed` | unchanged from FND-003B3A |
| delivery / refusal / return commands | **none exist** |
| `Permission.values` | **38**, unchanged |

A test sweeps every command type across `LifecycleCommand`,
`AssignmentCommand` and `CustodyCommand` and asserts nothing containing
`proof`, `assess`, `deliver`, `refus`, `return`, `attempt` or `dispute` exists.

## 2. The verdict vocabulary is two values

```dart
enum DeliveryProofAssessmentVerdict { satisfied, notSatisfied }
```

Wire ids are `satisfied` and `not_satisfied`. `Enum.index` is never serialized.

**Absence means "not assessed".** `DeliveryProofAssessmentFacts.absent` is
revision `0` with no record, following the repository's existing convention that
revision 0 means "never written". `currentVerdict` returns `null` there, and
`null` must never be collapsed into `notSatisfied`.

There is deliberately **no** `pending`, `processing`, `expired`,
`approvedByCustomer`, `disputed`, `overridden` or `delivered`. See
[ADR-0009](../decisions/ADR-0009-trusted-immutable-proof-assessment.md) for why
each was rejected.

### What `notSatisfied` does and does not mean

It means **only**: the trusted verifier concluded the referenced policy was not
satisfied by the referenced protected evidence, for this assessment.

It is **not** fraud, customer refusal, cancellation, delivery failure, a lost
dispute, fee liability, a refund, or financial default. A backend must not
derive a cancellation, a fee or a liability from it. `CONSTRAINTS.md` invariant
11 stands: delivery failure does not automatically justify a customer fee.

## 3. The public surface

| Type / function | Purpose |
|---|---|
| `DeliveryProofAssessmentVerdict` | `satisfied` / `notSatisfied` |
| `DeliveryProofAssessmentRecord` | one immutable assessment result |
| `DeliveryProofAssessmentFacts` | the aggregate: current record + its own revision |
| `DeliveryProofAssessmentContext` | canonical resource + **server-resolved** policy and evidence references |
| `DeliveryProofAssessmentRequest` | what a trusted verifier reports, plus the expected revisions |
| `DeliveryProofAssessmentTransition` | the record to append, and every effect as NONE |
| `DeliveryProofAssessmentOutcome` | allow or deny, with the exact D1 structural reason when relevant |
| `DeliveryProofAssessmentDenial` | 23 refusal reasons — internal, never returned verbatim |
| `DeliveryProofAssessmentEventType` | one event id |
| `executableProofAssessorKinds` | `{PrincipalKind.systemWorker}` |
| `validateDeliveryProofAssessmentAggregate` | canonical stored shape |
| `evaluateDeliveryProofAssessment` | the pure evaluator |

### Why policy and evidence live on the *context*, not the request

A verifier reports a verdict. It does **not** get to choose which policy it was
judged against or which evidence it judged. Both references are resolved
server-side from trusted state and handed in as context — criteria **DPA3** and
**DPA4**. The request has no policy or evidence field at all.

## 4. What one record binds

```dart
assessmentId                 // opaque, server-generated, immutable, never reused
resourceId                   // the order
assessmentRevision           // this aggregate's own revision; first is 1
policyRef                    // DeliveryProofPolicyRef — which policy applied
evidenceRef                  // DeliveryEvidenceRef — bound to resourceId
riderPrincipalId             // the rider whose custody was assessed
riderAssignmentId            // the exact attempt
riderAssignmentGeneration    // ...and its generation
assessedByPrincipalId        // the trusted worker
assessedByKind               // PrincipalKind.systemWorker
assessedAtUtc                // server UTC
verdict                      // satisfied | notSatisfied
supersedesAssessmentId       // backward pointer, null for the first
```

Every identity uses the repository's **canonical opaque-id rule** — the same one
`Principal`, `CommandEnvelope`, `EventEnvelope` and `CustodyHolder` apply.
That rule already rejects sequential-looking values, which is why `assessmentId`
cannot be a counter: a counter would let one actor guess another order's
assessment ids and would make a stolen id useful.

**Rider binding needs all three fields.** A replacement attempt takes a new id
*and* a new generation, so a principal id alone could match a different attempt
by the same rider. `SourcePickerBinding` is **not** copied in — no source code
demonstrated a requirement for it, and it stays immutable inside the rider
assignment where FND-003B2B put it.

**Evidence cardinality is not invented.** One `DeliveryEvidenceRef`, exactly as
D1 defined it. Whether the protected record behind it holds one artifact,
several, or a bundle — and by what mechanism any of it was captured — is private
proof-policy and storage design that no slice has made.

## 5. Current-delivery integrity — fail closed

An assessment is refused unless trusted current facts describe the **same**
delivery. Checks run in this order, and every one of them fails closed:

| # | Check | Denial |
|---|---|---|
| 0 | canonical `resourceId` is a valid opaque id | `resourceBindingMismatch` |
| 0 | policy reference is structurally usable | `policyRefInvalid` |
| 0 | evidence reference is well formed | `evidenceRefInvalid` |
| 0 | evidence belongs to **this** order | `evidenceResourceMismatch` |
| 1 | custody exists | `custodyNotInitialised` |
| 1 | a rider assignment record exists | `noAcceptedRiderAssignment` |
| 2 | every aggregate validates | `aggregateInconsistent` |
| 3 | every aggregate names the canonical order | `resourceBindingMismatch` |
| 4 | four compare-and-set revision checks | `…RevisionConflict` |
| 5 | assessor is a system worker | `assessorNotSystemWorker` |
| 5 | assessor principal id is a valid opaque id | `assessorPrincipalIdInvalid` |
| 5 | `assessedAtUtc` is UTC | `assessedAtNotUtc` |
| 6 | order is `in_delivery` | `orderNotInDelivery` |
| 6 | reservation is `committed` | `reservationNotCommitted` |
| 6 | custody is held by a **rider** | `custodyNotWithRider` |
| 7 | rider attempt is `accepted` | `noAcceptedRiderAssignment` |
| 7 | accepted rider matches the request | `notCurrentAcceptedRider` |
| 7 | assignment id matches | `assignmentIdMismatch` |
| 7 | generation matches | `generationMismatch` |
| 7 | custody is bound to that very attempt | `custodyHolderBindingMismatch` |
| 8 | `assessmentId` is a valid opaque id | `assessmentIdInvalid` |
| 8 | `assessmentId` is not the current one | `assessmentIdReuse` |

**This is context integrity, not authentication.** Possession is never an
authorization source: custody with the right rider makes the *delivery*
assessable, it does not make the rider an assessor.

The D1 validators are the **single source** of structural judgement — nothing is
reimplemented. `DeliveryProofAssessmentOutcome.structuralDenial` carries the
exact `DeliveryProofDenial` so a log does not have to guess whether a policy
reference was blank or over-long.

## 6. Revisions and compare-and-set

The assessment aggregate has **its own** `assessmentRevision`, deliberately
independent of the order revision, the custody revision and the rider
`slotRevision`. Four aggregates change at different rates; one shared counter
would make every unrelated write look like a conflict and a genuine conflict
undetectable.

```text
no assessment        -> assessmentRevision == 0
first assessment     -> 0 -> 1
each reassessment    -> r -> r + 1
```

Because the decision *depends* on the surrounding read-set, the request must
pin all four:

```text
expectedAssessmentRevision
expectedOrderRevision
expectedCustodyRevision
expectedRiderSlotRevision
```

**Correct revisions never bypass identity, state, reference or binding checks.**
They run in addition, not instead — a test pins exactly that by supplying every
correct revision alongside the wrong rider.

## 7. Reassessment is append-only

A reassessment creates a **new opaque `assessmentId`**, the **next revision**,
and a **new immutable record**. The previous record is not mutated, not erased
and not relabelled; the new record points back at it through
`supersedesAssessmentId`.

These do not exist and must never be added:

```text
setAssessmentStatus(...)   changeSatisfiedTo(...)
overrideVerdict(...)       patchAssessment(...)
```

The aggregate carries only the **current** record — no in-memory history array,
because an unbounded list on an aggregate loaded per request is a memory and
payload hazard. Bounded, paginated, append-only retention is the backend's
(**DPA12**), and historical id uniqueness is a **storage** guarantee a pure type
cannot make (**DPA11**). Both NOT RUN.

## 8. Effects — all NONE, structurally

| Effect | Value |
|---|---|
| Order | **NONE** — `changesOrderState == false` |
| Reservation | **NONE** |
| Inventory | **NONE** — `InventoryEffect.none()`, `availableStockDelta == 0` |
| Financial | **NONE** — `FinancialClassification.noneInThisSlice` |
| Custody | **NONE** — `changesCustody == false` |
| Assignment | **NONE** — `changesRiderAssignment == false` |
| Scope projection | **NONE** — `ScopeProjectionEffect.none()` |

`DeliveryProofAssessmentTransition` has **no order, custody or assignment effect
field**, so a transition that moves one cannot be constructed. That is a stronger
statement than a runtime check.

A `satisfied` verdict therefore does **not** move `in_delivery → delivered`,
move rider custody to the customer, complete the rider assignment, restore
inventory, settle COD, or open or close a dispute.

> **The financial classification describes the *recording*.** Writing a verdict
> posts nothing and never will. Whether a `notSatisfied` outcome eventually has
> a financial consequence is **UNKNOWN and deferred to FND-003C**, blocked on
> owner decision **O6**. It must never be read as zero.

## 9. The event

One event id: **`delivery.proof_assessed`**.

It reports that a trusted assessment record was created. It does **not** mean
delivery succeeded, the customer accepted, a dispute resolved, or money settled.

Payloads carry routing and identity only — resource id, assessment revision,
assessment id, server UTC. **Never** raw proof, policy contents, photographs,
signatures, OTP or QR material, GPS or location, address, phone number, order
contents, money, storage paths or signed URLs. Authorized clients re-read
protected state; a notification is a **hint, never proof or authority**.

Whether the verdict itself belongs in the payload is deliberately **not decided
here** — a routing id is always sufficient.

## 10. Server time

`assessedAtUtc` must be UTC. It is supplied by trusted server execution — never
a client clock, a mobile clock, a notification timestamp or a device timezone.

**No expiry, TTL, duration, maximum age or retry interval is derived from it,
and none is invented.** A test proves this by accepting both a year-2000 and a
year-2099 timestamp: the contract checks that the value is UTC and nothing more.
A proof policy that wants a validity window has to define one.

A pure Dart UTC value **cannot prove it came from a server**. That it is
authoritative is criterion **DPA13**, NOT RUN.

## 11. Trust boundary — read this before consuming an assessment

Any client can construct a `DeliveryProofAssessmentRecord` that says
`satisfied`, and a test asserts such a forgery **is** structurally well formed,
because it is. The type carries no signature, no attestation and no provenance,
and **cannot authenticate its own origin**.

Therefore:

- clients may construct equivalent Dart data locally;
- **the backend must ignore client-supplied assessment records**;
- only an assessment **loaded from trusted backend state** may later authorize
  progression;
- backend provenance remains **future acceptance evidence**, not something this
  contract establishes.

## 12. What a later delivery transition must do

**FND-003D2A does not implement it.** When it is built, a successful-delivery
transition may consume **only** a current trusted `satisfied` assessment whose

```text
resourceId · policyRef · evidenceRef · riderPrincipalId
riderAssignmentId · riderAssignmentGeneration
assessmentId · assessmentRevision
```

are still the exact authoritative values required by that transaction,
revalidated **inside** it (**DPA15**). A missing, malformed, superseded or
`notSatisfied` assessment **cannot** be treated as successful proof
(**DPA16**), and the fallback is FND-003D2B — never an automatic cancellation
or financial result.

## 13. Deliberately deferred — never defaulted

| Decision | Status | Owner |
|---|---|---|
| Proof mechanism (OTP/QR/signature/photo/GPS/biometric/attestation) | **DEFERRED** — none selected, named or implied | proof-policy slice |
| What a policy actually requires | **DEFERRED** | proof-policy slice |
| Evidence cardinality and internal material | **DEFERRED** — one D1 handle, no count | storage/policy design |
| Evidence retention, visibility, deletion, legal hold | **DEFERRED** (unchanged from D1) | privacy/retention slice |
| **Customer participation requirement** | **POLICY-DEFINED / DEFERRED** — not optional, not mandatory, not sufficient, not a veto | proof-policy slice |
| Fallback dispute workflow | **NOT STARTED** | **FND-003D2B** |
| Delivery attempts, refusal, returns | **NOT STARTED** | **FND-003B3B** |
| Any money at all | **UNKNOWN / DEFERRED** | **FND-003C**, blocked on **O6** |
| Manual/admin assessment override | **NOT INVENTED** — separate audited workflow if ever needed | future ADR |

`customer.delivery.confirm_proof` keeps its exact accepted meaning:
**participation only**, settling no cash and closing no dispute. No
`customerConfirmed` flag was added — a default `false` would silently choose the
answer.

## 14. Backend acceptance checklist — DPA1–DPA16

**Every item is NOT RUN.** No backend, no persistence, no Firebase project and
no emulator exists. Contract tests in `packages/contracts` are **not** evidence
that any of this is implemented.

| # | Requirement | Status |
|---|---|---|
| **DPA1** | The backend constructs the assessment context from trusted current records; a client cannot supply authoritative context. | **NOT RUN** |
| **DPA2** | Only trusted server/system authority may create a normal assessment; human clients cannot self-declare satisfaction. | **NOT RUN** |
| **DPA3** | The authoritative current policy reference is resolved server-side and matches the stored assessment exactly. | **NOT RUN** |
| **DPA4** | The protected evidence reference is loaded from trusted state and belongs to the same resource. | **NOT RUN** |
| **DPA5** | Order, committed reservation, rider custody and accepted rider assignment are loaded for one canonical resource in one consistent read-set. | **NOT RUN** |
| **DPA6** | Rider principal, assignment id and generation match between custody, assignment and the assessment binding. | **NOT RUN** |
| **DPA7** | Assessment, order, custody and rider revisions are revalidated **inside** the transaction. | **NOT RUN** |
| **DPA8** | Concurrent assessments from one expected assessment revision commit at most one next revision. | **NOT RUN** |
| **DPA9** | Stale or reordered assessment operations write nothing. | **NOT RUN** |
| **DPA10** | An exact retry returns one stored result without applying the assessment twice; changed content under the same dedupe identity rejects. | **NOT RUN** |
| **DPA11** | Assessment ids are server-generated create-if-absent; historical ids cannot be reused or overwritten. | **NOT RUN** |
| **DPA12** | Reassessment appends immutable history; it never rewrites the previous record. | **NOT RUN** |
| **DPA13** | `assessedAtUtc` comes from authoritative server time; no client timestamp is commercial truth. | **NOT RUN** |
| **DPA14** | The assessment record, current pointer/projection, dedupe result and outbox event commit atomically; raw evidence never enters the event or push. | **NOT RUN** |
| **DPA15** | A later delivery transaction revalidates and consumes the exact current trusted `satisfied` assessment atomically with order, custody, rider assignment, dedupe and outbox. **D2A contract tests are not evidence this persistence exists.** | **NOT RUN** |
| **DPA16** | A missing, malformed, superseded or `notSatisfied` assessment cannot be treated as successful delivery; fallback handling is D2B, not an automatic cancellation or financial result. | **NOT RUN** |

Earlier series are **unchanged** by this slice: **CA1–CA23**, **R33–R40**,
**L1–L13**, **P1–P17** and **RA1–RA18** all remain **NOT RUN**. **B3-C1** stays
satisfied by contract tests **for the picker only** — not persistence evidence.
**B3-C2** stays **NOT RUN / FUTURE**.

## 15. Related

- [delivery-proof-boundary.md](delivery-proof-boundary.md) — the D1 references
- [custody-lifecycle.md](custody-lifecycle.md) — the dispatch boundary this consumes
- [rider-assignment-lifecycle.md](rider-assignment-lifecycle.md) — the attempt binding
- [privacy-and-security-boundaries.md](privacy-and-security-boundaries.md)
- [ADR-0009](../decisions/ADR-0009-trusted-immutable-proof-assessment.md)
- [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md)
- `CONSTRAINTS.md` invariants 11 and 13
