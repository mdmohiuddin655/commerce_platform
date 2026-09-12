# Delivery-proof assessment

**Contract version 0.8** (FND-003D2A, corrected in place by
**FND-003D2A-FIX-001**). Source of truth: the module behind the stable barrel
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

> **This table is the state *after 0.8*, not the state today.** FND-003B3B
> (0.10) later added the delivery-attempt and return commands and one
> permission, taking `Permission.values` to **39**. `OrderState.delivered`,
> `CustodyHolderKind.customer` and rider `completed` are **still** unreachable.

A test sweeps every command type across `LifecycleCommand`,
`AssignmentCommand`, `CustodyCommand` and — since FND-003D2B widened it —
`DeliveryProofDisputeCommand`, and asserts nothing containing `proof`,
`assess`, `deliver`, `refus`, `return`, `attempt` or `dispute` exists, with the
three FND-003D2B dispute commands pinned **by name** so a new one still fails.
**No assessment command exists in any vocabulary**, and no dispute command
asserts, overrides or re-runs an assessment.

## 2. The verdict vocabulary is two values

```dart
enum DeliveryProofAssessmentVerdict { satisfied, notSatisfied }
```

Wire ids are `satisfied` and `not_satisfied`. `Enum.index` is never serialized.

**Absence means "not assessed".** `DeliveryProofAssessmentFacts.absent` is
revision `0` with no record, following the repository's existing convention that
revision 0 means "never written". `canonicalVerdict` returns `null` there, and
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
| `DeliveryProofAssessmentContext` | canonical resource + **server-resolved** policy reference, evidence reference and authorized verifier identity |
| `DeliveryProofAssessmentRequest` | what a trusted verifier reports, plus the expected revisions |
| `DeliveryProofAssessmentTransition` | the record to append, and every effect as NONE |
| `DeliveryProofAssessmentOutcome` | allow or deny, with the exact D1 structural reason when relevant |
| `DeliveryProofAssessmentDenial` | 24 refusal reasons — internal, never returned verbatim |
| `DeliveryProofAssessmentEventType` | one event id |
| `executableProofAssessorKinds` | `{PrincipalKind.systemWorker}` |
| `validateDeliveryProofAssessmentAggregate` | canonical stored shape |
| `canonicalVerdict` | trusted verdict access, canonical aggregates only |
| `evaluateDeliveryProofAssessment` | the pure evaluator |

### Module layout

*(FND-003D2A-FIX-001.)* The implementation is split by responsibility behind a
**stable barrel**, so `cp_contracts.dart` and every consumer keep one import
path:

| File | Responsibility |
|---|---|
| `…_verdict.dart` | the two-value verdict vocabulary |
| `…_record.dart` | one immutable assessment result |
| `…_facts.dart` | the aggregate as loaded from storage |
| `…_denial.dart` | refusal vocabulary |
| `…_authority.dart` | trusted assessor kinds, server-resolved context, request |
| `…_transition.dart` | the permitted transition and its outcome |
| `…_validation.dart` | canonical aggregate shape and trusted verdict access |
| `…_evaluator.dart` | the pure evaluator |
| `…_event.dart` | the single assessment event id |

The graph is **acyclic** and flows one way: vocabulary → model → shapes →
validation → evaluator. **No validation rule is duplicated** — identifier rules
come from `ids.dart`, proof and evidence rules from `delivery_proof.dart`, and
the order, custody and rider aggregate rules from their own canonical
validators. No file imports an app or the backend.

### Why policy, evidence *and the authorized verifier* live on the context

A verifier reports a verdict. It does **not** get to choose which policy it was
judged against, which evidence it judged, **or whether it was the verifier**.
All three are resolved server-side from trusted state and handed in as context —
criteria **DPA3**, **DPA4** and **DPA17**. The request has no policy, evidence
or assessor field at all.

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
assessedByPrincipalId        // the EXACT authorized proof verifier
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
| 5 | assessor is a system worker **at all** | `assessorNotSystemWorker` |
| 5 | the context's authorized verifier id is a valid opaque id | `assessorPrincipalIdInvalid` |
| 5 | assessor **is the authorized verifier**, exactly | `assessorAuthorityMismatch` |
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

## 5a. Assessor authority — kind is necessary, not sufficient

*(FND-003D2A-FIX-001.)* The evaluator takes the server-derived assessor as a
**separate `Principal` argument**, never as request content:

```dart
evaluateDeliveryProofAssessment(
  request: ...,          // what the verifier concluded
  assessor: principal,   // WHO it is — derived from verified service auth
  context: ...,          // WHO IS ALLOWED to be it, for this resource
  ...
)
```

Two independent conditions must both hold:

1. `assessor.kind` is in `executableProofAssessorKinds` — i.e.
   `PrincipalKind.systemWorker`. A human client fails
   `assessorNotSystemWorker`.
2. `assessor.id` **exactly equals**
   `context.authorizedAssessorPrincipalId`. Any other trusted worker fails
   `assessorAuthorityMismatch`.

