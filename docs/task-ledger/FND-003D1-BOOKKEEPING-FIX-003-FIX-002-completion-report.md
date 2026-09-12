# FND-003D1-BOOKKEEPING-FIX-003-FIX-002 completion report

- **Task:** final semantic closure sweep. Correct the known stale statement in the
  FND-003C1-FIX-002 report about `delivery-proof-boundary.md`, and time-scope every
  other mechanically stale present-tense claim in the two audited historical
  reports, without altering any quotation or captured output.
- **Owner:** ADMIN / task-ledger governance.
- **Baseline `origin/main`:** `4b22173227957b86994a3b95a6232ff03f766527`, verified
  by both `git rev-parse origin/main` and `git ls-remote origin refs/heads/main`,
  and unchanged by this task.
- **Starting HEAD / parent of this commit:**
  `41d3eda5150cd2c8ad7bdd73221f28b473e3f9fa` (single parent; no earlier commit
  amended).
- **Branch:** `fnd/FND-003D1-bookkeeping-fix-003-permission-root-debt`.
- **Scope:** report and ledger prose only. **Zero executable, test and contract
  change.**

---

## 1. Files changed — exactly four

| # | File | Change |
|---|---|---|
| 1 | `docs/task-ledger/FND-003C1-FIX-002-completion-report.md` | §5, §8, §12 and *Owner actions* time-scoped; all preserved blocks byte-identical |
| 2 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-FIX-001-completion-report.md` | §6's recorded-item passage and §10 row updated; sweep table framed as that task's sweep |
| 3 | `docs/task-ledger/TASK_LEDGER.md` | report-staleness debt discharged; one new row |
| 4 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-FIX-002-completion-report.md` | this report (new) |

Untouched and mechanically confirmed: every contract document, every Dart, test
and `lib/` file, `AGENTS.md`, every ADR, `SHARED_BLUEPRINT.md`, `CONSTRAINTS.md`
and `CONTRIBUTING.md`.

---

## 2. The known stale sentence (scope A)

`docs/task-ledger/FND-003C1-FIX-002-completion-report.md`, §12 heading and opening:

```diff
-## 12. Out of scope — recorded, not fixed
-
-`docs/contracts/delivery-proof-boundary.md` still asserts the **old permission
-count in the present tense**, in two places:
+## 12. Out of scope for this task — recorded here, corrected later
+
+**At the time of the original FND-003C1-FIX-002 task**,
+`docs/contracts/delivery-proof-boundary.md` still asserted the **old permission
+count in present-tense prose**, in the two places quoted below.
+**FND-003D1-BOOKKEEPING-FIX-001 later corrected that document and added a derived
+consistency guard**, so the debt recorded in this section has since been
+discharged. The quotation below is preserved **exactly as captured**: it is
+evidence of what that document said when this task ran, not a claim about the
+document today. Task and commit history is the authority on when each change
+landed.
```

The analysis paragraph beneath the quotation was re-tensed the same way, and now
records the outcome rather than implying an open debt:

```diff
-The first clause of `:69` is historically accurate — neither D2A nor D2B did add
-one — but *"remains 38"* is present tense and false since 0.10. `:212` is simply
-false today: the test pins **39**. Both are **stale and not corrected here**,
-because this task's declared file list does not include that document and
-widening scope silently is worse than recording the debt.
+The analysis this task recorded of those two quoted lines stands: the first clause
+of `:69` was historically accurate … and `:212` was false as written because the
+test pinned **39**. Both were **stale and deliberately not corrected by this
+task** … Neither sentence survives in that document:
+**FND-003D1-BOOKKEEPING-FIX-001** replaced both with chronological wording and
+guarded the claim with a derived regression test.
```

And the *Owner actions needed* line, which still asked for a task:

```diff
-The `delivery-proof-boundary.md` permission-count debt in §12 needs a scoped task.
+The `delivery-proof-boundary.md` permission-count debt recorded in §12 needed a
+scoped task when this report was written; **FND-003D1-BOOKKEEPING-FIX-001 has since
+discharged it**, and no owner action remains for it.
```

Current-tree verification behind this: `grep -nE '\b(38|39)\b'` over
`docs/contracts/delivery-proof-boundary.md` returns only correct chronological
wording — `38 → 39` transitions at lines 51, 92 and 93, *"is not 38 either:
FND-003B3B took it to 39 at 0.10"* at 243, and **Permission count: 39** at 247.
Neither quoted sentence survives.

---

## 3. The comprehensive sweep (scope B)

Every prose sentence in the two audited reports carrying current-state language
(*still, remains, currently, now, outstanding, not fixed, needs, future/later task,
unchanged, current, today, at present, is not authorized, has no, pending,
awaiting, published, not published, local only*) was classified, and every
present-tense **repository** claim was checked against the tree at HEAD.

### Stale, and corrected — seven claims

