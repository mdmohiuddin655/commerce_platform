# FND-003D2A-FIX-001 completion report

- **Task:** Correct the technical, maintainability, security and
  process-evidence defects found by **FND-003D2A-FINAL-REVIEW-001**
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Branch:** `fnd/FND-003D2A-proof-assessment-contract`
- **Starting HEAD:** `6bb23710ff6c31376cb30df69f999a754807714f`
- **Reviewed base:** `main` @ `f03fc99c2cca01d5eda8e4b2542cd3a7896c124d`
- **Contract version:** **0.8 — unchanged, not bumped**
- **Status:** **DONE** — the corrected candidate still requires final read-only
  acceptance before merge

## 1. Baseline

```text
git branch --show-current   fnd/FND-003D2A-proof-assessment-contract
git rev-parse HEAD          6bb23710ff6c31376cb30df69f999a754807714f
git rev-parse 6bb23710^     f03fc99c2cca01d5eda8e4b2542cd3a7896c124d
origin feature              6bb23710ff6c31376cb30df69f999a754807714f
origin/main                 f03fc99c2cca01d5eda8e4b2542cd3a7896c124d
git status --porcelain --untracked-files=all   (empty)
origin                      https://github.com/mdmohiuddin655/commerce_platform.git
```

Every ref matched exactly. **`6bb23710` was not amended, rebased or reset**;
this task adds **one new normal follow-up commit** on top of it.

## 2. Process exception — recorded, not repeated

Before the branch was first published, a local-only commit **`a9f3db98`** was
**amended** into `6bb23710` to remove a literal `<D2A>` ledger placeholder.

- **FND-003D2A acceptance criterion 48 (no amend) = FAIL.** It is not PASS
  anywhere, and the earlier claim that all 50 criteria were met is withdrawn.
- **No shared history, reviewer history or CI result was rewritten.**
  `a9f3db98` was never pushed; `git branch -r --contains a9f3db98` returns
  nothing, and the first publication was a clean `[new branch]` create.
- Accepted as a **one-time, documented, pre-publication** exception. It grants
  **no** licence to amend any current or future commit.
- **`a9f3db98` is not part of the accepted candidate chain.** The chain is
  `6bb23710` + this commit.

The false "no amend" statements in §1 and §12 of the FND-003D2A report are left
in place and corrected by an appended
[process-correction section](FND-003D2A-completion-report.md), not edited away.

## 3. Module split

| | Before | After |
|---|---|---|
| Production | **1 file, 980 lines** | **10 files, 1,270 lines**, largest **278** |
| Tests | **1 file, 1,455 lines** | **10 files + 1 fixture, 2,139 lines**, largest **275** |

### Production files

| File | Lines | Responsibility |
|---|---|---|
| `delivery_proof_assessment.dart` | 55 | **stable barrel** — re-exports the public surface |
| `…_verdict.dart` | 58 | the two-value verdict vocabulary |
| `…_facts.dart` | 58 | the aggregate as loaded from storage |
| `…_event.dart` | 30 | the single assessment event id |
| `…_denial.dart` | 119 | refusal vocabulary (24 values) |
| `…_validation.dart` | 94 | canonical aggregate shape + `canonicalVerdict` |
| `…_transition.dart` | 151 | permitted transition and outcome |
| `…_authority.dart` | 181 | assessor kinds, server-resolved context, request |
| `…_record.dart` | 246 | one immutable assessment result |
| `…_evaluator.dart` | 278 | the pure evaluator |

### Test files

| File | Lines |
|---|---|
| `…_event_test.dart` | 74 |
| `…_effects_test.dart` | 113 |
| `…_concurrency_test.dart` | 124 |
| `…_evaluator_test.dart` | 178 |
| `…_debug_test.dart` | 190 |
| `…_validation_test.dart` | 199 |
| `…_authority_test.dart` | 216 |
| `…_binding_test.dart` | 244 |
| `…_regression_test.dart` | 251 |
| `…_model_test.dart` | 275 |
| `support/…_fixtures.dart` | 275 |

**No hand-written file exceeds 300 lines**, so no size justification is owed.
The two largest production files are the evaluator (278 — one ordered
fail-closed decision procedure that would become harder to audit if split
mid-sequence) and the record (246 — one immutable value with its structural
predicates); both are comfortably under the threshold.

### API, cycles and duplication

