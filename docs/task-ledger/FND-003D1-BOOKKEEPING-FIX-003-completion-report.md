# FND-003D1-BOOKKEEPING-FIX-003 completion report

- **Task:** correct the root ordinal conflation in
  `docs/contracts/permission-matrix.md`, strengthen the document-consistency
  guard so it cannot silently return, and repair two unreproducible evidence
  claims in the FND-003D1-BOOKKEEPING-FIX-002 completion report.
- **Owner:** ADMIN / shared contracts and governance.
- **Baseline:** `origin/main` @ `4b22173227957b86994a3b95a6232ff03f766527`
  (verified by both `git rev-parse origin/main` and
  `git ls-remote origin refs/heads/main`).
- **Branch:** `fnd/FND-003D1-bookkeeping-fix-003-permission-root-debt`, created
  from that exact baseline.
- **Scope:** documentation and one test file. **Zero production change.**

---

## 1. The three debts

| # | Debt | Where it was recorded | Status |
|---|---|---|---|
| 1 | `agent.return.record_receipt` called *"the 39th"* — a declaration-order claim — in the canonical permission matrix | Ledger row for FND-003D1-BOOKKEEPING-FIX-002 (*"Newly found debt, NOT fixed here and out of scope"*) and §7 of its report | **DISCHARGED** |
| 2 | That report's §7 pointed at *"the recorded probe output at line 101"* although its committed position was line 123 | Raised as a non-blocking observation by the independent **FND-003D1-BOOKKEEPING-FIX-002-FINAL-REVIEW-001**; deferred at **FND-003D1-BOOKKEEPING-FIX-002-PUBLISH-001** | **DISCHARGED** |
| 3 | That report's §4 gave `base rows: 42   now rows: 43` with no stated extraction, so the totals could not be reproduced | Same review; same deferral | **DISCHARGED** |

Debt 1 is the root: the wording originated in the contract document, the
FND-003C1-FIX-002 report quoted it, and the quotation is how it spread. Debts 2
and 3 had not previously reached the ledger at all; their discovery is recorded
above and in the new ledger row.

---

## 2. Debt 1 — the root contract wording (scope A)

### Mechanical evidence first

Probed with `Permission.values.indexOf`, not grepped — reading a `grep -n` file
line number as an ordinal is what caused the original error:

```text
ContractVersion.current            = 0.11
Permission.values.length           = 39
permissionMatrix.length            = 39
agentRecordReturnReceipt index     = 12  (zero-based)
agentRecordReturnReceipt ordinal   = 13th declared
index 37 (38th declared)           = admin.cash.record_reconciliation
index 38 (39th declared)           = admin.release.view_health
enum name at index 12              = agentRecordReturnReceipt
```

So `agent.return.record_receipt` is the **13th declared** value. It is the
permission that took the **count** from 38 to 39, and the 39th declared value is
`admin.release.view_health`. The chronology is independently confirmed by the
contract source itself —
[contract_version.dart](../../packages/contracts/lib/src/contract_version.dart)
records under **0.10** (FND-003B3B): *"one new permission,
`agent.return.record_receipt`, so `Permission.values` and `permissionMatrix` go
**38 -> 39**"*.

### Before → after

`docs/contracts/permission-matrix.md`, the vocabulary-history sentence of the
header:

```diff
-FND-003B3B (`agent.return.record_receipt`, the 39th) — **39 permissions**.
+FND-003B3B (`agent.return.record_receipt`, which took the total from
+**38 → 39**) — **39 permissions**.
```

What is preserved, deliberately:

- **the 0.10 attribution** — the same sentence still opens *"The permission
  vocabulary itself last changed at **0.10**"*, and FND-003B3B is still named as
  the slice that added the permission;
- **the total** — `**39 permissions**` is unchanged, and the derived guard below
  still requires it;
- **all historical version information** — the FND-003A (0.2), FND-003B2A and
  FND-003B2B entries and the FND-003C1 (0.11) "added no permission" sentence are
  untouched;
