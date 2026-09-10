# FND-003D2B completion report

- **Task:** Fallback delivery-proof dispute workflow for a **missing,
  superseded or `notSatisfied`** assessment — the second half of
  `CONSTRAINTS.md` invariant 13
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Baseline:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract`
- **Final commit:** see [§12](#12-git) — a commit cannot contain its own SHA,
  and **no amend was used to insert one**
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.8 → **0.9** (additive, meaning-preserving)
- **Status:** **DONE** — implementation complete; **not yet accepted for merge**

## 1. Baseline verification

`origin/main`, `main` and the accepted D2A branch all matched the required SHA
exactly, the working tree was **clean including untracked files**, and `origin`
was the expected repository. One new branch was created with `git switch -c`
from the verified base.

```text
git remote -v
origin  https://github.com/mdmohiuddin655/commerce_platform.git (fetch/push)

git status --porcelain --untracked-files=all
(empty)

git fetch --all --prune                        exit 0

git rev-parse origin/main                      03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse main                             03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse fnd/FND-003D2A-proof-assessment-contract
                                               03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse origin/fnd/FND-003D2A-proof-assessment-contract
                                               03c71d00b89a2018d1a18631d8e36c40238c0b57
```

`main` and the D2A branch are **ahead/behind 0/0** — the expected accepted,
integrated D2A state. **No `git reset --hard`, no rebase, no cherry-pick, no
amend, no force-push, no push, no merge, no PR, no deployment, no GitHub setting
change and no Firebase or live-data operation occurred at any point.**

**Documentation drift, reconciled — not rewritten.** The ledger row for
FND-003D2A still described it as an unmerged candidate "not yet accepted for
merge". The repository evidence contradicts that: both `6bb23710` and `03c71d0`
are on `main`. The row now records the accepted, integrated state and says
explicitly that FND-003D2B reconciled it. **No historical completion report was
edited**, and the process exception below is untouched.

**FND-003D2A criterion 48 remains FAIL.** The one-time, pre-publication amend of
`a9f3db98` into `6bb23710` is still recorded as **FAIL** in the ledger row and in
the FND-003D2A report's process-correction section. It was **not** converted to
PASS, not softened, and is **not** cited as precedent — this task used exactly
one new normal commit and amended nothing.

## 2. The problem this slice solves

FND-003D1 gave the platform a way to *refer to* proof policy and evidence.
FND-003D2A added the trusted, immutable *result* of evaluating one. Nothing
defined what happens when that result is **one a delivery could never consume**:

```text
no assessment at all        -> delivery cannot proceed on proof
current notSatisfied        -> delivery cannot proceed on proof
the basis was superseded    -> which verdict was being contested?
```

`CONSTRAINTS.md` invariant 13 requires the fallback dispute workflow to exist
**before** delivery confirmation is coded, and ADR-0009 made assessment history
append-only precisely so a dispute could point at *"the assessment that was
current when X happened"*.

This slice is that fallback, and **only** that fallback.

## 3. Public surface added

| Type / function | Purpose |
|---|---|
| `DeliveryProofDisputeState` | `open` / `underReview`, plus unreachable `resolved` |
| `reachableDisputeRevisionFor` | exact revision per state; **null for `resolved`** |
| `DeliveryProofDisputeBasisKind` | `notAssessed` / `notSatisfied` |
| `DeliveryProofDisputeBasis` | immutable audit identity of what was disputed |
| `DeliveryProofDisputeBasisStanding` | `current` / `superseded` / `indeterminate` |
| `resolveDeliveryProofDisputeBasisStanding` | the standing calculation |
| `DeliveryProofDisputeCommand` | 3 named operations; **one never executable** |
| `DeliveryProofDisputeEventType` | 2 event ids |
| `DeliveryProofDisputeRecord` | one dispute, with `.raised` and `.reviewStarted` |
| `DeliveryProofDisputeFacts` | the aggregate (with `.absent`) |
| `DeliveryProofDisputeContext` | the canonical resource, server-resolved |
| `DeliveryProofDisputeRequest` | three constructors, one per operation |
| `DeliveryProofDisputeTransition` | the record to store; every effect NONE |
| `DeliveryProofDisputeOutcome` | allow / deny, plus `isPolicyDeferred` |
| `DeliveryProofDisputeDenial` | **20** refusal reasons — internal |
| `validateDeliveryProofDisputeAggregate` | canonical stored shape |
| `canonicalState` / `canonicalBasis` | trusted access, canonical aggregates only |
| `evaluateDeliveryProofDispute` | the pure evaluator |

## 4. The decisions, and what was deliberately not decided

### Five situations, five distinct answers

| Situation | Answer |
|---|---|
| canonical absence | dispute allowed; basis `notAssessed` |
| current `notSatisfied` | dispute allowed; basis pins that assessment id + revision |
| basis superseded afterwards | dispute stays valid and reviewable; standing `superseded` |
| **torn / malformed** assessment | **denied** `assessmentAggregateInconsistent` |
| current `satisfied` | **denied** `assessmentSatisfied` |

**Corruption is never laundered into `notSatisfied`**, and never becomes a
dispute basis. A test drives it for **both** verdicts, and a negative control
proves the guard can fail (§8).

**A `satisfied` assessment is not a fallback ground.** Contesting a satisfied
verdict is a different workflow no slice defines; refusing it is what stops this
becoming general support-case infrastructure.

### Supersession is a standing, never a rewrite

A dispute is always raised against the **current canonical** situation — the
raise request pins `expectedAssessmentRevision`. Supersession is what happens
afterwards, computed on demand against current facts. The stored basis is
**never rewritten**, and a later `satisfied` assessment does **not** dismiss the
dispute: deciding that would be deciding the outcome.

`DeliveryProofDisputeRequest.recordReviewStarted` **structurally cannot** pin an
assessment revision — the field is absent on that constructor — because review
must keep working after the basis has been superseded. Making it unrepresentable
is stronger than documenting that it is ignored.

### Nothing resolves — and that is the honest answer, not a gap

`DeliveryProofDisputeCommand.resolve` is **enumerated and always refused**
`resolutionPolicyDeferred`, **before any fact is read**.
`DeliveryProofDisputeState.resolved` is unreachable, with **no revision cost
invented** — `reachableDisputeRevisionFor` returns null, exactly as
`reachableSlotRevisionRange` does for rider `completed` (**B3-C2**).

This follows `LifecycleDenial.policyDeferred`'s precedent: a backend must be able
to tell **"not decided yet"** from **"never allowed"**, so nobody fills the gap
with a guessed rule, a zero fee or an automatic cancellation.
`DeliveryProofDisputeOutcome.isPolicyDeferred` exposes that distinction.

Resolving a dispute would require deciding **who prevails**; whether the order
becomes **delivered, refused or returned**, and where a return goes; whether a
**fee, refund, compensation or liability** follows and who bears it; whether
**stock is restored**; and whether **customer participation** is optional,
mandatory, sufficient or a veto. **Not one of those is decided anywhere in this
repository** — they need **O6**, **FND-003C** and **FND-003B3B**. None was
guessed. **Withdrawal, closure, expiry, escalation, SLAs and response windows are
equally absent**, and no timestamp yields a duration of any kind.

### No permission, no reinterpretation

`Permission.values` and `permissionMatrix` stay at **38**. Both executable
operations map to the accepted FND-003A rules unchanged —
`customer.dispute.raise` (`ownResource`, reason required) and
`admin.dispute.administer` (`ownRegion`, reason required). No admin proof
override was created, no assignment or custody permission was widened, and
`customer.delivery.confirm_proof` keeps its exact participation-only meaning:
**raising a dispute is not participation in proof**, and no `customerConfirmed`
flag was added.

### No free text, anywhere

The dispute record has no `reason`, `note`, `comment` or `description` field.
The required justification stays with the **audited command** in FND-003A — a
second copy would be a second place to drift, and a customer-supplied string on
a wire-facing value object is the one route by which a description of proof
material could reach an event payload. That is criterion **DPD11**.

### What is deliberately not in the read-set

**Custody and the rider assignment.** A dispute asserts nothing about a rider,
and the immutable audit identity of the rider attempt that *was* assessed
already lives on the assessment record the basis points at. Requiring current
custody would make the fallback **unavailable exactly when custody has gone
wrong** — the opposite of a fallback. **Possession is not an authorization
source** in either direction.

### One deliberate tightening, and its precedent

`reviewerIsRaiser`: the principal recording that review started may not be the
principal who raised the dispute. Nothing in the repository stated this rule, so
it is a **new constraint** — but it only ever tightens, and it applies the
settled reasoning `evaluateAuthorization` already uses for `ApprovalEvidence`
("self-approval is no control at all") to the one other place in the contract
where two parties must be distinct. It is flagged here rather than buried.

## 5. Effects — all NONE, structurally

| Effect | Value |
|---|---|
| Order | NONE — `changesOrderState == false` |
| Reservation | NONE |
| Inventory | NONE — `availableStockDelta == 0` |
| Financial | NONE — `FinancialClassification.noneInThisSlice` (the **recording**) |
| Custody | NONE — `changesCustody == false` |
| Assignment | NONE — `changesRiderAssignment == false` |
| **Assessment** | NONE — `changesAssessment == false` |
| Scope projection | NONE |

`DeliveryProofDisputeTransition` has **no order, custody, assignment or
assessment effect field**, so a transition that moves one cannot be constructed.

**O6 was not guessed.** `noneInThisSlice` classifies the *recording*: writing a
dispute record posts nothing. Whether a dispute — or the `notSatisfied`
assessment under it — ever costs anyone anything is **UNKNOWN and deferred to
FND-003C**, blocked on **O6**, and is never zero. Invariant 11 stands: delivery
failure does not automatically justify a customer fee, and nonpayment stays
representable. Invariant 12 stands: no dispute restores stock.

## 6. Files changed, and why

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/delivery_proof_dispute.dart` | **new** — stable barrel |
| `…/delivery_proof_dispute_state.dart` | **new** — states + `reachableDisputeRevisionFor` |
| `…/delivery_proof_dispute_basis.dart` | **new** — basis, kinds, standing calculation |
| `…/delivery_proof_dispute_command.dart` | **new** — 3 commands, 2 events, permission mapping |
| `…/delivery_proof_dispute_denial.dart` | **new** — 20 refusal reasons |
| `…/delivery_proof_dispute_record.dart` | **new** — the immutable record + its one forward edge |
| `…/delivery_proof_dispute_facts.dart` | **new** — aggregate, context, request |
| `…/delivery_proof_dispute_validation.dart` | **new** — validator + trusted accessors |
| `…/delivery_proof_dispute_transition.dart` | **new** — transition + outcome, all-NONE effects |
| `…/delivery_proof_dispute_evaluator.dart` | **new** — the pure evaluator |
| `packages/contracts/lib/cp_contracts.dart` | export the barrel; header 0.8 → 0.9; describe the addition; narrow the "not yet defined" entries |
| `packages/contracts/lib/src/contract_version.dart` | `current` 0.8 → **0.9**, with the 0.9 history entry |
| `packages/contracts/test/delivery_proof_dispute_*_test.dart` (9 files) | **new** — 155 tests |
| `packages/contracts/test/support/delivery_proof_dispute_fixtures.dart` | **new** — builders + source-scan vocabularies |
| `packages/contracts/test/contract_version_test.dart` | version pins 0.8 → 0.9; **new** 0.8↔0.9 policy test; the existing 0.7↔0.8 test re-anchored on literals so it keeps testing *that* pair |
| `packages/contracts/test/command_envelope_test.dart` | version pin |
| `packages/contracts/test/delivery_proof_test.dart` | D1 **command** sweep widened to the dispute vocabulary; **event** sweep widened; all new ids pinned by name |
| `packages/contracts/test/delivery_proof_assessment_regression_test.dart` | D2A command sweep widened the same way; version pin, with the D2A-was-not-a-bump history kept in the comment |
| `docs/contracts/delivery-proof-dispute.md` | **new** — the canonical contract document and **DPD1–DPD12** |
| `docs/contracts/README.md` | 0.9; the D2B section; new binding rules; the resolution row |
| `docs/contracts/version-history.md` | the 0.9 entry, behaviour table rows, migration and rollback |
| `docs/contracts/delivery-proof-assessment.md` | D2B delivered the deferred fallback; widened-sweep sentence corrected |
| `docs/contracts/delivery-proof-boundary.md` | "still true at 0.9"; the pinned command/event exceptions reconciled |
| `docs/task-ledger/TASK_LEDGER.md` | D2B rows and narrative; contract 0.9; **D2A merge-status drift reconciled** |
| `docs/task-ledger/FND-003D2B-completion-report.md` | **new** — this report |