- The barrel re-exports **every** public declaration, so
  `package:cp_contracts/cp_contracts.dart` keeps the identical assessment
  surface. A regression test reaches the whole API through the barrel only — had
  an export been dropped, that file would not compile.
- **Acyclic**, one direction: vocabulary → model → shapes → validation →
  evaluator. `dart analyze`: **No issues found!**
- **No duplicated validation.** Identifier rules come from `ids.dart`, proof and
  evidence rules from `delivery_proof.dart`, and the order, custody and rider
  aggregate rules from their own canonical validators.
- No app import, no backend import, no visibility workaround. Layering: **PASS**.

## 4. Assessor authority (defect C)

**The defect.** `PrincipalKind.systemWorker` is a broad infrastructure class —
the outbox drain, reservation expiry and scheduled reconciliation all hold it.
The evaluator accepted **any** structurally valid system worker, so an unrelated
job could mint the verdict that later gates delivery, custody handover and
eventually money.

**The fix.**

- The evaluator takes the assessor as a **separate `Principal` argument**,
  derived from verified internal service authentication.
- `DeliveryProofAssessmentContext` gained
  **`authorizedAssessorPrincipalId`** — the exact verifier that resource's
  trusted policy and routing state authorizes, a canonical opaque id.
- Both conditions must hold: the kind is in `executableProofAssessorKinds`
  **and** `assessor.id` equals the authorized id exactly.
- New denial **`assessorAuthorityMismatch`**, kept distinct from
  `assessorNotSystemWorker` (wrong kind) and `assessorPrincipalIdInvalid`
  (unusable authorized id) — "not a server process" and "the wrong server
  process" are different failures.
- The request's `assessedByPrincipalId` and `assessedByKind` fields were
  **removed**, not retained for source compatibility: a payload that names its
  own authorizer is not a check, and 0.8 is unreleased with no serialization.
- The record's `assessedByPrincipalId` is derived from the verified principal
  **after** it matches, so audit names exactly which verifier acted.

**Runtime provenance is still not claimed.** A test constructs the authorized
verifier `Principal` and a `satisfied` record locally and asserts both are
structurally perfect — **because they are**. The contract establishes a claimed
authority shape; that the claim is true is **DPA2** and **DPA17**, NOT RUN.

## 5. Fail-closed public API (defects E, F)

| Member | Before | After |
|---|---|---|
| `bindsRiderAttempt` | raw equality — a malformed record matched identically-malformed arguments | requires well-formed record, valid opaque `principalId`/`assignmentId`, `generation >= 1`, then exact equality on all three |
| `currentVerdict` | `current?.verdict` off raw facts — a **torn aggregate could expose `satisfied`** | replaced by **`canonicalVerdict`**, which returns a verdict only when the aggregate validator accepts the facts |

`DeliveryProofAssessmentFacts` now exposes **no verdict getter of its own**, and
`isAssessed` was renamed **`hasCurrentRecord`** and documented as a structural
fact rather than a trust claim.

**Corruption is never converted into `notSatisfied`** — `canonicalVerdict`
returns `null`, and a test asserts specifically that it is *not*
`notSatisfied`. A broken aggregate stays a denial and a reconciliation case.

## 6. Structural single event (defect G)

`DeliveryProofAssessmentTransition` takes **only the record**. `events` is a
fixed getter returning a `const` — therefore deeply immutable — single-element
list. There is no constructor parameter through which arbitrary, extra, missing
or fabricated ids (`delivery.proof_satisfied`) could enter, and
`events.add(...)` throws `UnsupportedError`.

## 7. Debug and log fail-safety (defect H)

Every public assessment value renders `(invalid)` when malformed:
`DeliveryProofAssessmentRecord`, `…Context`, `…Transition`, and `…Outcome`,
which delegates and so cannot reintroduce a raw field through nesting.

**One bad field suppresses the whole rendering**, including sound fields — until
validation passes they are all untrusted strings, and that pre-validation window
is exactly the one that matters. The policy reference renders through its own
non-disclosing `toString`, the evidence reference through its own fail-safe one.
Nothing is thrown, trimmed, normalised, repaired or hashed into a business
identity.

Hostile inputs are driven through every rendering: newline/tab, a URL, a
filesystem path, a fake secret marker and an oversized string. A guard test
asserts **every hostile fixture really is a malformed id** — one originally was
not (its characters were all inside the URL-safe alphabet, making it a *valid*
opaque id and silently disarming five assertions), and that was caught by this
guard and fixed.

