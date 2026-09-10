# FND-003D2B-FIX-004 completion report

- **Task:** Correct two obsolete current-tense statements left after
  FND-003D2B-FIX-003. **Documentation and source-comment only.**
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Reviewed base:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Starting candidate HEAD:** `202a8a9661b4ac31e2d8d0e59a605fe618de517c`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract` (existing)
- **Follow-up commit:** reported **out of band** after commit creation — a
  commit cannot contain its own SHA, and **no amend was used to insert one**
- **Contract version:** **0.9 — unchanged**
- **Status:** **DONE** — the corrected **five-commit** candidate requires a
  **new, separate read-only final acceptance review**. It is **not** accepted
  for merge.

## 1. Why the FIX-003 push was correctly blocked

`FND-003D2B-FIX-003-PUSH-001` refused to publish `202a8a9`. That was the right
call, and not a technicality: the push task gated publication on a scope check —
*"current docs contain no obsolete `DeliveryProofDisputeContext` claim"* — and
that check failed. Every ref matched, the fast-forward was valid, and the
runtime correction was sound; the **documentation** contradicted the code it
described.

Publishing would have put a contract document on the branch that told a reviewer
the opposite of what the shipped evaluator does, two paragraphs apart. The push
was declined, nothing was pushed, and the working tree was left untouched.

**This was a drafting omission in FIX-003, not a defect in its code.** FIX-003
added the new binding section and left the superseded FIX-002 paragraphs beside
it.

## 2. The reproduced contradiction

Two current-tense statements claimed the **authorization grant** is the source
of the canonical resource:

```text
docs/contracts/delivery-proof-dispute.md
  "**The grant carries the canonical resource**, so `DeliveryProofDisputeContext`
   was removed: two sources of resource truth could disagree, and the one bound
   to the authorization decision must win."

packages/contracts/lib/src/delivery_proof_dispute_facts.dart
  "/// **The canonical resource comes from the authorization grant.**"
```

The shipped executable contract says otherwise, in **both** evaluators:

```dart
final String resourceId = dispute.resourceId;   // raise (l.119) and review (l.328)
...
checkDisputeAuthorization(..., expectedResourceId: resourceId);
...
if (assessment.resourceId != resourceId || !order.belongsToResource(resourceId)) { ... }
```

Both statements were accurate when FIX-002 wrote them, and were superseded by
FIX-003 — which moved the anchor precisely because comparing a grant against a
value the grant itself supplied proves nothing.

## 3. The corrected wording

**`docs/contracts/delivery-proof-dispute.md`:**

> **The persisted dispute aggregate supplies the canonical resource anchor.**
> The `AuthorizationGrant` must **cover** that exact, independently anchored
> resource — it is not itself the source used to choose it. For a raise, the
> assessment aggregate and the resource-bound order read must identify the same
> resource before any order fact can produce a transition.
>
> ```text
> dispute.resourceId                 <- the anchor
>   == AuthorizationGrant.resourceId (grant.covers, checked first)
>   == assessment.resourceId
>   == DeliveryProofDisputeOrderRead.resourceId
> ```

**`packages/contracts/lib/src/delivery_proof_dispute_facts.dart`:**

> **The persisted dispute aggregate anchors the canonical operation resource.**
> The `AuthorizationGrant` must **cover** that resource; it is not the source
> used to choose it. A raise additionally binds the assessment aggregate and the
> resource-bound order read to the same anchor, before any order fact can
> produce a transition.

In both places the superseded framing is retained only under an explicit
**Historical** marker recording that FIX-002 removed
`DeliveryProofDisputeContext` and took the resource from the grant, and that
FIX-003 moved the anchor. The removed type stays removed either way.

**The wording was checked against the code, not against the previous prose:**
anchor at `dispute.resourceId` → `checkDisputeAuthorization(expectedResourceId:
…)` → assessment and order-read equality → *then* revision, `in_delivery` and
`committed`.

## 4. Sweep for equivalent claims

All sixteen current D2B source and documentation locations were searched for
`grant (carries|names|supplies|provides) the resource`,
`canonical resource comes from the grant`, `resource identity from the grant`
and `DeliveryProofDisputeContext`. Both target claims are **gone**. Four
mentions remain and all are correct:

| Location | Why it stays |
|---|---|
| `delivery_proof_dispute_facts.dart:67` | under an explicit **Historical** marker |
| `delivery-proof-dispute.md:356` | under an explicit **Historical** blockquote |
| `version-history.md:412` | inside the **dated FIX-002 changelog block** — historical evidence. A parenthetical forward pointer to FIX-003 was **added beside it**; the original sentence was not rewritten |
| `version-history.md:436` | FIX-003's own accurate account of what it corrected |

`docs/contracts/delivery-proof-assessment.md` and
`delivery_proof_assessment.dart` mention a "server-resolved context" for **D2A**,
where `DeliveryProofAssessmentContext` still exists. Accurate; left alone.

## 5. Files changed

| Path | Change |
|---|---|
| `docs/contracts/delivery-proof-dispute.md` | corrected anchor statement + Historical note |
| `packages/contracts/lib/src/delivery_proof_dispute_facts.dart` | **doc comment only** — corrected anchor statement + Historical note |
| `docs/contracts/version-history.md` | FIX-004 entry; forward pointer beside the FIX-002 sentence |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-004 recorded; candidate is now five commits |
| `docs/task-ledger/FND-003D2B-FIX-003-completion-report.md` | **appended** recheck note; nothing rewritten |
| `docs/task-ledger/FND-003D2B-FIX-004-completion-report.md` | **new** — this report |

**One Dart file changed, comments only.**

## 6. Executable-diff proof

```text
$ git diff --name-only -- '*.dart'
packages/contracts/lib/src/delivery_proof_dispute_facts.dart