**Deviation from the declared scope, recorded as required:** the task listed
`packages/contracts/test/` generally, and four **existing** test files were
edited — three version pins plus the command/event sweep widening. The sweeps
had to change: they iterate the command and event vocabularies by name, and a
guard that silently stops covering a new surface keeps passing while proving
nothing. That is FND-003D2A's own stated reason for widening the same sweep, and
every new id is pinned **by name** rather than skipped by substring.

**Not touched:** `apps/`, `backend/`, `infra/`, any `pubspec`, `pubspec.lock`,
`permission.dart`, `permission_matrix.dart`, `docs/contracts/permission-matrix.md`
(generated, and no permission changed), any ADR, any order/custody/assignment
state machine, any assignment revision formula, `delivery_proof.dart`, every
`delivery_proof_assessment_*.dart` source file, any `.github` configuration, and
any GitHub repository setting. **No dependency, platform code, Firestore rule or
index, Firebase config, backend handler, persistence adapter, app feature or UI
was added.**

## 7. Validation — real commands, real output

### Focused suites (the nine new files)

```text
$ dart test test/delivery_proof_dispute_model_test.dart \
            test/delivery_proof_dispute_basis_test.dart \
            test/delivery_proof_dispute_validation_test.dart \
            test/delivery_proof_dispute_evaluator_test.dart \
            test/delivery_proof_dispute_concurrency_test.dart \
            test/delivery_proof_dispute_authority_test.dart \
            test/delivery_proof_dispute_effects_test.dart \
            test/delivery_proof_dispute_debug_test.dart \
            test/delivery_proof_dispute_regression_test.dart
00:00 +155: All tests passed!
```

