# FND-003D2B-FIX-006 completion report

- **Task:** Close the MODERATE documentation/maintainability defect found by
  **FND-003D2B-FINAL-REVIEW-005**. **Documentation and source-comment only.**
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Reviewed base:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Starting candidate HEAD:** `cc0c1ae7d69b4493eb8c420ae40d088f99d5f108`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract` (existing)
- **Follow-up commit:** reported **out of band** after commit creation — a
  commit cannot contain its own SHA, and **no amend was used to insert one**
- **Contract version:** **0.9 — unchanged**
- **Status:** **DONE** — the corrected **seven-commit** candidate requires a
  **new, separate read-only final acceptance review**. It is **not** accepted
  for merge.

## 1. Baseline

```text
git fetch origin --prune                       exit 0
git status --porcelain --untracked-files=all   (empty)
git branch --show-current                      fnd/FND-003D2B-fallback-proof-dispute-contract
git rev-parse HEAD                             cc0c1ae7d69b4493eb8c420ae40d088f99d5f108
git rev-parse origin/main                      03c71d00b89a2018d1a18631d8e36c40238c0b57
remote feature (ls-remote)                     cc0c1ae7d69b4493eb8c420ae40d088f99d5f108
merge commits in candidate                     0
ContractVersion.current                        0.9
```

Every parent in `03c71d00 → b94e5424 → ded1aa79 → f04d453 → 202a8a9 → 45d21e9
→ cc0c1ae` verified. No published commit was amended, rebased, squashed or
reset.

## 2. The defect, reproduced before editing

The canonical review integrity table in `docs/contracts/delivery-proof-dispute.md`
carried this row:

```text
| 3 | it names the canonical order | `resourceBindingMismatch` |
```

`evaluateRecordDeliveryProofDisputeReview` has **no such check**. Its entire
resource logic is:

```dart
final String resourceId = dispute.resourceId;                 // l.333
final ... unauthorized = checkDisputeAuthorization(
  ..., expectedResourceId: resourceId);                       // l.342
```

followed by aggregate validation, then the dispute-revision CAS. Grepped
mechanically:

```text
occurrences of `resourceBindingMismatch` in the review function : 0
occurrences in the whole evaluator                              : 1  (line 167, raise)
```

**The documentation described a denial the operation cannot return.**

## 3. Correction — the row was removed, not implemented

The obvious "fix" would have been to add the check. That would have been wrong:
the stored dispute *supplies* the anchor, and step 1 already requires the grant
to **cover** exactly it, so a second comparison would compare
`dispute.resourceId` against itself — the same tautology FND-003D2B-FIX-003
removed from `checkDisputeAuthorization`.

Raise needs that binding because it has other, independently supplied read-set
members — the assessment aggregate and the resource-bound order read. Review has
none. **Stale prose is not a reason to add a runtime check**, so the
documentation was corrected to match the code, and the reason is recorded in the
document itself so the row is not "restored" later as a perceived gap.

Two further stale statements were corrected at the same time.

**The test comment** (`delivery_proof_dispute_evaluator_test.dart`) said the
canonical resource *"now arrives on the authorization grant"*. It now states
that the stored dispute aggregate remains the anchor; that a grant may carry a
different or malformed authorized resource; that such a grant simply cannot
satisfy coverage of the independently anchored resource; and that the grant is
never the source used to choose it. **No assertion changed.**

**`DeliveryProofDisputeDenial.resourceBindingMismatch`** still read *"The
canonical resource context is unusable…"* — naming the `DeliveryProofDisputeContext`
that FIX-002 deleted, and implying a resource-source model the contract no
longer uses. Its doc now describes the actual reachable semantics: an
independently supplied **raise** read-set member not matching the stored
dispute's resource, and explicitly **unreachable from review**, where a
wrong-resource grant fails as `authorizationGrantMismatch` instead. The enum
value is neither renamed nor removed.

## 4. Review-table-to-source reconciliation

Every documented row mapped mechanically to a real reachable branch:

| # | Documented check | Denial | Code path |
|---|---|---|---|
| 1 | grant covers the stored dispute's resource | `authorizationGrantMismatch` | `checkDisputeAuthorization` |
| 2 | dispute aggregate validates | `disputeAggregateInconsistent` | `validateDeliveryProofDisputeAggregate` |
| 3 | dispute revision CAS | `disputeRevisionConflict` | direct return |
| 4 | actor is a human principal | `actorNotHumanPrincipal` | `_checkActorAndTime` |
| 4 | timestamp is UTC | `timestampNotUtc` | `_checkActorAndTime` |
| 5 | `disputeId` is a valid opaque id | `disputeIdInvalid` | direct return |
| 5 | a dispute exists | `disputeNotFound` | direct return |
| 5 | it is the named dispute | `disputeIdMismatch` | direct return |
| 6 | it is still `open` | `disputeNotOpen` | direct return |
| 7 | review does not precede the raise | `reviewTimestampPrecedesRaise` | direct return |

**Documented set and reachable set are identical** — 10 denials: 6 direct
returns, 1 via the authorization helper, 2 via `_checkActorAndTime`, 1 via the
aggregate validator. `resourceBindingMismatch` appears in **neither**. No row
lacks an implementation, and no implementation was added.

## 5. The extended semantic sweep

Earlier sweeps covered production sources and canonical docs. This one adds
**every D2B test and support comment** — the coverage gap FINAL-REVIEW-005
identified — across 26 locations, normalized by stripping comment/blockquote
markers and collapsing **all** whitespace including newlines, and matched
against semantic ideas plus two new review-specific ones:

```text
resource comes/arrives/derives/is taken from the [authorization] grant
grant carries|names|supplies|provides|chooses|anchors|selects|determines|
      is the source of the [canonical|operation] resource
