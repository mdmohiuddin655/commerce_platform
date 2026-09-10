# FND-003D2B-BOOKKEEPING-FIX-001 completion report

- **Task:** Reconcile the current task ledger after publication of the separate
  D2B bookkeeping commit. **Documentation only.**
- **Owner project:** ADMIN / shared foundation
- **Date:** 2026-09-11
- **Starting HEAD / remote `main`:** `c99a0e56a9a15b0af8c758a42cb20df5cd613796`
- **Accepted D2B contract tip:** `743e157fe090d4abe42df05f492854601fd68b65`
- **Contract version:** **0.9 — unchanged**
- **Status:** **DONE** — one local commit, **not pushed**, returned for a
  separate read-only recheck/publication decision.

## 1. Preconditions

```text
git fetch origin --prune                       exit 0
git status --porcelain --untracked-files=all   (empty)
branch                                         main
local HEAD                                     c99a0e56a9a15b0af8c758a42cb20df5cd613796
origin/main (tracking and ls-remote)           c99a0e56a9a15b0af8c758a42cb20df5cd613796
HEAD^                                          743e157fe090d4abe42df05f492854601fd68b65
feature branch (ls-remote)                     743e157fe090d4abe42df05f492854601fd68b65
```

All seven accepted commits resolve unchanged: `b94e5424`, `ded1aa79`,
`f04d453`, `202a8a9`, `45d21e9`, `cc0c1ae`, `743e157`.

## 2. Why these three statements were drifting

Each was **true when written and falsified by a later, legitimate event** — the
worst kind of ledger error, because nothing looks wrong at the point of writing.

1. *"`main` is now `743e157`"* was accurate for about one task. Publishing the
   bookkeeping commit made it false. **A ledger sentence that pins a moving ref
   to a fixed SHA is self-invalidating by construction.**
2. The **O7** row said branch protection was *"unverified — no GitHub evidence
   was gathered."* Evidence has since been gathered.
3. The **0.9** wire-contract row described the D2B surface as first drafted at
   `b94e5424`: a `DeliveryProofDisputeContext`, one shared request and one
   `evaluateDeliveryProofDispute`. FIX-001 split the evaluator and FIX-002
   deleted the context, but the summary row was never revisited — so the
   ledger's *own* API summary described a contract that was corrected five
   commits before acceptance.

## 3. Correction 1 — integration status, worded so it cannot go stale

The D2B row and the MERGE-001 narrative now say the **accepted contract tip is
`743e157`**, that MERGE-001 integrated it into `main`, and that **`c99a0e5` is a
separate documentation-only bookkeeping child that is not part of the accepted
seven-commit chain**. The narrative states the reading rule explicitly:

> Read "`main` is at the accepted tip **plus documentation**", never "`main`
> equals the accepted tip".

**No current statement claims `main` equals `743e157`.** The surviving mentions
are the dated past-tense record of what MERGE-001 did, the chain diagram, the
parent statement, and the acceptance anchor — all correct and none of them a
claim about where `main` points now. **This report's own commit SHA is
deliberately absent from the ledger prose**, for exactly the reason above.

## 4. Correction 2 — O7 now carries dated evidence, and stays outstanding

The O7 row records the authenticated GitHub REST inspection of **2026-09-11**:
`main.protected = false`, branch-protection endpoint **404 "Branch not
protected"**, **rulesets collection empty**, `/rules/branches/main` **0
effective rules**, **0 workflows and 0 runs**.

It also records **why the negative is conclusive**: that endpoint returns 404
both when a branch is unprotected *and* when the caller lacks admin, so the row
notes the querying token holds `admin: true` and the owner is a **User**, which
rules out organization rulesets.

**O7 remains OUTSTANDING.** Verifying that governance is absent is not
configuring it, and the row says so in those words. **No CI passed** — there is
no CI. `run_checks.sh` remains **local evidence only**. The MERGE-001 block's
honest *"NOT INSPECTED this time"* note was **not rewritten**; a dated
`Superseded on 2026-09-11 (not rewritten)` blockquote was added beneath it.

## 5. Correction 3 — the 0.9 row now matches the accepted API

`context`, the single shared `request` and `evaluateDeliveryProofDispute` were
removed from the **current** summary, which now describes the real surface:
per-operation `DeliveryProofDisputeRaiseRequest` / `DeliveryProofDisputeReviewRequest`,
the resource-bound `DeliveryProofDisputeOrderRead`, the three evaluators
`evaluateRaiseDeliveryProofDispute`, `evaluateRecordDeliveryProofDisputeReview`
and zero-argument `evaluateResolveDeliveryProofDispute`, and authorization bound
through `AuthorizationGrant` / `checkDisputeAuthorization` proving **coverage**
of the resource anchored by `DeliveryProofDisputeFacts.resourceId`. **20**
denials retained.