| Suite | Tests | Covers |
|---|---|---|
| `…_model_test.dart` | 24 | vocabulary, revision arithmetic, basis and record integrity, equality |
| `…_basis_test.dart` | 13 | current / superseded / indeterminate, mixed resources, stale reads |
| `…_validation_test.dart` | 11 | canonical aggregate, torn loads, trusted accessors |
| `…_evaluator_test.dart` | 27 | the three fallback situations, five-way distinction, binding, order state, identity |
| `…_concurrency_test.dart` | 12 | four-way CAS, duplicate/reordered intent, independent revision |
| `…_authority_test.dart` | 21 | both permissions, wrong owner, wrong region, missing reason, actor kind, self-review |
| `…_effects_test.dart` | 12 | all-NONE effects, unreachability, assessment immutability, events |
| `…_debug_test.dart` | 12 | fail-safe renderings, hostile inputs, privacy |
| `…_regression_test.dart` | 23 | source scans + controls, widened sweeps, D1/D2A regression, version |

### Directly affected accepted suites, rerun

```text
$ dart test test/delivery_proof_test.dart \
            test/delivery_proof_assessment_{authority,binding,concurrency,debug,effects,evaluator,event,model,regression,validation}_test.dart
00:00 +173: All tests passed!

$ dart test test/permission_matrix_test.dart test/authorization_test.dart \
            test/custody_integrity_test.dart test/custody_lifecycle_test.dart \
            test/rider_assignment_integrity_test.dart test/rider_assignment_race_test.dart \
            test/rider_assignment_test.dart test/contract_version_test.dart \
            test/command_envelope_test.dart
00:00 +347: All tests passed!
```

