# FND-003C1-FIX-002 completion report

- **Task:** Correct the `permission-matrix.md` contract-version header and add a
  regression guard so the same drift cannot recur silently.
  **Documentation and test only.**
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Base:** `origin/main` @ `596413c2e51fe5540bde9fce38fab3b0201bcebc`
- **Branch:** `fnd/FND-003C1-fix-002-permission-doc-version` (new, from `596413c2`)
- **Commit:** reported **out of band** — a commit cannot contain its own SHA, and
  **no amend was used to insert one**
- **Contract version:** **0.11 — unchanged.** `ContractVersion.current` was
  already correct; the **document** was wrong. Nothing in this task touches the
  executable version.
- **Status:** **DONE — technically accepted** by
  **FND-003C1-FIX-002-FINAL-REVIEW-002**, which returned **ACCEPTED** with no
  material defect. Accepted technical commit:
  **`e90f2ec16ac4c1b2997052f242127be452284955`**. This report states no
  current publication claim in either direction — whether that commit is on
  `main` is a property of git history, not of this sentence, and history is
  the authority.

## 1. Baseline

```text
git fetch origin --prune                       exit 0
git status --porcelain --untracked-files=all   (empty)
git rev-parse origin/main                      596413c2e51fe5540bde9fce38fab3b0201bcebc
origin/main via ls-remote                      596413c2e51fe5540bde9fce38fab3b0201bcebc
branch created from                            596413c2
ContractVersion.current                        0.11
Permission.values.length                       39
permissionMatrix.length                        39
generated table rows in the document           39
```

## 2. The defect, reproduced before editing

`docs/contracts/permission-matrix.md`, line 3:

```text
**Contract version 0.10.** Introduced by FND-003A (0.2) and extended by ...
```

`packages/contracts/lib/src/contract_version.dart`:

```dart
static const ContractVersion current = ContractVersion(0, 11);
```

The canonical permission document declared a contract version **one minor behind
the executable contract**. FND-003C1 moved 0.10 → 0.11 and did not carry this
header with it.

## 3. Why it drifted — the part worth recording

This header is unlike every other contract document's. The others carry a
**fixed origin stamp**:

```text
delivery-proof-boundary.md   "**Introduced at contract version 0.7** (FND-003D1)"
custody-lifecycle.md         "**Contract version 0.6** (FND-003B3A)"
order-reservation-lifecycle  "**Contract version 0.3** (FND-003B1)"
```

Those name the slice that introduced the document and are **correct as written**;
they are not expected to move. `permission-matrix.md` instead carries a
**running current-version** header that enumerates its own history and states a
present number — so it is the one document of its kind that *must* be advanced on
every bump, and the only one that could silently drift.

Compounding it, the drift was **invisible to inspection**: FND-003C1 added no
permission, so the table stayed at 39 rows and looked entirely consistent. A
reader checking "is this document current?" by looking at its *content* would
have concluded yes. Only the header was wrong.

## 4. The correction

```text
**Contract version 0.11.** That is the *overall* contract version, which this
header tracks. The permission vocabulary itself last changed at **0.10**:
introduced by FND-003A (0.2) and extended by FND-003B2A
(`agent.assignment.revoke_picker`), FND-003B2B
(`picker.assignment.offer_rider`, `picker.assignment.revoke_rider`) and
FND-003B3B (`agent.return.record_receipt`, the 39th) — **39 permissions**.
**FND-003C1 (0.11) added no permission**: its COD-collection slice is authorized
entirely by permissions that already existed, so the table below is byte-for-byte
what 0.10 generated. A version here that is newer than the last vocabulary change
is therefore normal and expected. This table is **generated from ...**
```

The three facts the task required are now stated separately and explicitly:
the **overall** version is 0.11; the **permission vocabulary** last changed at
**0.10** (FND-003B3B added `agent.return.record_receipt`, taking the total
permission count from **38 → 39**); **FND-003C1 added no permission**. The
last sentence exists so the next reader does not "correct" 0.11 back to 0.10 on
seeing that the vocabulary is older than the header.

> **Corrected by FND-003D1-BOOKKEEPING-FIX-002** — documentation accuracy only,
> no executable change. The parenthetical above previously read *"(FND-003B3B's
> 39th permission)"*, which conflated **the permission that took the count to
> 39** with **the 39th declared value**. They are not the same thing:
> `agent.return.record_receipt` sits at **zero-based index 12 — the 13th
> declared value**, while the 38th declared is `admin.cash.record_reconciliation`
> and the 39th is `admin.release.view_health`
> (`Permission.values.indexOf(Permission.agentRecordReturnReceipt)` → `12`,
> probed against the tree, not grepped). The chronological fact was and remains
> correct: FND-003B3B added `agent.return.record_receipt` at contract **0.10**,
> taking the total from **38 to 39**, and the live total is **39**.
>
> The same phrase survives twice more in this report and is **deliberately left
> unedited**: the quoted block above reproduces the
> `docs/contracts/permission-matrix.md` header **verbatim**, and the probe output
> below is **recorded command evidence**. Correcting either would turn a faithful
> quotation into a misquotation or falsify recorded output. The phrase originates
> in `docs/contracts/permission-matrix.md` line 8 — a contract document this task
> is **not authorized to change** — so it is recorded as **outstanding** debt in
> the ledger and needs its own task.

