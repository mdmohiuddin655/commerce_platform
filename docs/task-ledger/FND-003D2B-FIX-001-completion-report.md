# FND-003D2B-FIX-001 completion report

- **Task:** Correct the three material defects found by
  **FND-003D2B-FINAL-REVIEW-001** in the FND-003D2B candidate
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Reviewed base:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Starting candidate HEAD:** `b94e5424ef2460c2d1ec30aeec80e9de09cf1699`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract` (existing; no new
  branch was created)
- **Follow-up commit:** reported **out of band** after commit creation — a
  commit cannot contain its own SHA, and **no amend was used to insert one**
- **Contract version:** **0.9 — unchanged, not bumped**
- **Status:** **DONE** — the corrected two-commit candidate still requires a
  **new, separate read-only final acceptance review**. It is **not** accepted
  for merge.

## 1. Baseline

Every ref matched exactly, and the working tree was clean including untracked
files.

```text
git fetch origin --prune                       exit 0
git remote get-url origin                      https://github.com/mdmohiuddin655/commerce_platform.git
git branch --show-current                      fnd/FND-003D2B-fallback-proof-dispute-contract
git rev-parse origin/main                      03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse HEAD                             b94e5424ef2460c2d1ec30aeec80e9de09cf1699
git rev-parse b94e5424^                        03c71d00b89a2018d1a18631d8e36c40238c0b57
git ls-remote origin refs/heads/fnd/FND-003D2B-fallback-proof-dispute-contract
                                               b94e5424ef2460c2d1ec30aeec80e9de09cf1699
git status --porcelain --untracked-files=all   (empty)
```

Chain before work: `03c71d00…` → `b94e5424…`. **`b94e5424` was not amended,
rebased, squashed, reset or force-pushed**; this task adds **one new normal
follow-up commit** on top of it, on the existing branch.

## 2. The three defects, and what each correction actually changes

### Finding 1 — the basis standing failed **open** on a verdict contradiction

**Root cause.** `resolveDeliveryProofDisputeBasisStanding` compared a
`notSatisfied` basis against the current assessment using **identity only** —
assessment id and revision. ADR-0009 gives every reassessment a **new opaque id
and the next revision**, so assessment A at revision 1 can never legitimately
change verdict. A canonical A/1 that read `satisfied` therefore satisfied the
identity test, and a basis recorded as `notSatisfied` against it was reported
**`current`** — a self-contradictory history certified as still true, on the
exact value a dispute is anchored to.

The aggregate in that scenario is **structurally perfect**, which is why the
existing torn-aggregate guard never caught it: the shape is fine and only the
*meaning* disagrees.

**Correction.** At the same revision the standing now requires all three to
agree — id, revision **and** `canonicalVerdict == notSatisfied`, read through
the trusted accessor rather than off raw facts. A mismatch answers
`indeterminate`. It is **not** converted to `superseded` (nothing superseded it;
the revision never moved), **not** converted to `notSatisfied` (nobody reached
that verdict), the assessment is **not** mutated, and the basis is **not**
rewritten.

Regressions added, exactly as specified: basis `notSatisfied`/A/1 against a
canonical A/1/`satisfied` → `indeterminate`; the ordinary matching
`notSatisfied` case → still `current`; a higher revision → still `superseded`
for **both** verdicts, since the verdict check applies only at the same
revision.

### Finding 2 — an invented separation-of-duties authorization rule

**Root cause.** The candidate denied `reviewerIsRaiser` when the principal
recording review had earlier raised the dispute. The original report defended it
as "a deliberate tightening" with the dual-control precedent. **That defence was
wrong.** The accepted matrix rule is:

```text
admin.dispute.administer
  eligibleRoles     {admin}
  scopes            {ownRegion}
  reasonRequired    true
  approvalRequired  FALSE
