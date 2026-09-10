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
`cp_contracts` still has no serialization.

## Behaviour across versions

| Situation | Version policy | Payload compatibility |
|---|---|---|
| 0.4 reader, 0.3 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.3 reader, 0.4 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.3 had no assignment types at all. |
| 0.3 reader, 0.2 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.2 reader, 0.3 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.2 had no lifecycle types at all. |
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
- 0.2 through 0.7 are purely additive, so no stored value changes shape or
  meaning. The 0.5 move of `AssignmentDenial` and
  `reachableSlotRevisionRange` into `assignment_integrity.dart` changed no
  name, no value and no behaviour, and neither has a wire form — but that is
  offered as a statement about the source, **not** as decode evidence.

**Rollback:** reverting the FND-003D1 commit returns the contract to 0.6,
reverting the FND-003B3A chain to 0.5,
reverting the FND-003B2B chain to 0.4,
reverting the FND-003B2A chain to 0.3,
reverting the FND-003B1 chain to 0.2, and the FND-003A chain to 0.1 — all with
no data implications, because no data was ever written under any of them.

The first version needing a real migration plan will be the one shipped to a
real client against a real database. That plan belongs to the task that ships
it, not to this one.