| # | Report / section | Claim as it stood | Current truth | Fix |
|---|---|---|---|---|
| 1 | FIX-002 §12 opening | `delivery-proof-boundary.md` *"still asserts the old permission count in the present tense"* | corrected by FND-003D1-BOOKKEEPING-FIX-001 | time-scoped (§2) |
| 2 | FIX-002 §12 analysis | *"Both are stale and not corrected here"*, *"`:212` is simply false today"* | neither sentence survives in that document | re-tensed, outcome named (§2) |
| 3 | FIX-002 *Owner actions* | that debt *"needs a scoped task"* | discharged | time-scoped (§2) |
| 4 | FIX-002 §5 opening | guard file *"(2 tests)"* | the file carries **9** tests in three groups | marked *"as created by this task"* + a time-scoping note naming FND-003D1-BOOKKEEPING-FIX-003 |
| 5 | FIX-002 §5 closing | *"The second test guards the other half"* | no longer the second test **in the file**; unchanged and still present | scoped to *"the second of this task's two tests"*, with the change named |
| 6 | FIX-002 §5 | *"13 existing test files already do it"* | **15** today | *"13 … did so when this task ran, and more do now; the convention is the point, not the count"* |
| 7 | FIX-002 §8 table | *"the regression guard (2 tests)"* | same file, since extended | *"(2 tests as created by this task; later extended — see §5)"* |

Counts 4–7 were found by this sweep rather than handed over, which is why the task
brief's instruction not to stop at the one known sentence mattered.

### Checked and accurate — left untouched

| Claim | Verification at HEAD |
|---|---|
| §3's three origin stamps — `delivery-proof-boundary.md` 0.7, `custody-lifecycle.md` 0.6, `order-reservation-lifecycle.md` 0.3 — *"correct as written"* | all three present at line 3 of their documents |
| §3: `permission-matrix.md` carries a *"running current-version"* header | still the only such header |
| §4 annotation: *"the chronological fact was and remains correct"*; index 12 / 13th declared; 38th `admin.cash.record_reconciliation`; 39th `admin.release.view_health` | live probe |
| §5: root-finder walks to an ancestor holding both `AGENTS.md` and `packages/contracts/` | unchanged in the file |
| §5/§12: the generated table *"still carries exactly one row per matrix entry"* | guard test asserts rows == `permissionMatrix.length` |
| §9: *"GitHub CI: NONE"*, no `.github` | no `.github` directory exists |
| §10: DPD1–DPD12 and DPA1–DPA18 **NOT RUN**; *"O7 outstanding"*; `CONSTRAINTS.md` invariant **13** *"still not discharged"* | invariant 13 (*customer OTP/proof and fallback dispute before delivery confirmation is coded*) is undischarged — successful delivery remains not executable; ledger records both id sets NOT RUN |
| §11: `ContractVersion.current` remains **0.11**; `Permission.values` and `permissionMatrix` remain **39** | live probe |
| §12: `delivery-proof-dispute.md:345` *"already says «was 38 throughout that slice, and is 39 today»"* | that sentence is present (with markdown emphasis) — a faithful paraphrase, **not** stale |
| §12: other surviving `38`s are slice-scoped | `version-history.md` 6, `delivery-proof-assessment.md` 1 (slice table), `delivery-proof-dispute.md` 2 (slice table + the sentence above) |
| §13 status table: FND-003C **PARTIAL**, FND-003D **PARTIAL** (*"proof-satisfaction policy is still undone"*), FND-004 **TODO**, O7 **outstanding** | every one matches its ledger row |
| FIX-003-FIX-001 §5/§8/§9: O7 outstanding; `a011add4` unamended and this chain's parent; 0.11; 39/39 | git and live probe |

### Not repository claims — excluded from correction by design

Preserved quotations (FIX-002 §4's `permission-matrix.md` header, §12's two
`delivery-proof-boundary.md` lines), captured command output (§4's probe block,
§7's and §9's `dart test` and gate transcripts), commands, and the `-`/`+` diff
blocks in the FIX-003-FIX-001 report — all left byte-identical. Where such a block
sits next to corrected prose, the surrounding text now says explicitly that it is
evidence of an earlier state rather than a current claim.

One count-and-heading table needed the same treatment: the FIX-003-FIX-001 report's
§6 sweep table quotes the old §12 heading and gives occurrence counts that were
true when it was written. It is now framed as *"the sweep as performed during this
task"*, naming this follow-up as the later re-sweep, so its figures cannot be read
as current.

### No business-policy judgement was required

Every correction above was settled by mechanical repository history — a `grep`, a
file's contents, a live probe, or a ledger row. Nothing turned on an undecided
policy question, so there was no reason to stop.

---

## 4. The FIX-003-FIX-001 report (scope C)

Its *"Recorded, not fixed"* passage became *"Found here, outside this task's
authorization, and since corrected"*, recording durably that the item was
**discovered during FND-003D1-BOOKKEEPING-FIX-003-FIX-001**, that fixing it was
outside that task's narrow authorization, that
**FND-003D1-BOOKKEEPING-FIX-003-FIX-002 subsequently corrected it**, and that **no
follow-up remains required for that debt**. Its §10 row is marked discharged and
`closed`. Neither statement says whether any commit is on any branch.

---

## 5. Ledger (scope D)