```

No accepted contract asks for two distinct principals, so refusing on identity
alone was a **policy decided nowhere** — precisely what this repository forbids.
Flagging an invention in a report does not make it acceptable.

**Correction.** Removed from every place it lived:

- the evaluator (no identity comparison between reviewer and raiser);
- `DeliveryProofDisputeRecord.isWellFormed` — a shape validator must not smuggle
  in an authorization policy, so a record whose reviewer equals its raiser is
  now **canonical**;
- `DeliveryProofDisputeDenial` — **20 → 19** values;
- the tests and the canonical documentation.

**No approval or dual control was added to the permission**, and separation of
duties is now recorded as **NOT DECIDED / DEFERRED**: it would need its own
permission and ADR.

The regression demonstrates the full path: a dispute raised by principal X, the
**same** X passing canonical `evaluateAuthorization` for
`admin.dispute.administer` under an active admin membership with the correct
`ownRegion` scope and a reason, and `recordReviewStarted` **allowing** it — plus
an assertion that the denial name no longer exists in the vocabulary at all.

### Finding 3 — record-review-started was coupled to facts it never reads

**Root cause.** A single `evaluateDeliveryProofDispute` took every aggregate for
every operation, and **a shared read-set silently becomes a shared
precondition**. Recording that review started required a canonical current
assessment, a canonical current order, the order revision, `in_delivery` **and**
`committed` — none of which that operation reads or changes.

The consequence is the one that matters: after a **validly raised** dispute, a
reassessment or a torn assessment read could **freeze it out of review**. A
fallback that stops working when the thing it is a fallback for changes is not a
fallback.

**Correction.** One evaluator per operation, each taking only its own read-set:

| Operation | Reads |
|---|---|
| `evaluateRaiseDeliveryProofDispute` | resource, dispute, **assessment**, **order** |
| `evaluateRecordDeliveryProofDisputeReview` | resource, dispute |
| `evaluateResolveDeliveryProofDispute` | **no arguments at all** |

Request shapes follow the read-sets. `DeliveryProofDisputeRequest` and its three
constructors were **replaced**, not deprecated:

- `DeliveryProofDisputeRaiseRequest` — dispute, assessment and order revisions;
- `DeliveryProofDisputeReviewRequest` — the dispute revision **alone**; there is
  no assessment revision and no order revision to pin, because a compare-and-set
  on something you never read is meaningless;
- resolve has no request type: a deferred edge consumes nothing.

0.9 is an unaccepted, unreleased candidate with **no serialization**, so the
definition was corrected in place rather than keeping misleading fields for a
compatibility nobody could depend on. **No migration is required or invented.**

**Raise remains strictly pinned** to the full read-set it genuinely depends on —
re-asserted by its own regression so the correction cannot loosen the operation
that does need current facts.

`evaluateResolveDeliveryProofDispute()` taking no arguments is a strictly
stronger statement than the previous "refused before any fact is read": it
cannot partially evaluate anything **even in principle**.

**Nothing about delivery, refusal or return is inferred from this
independence.** It says only that review may begin.

### Test-maintainability finding

`basisFrom` was removed. It mirrored production eligibility logic in the test
tree and would happily manufacture a `notSatisfied` basis from a **satisfied**
assessment — a state the evaluator can never produce, and the very contradiction
finding 1 is about. Canonical positive bases now come from a real
evaluator-produced raise (`raisedBasis`); deliberately malformed or
contradictory bases are still constructed directly, inline, where the test can
show what is wrong with them.

No file was split: the corrections left no separable new responsibility, and the
module's existing split by responsibility already carries it.

## 3. Files changed

| Path | Change |
|---|---|
| `…/lib/src/delivery_proof_dispute_basis.dart` | finding 1: verdict must still agree at the same revision |
| `…/lib/src/delivery_proof_dispute_evaluator.dart` | finding 3: three operation-specific evaluators; finding 2: self-review rule removed |
| `…/lib/src/delivery_proof_dispute_facts.dart` | finding 3: `…RaiseRequest` + `…ReviewRequest` replace the shared request |
| `…/lib/src/delivery_proof_dispute_record.dart` | finding 2: reviewer-equals-raiser is no longer "corrupt" |
| `…/lib/src/delivery_proof_dispute_denial.dart` | finding 2: `reviewerIsRaiser` removed (20 → 19), with the reason recorded |
| `…/lib/src/delivery_proof_dispute.dart` | module-barrel doc: per-operation evaluators and requests |
| `…/lib/cp_contracts.dart` | package-barrel doc: the old evaluator name no longer exists |
| `…/lib/src/contract_version.dart` | 0.9 history entry names the three evaluators (**version unchanged**) |
| `…/test/support/delivery_proof_dispute_fixtures.dart` | `basisFrom` → `raisedBasis`; fixtures follow the new API |
| `…/test/delivery_proof_dispute_basis_test.dart` | **+4** finding-1 regressions |
| `…/test/delivery_proof_dispute_evaluator_test.dart` | **+7** finding-3 regressions; resolve strengthened |
| `…/test/delivery_proof_dispute_authority_test.dart` | **+2** finding-2 regressions; request-shape pin updated |
| `…/test/delivery_proof_dispute_concurrency_test.dart` | review CAS is dispute-only; self-review case replaced |
| `…/test/delivery_proof_dispute_model_test.dart` | reviewer-equals-raiser is canonical; ordering still refused |
| `…/test/delivery_proof_dispute_regression_test.dart` | denial count 20 → 19 + absence assertion |
| `…/test/delivery_proof_dispute_effects_test.dart` | review no longer receives the assessment |
| `docs/contracts/delivery-proof-dispute.md` | "identity is not meaning"; per-operation integrity tables; separation of duties deferred |
| `docs/contracts/README.md` | correction summary + two new binding rules |
| `docs/contracts/version-history.md` | the in-place correction recorded under 0.9 |
| `docs/task-ledger/TASK_LEDGER.md` | D2B → **PARTIAL / FIX REQUIRED**; FIX-001 narrative |
| `docs/task-ledger/FND-003D2B-completion-report.md` | **appended** correction section; nothing erased |
| `docs/task-ledger/FND-003D2B-FIX-001-completion-report.md` | **new** — this report |

**Deviation from the declared scope, recorded as required.** Two files outside
the listed primary scope were touched, both **documentation-only**:
`lib/src/delivery_proof_dispute.dart` and `lib/cp_contracts.dart` referenced
`evaluateDeliveryProofDispute` by name, which no longer exists — leaving them
would have published a false description and a broken doc reference. No
executable line in either changed.

**Not touched:** `apps/`, `backend/`, `infra/`, `.github/`, any `pubspec` or
lockfile, `docs/decisions/`, `permission.dart`, `permission_matrix.dart`, the
generated `permission-matrix.md`, `authorization.dart`, `delivery_proof.dart`,
**every** `delivery_proof_assessment_*.dart` source, and every order, custody
and assignment state machine. Verified by `git diff --name-only b94e5424 -- …`
for each path.

## 4. Validation — real commands, real output

### Focused corrected D2B suites

```text
$ cd packages/contracts && dart test \
    test/delivery_proof_dispute_basis_test.dart \
    test/delivery_proof_dispute_model_test.dart \
    test/delivery_proof_dispute_validation_test.dart \
    test/delivery_proof_dispute_evaluator_test.dart \
    test/delivery_proof_dispute_concurrency_test.dart \
    test/delivery_proof_dispute_authority_test.dart \
    test/delivery_proof_dispute_effects_test.dart \
    test/delivery_proof_dispute_debug_test.dart \
    test/delivery_proof_dispute_regression_test.dart
