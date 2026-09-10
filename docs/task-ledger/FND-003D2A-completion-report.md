# FND-003D2A completion report

- **Task:** Mechanism-neutral, trusted-server-produced delivery-proof
  **assessment** contract — the smallest dependency-safe proof prerequisite
  after FND-003D1
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `main` @ `f03fc99c2cca01d5eda8e4b2542cd3a7896c124d`
- **Branch:** `fnd/FND-003D2A-proof-assessment-contract`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.7 → **0.8** (additive)
- **Status:** **DONE**

## 1. Baseline

`origin/main` matched the required SHA exactly, the working tree was **clean
including untracked files**, and `origin` was the expected repository. One new
branch was created with `git switch -c` from the verified base. **No
`git reset --hard`, no rebase, no cherry-pick, no amend.**

```text
git rev-parse origin/main
f03fc99c2cca01d5eda8e4b2542cd3a7896c124d

git status --porcelain --untracked-files=all
(empty)

git remote -v
origin  https://github.com/mdmohiuddin655/commerce_platform.git (fetch/push)
```

The next ADR number was **verified** on disk before use: `ADR-0008` was the
highest, so this task's is **ADR-0009**.

## 2. The problem this slice solves

FND-003D1 gave the platform a way to *refer to* a proof policy and to protected
evidence, and was deliberate that a reference is not a result. Nothing could
state **whether the referenced policy was satisfied**, so a later delivery
transaction had nothing to consume.

This slice adds that result — and **only** that result.

## 3. Public surface added

| Type / function | Purpose |
|---|---|
| `DeliveryProofAssessmentVerdict` | `satisfied` / `notSatisfied` |
| `DeliveryProofAssessmentRecord` | one immutable assessment result |
| `DeliveryProofAssessmentFacts` | aggregate: current record + own revision |
| `DeliveryProofAssessmentContext` | canonical resource + **server-resolved** policy and evidence references |
| `DeliveryProofAssessmentRequest` | what a trusted verifier reports, plus four expected revisions |
| `DeliveryProofAssessmentTransition` | the record to append; every effect NONE |
| `DeliveryProofAssessmentOutcome` | allow / deny, plus the exact D1 structural reason |
| `DeliveryProofAssessmentDenial` | 23 refusal reasons — internal |
| `DeliveryProofAssessmentEventType` | one event id |
| `executableProofAssessorKinds` | `{PrincipalKind.systemWorker}` |
| `validateDeliveryProofAssessmentAggregate` | canonical stored shape |
| `evaluateDeliveryProofAssessment` | the pure evaluator |

**Policy and evidence live on the *context*, not the request.** A verifier
reports a verdict; it does not choose which policy it was judged against or
which evidence it judged. The request type has no policy or evidence field at
all.

## 4. Decisions that could have been made badly

### Authority — no client can self-declare proof satisfied

`executableProofAssessorKinds` is exactly `{PrincipalKind.systemWorker}`. A
stored record naming any other kind is `aggregateInconsistent` — validating its
shape would legitimise it.

**No command and no permission was added.** `Permission.values` and
`permissionMatrix` stay at **38**, and none of these was created:

```text
customer.proof.accept        rider.proof.mark_satisfied
admin.proof.override         any generic proof-status setter
```

A client-selectable "declare proof satisfied" operation would be exactly the
arbitrary status patch `ProhibitedCapability` forbids, aimed at the one status
gating delivery, custody handover and eventually money. The precedent is
`initialiseCustodyAtShop`, which has no command either — custody at the shop is
not something a caller asserts, and neither is a verdict.