- **no declaration-order claim replaces the old one.** The new wording is a
  total-count transition, which cannot be read as a position.

Nothing else in the document changed: one hunk, one line replaced by two.

---

## 3. Debt 1 — the guard (scope B)

**File:** `packages/contracts/test/permission_matrix_doc_consistency_test.dart`
(the existing guard, extended). No production Dart was touched.

### Design

Three top-level pure functions, so the checks can be run against any text — the
real document, or a fixture outside the worktree:

| Function | What it does |
|---|---|
| `permissionMatrixProse(markdown)` | returns the document's prose with fenced code blocks and generated table rows removed |
| `declarationOrdinalsIn(prose)` | every `\d+(st\|nd\|rd\|th)` in the prose — a claim about position in `Permission.values` |
| `countTransitionsIn(prose)` | every `[from, to]` transition — `38 → 39`, `38 -> 39`, `38 to 39` |

Two document-level tests use them:

1. **`its prose attaches no declaration ordinal to the vocabulary`** — the prose
   must contain no numeric ordinal at all. This is the smallest generic rule that
   catches the whole defect class: this document neither derives nor regenerates
   declaration positions, so it has no way to keep such a claim true.
2. **`a count change is recorded as a transition to the live total`** — the prose
   must record a transition whose target equals `Permission.values.length` and
   whose source is smaller. This is what forces a count change to be expressed as
   a total-count movement rather than as the position of the value added.

Against each requirement:

- **no current total hard-coded as the source of truth** — the expected target is
  `Permission.values.length`, read live; the guard contains no `39`;
- **no dependence on the source declaration position** — neither function reads
  `permission.dart` or any index;
- **no coupling to a Markdown line number** — both work on the whole prose;
- **existing derived checks preserved** — the version test, the
  `**${Permission.values.length} permissions**` containment test and the
  table-row-count test are unchanged;
- **legitimate historical wording accepted** — `38 → 39`, `38 to 39` and
  `38 -> 39` carry no ordinal suffix, so none is flagged; a truthful statement
  that a permission increased the total count is exactly the required form;
- **clear failure messages** — each names the offending ordinal(s) or the
  transitions actually found, explains that "the 39th" meant the permission that
  moved the *count* while the 13th value was *declared* there, and states the two
  acceptable forms.

Markdown emphasis is stripped before transition matching so a bolded
`**38 → 39**` counts. A lookbehind rejects a dotted neighbour so a version range
such as `0.10 to 0.11` is never mistaken for a count transition; the lookahead
rejects only a decimal continuation, so a sentence-final `38 → 39.` still counts.

### Negative and positive controls

`AGENTS.md` §6: a guard that has never been shown to fail proves nothing. Five
control tests run the same functions over fixtures written to
`Directory.systemTemp`, never into the repository tree:

| Control | Fixture | Expected |
|---|---|---|
| pre-fix wording rejected | the published line verbatim, `…, the 39th) — **39 permissions**.` | ordinals = `[39th]` |
| corrected wording accepted | built from the live count: `…took the total from **38 → 39**) — **39 permissions**.` | no ordinals, transition to live total present |
| historical transitions are not ordinal errors | `go **38 → 39**`, `from 38 to 39`, `rose 38 -> 39` | no ordinals; all three parsed as `38 -> 39` |
| a version range is not a count transition | `moved 0.10 to 0.11` | no transitions |
| the generated table is not searched | a table row containing *"Only the 1st attempt."* | no ordinals |

### The end-to-end control: the real pre-fix document fails

The in-test controls prove the rule. This additionally runs the **exact guard
code** over the **whole published pre-fix document**, extracted to a temporary
directory outside the worktree and hash-verified against `origin/main`:

```text
prefix blob : c12ba132dc88b6912b1836136a5875d3c5a5a97d
origin blob : c12ba132dc88b6912b1836136a5875d3c5a5a97d   (identical)

--- PRE-FIX document (origin/main 4b22173)
    declaration ordinals found : [39th]
    count transitions found    : []
    transition to live (39)    : false
    GUARD VERDICT              : FAIL

--- CORRECTED document (worktree)
    declaration ordinals found : []
    count transitions found    : [38->39]
    transition to live (39)    : true
    GUARD VERDICT              : PASS
```

The pre-fix document fails **both** halves, and for the right reasons: the
ordinal is present and no total-count transition exists. The corrected document
passes both.

### Focused test run

```text
$ dart test test/permission_matrix_doc_consistency_test.dart
+1 permission-matrix.md states counts without declaration ordinals its prose attaches no declaration ordinal to the vocabulary
+2 permission-matrix.md states counts without declaration ordinals a count change is recorded as a transition to the live total
+3 the ordinal guard, proved against material outside the worktree the published pre-fix wording is rejected
+4 the ordinal guard, proved against material outside the worktree the corrected wording is accepted
+5 the ordinal guard, proved against material outside the worktree historical count-transition wording is not an ordinal error
+6 the ordinal guard, proved against material outside the worktree a version range is not read as a count transition
+7 the ordinal guard, proved against material outside the worktree the generated table is not searched for ordinals
+8 permission-matrix.md declares the current contract version its declared version equals ContractVersion.current
+9 permission-matrix.md declares the current contract version the document still records the 39-permission vocabulary
00:00 +9: All tests passed!
```

One honest note on the guard's own construction: the transition regex first
carried a trailing lookahead that also rejected a sentence-final digit, so the
`38 to 39.` control failed on the first run. The control caught it before the
document test could ever have depended on it — which is what the controls are
for. The lookahead was narrowed to reject only a decimal continuation.

---

## 4. Debt 2 — the unstable line pointer (scope C)

**File:** `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-002-completion-report.md`.

Raw line numbers into a living document cannot stay true; the FIX-002 commit
itself moved the probe-output block from line 101 to line 123 in the very same
commit that pointed at line 101. Every current-state pointer is now a
section/content reference:

```diff
-Line 85 is a **verbatim quotation** of the `docs/contracts/permission-matrix.md`
-header, and line 101 is **recorded probe output**. […] Both are annotated by the
-marked block added at line 94, so a reader is not left to trip over them.
+Both live in **§4 "The correction"** of the FND-003C1-FIX-002 report, and each is
+identified here by its section and content rather than by a line number […]
+- the **verbatim quotation** […] — the fenced `text` block that opens §4; and
+- the **recorded probe output** — the fenced `text` block under §4's subsection
+  *"The 'byte-for-byte what 0.10 generated' claim is verified, not asserted"* […]
```

Also converted, because this task's own fix would otherwise have left them
false or unstable:

- §7's *"the verbatim quotation at line 85 and the recorded probe output at line
  101"* → the same two section/content anchors;
- §7's *"`permission-matrix.md` line 8 still reads …"* → a past-tense finding
  marked **discharged by this task**, since "still reads" became false the moment
  the header was corrected;
- *"Until it is fixed, the quotation at line 85 must stay as it is"* → *"§4's
  opening quotation block"*;
- *"The phrase originates in `permission-matrix.md` line 8"* → *"the
  vocabulary-history sentence of `permission-matrix.md`'s header, which read, when
  this task ran"*, with the quoted evidence block **unaltered**.

The §2 sweep table keeps its numbers — they are a record of a sweep over the
pre-edit document, not an index — but its column is now labelled
`Line (pre-edit)` and a sentence states which commit they are against and that
the durable references are the section anchors. Nothing in the preserved
quotation or the captured probe output was touched.

One line-number reference is deliberately left: §3's *"a **single hunk at line
205**, inside §11 (which begins at line 201)"* describes the `AGENTS.md` diff of
a **fixed commit**, which is immutable and still accurate. This task's change
does not make it false, so rewriting it would be scope creep.

