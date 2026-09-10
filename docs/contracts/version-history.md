# Contract version history

`ContractVersion` in `packages/contracts` is the single version marker for the
shared wire contract. `ContractVersion.current` is what a build compiled
against; every command and event envelope carries it.

## Version policy is not a compatibility proof

`ContractVersion` answers **one narrow question**: does the version policy
permit attempting to decode a peer's payload at all?

```dart
bool isVersionCompatibleWith(ContractVersion other) => other.major == major;
bool isSameMajor(ContractVersion other) => other.major == major;
```

- **Same major** → an attempt is permitted.
- **Different major** → refuse, and surface an upgrade prompt rather than
  partially parsing.

A `true` result is **permission to try**. It is *not* evidence that a
particular payload decodes, that a field is understood, or that an unknown
field is safely ignored. Those are properties of a **decoder**, proven by that
decoder's own tests against real encoded payloads.

> The method was called `canRead` until FND-003A-FIX-001. That name read as a
> guarantee that a payload *would* be readable. It never was: the method
> compares two integers and knows nothing about any schema.

**There is no serialization in `cp_contracts` today** — no envelope has a
`toJson` or `fromJson`. So no payload-compatibility claim is made anywhere, and
none could be tested honestly. When serialization lands, its tests must use a
real encoded payload and a real decoder.

**Rule for bumping:** additive, non-meaning-changing definitions bump the
minor. A change in meaning bumps the major.

## Versions

### 0.1 — FND-001

`ContractVersion` itself. No vocabulary, no schemas, no transitions.

### 0.2 — FND-003A (2026-09-09) — additive

Added:

- `CommandEnvelope`, opaque-id rules, structural validation
- `CommandFingerprint`, `StoredCommandRecord`, `evaluateIdempotency`
- `EventEnvelope`
- `Principal`, `PrincipalKind`, `CommerceRole`, `Membership`,
  `MembershipStatus`, `ResourceScope`, `ScopeRequirement`
- `Permission` (35 ids), `PermissionRule`, `permissionMatrix`,
  `ProhibitedCapability`
- `AuthorizationRequest`, `AuthorizationDecision`, `DenyReason`,
  `ApprovalEvidence`, `evaluateAuthorization`

**Why minor, not major.** At the version-policy level the change is additive:
the major is unchanged, nothing defined at 0.1 changed meaning, and every
addition is new surface.

**What is *not* claimed.** 0.1 contained no command envelope, event envelope or
permission decoder, so a 0.1 build has nothing with which to read a 0.2
payload. 0.1 cannot be cited as evidence for decoding types that did not exist
in it. And no 0.1 client was ever released, so the question is theoretical
rather than a deployed compatibility obligation.

### Corrected by FND-003A-FIX-001

0.2 was corrected **in place**, not bumped again. It has never been merged to
`main` or released, so there is no external consumer of the earlier shape.
Corrections: assignment accept/decline now requires a targeted offer as well as
region; `ApprovalEvidence` is bound to requester, permission and resource;
idempotency is partitioned by trusted principal and gated on current
authorization; `canRead` became `isVersionCompatibleWith`.

### 0.3 — FND-003B1 (2026-09-10) — additive

Added the pre-dispatch order and reservation lifecycle:

- `OrderState`, `ReservationState`
- `LifecycleCommand`, `LifecycleEventType`
- `InventoryEffect` / `InventoryEffectKind`, `FinancialClassification`
- `OrderLifecycleFacts`, `LifecycleRequest`, `LifecycleTransition`,
  `LifecycleOutcome`, `LifecycleDenial`
- `evaluateOrderTransition`, `executableCancellationSources`,
  `policyDeferredCancellationSources`

**Why minor, not major.** Additive at the version-policy level: the major is
unchanged, nothing defined at 0.2 changed meaning, and every addition is new
surface. `OrderState.inDelivery` and `OrderState.delivered` are declared but
unreachable, so a later slice can implement them without an enum break.

**What is *not* claimed.** 0.2 contained no lifecycle types at all, so a 0.2
build could not decode a 0.3 lifecycle payload even if one existed. None does:
`cp_contracts` still has no serialization.

### 0.4 — FND-003B2A (2026-09-10) — additive

Added the picker assignment lifecycle:

- `AssignmentState`, `AssignmentRole`
- `AssignmentCommand`, `AssignmentEventType`
- `ScopeProjectionEffect`, `CustodyClassification`, `ReassignmentSafety`
- `PickerAssignmentAttempt`, `PickerEligibility`, `PickerAssignmentFacts`,
  `PickerAssignmentRequest`, `PickerAssignmentTransition`,
  `PickerAssignmentOutcome`, `AssignmentDenial`
- `evaluatePickerAssignment`, `validatePickerAssignmentAggregate`,
  `assignmentEligibleOrderStates`
- one new permission: `agent.assignment.revoke_picker`

**Why minor, not major.** Additive at the version-policy level: the major is
unchanged, nothing defined at 0.3 changed meaning, and every addition is new
surface. `AssignmentState.completed` and `AssignmentRole.rider` are declared
but unreachable, so later slices can implement them without an enum break.

**What is *not* claimed.** 0.3 contained no assignment types at all, so a 0.3
build could not decode a 0.4 assignment payload even if one existed. None does:
`cp_contracts` still has no serialization.

### 0.5 — FND-003B2B (2026-09-10) — additive

Added the rider assignment lifecycle:

- `SourcePickerBinding`, `RiderAssignmentAttempt`, `RiderEligibility`,
  `RiderAssignmentFacts`, `RiderAssignmentRequest`,
  `RiderAssignmentTransition`, `RiderAssignmentOutcome`
- `evaluateRiderAssignment`, `validateRiderAssignmentAggregate`
- five rider commands on the existing `AssignmentCommand` enum, plus an
  `AssignmentCommand.role` field and `AssignmentCommand.forRole`
- five rider ids on `AssignmentEventType`, plus `picker` / `rider` lists
- four cross-aggregate values on `AssignmentDenial`:
  `noAcceptedPickerAssignment`, `notCurrentAcceptedPicker`,
  `sourcePickerAssignmentMismatch`, `pickerAuthorityInconsistent`
- two new permissions: `picker.assignment.offer_rider`,
  `picker.assignment.revoke_rider`
- `AssignmentRole.executableInThisSlice` now holds **both** roles

**Moved, not changed.** `AssignmentDenial` and `reachableSlotRevisionRange`
moved from `picker_assignment.dart` to the new
`assignment_integrity.dart`, so one canonical revision model serves both
evaluators instead of two formulas that can disagree. **Same names, same
values, same behaviour, same export path** — `cp_contracts.dart` re-exports
the new file, so no consumer import changes. A negative control confirmed the
sharing is real: breaking the helper fails the picker *and* rider closure
suites.

**Why minor, not major.** Additive at the version-policy level: the major is
unchanged, nothing defined at 0.4 changed meaning, and every addition is new
surface. `AssignmentState.completed` remains declared but unreachable for both
roles.

**What is *not* claimed.** 0.4 contained no rider assignment types at all, so a
0.4 build could not decode a 0.5 rider payload even if one existed. None does:
`cp_contracts` still has no serialization, so the file move is a statement
about source organisation and **not** payload evidence.

### 0.6 — FND-003B3A (2026-09-10) — additive

Added physical custody and the picker→rider handoff:

- `CustodyHolderKind`, `CustodyHolder`
- `CustodyFacts` (with `CustodyFacts.initialAtShop`), `CustodyRequest`,
  `CustodyTransition`, `CustodyOutcome`, `CustodyDenial`
- `CustodyCommand` (`custody.record_shop_pickup`,
  `custody.record_rider_receipt`), `CustodyEventType`
- `CustodyOrderEffect`, `PickerAssignmentCompletionEffect`
- `validateCustodyAggregate`, `evaluateCustodyTransition`,
  `reassignmentSafetyFor`
- `OrderState.aggregateShapeKnown`, and `in_delivery: {committed}` in
  `canonicalAggregatePairs`
- `AssignmentState.executableForRole`
- `AssignmentEventType.pickerCompleted`, `LifecycleEventType.orderInDelivery`
- an **optional** `role` parameter on `reachableSlotRevisionRange`

**Additive, including the changed signature.** `reachableSlotRevisionRange`
gained an optional named parameter that **defaults to the pre-0.6 answer**, so
every existing call site compiles unchanged and returns exactly what it
returned before — `completed → null` included. A test pins that.