### Package-level

```text
$ cd packages/contracts && dart analyze
Analyzing contracts...
No issues found!
EXIT=0

$ cd packages/contracts && dart test
00:00 +962: All tests passed!
EXIT=0
```

**Test-count evidence, measured rather than derived.** The branch point was
verified by a real run in an isolated `git worktree` at
`03c71d00b89a2018d1a18631d8e36c40238c0b57`:

```text
(worktree @ 03c71d0) $ dart test
00:00 +806: All tests passed!
```

806 → **962**, i.e. **+156**: 155 in the nine new dispute suites, plus one new
`0.8 ↔ 0.9` version-policy test. The worktree was removed afterwards
(`git worktree list` shows only the repository) and it wrote nothing into the
repository tree.

### Workspace-level

```text
$ flutter analyze          # from the workspace root
Analyzing commerce_platform...
No issues found! (ran in 2.0s)
EXIT=0

$ ./tools/check_layering.sh
==> packages must not import apps
==> an app must not import another app
==> backend must not be imported by client code
==> feature domain/ must not import Flutter, Firebase or UI packages
==> feature presentation/ must not import data/
==> feature application/ must not import presentation/
==> no direct notification-vendor SDK import outside an adapter
==> no committed secrets in tracked source

LAYERING CHECK: PASS
EXIT=0
```