resource identity from the grant
DeliveryProofDisputeContext
review … names the canonical order              (second resource comparison)
review … resourceBindingMismatch                (unreachable denial claim)
```

**Seven matches remain; every one is historical or descriptive.** Neither
review-specific idea matches anywhere, and the test file no longer matches at
all.

| Location | Idea | Classification |
|---|---|---|
| `delivery_proof_dispute_denial.dart` | removed type | **descriptive-valid** — this task's own "previously said" note |
| `delivery_proof_dispute_facts.dart` | removed type | **historical-valid** — `**Historical.**` marker |
| `delivery-proof-dispute.md` | removed type | **historical-valid** — `**Historical.**` blockquote |
| `version-history.md` ×2 (FIX-002 block) | grant names the resource / removed type | **historical-valid** — dated block with the FIX-003 forward pointer |
| `version-history.md` (FIX-004 entry) | grant supplies the resource | **descriptive-valid** — reported speech |
| `version-history.md` (FIX-003 entry) | removed type | **descriptive-valid** — account of what FIX-003 corrected |

## 6. Files changed

| Path | Change |
|---|---|
| `docs/contracts/delivery-proof-dispute.md` | review table corrected; the removed row and its reason recorded |
| `packages/contracts/test/delivery_proof_dispute_evaluator_test.dart` | **comment only** — corrected anchor description |
| `packages/contracts/lib/src/delivery_proof_dispute_denial.dart` | **comment only** — `resourceBindingMismatch` reachable semantics |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-006 recorded; candidate is now seven commits |
| `docs/task-ledger/FND-003D2B-FIX-005-completion-report.md` | **appended** recheck note; nothing rewritten |
| `docs/task-ledger/FND-003D2B-FIX-006-completion-report.md` | **new** — this report |

## 7. Zero executable Dart change

```text
$ git diff --name-only -- '*.dart'
packages/contracts/lib/src/delivery_proof_dispute_denial.dart
packages/contracts/test/delivery_proof_dispute_evaluator_test.dart

# comments and blank lines stripped from both sides:
  delivery_proof_dispute_denial.dart
    IDENTICAL (22 code lines)   sha256 bd55c044a8296298949c5397ca42bddf26d1c4602db6da985a4613aece367d26
  delivery_proof_dispute_evaluator_test.dart
    IDENTICAL (596 code lines)  sha256 dc9a23e0c597359d89655c5b8e5ff935048aba282f97447ba52e24d83ee3dfbb

$ git diff -- '*.dart' | grep '^[+-]' | grep -v '^[+-]\s*\(///\|//\)' | grep -v '^[+-]\s*$'
  none

$ git diff --check
  EXIT=0
```

Identical SHA-256 on both. **No test assertion, fixture, API, export, permission
or version change.** `grep` for NC probe markers across `lib/` and `test/` finds
**none** — no negative-control mutation is committed, and the tests those
controls protect are unchanged apart from one comment.

## 8. Validation

```text
$ cd packages/contracts && dart analyze
No issues found!                                                   EXIT=0

$ dart test <the nine dispute suites>
00:00 +182: All tests passed!                                      EXIT=0   (baseline 182)

$ cd packages/contracts && dart test
00:00 +989: All tests passed!                                      EXIT=0   (baseline 989)

$ flutter analyze                     # workspace root
No issues found! (ran in 2.0s)                                     EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS                                               EXIT=0

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
No issues found! (ran in 2.0s)
--- packages/contracts --- 00:00 +989: All tests passed!
LAYERING CHECK: PASS
ALL CHECKS PASSED                                                  EXIT=0
```

Both counts match the stated baselines exactly, which is the point: a
comment-only correction must not move them.

**GitHub CI: NONE.** `ls .github` → *No such file or directory*. No workflow
exists and none ran. The local gate is **not** CI.

## 9. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 all
NOT RUN.** B3-C1 remains contract-test evidence only; **B3-C2 NOT RUN /
FUTURE**. FND-003B3B **NOT STARTED**; FND-003C **BLOCKED on O6**; **O7
outstanding**. **D2A criterion 48 remains FAIL** under its one-time
pre-publication exception and was not used as precedent.

## 10. Preserved

- Canonical anchor = `DeliveryProofDisputeFacts.resourceId`; the grant only
  proves **coverage** of it; raise also binds `assessment.resourceId` and
  `DeliveryProofDisputeOrderRead.resourceId` to the same anchor.
- Review's resource binding **is** the grant covering the stored dispute's
  resource, with **no second comparison** — and none was added.
- Review takes request + actor + admin grant + dispute only; resolve takes zero
  arguments and always returns `resolutionPolicyDeferred`.
- `DeliveryProofDisputeContext` absent from the current API; no
  `reviewerIsRaiser`; assessment-standing behaviour unchanged.
- `Permission.values` and `permissionMatrix` remain **38**; exactly two dispute
  events; all commercial/order/custody/assignment/assessment/scope effects
  **NONE**; no delivery, customer custody, rider completion, resolution, fee,
  refund, liability, return or stock restoration.
- **ContractVersion 0.9**; no serialization, no migration.

## 11. Status

| Task | Status |
|---|---|
| **FND-003D2B** | **PARTIAL / FIX REQUIRED / NOT ACCEPTED** — seven-commit chain awaiting a new separate read-only final review |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — **O6**, FND-003C, FND-003B3B |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

Nothing was merged, pushed, deployed or turned into a PR; no GitHub setting or
Firebase resource was touched. `CONSTRAINTS.md` invariant 13 is still **not**
discharged.

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.