The second condition is the point. `systemWorker` is a **broad infrastructure
class**: the outbox drain, reservation expiry and scheduled reconciliation all
hold it, and each is a legitimate trusted process. Accepting the kind alone
would have let any of them mint the verdict that later gates delivery. Tests
pin three such workers being refused.

The two denials stay **distinct** — "not a server process" and "the wrong server
process" are different failures, and a log should not have to guess which
occurred. A malformed authorized id fails `assessorPrincipalIdInvalid` rather
than silently falling back to the kind check.

The identity written onto the record is derived from the verified principal
*after* it matches, so `assessedByPrincipalId` names exactly which verifier
reached the verdict — the audit identity a superseding reassessment needs.

> **Still no runtime provenance.** Any client can construct the authorized
> verifier `Principal` and an identical `satisfied` record locally; a test
> asserts the forgery is structurally perfect, **because it is**. This contract
> establishes the *claimed* authority shape. That the claim is true is
> **DPA2** and **DPA17**, both NOT RUN.

## 5b. Fail-closed public accessors

Two convenience members failed **open** before FND-003D2A-FIX-001. Both now
require canonical inputs:

| Member | Rule |
|---|---|
| `DeliveryProofAssessmentRecord.bindsRiderAttempt` | requires a well-formed record, valid opaque `principalId` and `assignmentId`, `generation >= 1`, then exact equality on all three. Identically-malformed values can no longer match their way to `true`. |
| `canonicalVerdict` | returns a verdict **only** when `validateDeliveryProofAssessmentAggregate` accepts the facts. |

`DeliveryProofAssessmentFacts` deliberately exposes **no verdict getter of its
own**; `hasCurrentRecord` is a structural fact about the loaded aggregate and
explicitly not a trust claim.

| Aggregate | `canonicalVerdict` |
|---|---|
| canonical, absent | `null` — *not assessed* |
| canonical, satisfied | `satisfied` |
| canonical, notSatisfied | `notSatisfied` |
| torn or malformed, carrying `satisfied` | `null` |

**Corruption is never converted into `notSatisfied`.** A broken aggregate is a
denial and a reconciliation case, not a negative proof result; downgrading it
would fabricate a verdict nobody reached. `null` therefore means *no usable
verdict*, which a caller must not read as "the policy was not satisfied" either.

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

**It is structural, not supplied.** *(FND-003D2A-FIX-001.)*
`DeliveryProofAssessmentTransition` takes only the record;
`events` is a fixed getter returning a `const` — and therefore deeply immutable
— single-element list. There is no constructor parameter through which a caller
could pass an extra, missing or fabricated event id such as
`delivery.proof_satisfied`, and `events.add(...)` throws `UnsupportedError`.

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

## 10a. Debug and log renderings are fail safe

*(FND-003D2A-FIX-001, applying the FND-003D1 lesson consistently.)* The public
constructors intentionally permit malformed objects — that is what lets the
validators be tested — so a `toString` that echoed raw fields would be a
log-injection and amplification surface reachable **before** validation.

| Value | Well formed | Malformed |
|---|---|---|
| `DeliveryProofAssessmentRecord` | bounded canonical ids + verdict | `DeliveryProofAssessmentRecord(invalid)` |
| `DeliveryProofAssessmentContext` | bounded canonical ids | `DeliveryProofAssessmentContext(invalid)` |
| `DeliveryProofAssessmentTransition` | verdict, revision, ids | `DeliveryProofAssessmentTransition(invalid)` |
| `DeliveryProofAssessmentOutcome` | delegates to the above | delegates — cannot reintroduce a raw field |

**One bad field suppresses the whole rendering**, including the fields that
happen to be sound: until validation passes, all of them are untrusted strings.
The policy reference renders through its own non-disclosing `toString` and the
evidence reference through its own fail-safe one, so neither leaks here what it
refuses to leak there. Denials render enum names only.

Nothing is thrown, trimmed, normalised, repaired or hashed into a business
identity. Tests drive hostile inputs — newline and tab, a URL, a filesystem
path, a fake secret marker and an oversized string — and assert no fragment
survives in any rendering, plus a guard that every hostile fixture really is a
malformed id (one originally was not, and was caught this way).

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

> **Delivered at 0.9, and it still resolves nothing.**
> [FND-003D2B](delivery-proof-dispute.md) defines that fallback: a
> customer-raised dispute bound to an **immutable basis** naming exactly which
> assessment situation was contested, with a standing calculation that reports
> **supersession without rewriting history**. It changes nothing above — no
> verdict meaning, no assessment field, no assessor rule — and it decides **no
> outcome, fault, fee, refund, compensation, liability, return or delivery
> consequence**. A torn assessment is still never a negative result: it is
> refused as corruption rather than becoming a dispute basis.

## 13. Deliberately deferred — never defaulted