- **FND-003D1-BOOKKEEPING-FIX-003-FIX-001 row:** the discovery record is preserved
  and now ends **REPORT-STALENESS DEBT, DISCHARGED by
  FND-003D1-BOOKKEEPING-FIX-003-FIX-002**, stating what that task's sweep found,
  why its authorization did not extend to fixing it, and that the quoted evidence
  was left byte-identical.
- **One new row** for `FND-003D1-BOOKKEEPING-FIX-003-FIX-002`.
- One hunk, `@@ -55 +55,2 @@`. No unrelated task status and no owner-action row
  touched; **O7 remains OUTSTANDING** (zero diff lines on the O7 row).
- No mutable publication-state prose: *published*, *not published*, *pending
  publication*, *awaiting publication*, *unpublished* and *local only* each occur
  **0** times across every line this task adds.

```text
task rows: 40 at 41d3eda, 41 in the worktree
38a39
> FND-003D1-BOOKKEEPING-FIX-003-FIX-002 :: **DONE**
```

Exactly one new row; every pre-existing `ID :: Status` pair byte-identical.

---

## 6. Preserved evidence — byte comparisons

Hashed before any edit and again afterwards:

```text
FIX-002 §4  permission-matrix.md header quotation
  05ef90d7b1f707488486d6e6f11709b93a1f9e6dda748e2eb322c82d45d73b71  →  unchanged

FIX-002 §4  captured probe / command output
  5b92b3ca9c75bb9d3cdee4863ec2ec88e372ad7ed9de27ef91bdca9781f17175  →  unchanged

FIX-002 §12 quoted delivery-proof-boundary.md lines (:69 and :212)
  e07bd75160ea8405155f68111b9d4f38cd9a4fa832273705368a2580837f906e  →  unchanged
```

`diff` on each pair is empty. Every other captured transcript is also untouched —
§7's `00:00 +2: All tests passed!` and §9's `00:01 +1153: All tests passed!` still
read exactly as recorded, even though the suite now reports **1162**, because they
are that task's output and not a claim about today.

---

## 7. No known stale present-tense claim remains in the audited scope

After the corrections, every `still` / `remains` / `outstanding` / `needs` /
`today` occurrence in the two audited reports resolves to one of: an explicitly
historical statement naming its task; a preserved quotation or captured output; a
durable invariant; or a current fact verified above. The inventory in §3 is
complete for the swept vocabulary, and **no debt within this audited scope is
carried forward**.

---

## 8. Validation

```text
$ git status --short          # before edits
(empty — clean)

$ git rev-parse origin/main
4b22173227957b86994a3b95a6232ff03f766527
$ git ls-remote origin refs/heads/main
4b22173227957b86994a3b95a6232ff03f766527	refs/heads/main

$ git rev-parse HEAD          # before edits
41d3eda5150cd2c8ad7bdd73221f28b473e3f9fa

$ git diff --check
CLEAN
```

Contract facts, probed live:

```text
ContractVersion.current  = 0.11
Permission.values.length = 39
permissionMatrix.length  = 39
```

Both contract documents' count wording, read from the tree:

```text
permission-matrix.md      "…which took the total from **38 → 39**) — **39 permissions**."
delivery-proof-boundary.md  "take the permission count **38 → 39** at 0.10"; "Permission count: 39"
```

Tests — unchanged by this task, re-run to prove the prose edits break nothing:

```text
$ dart test test/permission_matrix_doc_consistency_test.dart
00:00 +9: All tests passed!

$ cd packages/contracts && dart test
00:01 +1162: All tests passed!

$ ./tools/run_checks.sh
LAYERING CHECK: PASS
workspace members declared : 15
members with tests run     : 10
members with NO TESTS      : 5
ALL CHECKS PASSED
(exit code 0)
```

---

## 9. What was NOT run

- **GitHub / hosted CI: NOT RUN.** No `.github` directory exists, so no hosted
  workflow could run. **O7 remains OUTSTANDING.** The local gate is not CI.
- **No push.** Nothing was pushed, force-pushed, amended, rebased, merged, squashed
  or cherry-picked; `4b22173`, `a011add4` and `41d3eda` are all unamended and
  `41d3eda` remains this commit's parent. No tag or release was created. No
  deployment, no Firebase or live-data access, no settings change.
- **Migration / rollback: not applicable.** No schema, contract or behaviour
  changed. Rollback is `git revert` of this single commit.

---

## 10. What remains

| Item | Owner |
|---|---|
| O7 — hosted CI does not exist (no `.github`) | FND-004 |

Nothing else. The three debts this chain opened — the root ordinal wording, the
relabelling of the older report's annotation, and that report's stale
delivery-proof-boundary status prose — are each discharged and recorded as such in
the ledger.

---

## 11. Owner actions needed

One fresh independent read-only review of the local chain

```text
4b22173227957b86994a3b95a6232ff03f766527
→ a011add4d01fa5073e958b24021d4b6d9045e10f
→ 41d3eda5150cd2c8ad7bdd73221f28b473e3f9fa
→ <this commit>
```

before any publication decision. No owner action is required for the content
itself: zero executable, test and contract change, and the full gate passes.