---

## 5. Debt 3 — the unreproducible row totals (scope D)

The published block asserted `base rows: 42   now rows: 43` with no extraction
stated. A ledger row count depends entirely on which rows are counted; filters
tried during review yielded 37/38, 38/39, 44/45 and 51/52, and none yielded
42/43. The quoted `diff` hunk and the conclusion were always sound — only the
totals were unsupported.

The block now states the filter and gives the command's real output:

```bash
rows() {
  git show "$1:docs/task-ledger/TASK_LEDGER.md" \
    | grep -E '^\| (FND|ROLE|HARD|E2E)[A-Z0-9-]* \|' \
    | awk -F'|' '{gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$6); print $2" :: "$6}'
}
diff <(rows 5385935) <(rows 4b22173)
```

```text
task rows: 37 at 5385935, 38 at 4b22173
35a36
> FND-003D1-BOOKKEEPING-FIX-002 :: **DONE**
```

A marked **"Corrected by FND-003D1-BOOKKEEPING-FIX-003"** blockquote records what
the block previously said, why it was not reproducible, and that the hunk and the
conclusion are unchanged. The candidate-diff evidence proving one row was added
and no existing status changed is preserved in full.

### The same comparison for this task

```text
task rows: 38 at 4b22173, 39 in the worktree
36a37
> FND-003D1-BOOKKEEPING-FIX-003 :: **DONE**
```

Exactly one new row; every pre-existing `ID :: Status` pair byte-identical.

---

## 6. Ledger (scope E)

- **FND-003D1-BOOKKEEPING-FIX-002 row:** the *"Newly found debt"* discovery text
  is kept verbatim and followed by **ROOT ORDINAL DEBT — DISCHARGED by
  FND-003D1-BOOKKEEPING-FIX-003**, plus a note recording debts 2 and 3, how they
  were found (the independent final review), where they were deferred (the
  publication task) and that they too are discharged.
- **One new row** for `FND-003D1-BOOKKEEPING-FIX-003`.
- Nothing else changed: one hunk, `@@ -53 +53,2 @@`. No unrelated task status,
  no unrelated debt, and no owner-action row was touched. **O7 remains
  OUTSTANDING.**
- No mutable publication-state prose was introduced; git history remains the
  authority on publication state.

---

## 7. Semantic sweep

`docs/contracts/` — the surface this task was asked to clean — now contains
**zero** numeric ordinals:

```text
$ git grep -nE '[0-9]+(st|nd|rd|th)\b' -- docs/contracts/
(no output)
```

Surviving instances elsewhere, classified:

| Where | Class |
|---|---|
| `FND-003C1-FIX-002` report §4 quotation block, and its probe output | **preserved historical quotation / captured output** — unaltered, and labelled in place |
| `FND-003C1-FIX-002` report correction blockquote; `FND-003D1-BOOKKEEPING-FIX-002` report §2 and this report | **explicit correction** |
| `FND-003D1-BOOKKEEPING-FIX-001` and `-FIX-001-FIX-001` reports | **accurate historical statements** — untouched by this task |
| `TASK_LEDGER.md` rows for FIX-002 and FIX-003 | **explicit correction** plus **correct declaration-order facts** (13th declared; 38th `admin.cash.record_reconciliation`; 39th `admin.release.view_health`) |
| the guard's doc comments, failure message and pre-fix fixture | **explicit correction** and the **negative-control input** — the defect string is deliberately the fixture |
| `line 101`, `base rows`, `now rows`, `42/43` | only inside explicit correction notes that quote what they replaced |