A short parenthetical records what the earlier draft claimed and that **none of
it exists in the accepted contract**, so the obsolete names are not re-added
later as a perceived gap. Canonical sources are **referenced, not duplicated** —
`docs/contracts/delivery-proof-dispute.md` and the `cp_contracts` barrel remain
the single source of truth. Every symbol in the new wording was verified to
exist in `packages/contracts/lib/`.

## 6. Semantic search and classification

| Symbol / phrase | Occurrences | Classification |
|---|---|---|
| `` `main` is now `743e157` `` | **0** | removed |
| `743e157` elsewhere | 7 | dated past-tense merge record, chain diagram, parent, acceptance anchor — all **current-valid** |
| `c99a0e5` | 2 | both explicitly **separate bookkeeping, not accepted contract** |
| `DeliveryProofDisputeContext` | 2 | L522 FIX-002 block (*"was removed"*) and the 0.9 parenthetical (*"none of those exist"*) — both **clearly historical** |
| `evaluateDeliveryProofDispute` | 1 | the same 0.9 parenthetical — **clearly historical** |
| O7 / branch protection | dated 2026-09-11 evidence | **outstanding**, not promoted |

In `packages/contracts/lib/` the lone `evaluateDeliveryProofDispute` is a doc
comment marked *"Restructured by FND-003D2B-FIX-001"*; comment-stripped it is
**0**, and `class DeliveryProofDisputeContext` is **0**. Source is unchanged by
this task either way.

## 7. Nothing was lost

Status-token counts, committed vs. working tree: `NOT RUN` 19→19, `NOT STARTED`
1→1, `BLOCKED` 6→6, `TODO` 10→10, `FUTURE` 4→4, `DPD1` 5→5, `DPA1` 7→7,
`CA1–CA23` 3→3, `R33` 4→4, `L1–L13` 1→1, `P1–P17` 1→1, `RA1` 4→4, `B3-C1` 4→4,
`B3-C2` 7→7, `criterion 48` 3→3, `invariant 13` 6→6, `FND-003B3B` 3→3, `O6` 9→9,
`0.9` 16→16. `O7` 3→4 — the one addition is the new dated forward pointer.

## 8. Validation

```text
git diff --check                    EXIT=0
changed files                       docs/task-ledger/TASK_LEDGER.md
                                    docs/task-ledger/FND-003D2B-BOOKKEEPING-FIX-001-completion-report.md
non-docs/task-ledger changes        0
ContractVersion.current             ContractVersion(0, 9)

$ ./tools/run_checks.sh
ALL CHECKS PASSED                   EXIT=0     (local evidence only — NOT CI)
```

**GitHub CI: NONE** — 0 workflows and 0 runs, confirmed against the live API.

## 9. Preserved

FND-003D2B **DONE / ACCEPTED AND INTEGRATED**; FND-003D **PARTIAL**;
FND-003B3B **NOT STARTED**; FND-003C **BLOCKED on O6**; FND-004 **TODO**;
**O6** and **O7** outstanding; **D2A criterion 48 FAIL** under its one-time
pre-publication exception; **DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 ·
L1–L13 · P1–P17 · RA1–RA18 all NOT RUN**; **B3-C1** contract-test evidence only;
**B3-C2 FUTURE**; `CONSTRAINTS.md` **invariant 13 not discharged**; delivery
confirmation **unavailable**.

Contract behaviour untouched: anchor `DeliveryProofDisputeFacts.resourceId`,
grant proves coverage only, four-way raise binding, narrow review read-set,
zero-argument deferring resolve, no executable `DeliveryProofDisputeContext`,
**20** denials, `Permission.values` / `permissionMatrix` **38**, two dispute
events, all D2B commercial effects **NONE**, no serialization or migration,
successful delivery **non-executable**.

## 10. Process

One normal documentation-only commit on top of `c99a0e5`. **No** amend, rebase,
squash, cherry-pick, merge, `reset --hard`, force-push or history rewrite; **no**
branch deleted or modified; **no** PR, tag, release, deployment, GitHub-setting
change or Firebase/live-data access; **no** roadmap task started. **Not pushed** —
returned for a separate read-only recheck/publication decision.

## Owner actions needed

None new. **O6** and **O7** remain outstanding — O7 now with dated evidence that
it is unconfigured.