## 8. Reassessment audit boundary (item I)

No reason taxonomy, admin override or proof mechanism was invented. The contract
audit identities remain the immutable `assessmentId`,
`supersedesAssessmentId`, the authorized assessor identity, `assessedAtUtc` and
the policy/evidence references — and a test pins that a verdict-changing
reassessment carries all of them.

**DPA18** records the backend obligation: a verdict-changing reassessment must
retain an immutable basis — the exact policy/evidence snapshot or an equivalent
immutable assessment-basis reference for **both** assessments — and must never
mutate evidence behind a historical assessment in place. **NOT RUN.** It defines
no dispute outcome, winner, SLA, retention, compensation, refund, liability or
fee.

## 9. Preserved unchanged

Server time (UTC required, no expiry/TTL/age/duration, provenance = DPA13) ·
append-only reassessment · `0 → 1`, `r → r+1`, new id required, exact
supersedes, previous record never mutated · all four revision CAS checks ·
correct revisions never substituting for identity checks · every denial
`transition == null` · cross-aggregate binding (resource, D1 refs, order
`inDelivery`, reservation `committed`, rider custody, exact accepted attempt) ·
verdicts `satisfied`/`notSatisfied` only · absence = not assessed · all
commercial effects NONE · financial consequence UNKNOWN/DEFERRED to FND-003C/O6,
never zero · customer participation POLICY-DEFINED/DEFERRED with no flag ·
`Permission.values` and `permissionMatrix` = **38** · no proof mechanism · no
delivery/refusal/return/dispute/money rule · `delivered`, customer custody and
rider `completed` unreachable · picker completion arithmetic untouched · **B3-C2
FUTURE**.

## 10. Negative controls

Each fix was temporarily reverted, the named test observed to **fail**, and the
production source **restored**. A final scan confirms **no residue**: no
`NEGATIVE CONTROL` marker, no `if (false)`, no `=> true` remains anywhere under
`packages/`.

| # | Reverted | Test that failed |
|---|---|---|
| 1 | exact authorized-verifier comparison | `assessor authority … an UNRELATED trusted worker cannot assess` |
| 2 | raw equality in `bindsRiderAttempt` | `bindsRiderAttempt fails closed … a MALFORMED record cannot bind its own malformed values` |
| 3 | raw `current?.verdict` accessor | `canonicalVerdict fails closed … a TORN aggregate carrying satisfied exposes no verdict` |
| 4 | caller-supplied transition events | `the single event is structural … a caller cannot select the events at all` |
| 5 | raw malformed record rendering | `debug renderings are fail safe … no hostile fragment survives in any record rendering` |

The pre-existing proof-mechanism source scanner keeps its own in-suite negative
control: a planted `otpCode` declaration is detected while the same word in a
doc comment is not.

## 11. Validation — actually executed

```text
$ cd packages/contracts

$ dart test test/delivery_proof_assessment_*_test.dart
00:00 +127: All tests passed!

$ dart test test/delivery_proof_test.dart          00:00 +46:  All tests passed!
$ dart test test/contract_version_test.dart        00:00 +13:  All tests passed!
$ dart test test/permission_matrix_test.dart       00:00 +23:  All tests passed!
$ dart test test/custody_integrity_test.dart       00:00 +47:  All tests passed!
$ dart test test/custody_lifecycle_test.dart       00:00 +62:  All tests passed!
$ dart test test/rider_assignment_integrity_test.dart  00:00 +71:  All tests passed!
$ dart test test/rider_assignment_test.dart        00:00 +53:  All tests passed!
$ dart test test/rider_assignment_race_test.dart   00:00 +23:  All tests passed!

$ dart test          (whole package)
00:00 +806: All tests passed!

$ dart analyze
No issues found!

$ flutter analyze    (workspace root)
No issues found! (ran in 2.0s)
```

```text
$ ./tools/check_layering.sh
LAYERING CHECK: PASS

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
No issues found! (ran in 2.0s)
LAYERING CHECK: PASS
workspace members declared : 15
members with tests run     : 10
members with NO TESTS      : 5
ALL CHECKS PASSED
```

Exit status 0.