**Why minor, not major.** The major is unchanged and nothing defined at 0.5
changed meaning. Two states became *reachable* — `OrderState.inDelivery` and
picker `AssignmentState.completed` — but both were already declared, and
neither is entered by any command a client may select. Rider `completed` and
`customer` custody remain unreachable, with **no mutation cost or shape
invented** for either.

**What is *not* claimed.** 0.5 contained no custody types at all, so a 0.5
build could not decode a 0.6 custody payload even if one existed. None does:
`cp_contracts` still has no serialization.

**Corrected in place by FND-003B3A-FIX-001**, while 0.6 is still an unmerged,
unreleased candidate — `origin/main` is `bfec4be`, which predates it, no app has
a build and no Firebase project exists, so nothing has consumed 0.6. The
corrections add `CustodyResourceContext`, `initialiseCustodyAtShop` and
`CustodyInitialisationOutcome`; four denial values; `expectedPickerSlotRevision`
and `expectedRiderSlotRevision` on `CustodyRequest`; a required `resource`
argument on `evaluateCustodyTransition`; `OrderState.outsideThisSliceEvaluator`;
and `AssignmentState.notYetImplementedForRole`. `OrderState.notYetImplemented`
narrows to `{delivered}` — a correction of metadata that had become false, not a
removal. **No version bump**: these are edits to an unreleased definition, and a
review finding is not a release event.

### 0.7 — FND-003D1 (2026-09-10) — additive

Added mechanism-neutral delivery-proof **references**:

- `DeliveryProofPolicyRef` — which immutable proof policy applies
- `DeliveryEvidenceRef` — a resource-bound pointer to protected evidence
- `validateDeliveryProofPolicyRef`, `validateDeliveryEvidenceRef`
- `DeliveryProofDenial` — four **structural** values only

**References, never results.** A policy reference does not say the policy was
satisfied; an evidence reference does not say the evidence is authentic, or that
anything was delivered. Neither can move `OrderState` or `CustodyHolder`,
complete an assignment, authorize a caller or create money.

