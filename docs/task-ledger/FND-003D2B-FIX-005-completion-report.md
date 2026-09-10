# FND-003D2B-FIX-005 completion report

- **Task:** Close the MODERATE defect found by **FND-003D2B-FINAL-REVIEW-004**,
  and correct the FIX-004 sweep claim. **Documentation, source-comment and
  evidence only.**
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Reviewed base:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Starting candidate HEAD:** `45d21e9c6908b32079bee1d9fba408f0902721ca`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract` (existing)
- **Follow-up commit:** reported **out of band** after commit creation — a
  commit cannot contain its own SHA, and **no amend was used to insert one**
- **Contract version:** **0.9 — unchanged**
- **Status:** **DONE** — the corrected **six-commit** candidate requires a
  **new, separate read-only final acceptance review**. It is **not** accepted
  for merge.

## 1. Baseline

```text
git fetch origin --prune                       exit 0
git status --porcelain --untracked-files=all   (empty)
git branch --show-current                      fnd/FND-003D2B-fallback-proof-dispute-contract
git rev-parse HEAD                             45d21e9c6908b32079bee1d9fba408f0902721ca
git rev-parse origin/main                      03c71d00b89a2018d1a18631d8e36c40238c0b57
remote feature (ls-remote)                     45d21e9c6908b32079bee1d9fba408f0902721ca
merge commits in candidate                     0
ContractVersion.current                        0.9
```

Published chain before work: `03c71d00 → b94e5424 → ded1aa79 → f04d453 →
202a8a9 → 45d21e9`, every parent verified. No published commit was amended,
rebased, squashed or reset.

## 2. The defect, reproduced before editing

Under `evaluateRecordDeliveryProofDisputeReview`'s own **"What it does check"**
heading:

```text
lib/src/delivery_proof_dispute_evaluator.dart:298-299
/// UTC, and that review does not precede the raise. The canonical resource
/// comes from the grant.
```

The implementation in that same function:

```dart
final String resourceId = dispute.resourceId;              // l.333
...
checkDisputeAuthorization(..., expectedResourceId: resourceId);
```

A current API description saying the opposite of the code it documents, in the
same doc comment block.

## 3. Why the FIX-004 sweep missed it — the part worth recording

Not a file FIX-004 forgot. Its §4 listed `delivery_proof_dispute_evaluator.dart`
among the sixteen locations swept, and its regex
`canonical resource (comes|came) from the (authorization )?grant` **matches this
sentence** when the text is unwrapped.

The sweep was **line-based**, and the sentence **wraps across two lines**.
Demonstrated mechanically on the exact two lines:

```text
line-based grep   (the FIX-004 method) : 0 matches
unwrapping search (the FIX-005 method) : 1 match
```

A prose sweep that cannot see across a line break will keep missing wrapped
prose — which is most prose in this repository, where doc comments are wrapped
at 80 columns. **The method was the defect, not the file list.** Recording that
matters more than the one sentence, because the same technique had been used to
certify "all equivalent claims gone" twice.

## 4. The correction

```dart
/// **The canonical resource is anchored by the stored dispute aggregate**; the
/// grant must **cover** that independently selected resource. It does not
/// choose, supply or name it — comparing a grant against a value the grant
/// itself provided would prove nothing, which is the tautology
/// FND-003D2B-FIX-003 removed.
```

The wording was checked against the code, not the previous prose. It does not
imply the grant chooses, supplies, provides, anchors or names-as-authoritative
the operation resource.

## 5. The broader semantic sweep

Re-run across the same sixteen current D2B source and documentation locations,
with a method that cannot be defeated by wrapping: comment/blockquote markers
stripped, **all whitespace collapsed including newlines**, then matched against
**semantic ideas** rather than literal strings —

```text
canonical resource comes/came/derives/is taken from the [authorization] grant
grant (already) carries|names|supplies|provides|chooses|anchors|selects|
      determines the [canonical|operation] resource
