# ADR-0009 — Delivery-proof assessment is trusted, immutable and append-only

- **Status:** Accepted; **amended by FND-003D2A-FIX-001** (2026-09-10)
- **Date:** 2026-09-10
- **Task:** FND-003D2A, amended by FND-003D2A-FIX-001
- **Contract:** 0.7 → 0.8 (additive)
- **Supersedes:** nothing. **Extends:**
  [ADR-0008](ADR-0008-bounded-delivery-proof-policy-reference.md)

## Context

FND-003D1 gave the platform a way to *refer to* a delivery-proof policy and to
protected evidence, and was deliberate that a reference is not a result:

```text
reference != proof
structural validation != authorization
structural validation != satisfaction
```

Something still has to state **whether the referenced policy was satisfied**,
because `CONSTRAINTS.md` invariant 13 requires customer proof and the fallback
dispute workflow to be defined *before* delivery confirmation is coded, and a
delivery transaction has nothing to consume until such a result exists.

Writing that result down forces four decisions that are easy to make badly and
expensive to reverse, because each one would be baked into stored history:

1. **Who may say "satisfied"?**
2. **What happens when a verdict changes?**
3. **What does "no verdict yet" mean?**
4. **How much does stating a verdict decide?**

The tempting answers are all wrong in the same direction — they make the most
valuable status in the system cheap to assert and easy to overwrite.

## Decision

### 1. A normal assessment is produced only by the *authorized proof verifier*

**Amended by FND-003D2A-FIX-001.** The original decision required the assessor's
`PrincipalKind` to be in `executableProofAssessorKinds` — exactly
`PrincipalKind.systemWorker` — and stopped there. Review found that
insufficient, and it was: `systemWorker` is a **broad infrastructure class**
shared by the outbox drain, reservation expiry, scheduled reconciliation and
every other trusted job. Requiring only the kind would have let any of them mint
the verdict that later gates delivery, custody handover and eventually money.

Two conditions are now required, and neither is sufficient alone:

1. `assessor.kind` is in `executableProofAssessorKinds`; otherwise
   `assessorNotSystemWorker`.
2. `assessor.id` **exactly equals** the resource's
   `context.authorizedAssessorPrincipalId`, resolved from trusted backend
   policy and routing state; otherwise `assessorAuthorityMismatch`.

The assessor arrives as a **separate server-derived `Principal` argument**, and
the request's `assessedByPrincipalId` / `assessedByKind` fields were **removed**
rather than kept for source compatibility — a payload field that names the
authority checking it is not a check. 0.8 is unreleased and has no
serialization, so nothing outside the package depended on the old shape.

A stored record naming a non-worker kind remains `aggregateInconsistent` —
validating its shape would legitimise it. Whether the stored principal was the
*authorized* verifier is a question about backend policy state that a pure
aggregate cannot answer after the fact; that is **DPA17**.

**No command and no permission was added.** There is no `CustodyCommand`-style
enum entry, and `Permission.values` stays at 38. In particular these do not
exist and must not be created:

```text
customer.proof.accept
rider.proof.mark_satisfied
admin.proof.override
any generic proof-status setter
```

A client-selectable "declare proof satisfied" operation would be exactly the
arbitrary status patch `ProhibitedCapability` forbids, aimed at the one status
that gates delivery, custody handover and eventually money.

The precedent already exists: `initialiseCustodyAtShop` has no command either,
because custody at the shop is not something a caller asserts. A proof verdict
is the same kind of fact — the output of a trusted evaluator, not a claim.

> **A Dart object is not runtime trust.** Any client can construct a
> `DeliveryProofAssessmentRecord` that says `satisfied`, and a test asserts that
> such a forgery is structurally well formed — because it is. The type carries
> no signature, no attestation and no provenance, and **cannot authenticate its
> own origin**. The same is true of the verifier `Principal` itself: a client
> can construct the authorized identity locally, and a test asserts that forgery
> is structurally perfect **because it is**. The backend must ignore
> client-supplied records and treat only records loaded from trusted state as
> authoritative. That is criteria **DPA1**, **DPA2** and **DPA17**, all
> **NOT RUN**.