| Decision | Status | Owner |
|---|---|---|
| Proof mechanism (OTP/QR/signature/photo/GPS/biometric/attestation) | **POLICY DECIDED** 2026-09-12 — [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) selects a server-issued, single-use, resource-bound confirmation challenge. **None is selected, named or implied *in this contract***: no type, field, enum or event represents one, and the source sweep is unchanged | decided; **executable form DEFERRED** to the implementing slice |
| What a policy actually requires | **DECIDED** 2026-09-12 — [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md): a live, bound challenge fulfilled by the customer side and **verified server-side**, fail-closed. Photo, GPS, timestamp, unbound signature, rider assertion, cash collection, non-response, attempt completion and custody possession are each **insufficient alone** | ADR-0012; **implementation DEFERRED** |
| Evidence cardinality and internal material | **DEFERRED** — one D1 handle, no count | storage/policy design |
| Evidence retention, visibility, deletion, legal hold | **DEFERRED** (unchanged from D1) | privacy/retention slice |
| **Customer participation requirement** | **DECIDED** 2026-09-12 — [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md): **MANDATORY and NOT SUFFICIENT**, and not a veto that ends the order. **No `customerConfirmed` flag was added, and none exists** — the requirement binds the implementing slice, not this contract. **No administrative act may supply the customer's part** — an ADMIN exception review records and audits an unresolved case and **cannot conclude satisfaction** ([ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) Decision 9) | ADR-0012; **implementation DEFERRED** |
| Fallback dispute workflow | **DONE** (0.9) — see [delivery-proof-dispute.md](delivery-proof-dispute.md) | **FND-003D2B** |
| **How a dispute resolves** | **DEFERRED** — enumerated and refused, never guessed | resolution slice, **O6**, FND-003C |
| Delivery attempts, refusal, returns | **DONE** (0.10) — the non-success path only; see [delivery-attempt-return-lifecycle.md](delivery-attempt-return-lifecycle.md). Successful delivery is still **not** executable | **FND-003B3B** |
| Any money at all | **UNKNOWN / DEFERRED** | **FND-003C** — **O6 resolved** (ADR-0011); the remaining money lifecycle work is unimplemented |
| Manual/admin assessment override | **STILL NOT INVENTED** — none exists, and none was added. [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) now sets the boundary for one: an exception review must be separately authorized, reason- and reference-bearing, audited, bound to the same resource and attempt, append-only, and **distinguishable afterwards** — never a silent waiver. It **does not create the workflow, and no permission for it exists**. Its authority is bounded to **recording, classifying and auditing** an unresolved case: it **cannot mark proof satisfied, cannot mark an order delivered, cannot waive the proof requirement, cannot assign customer fault, cannot create a fee and cannot resolve a dispute**, and it may not substitute a photograph, GPS fix, signature, rider statement, cash collection or administrator judgement for a customer-side act. Any future policy allowing satisfaction **without** a customer-side act requires a **superseding ADR and contract migration, accepted before implementation** | future bounded slice, under ADR-0012 |
| **Governing policy version missing / unknown / unresolvable / unsupported / unverifiable** | **FAILS CLOSED — no satisfaction** ([ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md) Decision 11). **No default policy is inferred**: no built-in fallback, and no silent substitution of the latest or a previous version — an order keeps the version it was quoted under | ADR-0012; **implementation DEFERRED** |

`customer.delivery.confirm_proof` keeps its exact accepted meaning:
**participation only**, settling no cash and closing no dispute. No
`customerConfirmed` flag was added — a default `false` would silently choose the
answer.

## 14. Backend acceptance checklist — DPA1–DPA18

**Every item is NOT RUN.** No backend, no persistence, no Firebase project and
no emulator exists. Contract tests in `packages/contracts` are **not** evidence
that any of this is implemented.

| # | Requirement | Status |
|---|---|---|
| **DPA1** | The backend constructs the assessment context from trusted current records; a client cannot supply authoritative context. | **NOT RUN** |
| **DPA2** | Only trusted server/system authority may create a normal assessment; human clients cannot self-declare satisfaction. **Strengthened by DPA17: server authority alone is not enough.** | **NOT RUN** |
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
| **DPA17** | *(FND-003D2A-FIX-001.)* The backend **authenticates the invoking internal service principal** and permits a normal assessment only for an **explicitly authorized proof-verifier service identity or capability** for the applicable resource and policy. Holding `PrincipalKind.systemWorker` is **not** sufficient: outbox, reservation-expiry, reconciliation and every other internal worker identity **fail closed** unless explicitly authorized as proof verifiers. The Dart fixtures that name an authorized verifier are test infrastructure and are **not** evidence that any such allow-list exists. | **NOT RUN** |
| **DPA18** | *(FND-003D2A-FIX-001.)* A **verdict-changing reassessment preserves an immutable audit basis** sufficient to explain the supersession: the backend retains the exact policy and evidence snapshot — or an equivalent immutable assessment-basis reference — associated with **both** assessments, and **never mutates evidence behind a historical assessment in place**. Without it, an unexplained same-basis verdict flip would behave like an undocumented override. This defines **no** dispute outcome, winner, refund, liability, fee or manual-override workflow. | **NOT RUN** |

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