### The gate

```text
$ ./tools/run_checks.sh
...
WORKSPACE CHECK: PASS (15 declared members)

Analyzing commerce_platform...
No issues found! (ran in 2.0s)

--- packages/contracts ---
00:00 +962: All tests passed!
...
LAYERING CHECK: PASS

======================================================
==> summary
======================================================
workspace members declared : 15
members with tests run     : 10
members with NO TESTS      : 5
    - packages/design_system
    - packages/feature_flags
    - packages/networking
    - packages/observability
    - packages/sync

NOTE: members listed as NO TESTS carry no implementation at FND-001.
      Any task adding code to one of them must add tests with it.

ALL CHECKS PASSED
EXIT=0
```

The five `NO TESTS` members are the pre-existing FND-001 placeholders; **this
task added code to none of them.**

**This is the local repository gate, not GitHub CI.** No CI system ran anything:
FND-004 has not landed and **O7** (branch protection / CI governance) is
outstanding.

## 8. Negative controls — the guards were proven able to fail

Each was applied, run, and **fully reverted** (verified byte-identical by `diff`
against a pre-edit copy; `grep -r "NEGATIVE CONTROL"` finds nothing in the tree).

| # | Change | Result |
|---|---|---|
| **NC1** | removed the assessment-corruption check from the evaluator | `a torn assessment never becomes a negative basis` **FAILED**, plus 2 more |
| **NC2** | weakened `identifiesAssessment` to raw equality | `two identically-malformed values cannot match their way to true` **FAILED** |
| **NC3** | removed the pre-fact policy-deferred refusal | `it is refused before any fact is read` **FAILED**, plus 3 more |

**NC2 found a real defect in this task's own tests and was worth running.** On
its first attempt **nothing failed**: the original `identifiesAssessment` suite
tested wrong-id and wrong-revision cases but never the fail-open case — a
malformed basis compared against an equally malformed argument — so it was
asserting a property it could not detect. The test was strengthened with three
such cases (broken id, revision 0, broken resource) and NC2 then failed as it
should. The production code was already correct; the *guard* was not, and would
have passed forever while proving nothing.

`tools/check_layering.sh` was **not modified**, so its own negative controls were
not re-run — AGENTS.md requires that only when the guard changes.

## 9. What was NOT run, and why

**No backend, no persistence, no Firebase project, no emulator and no device
exists on this host. Nothing below was promoted to PASS by a Dart test.**

| Evidence | Status | Why |
|---|---|---|
| **DPD1–DPD12** (new) | **NOT RUN** | no backend or persistence exists. Contract tests are not evidence that any of it is implemented |
| DPA1–DPA18 | **NOT RUN** | unchanged by this task |
| CA1–CA23, R33–R40, L1–L13, P1–P17, RA1–RA18 | **NOT RUN** | unchanged by this task |
| **B3-C1** | satisfied by contract tests, **picker only** | not persistence evidence; unchanged |
| **B3-C2** | **NOT RUN / FUTURE** | rider completion unreachable; no revision cost invented |
| Firebase project / Rules / indexes / emulator | **NOT RUN** | Firebase CLI and FlutterFire CLI are **not installed** (O4); no project exists (O5). **None was created to make a check runnable** |
| Backend persistence | **NOT IMPLEMENTED / NOT RUN** | out of scope; no handler, adapter or transaction exists |
| Physical-device / Android / iOS checks | **NOT RUN** | no device attached (O3); Android licences unaccepted (O1) |
| Windows build, auth, toast, Drift native | **NOT RUN** | no Windows runner (O2) |
| GitHub CI | **NOT RUN** | FND-004 has not landed; **O7** outstanding. The local gate is not CI |
| Deployment | **NOT RUN** | forbidden by the task and by AGENTS.md §9 |
| Web / push / notification runtime | **NOT RUN** | unchanged by this task; C1–C6 remain NOT RUN |