### 2. Reassessment is append-only, never an overwrite

There is no `setAssessmentStatus`, `changeSatisfiedTo`, `overrideVerdict`,
`patchAssessment` or `copyWith`. A reassessment produces a **new record** with:

- a **new opaque `assessmentId`** — reusing the current one is denied
  `assessmentIdReuse`;
- the **next `assessmentRevision`** — `r → r + 1`;
- a `supersedesAssessmentId` **backward pointer** into history.

The previous record is not mutated, relabelled or erased.

The reason is dispute, not tidiness. FND-003D2B must be able to say "the
assessment that was current when X happened" and have that mean something. If a
verdict could be overwritten, a contested `satisfied` would become unfindable
the moment anyone reassessed, and the audit trail would show only the last
opinion — which is not an audit trail.

Historical id uniqueness across records that are no longer current is a
**storage guarantee** a pure type cannot make: criterion **DPA11**, NOT RUN.
The aggregate deliberately carries only the *current* record — an unbounded
in-memory history array on an aggregate loaded per request is a memory and
payload hazard. Bounded, paginated, append-only retention is **DPA12**, NOT RUN.

### 3. Absence is "not assessed" — there is no `pending` state

The verdict vocabulary is exactly two values:

```text
satisfied
notSatisfied
```

Canonical absence is `DeliveryProofAssessmentFacts.absent` — revision `0`, no
record — following the repository's existing convention that revision 0 means
"never written".

`pending` was rejected because absence already says it, and two ways to say the
same thing drift apart. A queue that has not run yet is **backend operational
state**, not a commerce-domain verdict; putting job scheduling in the wire
contract would make every client reason about the verifier's infrastructure.

`expired`, `approvedByCustomer`, `disputed`, `overridden` and `delivered` were
rejected for a stronger reason: each decides something no slice has decided — a
validity window, whether customer participation suffices, how a dispute
resolves, who may override a verifier, and whether an order was delivered.

`notSatisfied` means **only** that the trusted verifier concluded the referenced
policy was not satisfied by the referenced evidence. It is not fraud, refusal,
cancellation, delivery failure, a lost dispute, fee liability, a refund or
financial default.

### 4. Proof mechanism and customer participation remain separate decisions

An assessment says a policy evaluator reached a verdict. It does **not** reveal
what produced the evidence. No OTP, QR, barcode, signature, photograph, video,
GPS, biometric or device attestation is named, required or implied, and the
evidence handle stays the single D1 `DeliveryEvidenceRef` — **no artifact count
and no bundle shape is invented**.

`customer.delivery.confirm_proof` keeps its exact accepted meaning:
participation only, settling no cash and closing no dispute. Whether customer
participation is **optional, mandatory, sufficient or a veto** is recorded
**POLICY-DEFINED / DEFERRED**. No `customerConfirmed` flag was added, precisely
because a default `false` would silently choose the answer.

## Consequences