resource identity (is) (taken) from the grant
grant is the (single) source of (canonical) resource (truth)
the one bound to the authorization decision must win        (FIX-002 framing)
DeliveryProofDisputeContext
```

**Six matches remain. None is a current API statement.**

| # | Location | Idea matched | Classification |
|---|---|---|---|
| 1 | `delivery_proof_dispute_facts.dart` | removed type | **historical-valid** — under an explicit `**Historical.**` marker |
| 2 | `delivery-proof-dispute.md` | removed type | **historical-valid** — under an explicit `**Historical.**` blockquote |
| 3 | `version-history.md` (FIX-002 block) | grant names the resource | **historical-valid** — dated changelog entry, with the FIX-003 forward pointer beside it |
| 4 | `version-history.md` (FIX-004 entry) | grant supplies the resource | **descriptive-valid** — reported speech describing the defect FIX-004 corrected |
| 5 | `version-history.md` (FIX-002 block) | removed type | **historical-valid** — same dated block as #3 |
| 6 | `version-history.md` (FIX-003 entry) | removed type | **descriptive-valid** — FIX-003's account of what it corrected |

`delivery_proof_dispute_evaluator.dart` now matches **nothing**.

**Positive consistency** — every current API location states the same model:

```text
delivery_proof_dispute_evaluator.dart:49   "canonical resource is the stored dispute aggregate's"
delivery_proof_dispute_evaluator.dart:300  "anchored by the stored dispute aggregate"
delivery_proof_dispute_evaluator.dart:332  "the canonical resource is the stored dispute's"
delivery_proof_dispute_facts.dart:60       "persisted dispute aggregate anchors the canonical operation resource"
delivery-proof-dispute.md:339              "persisted dispute aggregate supplies the canonical resource anchor"
```

…describing `final String resourceId = dispute.resourceId;` at lines **119**
(raise) and **333** (review).

**D2A left alone.** `delivery_proof_assessment.dart:31` and
`delivery-proof-assessment.md:97` describe a "server-resolved context" for
**D2A**, where `DeliveryProofAssessmentContext` still exists (verified present).
Accurate, and untouched — `git diff` against `45d21e9` shows no D2A change.

## 6. Files changed

| Path | Change |
|---|---|
| `packages/contracts/lib/src/delivery_proof_dispute_evaluator.dart` | **doc comment only** — corrected anchor statement |
| `docs/task-ledger/FND-003D2B-FIX-004-completion-report.md` | **appended** correction of its §4 sweep claim; nothing rewritten |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-005 recorded; candidate is now six commits |
| `docs/task-ledger/FND-003D2B-FIX-005-completion-report.md` | **new** — this report |

`docs/contracts/delivery-proof-dispute.md` and `version-history.md` were **not**
touched: the sweep found no current inaccurate statement in either.

## 7. Zero executable Dart change

```text
$ git diff --name-only -- '*.dart'
packages/contracts/lib/src/delivery_proof_dispute_evaluator.dart

# comments and blank lines stripped from both sides:
  executable code IDENTICAL (217 code lines)
  sha256 before: 669db4e74642a4ed1bc239f25ba17240c9d6854e2cd610e7aee04c5bb95c7430
  sha256 after : 669db4e74642a4ed1bc239f25ba17240c9d6854e2cd610e7aee04c5bb95c7430

$ git diff -- '*.dart' | grep '^[+-]' | grep -v '^[+-]\s*\(///\|//\)' | grep -v '^[+-]\s*$'
  none

$ git diff --check
  EXIT=0
```

Identical SHA-256 on the comment-stripped source. No test, fixture, export,
request shape, permission, `OrderLifecycleFacts` or authorization-logic change.

## 8. Validation

All executed against this working tree; outputs and exit codes are in the
handoff summary. The runtime suites are unchanged and serve as regression
evidence that a documentation-only correction disturbed nothing.

## 9. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 all
NOT RUN.** B3-C1 remains contract-test evidence only; **B3-C2 NOT RUN /
FUTURE**. FND-003B3B **NOT STARTED**; FND-003C **BLOCKED on O6**; **O7
outstanding**. **D2A criterion 48 remains FAIL** under its one-time
pre-publication exception and was not used as precedent. The local repository
gate is **not GitHub CI** — no CI ran.

## 10. Preserved

- Canonical resource anchor = `DeliveryProofDisputeFacts.resourceId`; the grant
  **proves coverage** of it and does not choose it; `checkDisputeAuthorization`
  still receives `expectedResourceId`; no
  `grant.covers(..., resourceId: grant.resourceId)` tautology.
- Raise still requires `assessment.resourceId == dispute.resourceId` and
  `DeliveryProofDisputeOrderRead.resourceId == dispute.resourceId`.
- Review remains request + actor + admin grant + dispute only; resolve remains
  zero-argument and always `resolutionPolicyDeferred`.
- No `DeliveryProofDisputeContext` in the current executable API; no
  `reviewerIsRaiser`; `basisFrom` absent.
- `Permission.values` and `permissionMatrix` remain **38**; exactly two dispute
  events; every commercial/assignment/assessment effect **NONE**; `delivered`,
  customer custody and rider completion unreachable.
- FIX-001, FIX-002 and FIX-003 regressions intact.
- **ContractVersion 0.9**; no serialization, no migration.

## 11. Status

| Task | Status |
|---|---|
| **FND-003D2B** | **PARTIAL / FIX REQUIRED / NOT ACCEPTED** — six-commit chain awaiting a new separate read-only final review |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — **O6**, FND-003C, FND-003B3B |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

Nothing was pushed, merged, deployed or turned into a PR; no GitHub setting or
Firebase resource was touched. `CONSTRAINTS.md` invariant 13 is still **not**
discharged.

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.