> **A pure Dart object is not runtime trust.** A test constructs a forged
> `satisfied` record and asserts it **is** structurally well formed, because it
> is. The type carries no signature, no attestation and no provenance and
> **cannot authenticate its own origin**. The backend must ignore
> client-supplied records — **DPA1**/**DPA2**, NOT RUN.

### Verdicts — two, and absence is not one of them

`satisfied` and `notSatisfied` only. Absence is
`DeliveryProofAssessmentFacts.absent` — revision 0, no record — so a `pending`
verdict would be a second, contradictory way to say the same thing. A queue that
has not run is backend operational state, not domain truth.

`notSatisfied` means **only** that the verifier concluded the policy was not
satisfied. It is **not** fraud, refusal, cancellation, delivery failure, a lost
dispute, fee liability, a refund or financial default. `CONSTRAINTS.md`
invariant 11 stands.

### History — append-only, never overwritten

A reassessment creates a **new opaque `assessmentId`**, revision `r → r+1`, and
a `supersedesAssessmentId` backward pointer. Reusing the current id is denied
`assessmentIdReuse`. There is no `setAssessmentStatus`, `changeSatisfiedTo`,
`overrideVerdict`, `patchAssessment` or `copyWith`.

The reason is dispute, not tidiness: FND-003D2B must be able to point at "the
assessment that was current when X happened". An overwritable verdict makes a
contested `satisfied` unfindable the moment anyone reassesses.

The aggregate carries only the **current** record — no in-memory history array,
which on a per-request aggregate would be a memory and payload hazard. Bounded
append-only retention is **DPA12**; historical id uniqueness is a **storage**
guarantee (**DPA11**). Both NOT RUN.

### Revisions — independent, and never a bypass

`assessmentRevision` is the assessment aggregate's own, deliberately **not**
the order revision, custody revision or rider `slotRevision`: four aggregates
change at different rates, and one shared counter makes unrelated writes look
like conflicts while hiding real ones.

```text
absent -> 0 · first -> 0 -> 1 · each reassessment -> r -> r + 1
```

The request pins all four revisions, because the verdict *depends* on all four.
**Correct revisions never bypass identity, state, reference or binding checks** —
a test supplies every correct revision alongside the wrong rider and still gets
`notCurrentAcceptedRider`.

### Effects — NONE, structurally rather than by assertion

`DeliveryProofAssessmentTransition` has **no order, custody or assignment effect
field**, so a transition that moves one cannot be constructed. That is stronger
than a runtime check.

A `satisfied` verdict does **not** move `in_delivery → delivered`, move custody
to the customer, complete the rider assignment, restore inventory, settle COD,
or open or close a dispute.

`FinancialClassification.noneInThisSlice` classifies the **recording** — writing
a verdict posts nothing. Whether a `notSatisfied` outcome ever has a financial
consequence is **UNKNOWN and deferred to FND-003C**, blocked on **O6**, and is
never zero. No money vocabulary exists anywhere in the file; a whole-word test
enforces it.

### Nothing about the mechanism, and nothing about the customer

No OTP, QR, barcode, signature, photograph, video, GPS, biometric or
attestation is named, required or implied. **Evidence cardinality is not
invented**: the record carries the single D1 `DeliveryEvidenceRef` and says
nothing about whether one artifact, several or a bundle sits behind it.

Customer participation is **POLICY-DEFINED / DEFERRED** — not optional, not
mandatory, not sufficient, not a veto. **No `customerConfirmed` flag was added**,
because a default `false` would silently choose the answer.
`customer.delivery.confirm_proof` keeps its exact accepted restriction text.

### Server time, and no invented window

`assessedAtUtc` must be UTC. **No expiry, TTL, duration, maximum age or retry
interval is derived from it**, and a test proves it by accepting both a
year-2000 and a year-2099 timestamp. A source guard additionally rejects
`DateTime.now`, `isBefore`, `isAfter` and `difference(` in the file. That the
value is *authoritative* is **DPA13**, NOT RUN.

## 5. Current-delivery integrity

An assessment is refused unless trusted current facts describe the same
delivery: canonical resource valid; policy reference structurally usable;
evidence well formed and belonging to **this** order; custody present and held
by a **rider**; order `in_delivery` with a `committed` reservation; rider
assignment present and `accepted`; and the rider principal, assignment id and
generation matching **both** the accepted assignment and custody exactly.

**This is context integrity, not authentication.** Possession is never an
authorization source: a test confirms custody with the right rider does not make
that rider an assessor.

The D1 validators remain the **single source** of structural judgement — nothing
is reimplemented, and `DeliveryProofAssessmentOutcome.structuralDenial` carries
the exact `DeliveryProofDenial` so logs need not guess.

## 6. Validation — actually executed

All commands run on this host, on this branch, at the commit reported in §9.

### Focused suites

```text
$ cd packages/contracts
$ dart test test/delivery_proof_assessment_test.dart
00:00 +76: All tests passed!

$ dart test test/delivery_proof_test.dart
00:00 +46: All tests passed!

$ dart test test/contract_version_test.dart
00:00 +13: All tests passed!
```

### Directly affected custody and rider regression suites

D2A consumes their facts and bindings, so all five were re-run with the real
repository filenames:

```text
$ dart test test/custody_integrity_test.dart
00:00 +47: All tests passed!

$ dart test test/custody_lifecycle_test.dart
00:00 +62: All tests passed!

$ dart test test/rider_assignment_integrity_test.dart
00:00 +71: All tests passed!

$ dart test test/rider_assignment_test.dart
00:00 +53: All tests passed!

$ dart test test/rider_assignment_race_test.dart
00:00 +23: All tests passed!
```

### Whole package and analysis

```text
$ dart test          (packages/contracts)
00:00 +755: All tests passed!

$ flutter analyze    (workspace root)
No issues found! (ran in 2.3s)
```

### Repository gate

```text
$ ./tools/check_layering.sh
LAYERING CHECK: PASS

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
No issues found! (ran in 2.3s)
LAYERING CHECK: PASS

workspace members declared : 15
members with tests run     : 10
members with NO TESTS      : 5
    - packages/design_system
    - packages/feature_flags
    - packages/networking
    - packages/observability
    - packages/sync

ALL CHECKS PASSED
```

Exit status 0.

| Member | Tests before | Tests now |
|---|---|---|
| apps/admin · agent · picker · rider · user | 1 each = 5 | 5 |
| packages/auth | 6 | 6 |
| **packages/contracts** | **678** | **755** |
| packages/core | 8 | 8 |
| packages/local_store | 7 | 7 |
| packages/notifications | 15 | 15 |
| **Repository total** | **719** | **796** |

**+77**: 76 new assessment tests and one new `ContractVersion` 0.7↔0.8 policy
test. The five `NO TESTS` members are unchanged — this task added code to none
of them.

### Classification of what was NOT run

| Check | Status | Reason |
|---|---|---|
| **GitHub CI** | **NONE / NOT RUN** | No workflow exists; no status evidence. The gate above is a **local repository gate**, not CI. **O7** remains outstanding, and the absence of branch protection does not convert local tests into CI evidence. |
| Backend / persistence | **NOT IMPLEMENTED** | No backend exists. **DPA1–DPA16 all NOT RUN.** |
| Firebase project, rules, indexes, emulator | **NOT RUN** | No project (O5), no Firebase CLI (O4). |
| Platform builds, devices, Windows runner | **NOT RUN** | O1–O3 outstanding. |
| Migration | **NOT APPLICABLE** | No serialization, no released client, no data. |

## 7. Test coverage

Every case the task required is covered through the **real public evaluators**,
not through source text:

absent assessment / revision 0 · first `satisfied` · first `notSatisfied` ·
reassessment after each · new assessment id required · revision increment
(1→2→3) · stale expected assessment revision · delayed old-revision
reassessment · two concurrent reassessments from one revision · duplicate
request · stale order, custody and rider slot revisions · correct revisions not
bypassing identity · wrong rider principal / assignment id / generation · wrong
resource · malformed canonical resource · malformed policy ref (blank and
over-long) · policy bound at exactly the limit · malformed evidence ref ·
cross-resource evidence · malformed and torn assessment aggregates · stored
record for another order · stored record produced by a non-worker · first record
superseding something · malformed assessment id · corrupt rider aggregate ·
wrong order state (four states, each with its canonical reservation) ·
non-committed reservation · missing custody · non-rider custody · custody bound
to another attempt · missing rider assignment · rider assignment in each
non-accepted state · empty rider slot · non-system assessor · malformed assessor
id · non-UTC time · no expiry invented · forged record is not trust.

Then: every denial asserts `transition == null`; both verdicts assert all-NONE
effects; the surrounding aggregates are asserted unchanged; the previous record
is asserted unmutated across a reassessment; and regression tests re-pin
`Permission.values == 38`, the customer participation restriction, `delivered`,
customer custody and rider `completed` as unreachable, the picker completion
range, **B3-C2** as null, and that the FND-003B3A dispatch boundary still
behaves exactly as accepted.

**Negative control.** The only source-shape guard added — the proof-mechanism
scanner — is demonstrated to actually fail: a planted `otpCode` declaration is
detected, while the same word inside a doc comment is correctly **not**
detected, proving the comment-stripping does not turn the guard into a no-op.

## 8. Existing tests changed, and why

Three changes, all **coverage or version pins**, no behaviour:

| File | Change | Why it was necessary |
|---|---|---|
| `test/contract_version_test.dart` | `0.7` → `0.8` (×2); added a 0.7↔0.8 policy test | The build reports a new version. |
| `test/command_envelope_test.dart` | `0.7` → `0.8` | Same pin, in the envelope test. |
| `test/delivery_proof_test.dart` | event sweep now includes `DeliveryProofAssessmentEventType.all`; `delivery.proof_assessed` pinned by name alongside `order.in_delivery` | **This is the "must acknowledge" case.** The sweep covered three event vocabularies. Left alone it would still have passed while silently covering none of the new surface — a guard that keeps passing while proving nothing is worse than no guard. It now also asserts `delivery.proof_submitted` and `delivery.proof_satisfied` do **not** exist. |

The D1 source-scan tests over `lib/src/delivery_proof.dart` are **untouched and
still pass**: that file was not modified by this task.

## 9. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/delivery_proof_assessment.dart` | **new** — the whole assessment contract |
| `packages/contracts/test/delivery_proof_assessment_test.dart` | **new** — 76 tests |
| `packages/contracts/lib/cp_contracts.dart` | export the new file; header 0.7 → 0.8; describe the addition and narrow the "not yet defined" entry |
| `packages/contracts/lib/src/contract_version.dart` | `current` 0.7 → **0.8**, with the 0.8 history entry |
| `packages/contracts/test/contract_version_test.dart` | version pins + new 0.7↔0.8 policy test |
| `packages/contracts/test/command_envelope_test.dart` | version pin |
| `packages/contracts/test/delivery_proof_test.dart` | event sweep widened to the new vocabulary |
| `docs/contracts/delivery-proof-assessment.md` | **new** — the contract document and **DPA1–DPA16** |
| `docs/decisions/ADR-0009-trusted-immutable-proof-assessment.md` | **new** — the durable decision |
| `docs/contracts/delivery-proof-boundary.md` | record that D1's statements still hold at 0.8; widened sweep; deferred list clarified |
| `docs/contracts/README.md` | 0.8; D2A section; new binding rules; D1/B3A merge status reconciled |
| `docs/contracts/version-history.md` | the 0.8 entry, behaviour table, migration and rollback; D1 pre-merge wording reconciled |
| `docs/task-ledger/TASK_LEDGER.md` | D2A rows and narrative; contract 0.8; D1/B3A reconciliation |
| `docs/task-ledger/FND-003D2A-completion-report.md` | **new** — this report |

**Not touched:** `apps/`, `backend/`, `infra/`, any `pubspec`, any lockfile,
`permission.dart`, `permission_matrix.dart`, any order/custody/assignment state
machine, any assignment revision formula, any `.github` configuration, and any
GitHub repository setting.

## 10. Evidence status

**New:** **DPA1–DPA16**, all **NOT RUN**.

**Unchanged by this task, and not upgraded by any pure-Dart test:**

```text
CA1–CA23  NOT RUN      R33–R40  NOT RUN
L1–L13    NOT RUN      P1–P17   NOT RUN
RA1–RA18  NOT RUN
```

**B3-C1** — satisfied by contract tests **for the picker only**; not persistence
evidence. **B3-C2** — **NOT RUN / FUTURE**; rider completion remains unreachable
and its revision cost remains undefined.

## 11. Roadmap after this task

| Task | Status |
|---|---|
| FND-003D1 | **DONE** — accepted and integrated on `main` @ `f03fc99` |
| **FND-003D2A** | **DONE** (this task) |
| FND-003D | **PARTIAL** — the satisfaction *policy* and the dispute workflow are undone |
| FND-003D2B | **NOT STARTED** |
| FND-003B3 | **PARTIAL** |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (TODO) |
| O7 | **outstanding** |

**D2A completion does not mean** FND-003D is done, that delivery confirmation is
unblocked, or that FND-003B3 is done. `CONSTRAINTS.md` invariant 13 is **not**
discharged: the proof-satisfaction policy and the fallback dispute workflow are
still required before delivery confirmation may be coded.

## 12. Git

Exactly **one normal commit** on `fnd/FND-003D2A-proof-assessment-contract`.

**Nothing was pushed, merged, rebased, squashed, amended, force-pushed or
deployed. No PR was created. No GitHub setting was changed. No Firebase or
live-data operation occurred. No later task was started.**