### The "byte-for-byte what 0.10 generated" claim is verified, not asserted

```text
table rows at cdb5f35b (FND-003B3B, where 0.10 introduced the 39th) : 39  identical=True
table rows at 789682c  (FND-003C1 implementation)                   : 39  identical=True
table rows at 596413c2 (origin/main)                                : 39  identical=True

$ dart run tool/print_permission_matrix.dart   # regenerated from source
generator rows : 39
document  rows : 39
IDENTICAL      : True
```

## 5. The regression guard

**New file:** `packages/contracts/test/permission_matrix_doc_consistency_test.dart`
(2 tests). It reads the canonical document from disk and compares its declared
version to `ContractVersion.current`.

**It hard-codes no version literal.** The expected value is derived:

```dart
final String expected = ContractVersion.current.toString();
```

so the next bump fails this test until the document follows — which is precisely
what did not happen at 0.11.

**Repository-root location is robust and deliberately decoupled from the
document under test.** It walks up to an ancestor holding **both** `AGENTS.md`
and `packages/contracts/`. Neither marker is the file being checked: an earlier
draft used the document itself as the marker, and a deleted document then
surfaced as *"repository root not found"* — the real fault hidden behind a
misleading message. That draft was corrected before commit, and both variants'
messages are shown in §6.

**No new dependency.** `dart:io` and the existing `test` package only. Reading
files from disk in a test is established convention here — 13 existing test files
already do it.

The second test guards the other half: `Permission.values` and `permissionMatrix`
are both 39, the document states the live count, and the generated table still
carries exactly one row per matrix entry. The version header and the permission
count are independent facts, and C1 moved only the first.

## 6. The guard is meaningful — four failure modes, each proven

Non-destructive throughout: the document was moved aside or mutated in place and
restored from a pre-image, with **SHA-256 verified byte-identical after every
control**. Baseline `3d36a1a856c58819ef2534f69614d978ce47dd4328a0852bba0e072d9f216c3f`.

| # | Control | Real failure message | Restored |
|---|---|---|---|
| A | **version mismatch** — the pre-fix state | `…permission-matrix.md declares contract version 0.10, but ContractVersion.current is 0.11. Update the document header when the contract version changes.` | byte-identical |
| B | **document missing** | `canonical document not found at …/docs/contracts/permission-matrix.md` | byte-identical |
| C | **declaration malformed** | `no "**Contract version <major>.<minor>**" declaration found in …; the guard cannot verify a version it cannot locate` | byte-identical |
| D | **declaration ambiguous** (a second one added) | `expected exactly one current-version declaration in …, found 2 — an ambiguous header cannot be checked` | byte-identical |

Control **A** is the decisive one: it was run **against the unmodified pre-fix
tree before any edit**, and again afterwards by reverting only the document via
`git stash`. In both directions it failed for exactly the intended reason.

Before the root-finder was decoupled, control **B** instead produced *"could not
locate the repository root from …; expected an ancestor containing both
docs/contracts/permission-matrix.md and packages/contracts"* — accurate but
pointing at the wrong cause. Recorded because the corrected message is the
difference between a guard that reports its fault and one that misdirects.

After every control the guard is green again and `git diff --stat` on the
document shows only this task's intended change.

**No published history was mutated.** Every control was a working-tree operation
on a local branch; no commit was amended, rebased, reset or force-pushed.

## 7. Portability

```text
$ dart test test/permission_matrix_doc_consistency_test.dart    # from packages/contracts
00:00 +2: All tests passed!

$ dart test packages/contracts/test/permission_matrix_doc_consistency_test.dart   # from repo root
00:00 +2: All tests passed!
```

Both invocation directories pass, which is the point of the upward search: no
absolute path and no fixed `..` count.

## 8. Files changed

| Path | Change |
|---|---|
| `docs/contracts/permission-matrix.md` | header 0.10 → 0.11 + the vocabulary/overall distinction. **Table untouched** |
| `packages/contracts/test/permission_matrix_doc_consistency_test.dart` | **new** — the regression guard (2 tests) |
| `docs/task-ledger/TASK_LEDGER.md` | one bounded FND-003C1-FIX-002 row |
| `docs/task-ledger/FND-003C1-FIX-002-completion-report.md` | **new** — this report |

**No production Dart file was touched.**