**Relabelling debt, recorded by this task and since discharged.** Correcting the
canonical header left the FND-003C1-FIX-002 report's §4 opening block quoting a
**superseded** header, with a correction blockquote that described the root
wording as outstanding. **During this implementation task, editing that report was
outside the authorized file list** — it was on the do-not-change list — so the
debt was recorded rather than scope silently widened.
**FND-003D1-BOOKKEEPING-FIX-003-FIX-001** subsequently time-scoped that
annotation's status prose, naming the task each statement belongs to. The
quotation and the captured probe output were **not** touched by either task and
remain byte-identical historical evidence. **No follow-up remains required for
this debt.** No other defect, and none introduced here.

---

## 8. Files changed — exactly five

| # | File | Change |
|---|---|---|
| 1 | `docs/contracts/permission-matrix.md` | root ordinal wording → total-count transition (one hunk) |
| 2 | `packages/contracts/test/permission_matrix_doc_consistency_test.dart` | ordinal/transition guard + five controls; existing tests unchanged |
| 3 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-002-completion-report.md` | line pointers → section/content anchors; row totals → reproducible command |
| 4 | `docs/task-ledger/TASK_LEDGER.md` | three debts discharged; one new row |
| 5 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-completion-report.md` | this report (new) |

```text
$ git diff --name-status origin/main..HEAD
M	docs/contracts/permission-matrix.md
M	docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-002-completion-report.md
A	docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-completion-report.md
M	docs/task-ledger/TASK_LEDGER.md
M	packages/contracts/test/permission_matrix_doc_consistency_test.dart
```

Prohibited surfaces, all mechanically confirmed untouched:

```text
no production Dart changed (no lib/ file in the diff)
only the one authorized test file changed
no ADR file changed
AGENTS.md, SHARED_BLUEPRINT.md, CONSTRAINTS.md, CONTRIBUTING.md unchanged
no other contract document changed (delivery-proof-boundary.md, version-history.md, …)
FND-003C1-FIX-002 completion report unchanged
```

---

## 9. What was verified

```text
$ git status --short          # before edits
(empty — clean)

$ git rev-parse origin/main
4b22173227957b86994a3b95a6232ff03f766527
$ git ls-remote origin refs/heads/main
4b22173227957b86994a3b95a6232ff03f766527	refs/heads/main

$ git diff --check
CLEAN
```

Contract facts, probed live after the edits:

```text
ContractVersion.current  = 0.11
Permission.values.length = 39
permissionMatrix.length  = 39
agentRecordReturnReceipt zero-based index = 12
```

Focused tests: 9/9 pass (§3). Full package:

```text
$ cd packages/contracts && dart test
00:01 +1162: All tests passed!
```

Full gate:

```text
$ ./tools/run_checks.sh
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
(exit code 0)
```

---

## 10. What was NOT run

- **GitHub / hosted CI: NOT RUN.** No `.github` directory exists in the
  repository, so no hosted workflow could run. **O7 remains OUTSTANDING.** The
  local gate is not CI.
- **No push.** Nothing was pushed, force-pushed, amended, rebased, merged,
  squashed or cherry-picked. No tag or release was created. No deployment, no
  Firebase or live-data access, no settings change. The chain is handed to ADMIN
  for independent read-only review first.
- **Migration / rollback: not applicable.** No schema and no contract *behaviour*
  changed — `ContractVersion.current` stays 0.11, the permission vocabulary stays
  39/39, and the generated table is byte-identical. Rollback is `git revert` of
  the single commit; it restores four documentation files and one test file.

---

## 11. What remains

| Item | Owner |
|---|---|
| Relabelling the FND-003C1-FIX-002 report's §4 status annotation, which this implementation task was not authorized to edit. **Discharged by FND-003D1-BOOKKEEPING-FIX-003-FIX-001**, which time-scoped that prose to the task it describes; the quotation and captured output were left byte-identical. | closed |
| O7 — hosted CI does not exist (no `.github`) | FND-004 |

---

## 12. Owner actions needed

One independent read-only review of the local chain

```text
4b22173227957b86994a3b95a6232ff03f766527
→ <this commit>
```

before any publication decision. No owner action is required for the content
itself: zero production change, and the full gate passes.
