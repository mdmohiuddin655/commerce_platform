# FND-003D1-BOOKKEEPING-FIX-002 completion report

- **Task:** correct the inaccurate *"39th permission"* ordinal wording carried by
  the FND-003C1-FIX-002 report, and complete the stale `AGENTS.md` §11 ADR index.
- **Owner:** ADMIN / repository governance.
- **Baseline:** `origin/main` @ `53859355bbce39197b71a1ac3c87b2ad64e3e0e8`
  (verified by both `git rev-parse origin/main` and
  `git ls-remote origin refs/heads/main`).
- **Branch:** `fnd/FND-003D1-bookkeeping-fix-002-doc-consistency`, created from
  that exact baseline.
- **Depends on:** FND-003D1-BOOKKEEPING-FIX-001
  (`734863c` → `64930e3` → `5385935`). Ancestry is answerable from git history,
  which is the authority; this report states no publication status.
- **Scope:** documentation-only bookkeeping. **Zero executable change.**

---

## 1. What was created and changed

Exactly four documentation files, all of them authorized:

| # | File | Change |
|---|---|---|
| 1 | `AGENTS.md` | §11 ADR index only — completed to the full canonical inventory |
| 2 | `docs/task-ledger/FND-003C1-FIX-002-completion-report.md` | ordinal wording corrected as a marked block |
| 3 | `docs/task-ledger/TASK_LEDGER.md` | ordinal wording corrected; two debts marked discharged; one new row |
| 4 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-002-completion-report.md` | this report (new) |

No other file changed. Verified below.

---

## 2. The permission wording (scope A)

### The defect

`agent.return.record_receipt` was described as *"the 39th"*. That conflates two
different things:

- **the permission that took the *count* to 39** — true of
  `agent.return.record_receipt`; and
- **the 39th *declared* value** — a declaration-order claim, and false.

### Mechanical evidence

Probed against the tree with `Permission.values.indexOf`, not grepped — the
original defect was caused precisely by reading a `grep -n` **file line number**
as an ordinal:

```text
ContractVersion.current            = 0.11
Permission.values.length           = 39
permissionMatrix.length            = 39
agentRecordReturnReceipt index     = 12  (zero-based)
agentRecordReturnReceipt ordinal   = 13th declared
38th declared value                = admin.cash.record_reconciliation
39th declared value                = admin.release.view_health
```

So the 39th declared value is `admin.release.view_health` — decisively **not**
`agent.return.record_receipt`.

### Before → after

**`docs/task-ledger/FND-003C1-FIX-002-completion-report.md`**, report prose:

```diff
-**0.10** (FND-003B3B's 39th permission); **FND-003C1 added no permission**. The
+**0.10** (FND-003B3B added `agent.return.record_receipt`, taking the total
+permission count from **38 → 39**); **FND-003C1 added no permission**. The
```

followed by a marked correction block recording the ordinal facts, why the
phrase was wrong, and which copies were deliberately left alone.

**`docs/task-ledger/TASK_LEDGER.md`**, FND-003C1-FIX-002 row:

```diff
-(FND-003B3B's `agent.return.record_receipt`, the 39th)
+(FND-003B3B added `agent.return.record_receipt` at 0.10, taking the count **38 → 39**)
```

The chronological fact **38 → 39 at contract 0.10** is preserved because it was
always correct, and the live count **39** is preserved. No new
declaration-position claim is introduced anywhere; where an ordinal is stated at
all, it states **zero-based index 12** and **13th declared value** together.

### Semantic sweep of the full FIX-002 report

Every occurrence of `39th`, `38th`, `13th declared`, `38`, `39` and
`agent.return.record_receipt` was classified. Line numbers below are the
**pre-edit** ones, against `origin/main` @ `5385935` — that is the document the
sweep read, and the `Action` column records what was then done to each hit.
They are a record of the sweep, not a current index; the durable references are
the section anchors used in the next subsection.

| Line (pre-edit) | Occurrence | Classification | Action |
|---|---|---|---|
| 85 | ``FND-003B3B (`agent.return.record_receipt`, the 39th) — **39 permissions**.`` | **Verbatim quotation** of the `docs/contracts/permission-matrix.md` header | **Left intact** — see below |
| 94 | "FND-003B3B's 39th permission" | The report's **own prose assertion** | **CORRECTED** |
| 101 | "table rows at cdb5f35b (FND-003B3B, where 0.10 introduced the 39th) : 39" | **Recorded command/probe output** | **Left intact** — see below |
| 8, 28–29 | `596413c2…fe38fab…` | SHA substrings, not counts | no defect |
| 32–34, 73, 102–107, 139, 250–252 | count `39` | correct live count | no defect |
| 265–272 | `38` inside quoted stale lines of `delivery-proof-boundary.md` | quoted evidence of a defect that task found | no defect |
| 281–285 | "was 38 throughout that slice, and is 39 today" | correctly time-scoped history | no defect |

**Ordinal/chronology defects remaining in the report's own assertions: zero.**

### Why two copies were deliberately not edited

Both live in **§4 "The correction"** of the FND-003C1-FIX-002 report, and each is
identified here by its section and content rather than by a line number, so the
reference survives any later edit that moves it:

- the **verbatim quotation** of the `docs/contracts/permission-matrix.md` header
  — the fenced `text` block that opens §4; and
- the **recorded probe output** — the fenced `text` block under §4's subsection
  *"The 'byte-for-byte what 0.10 generated' claim is verified, not asserted"*,
  the one reporting `table rows at cdb5f35b … identical=True`.

Correcting either would turn a faithful quotation into a misquotation, or falsify
recorded evidence — the opposite of the honesty rule in `AGENTS.md` §7. Both are
annotated by the marked **"Corrected by FND-003D1-BOOKKEEPING-FIX-002"**
blockquote in the same section, so a reader is not left to trip over them.

### Newly found debt — NOT fixed here, out of scope

The phrase originates in the **vocabulary-history sentence of
`docs/contracts/permission-matrix.md`'s header**, which read, when this task ran:

```text
FND-003B3B (`agent.return.record_receipt`, the 39th) — **39 permissions**.
```

That is a **contract document this task is explicitly prohibited from
changing**. It is the root cause: the FIX-002 report quotes it, which is how the
wording spread. It is recorded as outstanding debt in the ledger and needs its
own bounded task. Until it is fixed, §4's opening quotation block must stay as it
is.

---

## 3. The ADR index (scope B)

### Inventory before editing — read from the canonical directory

```text
ADR-0001-modular-monorepo.md                            Accepted
ADR-0002-pub-workspace.md                               Accepted
ADR-0003-package-name-prefix.md                         Accepted
ADR-0004-strict-analysis.md                             Accepted
ADR-0005-notification-stack-decision-required.md        Proposed — blocked on an owner decision. Not accepted.
ADR-0006-admin-picker-assignment-override.md            Accepted
ADR-0007-admin-rider-assignment-override.md             Accepted
ADR-0008-bounded-delivery-proof-policy-reference.md     Accepted
ADR-0009-trusted-immutable-proof-assessment.md          Accepted; amended by FND-003D2A-FIX-001 (2026-09-10)
ADR-0010-direct-rider-to-shop-return-route.md           Accepted
ADR-0011-o6-currency-fees-commission-and-cash-custody.md Accepted
```

Pre-edit assumptions, all **confirmed** before any edit:

- ADR-0001 through ADR-0011 exist — **yes**, 11 files, no gaps.
- ADR-0009, ADR-0010, ADR-0011 missing from §11 — **yes**, §11 stopped at ADR-0008.
- No ADR beyond ADR-0011 — **yes**.
- Titles/statuses readable directly from the files — **yes**, as listed above.

### The §11 change

```diff
-rails · ADR-0005 notification stack decision required · ADR-0006 / ADR-0007
-admin assignment override governance · ADR-0008 bounded delivery-proof policy
-reference. Read the relevant ADR before changing what it decided.
+rails · ADR-0005 notification stack decision required *(Proposed — blocked on an
+owner decision; not accepted)* · ADR-0006 / ADR-0007 admin assignment override
+governance · ADR-0008 bounded delivery-proof policy reference · ADR-0009
+Delivery-proof assessment is trusted, immutable and append-only *(Accepted;
+amended by FND-003D2A-FIX-001)* · ADR-0010 The first executable return route is
+direct rider→shop, and returned stock is separate from liability · ADR-0011 O6
+resolved: BDT-only v1, quoted customer price, commission as an allocation, and
+rider cash as custody. Read the relevant ADR before changing what it decided.
+
+Every entry above is **Accepted** unless its own parenthetical says otherwise,
+and the list is the complete inventory — eleven decisions, each appearing
+exactly once, no gap and none beyond the last. `docs/decisions/` remains the
+authority: if the directory and this index ever disagree, the directory wins and
+this index is the defect.
```

The three additions carry their **exact canonical titles** as written in the ADR
files. The eight pre-existing entries keep their wording; ADR-0005 and ADR-0009
gained an inline status parenthetical because their status is not "Accepted,
unamended" and a bare label would misrepresent them.

Status is stated **inline** rather than in a trailing paragraph deliberately: a
trailing status note had to name ADR-0005 and ADR-0009 a second time, which made
a mechanical "each identifier exactly once" scan report false duplicates.

### Coverage proof after the edit

```text
§11 identifiers, counted:
   1 ADR-0001    1 ADR-0002    1 ADR-0003    1 ADR-0004
   1 ADR-0005    1 ADR-0006    1 ADR-0007    1 ADR-0008
   1 ADR-0009    1 ADR-0010    1 ADR-0011

directory ids vs §11 ids : EXACT ONE-TO-ONE MATCH (no missing, no extra)
numerical order          : ascending, correct
```

No ADR file was opened for writing; no ADR content changed. The `AGENTS.md` diff
is a **single hunk at line 205**, inside §11 (which begins at line 201) — no
other rule in `AGENTS.md` is touched.

---

## 4. Ledger (scope C)

- **One new row** added for `FND-003D1-BOOKKEEPING-FIX-002`, recording the
  dependency chain, both debts, zero executable change, `ContractVersion` 0.11
  and permissions 39/39.
- **FND-003C1-FIX-002 row:** ordinal wording corrected; the ordinal-wording debt
  marked **DISCHARGED**, with the original defect described so the history of
  what was wrong survives.
- **FND-003D1-BOOKKEEPING-FIX-001 row:** the ADR-index debt note now ends
  **DISCHARGED by FND-003D1-BOOKKEEPING-FIX-002**, with the discovery record
  above it kept intact rather than deleted.

No mutable publication-state prose ("local only", "not published", "publication
pending", "awaiting publication", "published") was introduced; git history stays
the authority on publication state.

**No unrelated task status changed** — proven by extracting the `ID :: Status`
pair for every **task row** before and after. A task row is a ledger table row
whose first cell is a task id; owner-action rows (`O1`…`O7`) and the
contract-version table are not task rows. Run from the repository root, in bash:

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

> **Corrected by FND-003D1-BOOKKEEPING-FIX-003** — bookkeeping accuracy only.
> This block previously reported `base rows: 42   now rows: 43` without stating
> the extraction, and those totals are not reproducible: a row count depends
> entirely on which rows are counted, and no filter yielding 42/43 was recorded.
> The command is now given in full and the figures above are what it prints. The
> quoted `diff` hunk and the conclusion are unchanged and were always
> reproducible — exactly one task row was added, and no pre-existing
> `ID :: Status` pair changed.

That is the only difference: one row added, every pre-existing status
byte-identical.

---

## 5. What was verified

```text
$ git status --short              # before edits
(empty — clean)

$ git rev-parse origin/main
53859355bbce39197b71a1ac3c87b2ad64e3e0e8
$ git ls-remote origin refs/heads/main
53859355bbce39197b71a1ac3c87b2ad64e3e0e8	refs/heads/main

$ git diff --check
CLEAN

$ git diff --name-status origin/main
M	AGENTS.md
M	docs/task-ledger/FND-003C1-FIX-002-completion-report.md
M	docs/task-ledger/TASK_LEDGER.md
(+ this report, added in the same commit)
```

Prohibited-surface assertions, all mechanical:

```text
no Dart file changed
no lib/ file changed
no ADR file changed
no protected contract/config file changed
    (permission-matrix.md, delivery-proof-boundary.md, delivery-proof-dispute.md,
     SHARED_BLUEPRINT.md, CONSTRAINTS.md, pubspec* all untouched)
```

Contract facts, probed live:

```text
ContractVersion.current  = 0.11
Permission.values.length = 39
permissionMatrix.length  = 39
agentRecordReturnReceipt zero-based index = 12
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

## 6. What was NOT run

- **GitHub / hosted CI: NOT RUN.** No `.github` directory exists in the
  repository, so no hosted workflow could run. **O7 remains OUTSTANDING.** The
  local gate is not CI.
- **No push.** Nothing was pushed, force-pushed, amended, rebased, merged,
  squashed or cherry-picked. No tag or release was created. The chain is handed
  to ADMIN for independent read-only review first.
- **Migration / rollback: not applicable.** No schema and no contract changed.
  Rollback is `git revert` of the single commit; it restores four documentation
  files and nothing else.

---

## 7. What remains

| Item | Owner |
|---|---|
| `docs/contracts/permission-matrix.md` carried the same ordinal wording in its vocabulary-history header — the root cause, and prohibited to this task. **Discharged by FND-003D1-BOOKKEEPING-FIX-003**, which replaced it with the total-count transition and added a guard against its return. | closed |
| O7 — hosted CI does not exist (no `.github`) | FND-004 |

Once the permission-matrix wording is fixed, the two deliberately preserved
copies in the FND-003C1-FIX-002 report — §4's opening quotation block and the
probe-output block under its *"byte-for-byte what 0.10 generated"* subsection —
should be re-examined by that task, because the quotation then reproduces a
header that has since been superseded.

> **Note added by FND-003D1-BOOKKEEPING-FIX-003.** That re-examination is now
> due and is **not** done: FIX-003 corrected the header but is explicitly
> prohibited from editing the FND-003C1-FIX-002 report, so §4's quotation there
> still faithfully reproduces the **superseded** wording and its correction
> blockquote still describes the root wording as outstanding. Both remain
> accurate as history and neither was altered; the re-labelling they now need is
> recorded as a fresh debt in the ledger and needs its own bounded task.

---

## 8. Owner actions needed

One independent read-only review of the local chain

```text
53859355bbce39197b71a1ac3c87b2ad64e3e0e8
→ <this commit>
```

before any publication decision. No owner action is required for the content
itself: zero executable change, and the full gate passes.