00:00 +168: All tests passed!
EXIT=0
```

| Suite | Before | After |
|---|---|---|
| `…_model_test.dart` | 24 | **25** |
| `…_basis_test.dart` | 13 | **17** |
| `…_validation_test.dart` | 11 | 11 |
| `…_evaluator_test.dart` | 27 | **34** |
| `…_concurrency_test.dart` | 12 | 12 |
| `…_authority_test.dart` | 21 | **22** |
| `…_effects_test.dart` | 12 | 12 |
| `…_debug_test.dart` | 12 | 12 |
| `…_regression_test.dart` | 23 | 23 |
| **total** | **155** | **168** |

### Affected accepted suites, rerun

```text
$ dart test test/delivery_proof_test.dart \
            test/delivery_proof_assessment_*_test.dart \
            test/permission_matrix_test.dart test/authorization_test.dart \
            test/contract_version_test.dart test/command_envelope_test.dart
00:00 +264: All tests passed!
EXIT=0
```

### Package-level

```text
$ cd packages/contracts && dart analyze
Analyzing contracts...
No issues found!
EXIT=0

$ cd packages/contracts && dart test
00:00 +975: All tests passed!
EXIT=0
```

962 (at `b94e5424`) → **975**, i.e. **+13**.

### Workspace-level and the gate

```text
$ flutter analyze          # from the workspace root
Analyzing commerce_platform...
No issues found! (ran in 2.0s)
EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS
EXIT=0

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
Analyzing commerce_platform...
No issues found! (ran in 2.0s)
--- packages/contracts ---
00:00 +975: All tests passed!
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
EXIT=0
```

The five `NO TESTS` members are the pre-existing FND-001 placeholders; this task
added code to none of them.

**This is the local repository gate, not GitHub CI.** No CI system ran anything:
FND-004 has not landed and **O7** is outstanding.

## 5. Negative controls

Each correction carries one. All were applied, run, and **fully reverted** —
verified byte-identical by `diff` against a pre-edit copy, with
`grep -rn "NEGATIVE CONTROL" lib/ test/` finding nothing in the tree afterwards.

| # | Change | Result |
|---|---|---|
| **NC1** | removed the verdict check from the standing calculation | `same id + same revision + opposite verdict is indeterminate` **FAILED**, plus `the contradiction becomes neither superseded nor notSatisfied` |
| **NC2** | re-added the `reviewerIsRaiser` denial and its evaluator check | `no separation-of-duties rule is invented — FND-003D2B-FIX-001` **FAILED**, plus `a record whose reviewer is also the raiser is canonical` |
| **NC3** | attempted to pass `assessment:` and `order:` to the review evaluator | **compile error**, both parameters undefined |

NC3 deserves a note: the read-set independence is enforced by the **type
system**, not by a test remembering not to pass something. The probe lived in
the scratchpad, was copied in only for the analyzer run, and was removed
immediately:

```text
error - The named parameter 'assessment' isn't defined … - undefined_named_parameter
error - The named parameter 'order' isn't defined … - undefined_named_parameter
2 issues found.
```

`tools/check_layering.sh` was **not modified**, so its own negative controls were
not re-run — AGENTS.md requires that only when the guard changes.

## 6. What was NOT run, and why

**No backend, no persistence, no Firebase project, no emulator and no device
exists on this host. Nothing below was promoted from NOT RUN by a Dart test.**

| Evidence | Status | Why |
|---|---|---|
| **DPD1–DPD12** | **NOT RUN** | no backend or persistence exists; contract tests are not evidence that any of it is implemented |
| DPA1–DPA18 | **NOT RUN** | unchanged by this task |
| CA1–CA23, R33–R40, L1–L13, P1–P17, RA1–RA18 | **NOT RUN** | unchanged by this task |
| **B3-C1** | contract-test evidence only, **picker only** | unchanged |
| **B3-C2** | **NOT RUN / FUTURE** | rider completion unreachable; no revision cost invented |
| Firebase project / Rules / indexes / emulator | **NOT RUN** | Firebase CLI and FlutterFire CLI **not installed** (O4); no project exists (O5). **None was created** |
| Backend persistence | **NOT IMPLEMENTED / NOT RUN** | out of scope |
| Physical-device / Android / iOS | **NOT RUN** | no device attached (O3); Android licences unaccepted (O1) |
| Windows build, auth, toast, Drift native | **NOT RUN** | no Windows runner (O2) |
| GitHub CI | **NOT RUN** | FND-004 has not landed; **O7** outstanding |
| Deployment | **NOT RUN** | forbidden by the task and AGENTS.md §9 |

## 7. Confirmations

- **Contract stays 0.9**, corrected in place. This is not a release event, and
  no serialization or migration was invented.
- **Successful delivery remains unavailable.** No delivery, refusal, return or
  attempt command, state, transition or event exists. Pinned by test.
- **`OrderState.delivered`, `CustodyHolderKind.customer` and rider
  `AssignmentState.completed` remain unreachable**; **B3-C2 stays FUTURE / NOT
  RUN** and no rider completion cost was invented.
- **O6 was not guessed.** No fee, refund, compensation, liability, commission,
  journal posting, settlement or amount exists; the source scan over every
  dispute file still enforces it, with its own negative control.
- **O7 remains outstanding operational debt.** No GitHub setting was changed and
  no CI ran.
- **FND-003D2A criterion 48 remains FAIL** under its one-time pre-publication
  exception, and was **not** used as precedent here.
- **D1 and D2A behaviour is unchanged.** No file in either module was edited,
  and the regression group re-exercises the D1 references, the D2A verdict
  vocabulary, `canonicalVerdict`'s corruption behaviour and the D2A evaluator's
  allow and denial paths.
- **`Permission.values` and `permissionMatrix` remain exactly 38**;
  `customer.dispute.raise` and `admin.dispute.administer` are byte-for-byte the
  accepted rules, and **no approval was added**;
  `customer.delivery.confirm_proof` keeps its participation-only meaning.
- **Resolution remains always `resolutionPolicyDeferred`**, `resolved` remains
  unreachable, and **no resolution event exists**.
- **Every order, reservation, inventory, financial, custody, assignment and
  assessment effect remains NONE**, structurally.
- **The stored dispute basis is never rewritten** — the review edge carries it
  forward by construction, re-asserted by test.
- **No amend, rebase, squash, cherry-pick, force-push or history rewrite
  occurred.** `b94e5424` is untouched; this task adds exactly one new normal
  follow-up commit. Nothing was pushed, merged, deployed, tagged, or turned into
  a PR, and no GitHub setting or Firebase resource was touched.
- **No TODO, stub, placeholder or fake-completion path exists.**

## 8. Status after this task

| Task | Status |
|---|---|
| FND-003D1 | **DONE** — accepted and integrated |
| FND-003D2A | **DONE** — accepted and integrated on `main` @ `03c71d0` |
| **FND-003D2B** | **PARTIAL / FIX REQUIRED** — corrected here; **awaiting a new, separate read-only final acceptance review** |
| FND-003D | **PARTIAL** — the proof-satisfaction **policy** is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — needs **O6**, FND-003C, FND-003B3B |
| Separation of duties (raiser vs reviewer) | **NOT DECIDED** — needs its own permission and ADR |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

**FND-003D2B is not accepted for merge.** `CONSTRAINTS.md` invariant 13 is still
**not** discharged: the proof-satisfaction policy remains undefined, so delivery
confirmation still may not be coded.

## Owner actions needed

None new. Unchanged and still outstanding: **O6** (currency, fee policy,
commission ownership — blocks FND-003C and any dispute outcome) and **O7**
(branch protection / CI governance on `main`).