**A satisfied assessment delivers nothing.** Every effect is NONE —
order, reservation, inventory, financial, custody and assignment — and that is
structural: `DeliveryProofAssessmentTransition` has no order, custody or
assignment effect field, so a transition that moves one cannot be constructed.
`OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable, and **no revision cost for
rider completion was invented** — criterion **B3-C2** stays FUTURE.

**A later delivery transaction is the only thing that may consume a verdict**,
and only a *current, trusted, `satisfied`* one whose resource, policy reference,
evidence reference, rider principal, rider assignment id, rider generation,
assessment id and assessment revision are all still the authoritative values —
revalidated inside that transaction (**DPA15**, NOT RUN). A missing, malformed,
superseded or `notSatisfied` assessment can never be treated as successful proof
(**DPA16**).

**Financial consequence is UNKNOWN, never zero.** The transition's
`FinancialClassification.noneInThisSlice` classifies the *recording* — writing a
verdict posts nothing. Whether a `notSatisfied` outcome eventually costs anyone
anything belongs to **FND-003C**, blocked on owner decision **O6**, and
`CONSTRAINTS.md` invariant 11 still stands: delivery failure does not
automatically justify a customer fee.

**If manual assessment is ever needed**, it must be a separate audited workflow
with its own permission, scoped authority, a recorded reason, approval or dual
control where policy requires it, and immutable audit history — never an
arbitrary status patch. `executableProofAssessorKinds` is the single place a
later task would have to widen deliberately rather than by accident. **That
workflow is not invented here.**

## Amendment — FND-003D2A-FIX-001

Four further defects in the unreleased 0.8 candidate were corrected in place.
None changes the decisions above; each closes a way the contract failed **open**.

| Defect | Correction |
|---|---|
| Any `systemWorker` could assess | exact authorized-verifier identity required; new `assessorAuthorityMismatch` denial (see §1 above) |
| `bindsRiderAttempt` used raw equality, so identically-malformed values matched | requires a well-formed record, valid opaque arguments and `generation >= 1` before comparing |
| `currentVerdict` read straight off raw facts, so a **torn aggregate could expose `satisfied`** | replaced by `canonicalVerdict`, which returns a verdict only when the aggregate validator accepts the facts. Corruption is **never** downgraded to `notSatisfied` |
| `events` was a caller-supplied list, so a transition could carry arbitrary or fabricated event ids | the constructor takes only the record; `events` is a fixed `const` single-element list |
| `toString` echoed raw fields of malformed values before validation | every public assessment value renders `(invalid)` when malformed; one bad field suppresses the whole rendering |

Each correction carries a negative control: reverting it makes a specific named
test fail. The 980-line module was also split by responsibility behind a stable
barrel, and the contract stays at **0.8** — this is an in-place correction to an
unreleased, unmerged candidate, not a release event.

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| A `pending` verdict | Absence already means it. Two representations of one fact drift; a verifier's job queue is not domain state. |
| A mutable `proofSatisfied` boolean or status setter | Exactly the prohibited status patch, on the highest-value status in the system. It also destroys the history a dispute needs. |
| Letting the customer or rider assert satisfaction | Self-declared proof is not proof. It would make the delivery gate assertable by the parties it exists to adjudicate between. |
| Trusting `PrincipalKind.systemWorker` alone | A broad infrastructure class. It would let the outbox, expiry or reconciliation worker mint the delivery gate. Corrected by FND-003D2A-FIX-001. |
| Keeping the request's assessor fields for compatibility | A payload that names its own authorizer is not an authorization check, and 0.8 is unreleased with no serialization, so there was nothing to stay compatible with. |
| An admin override verdict in this slice | Would need scoped authority, reason capture and approval rules that no slice defines. Deferred to a separate audited workflow. |
| A list of evidence artifacts on the record | Invents a cardinality and leaks storage design. The D1 handle already refers to whatever the protected record holds. |
| Deriving expiry from `assessedAtUtc` | Would invent a validity window — a proof-policy decision. The contract checks only that the value is UTC. |
| Reusing the order, custody or rider `slotRevision` | Four aggregates change at different rates; a shared counter makes unrelated writes look like conflicts and real conflicts undetectable. |

## References

- `packages/contracts/lib/src/delivery_proof_assessment.dart`
- `packages/contracts/test/delivery_proof_assessment_test.dart`
- [delivery-proof-assessment.md](../contracts/delivery-proof-assessment.md)
- [delivery-proof-boundary.md](../contracts/delivery-proof-boundary.md)
- [ADR-0008](ADR-0008-bounded-delivery-proof-policy-reference.md)
- `CONSTRAINTS.md` invariants 11 and 13