```text
$ git diff --name-only -- 'packages/*/lib/*'
  (none)
```

## 9. Validation

```text
$ cd packages/contracts && dart analyze
No issues found!                                                   EXIT=0

$ dart test test/permission_matrix_doc_consistency_test.dart
00:00 +2: All tests passed!                                        EXIT=0

$ dart test test/contract_version_test.dart
00:00 +14: All tests passed!                                       EXIT=0

$ dart test test/permission_matrix_test.dart
00:00 +23: All tests passed!                                       EXIT=0

$ dart test                                    # full contracts suite
00:01 +1153: All tests passed!                                     EXIT=0

$ git diff --check
                                                                   EXIT=0

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
No issues found! (ran in 2.1s)
--- packages/contracts --- 00:01 +1153: All tests passed!
LAYERING CHECK: PASS
ALL CHECKS PASSED                                                  EXIT=0
```

**The count moved 1151 → 1153, and that was verified rather than assumed:** the
guard file was withdrawn to the scratchpad, the suite re-run to establish
`+1151`, and the file restored byte-identically. The delta is exactly the two new
tests and nothing else — a documentation correction must not move anything else.

**GitHub CI: NONE.** `ls .github` → *No such file or directory*. No workflow
exists and none ran. The local gate is **not** CI.

## 10. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 ·
ATT1–ATT9 · RET1–RET8 · CJ1–CJ12 all NOT RUN.** B3-C1 remains contract-test
evidence only; **B3-C2 NOT RUN / FUTURE**. **O7 outstanding.** `CONSTRAINTS.md`
invariant 13 is still **not** discharged. A documentation and test correction
promotes nothing.

## 11. Preserved

- **`ContractVersion.current` remains 0.11** — unchanged, and not a target of
  this task. The document was wrong, not the code.
- `Permission.values` and `permissionMatrix` remain **39**; no permission was
  added, removed, renamed, widened or re-scoped.
- The generated 39-row table is **unchanged**, and verified identical to both its
  0.10 origin and a fresh run of the generator.
- **Zero executable contract change.** No production Dart file was modified; no
  rule, evaluator, request shape, denial, export or event id moved.
- All FND-003C1 financial behaviour is untouched.

## 12. Out of scope — recorded, not fixed

`docs/contracts/delivery-proof-boundary.md` still asserts the **old permission
count in the present tense**, in two places:

```text
:69   "**Neither FND-003D2A nor FND-003D2B added a permission**: `Permission.values`
       remains **38**."
:212  "**No permission was added** — a test pins the count at 38 for both
       `Permission.values` and `permissionMatrix`."
```

The first clause of `:69` is historically accurate — neither D2A nor D2B did add
one — but *"remains 38"* is present tense and false since 0.10. `:212` is simply
false today: the test pins **39**. Both are **stale and not corrected here**,
because this task's declared file list does not include that document and
widening scope silently is worse than recording the debt.

That document's own header, *"Introduced at contract version 0.7"*, is **correct
and must not be "fixed"** — it is an origin stamp, not a running version. The new
guard therefore targets `permission-matrix.md` **only**, and should not be
generalized to documents using the origin-stamp convention.

Other surviving `38` references were checked and are **correctly scoped**: they
appear in dated `version-history.md` entries, in slice-scoped tables in
`delivery-proof-assessment.md` and `delivery-proof-dispute.md` describing the 0.8
and 0.9 slices, and in `delivery-proof-dispute.md:345`, which already says
*"was 38 throughout that slice, and is 39 today"*.

## 13. Status

| Task | Status |
|---|---|
| **FND-003C1-FIX-002** | **DONE — technically accepted.** FND-003C1-FIX-002-FINAL-REVIEW-002 returned **ACCEPTED** on `e90f2ec16ac4c1b2997052f242127be452284955`, with no material defect and five non-blocking observations |
| FND-003C1 | **DONE** — accepted and integrated; unaffected |
| FND-003C | **PARTIAL** — remittance, settlement, reconciliation, refunds, commission payout and worker pay outstanding |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

**During the original FND-003C1-FIX-002 implementation task**, nothing was
pushed, merged, deployed or turned into a PR; no branch was deleted, no tag or
release created, no GitHub setting changed and no Firebase resource touched.
That is a record of what **that task** did, and it stays true however the
accepted commit is handled afterwards.

**The implementation task claimed no technical acceptance for itself**, and was
right not to: this report records what was changed and what was run, and
acceptance was a separate review's decision. That decision has since been made —
**FND-003C1-FIX-002-FINAL-REVIEW-002 returned ACCEPTED** — which is why the
status above records acceptance. Nothing in this report is self-certified.

## Owner actions needed

None new. **O7** remains outstanding, unchanged. The
`delivery-proof-boundary.md` permission-count debt in §12 needs a scoped task.