| Member | Before this fix | Now |
|---|---|---|
| apps ×5 · auth · core · local_store · notifications | 5 · 6 · 8 · 7 · 15 | unchanged |
| **packages/contracts** | **755** | **806** |
| **Repository total** | **796** | **847** |

**+51**, from splitting the suite and adding the authority, fail-closed,
event-structure and debug-safety cases. The five `NO TESTS` members are
unchanged — no code was added to any of them.

### Not run, and why

| Check | Status | Reason |
|---|---|---|
| **GitHub CI** | **NONE / NOT RUN** | No workflow and no status evidence exist. Everything above is a **local repository gate**, never CI. **O7** remains outstanding. |
| Backend / persistence | **NOT IMPLEMENTED / NOT RUN** | No backend exists. **DPA1–DPA18 all NOT RUN.** |
| Firebase project, rules, indexes, emulator | **NOT RUN** | O4, O5. |
| Platform builds, devices, Windows runner | **NOT RUN** | O1–O3. |
| Migration | **NOT APPLICABLE** | No serialization, no released client, no data. |

**No DPA, CA, R, L, P or RA criterion becomes PASS from a Dart test.**

## 12. Evidence status

**New:** **DPA17** (authorized proof-verifier service identity; generic
`systemWorker` insufficient) and **DPA18** (immutable reassessment audit basis)
— both **NOT RUN**, added without renumbering DPA1–DPA16.

**Unchanged and NOT RUN:** DPA1–DPA16 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 ·
RA1–RA18.

**B3-C1** — satisfied by contract tests **for the picker only**; not persistence
evidence. **B3-C2** — **NOT RUN / FUTURE**.

## 13. Contract version

**0.8, unchanged.** No bump to 0.9: this corrects an unmerged, unreleased
candidate in place, and splitting internal files changes no public version by
itself. No serialization exists; no payload-decoding, unknown-field,
released-client or persistence-correctness claim is made.

## 14. Files changed

| Path | Purpose |
|---|---|
| `lib/src/delivery_proof_assessment.dart` | now the **stable barrel** |
| `lib/src/delivery_proof_assessment_{verdict,record,facts,denial,authority,transition,validation,evaluator,event}.dart` | **new** — the split module, carrying fixes C, E, F, G, H |
| `test/support/delivery_proof_assessment_fixtures.dart` | **new** — shared builders, hostile inputs, source-scan helpers |
| `test/delivery_proof_assessment_{model,validation,evaluator,concurrency,binding,authority,debug,event,effects,regression}_test.dart` | **new** — the split suites |
| `test/delivery_proof_assessment_test.dart` | **removed** — replaced by the above |
| `docs/contracts/delivery-proof-assessment.md` | module map, authority §5a, fail-closed §5b, structural event, debug §10a, **DPA17/DPA18** |
| `docs/decisions/ADR-0009-…md` | amended: authority decision rewritten, amendment table, new rejected alternatives |
| `docs/task-ledger/FND-003D2A-completion-report.md` | **appended** process-correction section; nothing deleted |
| `docs/task-ledger/TASK_LEDGER.md` | row corrected — no longer calls `6bb23710` alone accepted |
| `docs/task-ledger/FND-003D2A-FIX-001-completion-report.md` | **new** — this report |

**Not touched:** `apps/`, `backend/`, `infra/`, Firebase, any pubspec or
lockfile, `permission.dart`, `permission_matrix.dart`, any order/custody/
assignment transition, any assignment revision formula, `.github/`, any GitHub
setting.

## 15. Status after this task

| Task | Status |
|---|---|
| **FND-003D2A** | implementation **DONE as corrected candidate** — `6bb23710` + this commit; **final read-only acceptance still required** |
| FND-003D | **PARTIAL** |
| FND-003D2B | **NOT STARTED** |
| FND-003B3 | **PARTIAL** |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (TODO) |
| O7 | **outstanding** |

`CONSTRAINTS.md` invariant 13 is **not** discharged: the proof-satisfaction
policy and the fallback dispute workflow remain required before delivery
confirmation may be coded.

## 16. Git

Exactly **one new normal commit** on
`fnd/FND-003D2A-proof-assessment-contract`, parent
`6bb23710ff6c31376cb30df69f999a754807714f`.

**No amend, no rebase, no squash, no reset, no force push. Nothing was pushed,
merged, deployed; no PR was created; no GitHub setting or Firebase data was
touched; no later task was started.**