**Nothing was reported PASS that was not executed here.**

## 10. Confirmations required by the task

- **Successful delivery remains non-executable.** No delivery, refusal, return
  or attempt command, state, transition or event was added. Pinned by test.
- **`OrderState.delivered` remains unreachable** — `notYetImplemented`, no
  canonical pairing, no transition into it. Pinned by test.
- **`CustodyHolderKind.customer` remains unreachable** — `notYetImplemented`.
  Pinned by test.
- **Rider `AssignmentState.completed` remains unreachable**, and **B3-C2 stays
  FUTURE / NOT RUN** — `reachableSlotRevisionRange(..., role: rider)` still
  returns null. **No rider completion cost was invented.** Pinned by test.
- **O6 was not guessed.** No fee, refund, compensation, liability, commission,
  journal posting, settlement or amount exists; a source scan over every dispute
  file enforces it, with its own negative control.
- **O7 remains outstanding operational debt.** Branch protection and CI
  governance on `main` are still unverified and unconfigured; this task changed
  no GitHub setting and ran no CI.
- **FND-003D2A criterion 48 remains FAIL**, recorded as the one-time
  pre-publication exception, **not rewritten and not cited as precedent**.
- **D1 and D2A semantics are unchanged.** No file in either module was edited.
  A regression group re-exercises the D1 references, the D2A verdict vocabulary,
  `canonicalVerdict`'s corruption behaviour and the D2A evaluator's allow and
  denial paths.
- **Assessments remain immutable and append-only.** No dispute path can mutate,
  relabel, erase, supersede or reassess one; the transition has no field for it.
- **No proof mechanism** is selected or implied — no OTP, QR, barcode,
  signature, photograph, video, GPS, biometric or attestation. Source-scanned,
  with a negative control.
- **No raw proof or evidence material** enters any record, event, debug string
  or routing payload — the dispute contract holds no policy reference, no
  evidence reference and no verdict copy at all, and a source scan enforces it.
- **No generic status patch, balance edit, journal edit or unaudited override**
  was introduced; every `ProhibitedCapability` fragment is asserted absent from
  every dispute command type.
- **No TODO, stub, placeholder or fake-completion path exists.** The one
  non-executable edge is `resolve`, which is *explicitly* refused
  `resolutionPolicyDeferred`, documented, and covered by tests — not a stub.

## 11. Blockers and policy questions encountered

**No blocker prevented completion of the declared scope.** The bounded fallback
workflow was completable without guessing any unresolved policy, because the
undecided part — the **outcome** — is enumerated and refused rather than
implemented.

Open questions this task deliberately did **not** answer, each now recorded in
the contract document:

1. **How does a dispute resolve?** Needs **O6**, FND-003C and FND-003B3B.
2. **May a customer withdraw a dispute, and at what point?** Not invented.
3. **Is there any deadline, SLA or escalation?** Not invented; no duration is
   derived from any timestamp.
4. **May a dispute be raised after delivery, refusal, return or post-dispatch
   cancellation?** None of those states is reachable, so the answer would be an
   invention. Only `in_delivery` is executable today.
5. **Can a `satisfied` assessment be contested?** Refused here; that is a
   different workflow no slice defines.

## 12. Git

Exactly **one normal commit** on
`fnd/FND-003D2B-fallback-proof-dispute-contract`, created from the verified
`main` @ `03c71d0`.

**The final commit SHA is deliberately not embedded in the commit itself.** A
commit cannot contain its own hash, and the repository's previous attempt to
solve that by amending is exactly what made FND-003D2A criterion 48 **FAIL**.
This task therefore follows the ledger's existing convention of naming the
commit ("**the FND-003D2B commit**") and reports the SHA out of band, in the
handoff accompanying this branch. **No amend was used.**