# comments and blank lines stripped from both sides:
packages/contracts/lib/src/delivery_proof_dispute_facts.dart
  : executable code IDENTICAL (64 code lines)

$ git diff -- '*.dart' | grep '^[+-]' | grep -v '^[+-]\s*\(///\|//\)' | grep -v '^[+-]\s*$'
  no non-comment line added or removed
```

**Zero executable behaviour change.** The FIX-003 runtime correction is intact:
the resource-bound order read, the completed raise binding and the removal of
the tautological `grant.covers` argument are all untouched.

## 7. Validation

Full outputs and exit codes are in §8 of the handoff summary; all were executed
against this working tree, not copied from a previous run.

## 8. Evidence status

**Unchanged by a documentation correction, and none was promoted:**

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 all
NOT RUN.** B3-C1 remains contract-test evidence only; **B3-C2 NOT RUN /
FUTURE**. FND-003B3B **NOT STARTED**; FND-003C **BLOCKED on O6**; **O7
outstanding**. **D2A criterion 48 remains FAIL** under its one-time
pre-publication exception and was not used as precedent. The local repository
gate is **not GitHub CI** — no CI ran.

## 9. Preserved

- `dispute.resourceId` remains the resource anchor; the grant must cover an
  independently supplied expected resource; assessment and order read must match
  the anchor on raise.
- Review remains **grant + dispute only**; resolve remains **zero-argument** and
  always `resolutionPolicyDeferred`.
- All order/reservation/inventory/financial/custody/picker/rider/assessment/
  scope effects remain **NONE**; only the two dispute events exist;
  `delivered`, customer custody and rider completion remain unreachable.
- `Permission.values` and `permissionMatrix` remain **38**; no permission rule,
  matrix, export, request field, aggregate field, test behaviour or
  `OrderLifecycleFacts` API changed.
- **ContractVersion.current remains 0.9**; no serialization or migration claim.

## 10. Status

| Task | Status |
|---|---|
| **FND-003D2B** | **PARTIAL / FIX REQUIRED / NOT ACCEPTED** — five-commit chain awaiting a new separate read-only final review |
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

---

# CORRECTION — THE §4 SWEEP CLAIM WAS INCOMPLETE

**Appended by FND-003D2B-FIX-005 (2026-09-11). Nothing above is rewritten.**

FND-003D2B-FINAL-REVIEW-004 found **one additional current-tense statement that
this report's §4 sweep missed**, in `delivery_proof_dispute_evaluator.dart`:

```text
/// UTC, and that review does not precede the raise. The canonical resource
/// comes from the grant.
```

That is the same defect FIX-004 set out to close, in a file §4 listed as swept.
**The §4 assertion that "both target claims are gone" was therefore true only of
the two exact strings searched for, and the broader implication — that no
equivalent current claim survived — was incomplete.** It is corrected here
rather than edited above.

## Why the sweep missed it

Not a missing file: the mechanism. §4 used a **line-based** `grep`, and the
sentence is **wrapped across two lines**. Its own regex
`canonical resource (comes|came) from the (authorization )?grant` matches the
sentence when unwrapped, and cannot match it across a newline. Demonstrated:

```text
line-based grep (the FIX-004 method) : 0 matches
unwrapping search (the FIX-005 method): 1 match
```

A prose sweep that cannot see across a line break will keep missing wrapped
prose, which is most of it.

## What changed

`FND-003D2B-FIX-005` corrects the comment and re-runs the sweep with markers
stripped and whitespace collapsed, so wrapping cannot hide a statement, and
against **semantic ideas** rather than two literal strings.

**Executable behaviour was unaffected then and now:** the missed text was a doc
comment. The FIX-003 runtime binding — `dispute.resourceId` as anchor, the grant
proving coverage, assessment and order read matching it — was correct throughout
and is unchanged.

Full detail: [FND-003D2B-FIX-005 report](FND-003D2B-FIX-005-completion-report.md).