**Why minor, not major.** Additive at the version-policy level: the major is
unchanged, nothing defined at 0.6 changed meaning, and every addition is new
surface. **No command, state, transition, event or permission was added**, and
`OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable.

**No proof mechanism was selected** — no OTP, QR, barcode, signature,
photograph, video, GPS, biometric or attestation — and no grammar was imposed on
the policy reference, because the repository has none to reuse.

**What is *not* claimed.** 0.6 contained no delivery-proof types, so a 0.6 build
could not decode a 0.7 reference even if one were serialized. None is:
`cp_contracts` still has no serialization, and **no payload or unknown-field
compatibility is claimed at any version**.

**Corrected in place by FND-003D1-FIX-001**, while 0.7 was still an unmerged,
unreleased candidate — `origin/main` was `e8dacfc`, which predates it. The
corrections add `maxDeliveryProofPolicyRefLength` (64) and two denial values
(`policyRefTooLong`, `expectedResourceIdInvalid`); stop
`DeliveryProofPolicyRef.toString` reproducing the raw value; make
`DeliveryEvidenceRef.belongsTo` fail closed on malformed references and targets;
and correct the `cp_contracts.dart` header from 0.6 to 0.7. **No version bump** —
these are edits to an unreleased definition, and a review finding is not a
release event. See
[ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md).

**Corrected again by FND-003D1-FIX-002**, still in place and still 0.7: the
policy-reference ceiling now **aliases `maxIdLength`** instead of repeating its
literal, and `DeliveryEvidenceRef.toString` no longer echoes the fields of a
**malformed** instance. Both are hardening of the same unreleased candidate.

**0.7 is now accepted and integrated.** FND-003D1-MERGE-001 fast-forwarded
`main` from `e8dacfc` to **`f03fc99`** on 2026-09-10, preserving the reviewed
three-commit linear history with no merge, squash, rebase or amend. The three
statements above describe the state *at the time each correction was made* and
are retained as history; 0.7 is no longer a candidate. It is still **unreleased**
in the sense that matters for compatibility — no client has ever been built
against it, and no data exists under it.

### 0.8 — FND-003D2A (2026-09-10) — additive

Added the delivery-proof **assessment** — the result of evaluating a policy,
which 0.7 deliberately had no place to record:

- `DeliveryProofAssessmentVerdict` — `satisfied` / `notSatisfied`, and nothing
  else
- `DeliveryProofAssessmentRecord` — one immutable result, binding assessment id,
  resource, revision, policy reference, evidence reference, rider
  principal/assignment/generation, assessor, server UTC and verdict
- `DeliveryProofAssessmentFacts` (with `.absent`), `…Context`, `…Request`,
  `…Transition`, `…Outcome`, `…Denial`
- `validateDeliveryProofAssessmentAggregate`,
  `evaluateDeliveryProofAssessment`
- `executableProofAssessorKinds` — `{PrincipalKind.systemWorker}`
- `DeliveryProofAssessmentEventType.proofAssessed` —
  `delivery.proof_assessed`

**A result, never a delivery.** Every order, reservation, inventory, financial,
custody and assignment effect is **NONE**, and structurally so: the transition
type has no order, custody or assignment effect field, so one that moves them
cannot be constructed. `OrderState.delivered`, `CustodyHolderKind.customer` and
rider `AssignmentState.completed` all remain **unreachable**, and **no revision
cost for rider completion was invented** — **B3-C2** stays FUTURE.

**No command and no permission was added.** `Permission.values` and
`permissionMatrix` stay at **38**. A normal assessment is produced only under
trusted server authority, in the same way `initialiseCustodyAtShop` is — a
client-selectable "declare proof satisfied" operation would be the arbitrary
status patch this contract forbids.

**No proof mechanism was selected** — no OTP, QR, barcode, signature,
photograph, video, GPS, biometric or attestation — and **no evidence cardinality
was invented**: the record carries the single D1 `DeliveryEvidenceRef` and says
nothing about what the protected record behind it holds.

**Absence is "not assessed"**, expressed once as revision 0 with no record.
There is no `pending` verdict, so the two cannot disagree.

**Why minor, not major.** Additive at the version-policy level: the major is
unchanged, **nothing defined at 0.7 changed meaning**, and every addition is new
surface. The D1 reference types, their validators, their bound and their
`toString` behaviour are **byte-for-byte untouched** — the assessment reuses
them and maps their denials rather than reimplementing or widening them.

**What is *not* claimed.** 0.7 contained no assessment types at all, so a 0.7
build could not decode a 0.8 assessment payload even if one were serialized.
None is: `cp_contracts` still has no serialization, and **no payload or
unknown-field compatibility is claimed at any version**.

Three existing tests were updated, all version or coverage pins rather than
behaviour: two `ContractVersion.current` assertions moved from `0.7` to `0.8`,
and the D1 event sweep was widened to include the new event vocabulary and to
pin `delivery.proof_assessed` by name alongside `order.in_delivery`. A guard
that silently stops covering a new surface keeps passing while proving nothing.

See [delivery-proof-assessment.md](delivery-proof-assessment.md) and
[ADR-0009](../decisions/ADR-0009-trusted-immutable-proof-assessment.md).

### 0.9 — FND-003D2B (2026-09-11) — additive

Added the **fallback delivery-proof dispute** workflow — what happens when the
assessment a delivery would need is missing, superseded or `notSatisfied`, which
0.8 deliberately had no place to record:

- `DeliveryProofDisputeState` — `open` / `underReview`, plus a declared but
  **unreachable** `resolved`
- `reachableDisputeRevisionFor` — the exact revision each state may carry;
  **null for `resolved`**, so no resolution cost is invented
- `DeliveryProofDisputeBasisKind` — `notAssessed` / `notSatisfied`
- `DeliveryProofDisputeBasis` — the immutable audit identity of what was
  disputed: an assessment id and revision, and **nothing copied** from the
  assessment
- `DeliveryProofDisputeBasisStanding` and
  `resolveDeliveryProofDisputeBasisStanding` — `current` / `superseded` /
  `indeterminate`
- `DeliveryProofDisputeCommand` — `raise`, `recordReviewStarted`, and a
  deliberately non-executable `resolve`; plus `executableInThisSlice` and
  `policyDeferredInThisSlice`
- `DeliveryProofDisputeEventType` — `delivery.proof_dispute_raised` and
  `delivery.proof_dispute_review_started`
- `DeliveryProofDisputeRecord` (with `.raised` and `.reviewStarted`),
  `…Facts` (with `.absent`), `…Context`, `…Request` (three constructors),
  `…Transition`, `…Outcome`, `…Denial`
- `validateDeliveryProofDisputeAggregate`, `canonicalState`, `canonicalBasis`,
  `evaluateDeliveryProofDispute`

**A record, never a resolution.** Every order, reservation, inventory,
financial, custody, assignment **and assessment** effect is **NONE**, and
structurally so: the transition type has no field for any of them, so one that
moves them cannot be constructed. `OrderState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` all remain
**unreachable**, and **B3-C2** stays FUTURE.

**No permission was added.** `Permission.values` and `permissionMatrix` stay at
**38**. Both executable operations map to the accepted FND-003A rules —
`customer.dispute.raise` (`ownResource`, reason required) and
`admin.dispute.administer` (`ownRegion`, reason required) — unchanged in role,
scope, reason requirement and restriction.
`customer.delivery.confirm_proof` is **not** reinterpreted.

**No outcome was decided.** `DeliveryProofDisputeCommand.resolve` is enumerated
and always refused `resolutionPolicyDeferred` before any fact is read, following
`LifecycleDenial.policyDeferred`'s precedent, because resolving a dispute would
require deciding who prevails, whether the order is delivered, refused or
returned, whether a fee, refund, compensation or liability follows, and whether
customer participation is optional, mandatory, sufficient or a veto — **owner
decision O6, FND-003C and FND-003B3B, none of which has run**.

**The five proof situations stay distinct**: canonical absence, current
`notSatisfied`, a superseded basis, a torn aggregate, and current `satisfied`.
Corruption is **never** laundered into `notSatisfied` and never becomes a
dispute basis.

**Why minor, not major.** Additive at the version-policy level: the major is
unchanged, **nothing defined at 0.8 changed meaning**, and every addition is new
surface. The D1 reference types and the D2A assessment module — their verdicts,
records, validators, evaluator, denials, event and `toString` behaviour — are
**untouched**; the dispute reuses `validateDeliveryProofAssessmentAggregate` and
`canonicalVerdict` rather than reimplementing, widening or mutating anything.

**What is *not* claimed.** 0.8 contained no dispute types at all, so a 0.8 build
could not decode a 0.9 dispute payload even if one were serialized. None is:
`cp_contracts` still has no serialization, and **no payload or unknown-field
compatibility is claimed at any version**.

Four existing test files were updated, all version or coverage pins rather than
behaviour: three `ContractVersion.current` assertions moved from `0.8` to `0.9`
(plus one existing 0.7↔0.8 test re-anchored on literals so it keeps testing that
pair), and the D1 and D2A **command** sweeps plus the D1 **event** sweep were
widened to include the new dispute vocabulary, with all three commands and both
events pinned **by name**. A guard that silently stops covering a new surface
keeps passing while proving nothing.

**Corrected in place by FND-003D2B-FIX-001 — still 0.9.** FND-003D2B-FINAL-
REVIEW-001 found three material defects in the unreleased candidate. All are
corrected in one follow-up commit, and **the contract stays at 0.9**: this is an
in-place correction to an unmerged, unaccepted candidate, not a release event.

| Defect | Correction |
|---|---|
| `resolveDeliveryProofDisputeBasisStanding` reported `current` when the assessment id and revision matched but the **verdict had flipped** — a contradiction ADR-0009's append-only history cannot produce | the same-revision comparison now also requires `canonicalVerdict` to still be `notSatisfied`; a mismatch is `indeterminate`, never `superseded` and never `notSatisfied`, and the basis is not rewritten |
| An invented `reviewerIsRaiser` denial refused an administrator who had earlier raised the dispute, although `admin.dispute.administer` carries `approvalRequired: false` and no accepted contract asks for separation of duties | the rule was removed from the evaluator, the record validator, the denial vocabulary (**20 → 19**), the tests and the documentation. Separation of duties, if ever wanted, needs its own permission and ADR |
| Recording that review started required a canonical current assessment, a canonical current order, the order revision, `in_delivery` and `committed` — none of which it reads — so a reassessment or torn assessment read could **freeze a validly raised dispute out of review** | one evaluator per operation, each taking only its own read-set: `evaluateRaiseDeliveryProofDispute` (resource, dispute, assessment, order), `evaluateRecordDeliveryProofDisputeReview` (resource, dispute) and `evaluateResolveDeliveryProofDispute` (**no arguments at all**) |

**Corrected again by FND-003D2B-FIX-002 — still 0.9.**
FND-003D2B-FINAL-REVIEW-002 found two further defects in the same unreleased
candidate. Both are corrected in one follow-up commit, and **the contract stays
at 0.9**.

| Defect | Correction |
|---|---|
| `resolveDeliveryProofDisputeBasisStanding` reported `superseded` for any higher revision, including one whose current record **reused the basis's assessment id** — impossible history, since ADR-0009 requires a new id for every reassessment, and the aggregate is structurally canonical so no shape check could catch it | a higher revision must also carry a **different** assessment id; reuse answers `indeterminate`. The comparison uses the current record only — no history array, no global uniqueness lookup (**DPA11**, NOT RUN) |
| The executable evaluators took a bare `Principal` and only *documented* that authorization had run, which a pure function cannot assert about its caller — so a **non-owner customer could raise** and a **customer-only principal could review** by calling the evaluator directly | both now require FND-003A's unforgeable `AuthorizationGrant`, verified as bound to this principal, this permission and this resource by `checkDisputeAuthorization`. One generic `authorizationGrantMismatch` denial (19 → **20**); **no policy is re-decided and the matrix is not copied** |

`DeliveryProofDisputeContext` was **removed**: the grant already names the
canonical resource, and two sources of resource truth could disagree. *(That
last clause is superseded by FND-003D2B-FIX-003 below — the anchor moved to the
stored dispute aggregate, which the grant must cover. The type stays removed.)*
The authorization binding lives in its own file behind the stable barrel, so
authorization validation, aggregate validation and transition construction can
be audited independently.

`Permission.values` and `permissionMatrix` remain **38**, unchanged;
`customer.dispute.raise` and `admin.dispute.administer` keep their exact
accepted rules and `approvalRequired: false`; no separation-of-duties rule
returned. Each correction carries a negative control, and the read-set
independence remains enforced by the **type system**.

**Corrected a third time by FND-003D2B-FIX-003 — still 0.9.**
FND-003D2B-FINAL-REVIEW-003 found one material defect, plus documentation drift
left by FIX-002. Both are corrected in one follow-up commit.

| Defect | Correction |
|---|---|
| `evaluateRaiseDeliveryProofDispute` could not structurally prove its `OrderLifecycleFacts` belonged to the same order as the grant, the dispute and the assessment — that accepted type carries **no resource id**, so an order-B read whose scalars matched order A was indistinguishable from A's own facts | a small D2B-scoped `DeliveryProofDisputeOrderRead` binds lifecycle facts to the order they were read for, and the raise requires **grant == dispute == assessment == order read**. The accepted `OrderLifecycleFacts` API is **unchanged** |
| `checkDisputeAuthorization` called `grant.covers(…, resourceId: grant.resourceId)` — the resource half tautological, while documented as proving the resource binding | the helper now takes an `expectedResourceId` supplied from the read-set. The canonical anchor is the **stored dispute aggregate's** resource, and the grant must cover exactly it |

Stale post-FIX-002 wording that still described a "server-resolved context" in
the D2B module — after `DeliveryProofDisputeContext` was deleted — was corrected
in the module barrel, the contract document and the 0.9 source history.
Historical descriptions elsewhere remain, clearly marked as historical.

`DeliveryProofDisputeOrderRead` is a **read, not a second order aggregate**: no
state, no transition, no revision arithmetic, no lifecycle rule, no actor, role,
permission, reason, money or proof material. Binding is not provenance — **DPD3**
and **DPD4** remain **NOT RUN**.

Everything else is unchanged: `Permission.values` **38**, review still reads only
the grant and the dispute, resolve still takes **zero arguments**, every effect
still NONE, and `delivered`, customer custody and rider `completed` still
unreachable. **NC6** proves the new binding can fail, and NC1–NC5 were
re-verified.

**Corrected a fourth time by FND-003D2B-FIX-004 — still 0.9, and
documentation only.** Two current-tense statements still said the authorization
grant supplies the canonical resource, which FIX-003 had already changed: the
anchor is the **stored dispute aggregate's** resource, and the grant proves
*coverage* of it. They were in `docs/contracts/delivery-proof-dispute.md` and
the `delivery_proof_dispute_facts.dart` doc comment, and they contradicted the
shipped code (`final String resourceId = dispute.resourceId;` in both
evaluators). **No executable Dart changed** — the FIX-003 runtime correction is
intact and untouched.

The FND-003D2B-FIX-003 push was **correctly blocked** on exactly this: the push
task gated publication on a documentation check that failed.

The single `evaluateDeliveryProofDispute` and the multi-constructor
`DeliveryProofDisputeRequest` were **replaced**, not deprecated:
`DeliveryProofDisputeRaiseRequest` pins the dispute, assessment and order
revisions, and `DeliveryProofDisputeReviewRequest` pins the dispute revision
alone. 0.9 is an unaccepted, unreleased candidate with **no serialization**, so
the definition was corrected in place rather than keeping misleading fields for
a compatibility nobody could depend on. **No migration is required or invented.**

Each correction carries a negative control: reverting it makes a specific named
test fail, and the read-set independence is enforced by the **type system** — a
call that hands review an assessment or an order does not compile.

Nothing else moved: `Permission.values` stays **38**, resolution stays
non-executable, every effect stays NONE, and `delivered`, customer custody and
rider `completed` stay unreachable.

See [delivery-proof-dispute.md](delivery-proof-dispute.md).

## Behaviour across versions

| Situation | Version policy | Payload compatibility |
|---|---|---|
| 0.4 reader, 0.3 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.3 reader, 0.4 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.3 had no assignment types at all. |
| 0.3 reader, 0.2 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.2 reader, 0.3 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.2 had no lifecycle types at all. |
| 0.8 reader, 0.7 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.7 reader, 0.8 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.7 had no assessment types at all. |
| 0.9 reader, 0.8 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.8 reader, 0.9 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.8 had no dispute types at all. |
| 0.2 reader, 0.1 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.1 reader, 0.2 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.1 had no envelope or permission decoder at all. |
| Either reader, 1.x payload | **Refused** — surfaced as an upgrade prompt, never silently partially parsed | n/a |

The middle column is a statement about two integers. The right-hand column is
the one that would matter to a real client, and it is deliberately empty until
a decoder and its tests exist.

### Unknown identifiers must fail safe

- **Unknown permission id** → `Permission.byId` returns `null`;
  `evaluateAuthorization` **denies**. Fail closed, never open. Tested.
- **Unknown command type** → the server rejects it. A build that does not
  implement a command must not guess.
- **Unknown event type** → a client **may** ignore it, and this is the one
  place ignoring is explicitly allowed: an event is a hint, so a client that
  does not understand a fact simply re-reads server state. It must not crash,
  and it must not infer meaning from the name.
- **Unknown envelope field** → no behaviour is claimed. There is no decoder,
  so "unknown fields are ignored" would be an assertion about code that does
  not exist. The decoder that lands first must specify and test it.

## Migration status

**No migration is required, and none is invented.**

- There are no released clients: no app has a platform folder or a build
  (FND-002A), so nothing in the field reads any version of this contract.
- There is no production data: no Firebase project exists (owner action O5).
- 0.2 through 0.9 are purely additive, so no stored value changes shape or
  meaning. The 0.5 move of `AssignmentDenial` and
  `reachableSlotRevisionRange` into `assignment_integrity.dart` changed no
  name, no value and no behaviour, and neither has a wire form — but that is
  offered as a statement about the source, **not** as decode evidence.

**Rollback:** reverting the FND-003D2B commit returns the contract to 0.8,
reverting the FND-003D2A chain to 0.7,
reverting the FND-003D1 chain to 0.6,
reverting the FND-003B3A chain to 0.5,
reverting the FND-003B2B chain to 0.4,
reverting the FND-003B2A chain to 0.3,
reverting the FND-003B1 chain to 0.2, and the FND-003A chain to 0.1 — all with
no data implications, because no data was ever written under any of them.

The first version needing a real migration plan will be the one shipped to a
real client against a real database. That plan belongs to the task that ships
it, not to this one.