**Nothing was pushed, merged, rebased, squashed, amended, force-pushed or
deployed. No PR was created. No GitHub setting was changed. No Firebase or
live-data operation occurred. No later task was started.**

## 13. Roadmap after this task

| Task | Status |
|---|---|
| FND-003D1 | **DONE** — accepted and integrated |
| FND-003D2A | **DONE** — accepted and integrated on `main` @ `03c71d0` |
| **FND-003D2B** | **DONE** (this task) — awaiting acceptance and merge |
| FND-003D | **PARTIAL** — the proof-satisfaction **policy** is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — needs **O6**, FND-003C, FND-003B3B |
| FND-003B3 / FND-003B | **PARTIAL** — unchanged |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

**D2B completion does not mean** FND-003D is done, that delivery confirmation is
unblocked, or that FND-003B3 is done. `CONSTRAINTS.md` invariant 13 is **not**
discharged: the proof-satisfaction policy is still required before delivery
confirmation may be coded.

## Owner actions needed

None new. The outstanding ones this slice touches are unchanged: **O6**
(currency, fee policy, commission ownership — blocks both FND-003C and any
dispute outcome) and **O7** (branch protection / CI governance on `main`).

---

# FND-003D2B-FINAL-REVIEW-001 CORRECTION

**Appended by FND-003D2B-FIX-001 (2026-09-11). Nothing above is deleted or
rewritten — the incorrect statements stay visible, and this section corrects
them.**

FND-003D2B-FINAL-REVIEW-001 found **three material defects** in the candidate
this report describes. `b94e5424` alone is therefore **not acceptable**, and the
report's own status line ("implementation complete") must be read as
**superseded**: FND-003D2B is **PARTIAL / FIX REQUIRED** until the corrected
two-commit chain passes a new, separate read-only acceptance review.

## What this report got wrong

### 1. §4 "Supersession is a standing, never a rewrite" — fail-open

The standing calculation compared only the assessment **id and revision**. A
basis recorded as `notSatisfied` against assessment A revision 1 was reported
**`current`** when the canonical A/1 read `satisfied` — a contradiction
ADR-0009's append-only history cannot produce, certified as "still true".
Corrected: the same-revision comparison now also requires the canonical verdict
to still be `notSatisfied`, and a mismatch is `indeterminate`.

### 2. §4 "One deliberate tightening, and its precedent" — withdrawn

This report defended `reviewerIsRaiser` as a tightening with the dual-control
precedent. **That defence was wrong.** `admin.dispute.administer` carries
`approvalRequired: false` and requires only an active admin membership,
`ownRegion` scope and a stored reason. No accepted contract asks for separation
of duties, so the denial was an **invented authorization policy** — the thing
this repository exists to prevent. It has been removed from the evaluator, the
record validator, the denial vocabulary (**20 → 19**), the tests and the
documentation. Flagging an invention in a report does not make it acceptable.

### 3. §4 "What is deliberately not in the read-set" — incomplete

The claim that custody and the rider assignment were excluded was true, but the
report did not notice that **recording that review started still depended on the
current assessment and the current order**: a canonical assessment aggregate, a
canonical order aggregate, the order revision, `in_delivery` and `committed`.
None of those is read or changed by that operation, so a reassessment or a torn
assessment read after a validly raised dispute could freeze it out of review.
Corrected: one evaluator per operation, each with its own read-set, enforced by
the type system.

## What in this report still stands

The slice's boundaries are unchanged and were not the problem: no permission was
added (`Permission.values` = 38), resolution remains enumerated and always
`resolutionPolicyDeferred`, no outcome/fault/fee/refund/compensation/liability
is decided, no proof mechanism exists, every effect remains NONE, `delivered`,
customer custody and rider `completed` remain unreachable, **DPD1–DPD12 remain
NOT RUN**, and the contract stays at **0.9**.

The baseline, git-hygiene and NOT RUN sections of this report are accurate and
are not modified. **No amend, rebase, squash or force-push was used**, then or
now.

Full detail: [FND-003D2B-FIX-001 report](FND-003D2B-FIX-001-completion-report.md).
