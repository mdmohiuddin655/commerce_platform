# FND-003D1-BOOKKEEPING-FIX-003-FIX-001 completion report

- **Task:** time-scope the FND-003C1-FIX-002 report's root-wording status
  annotation, and clear the follow-up claims FND-003D1-BOOKKEEPING-FIX-003 left
  behind, without touching the preserved quotation or the captured output.
- **Owner:** ADMIN / task-ledger governance.
- **Starting HEAD:** `a011add4d01fa5073e958b24021d4b6d9045e10f`
- **Parent of this commit:** `a011add4d01fa5073e958b24021d4b6d9045e10f`
  (single parent; `a011add4` is **not** amended).
- **Baseline `origin/main`:** `4b22173227957b86994a3b95a6232ff03f766527`,
  verified by both `git rev-parse origin/main` and
  `git ls-remote origin refs/heads/main`, and unchanged by this task.
- **Branch:** `fnd/FND-003D1-bookkeeping-fix-003-permission-root-debt`.
- **Scope:** ledger and report prose only. **Zero executable, test and contract
  change.**

---

## 1. The contradiction this task removes

FND-003D1-BOOKKEEPING-FIX-003 corrected the canonical wording in
`docs/contracts/permission-matrix.md`. That correction made three present-tense
assertions in the **older** FND-003C1-FIX-002 report's §4 correction blockquote
false at once:

```text
> … The phrase originates
> in `docs/contracts/permission-matrix.md` line 8 — a contract document this task
> is **not authorized to change** — so it is recorded as **outstanding** debt in
> the ledger and needs its own task.
```

- *"originates in … line 8"* — a raw line pointer, and the sentence it pointed at
  no longer reads that way;
- *"this task is not authorized to change"* — true of the FIX-002 task, but
  written as a standing fact;
- *"recorded as outstanding debt … needs its own task"* — the debt had since been
  discharged.

The block quoted **above** that paragraph, and the probe output **below** it, were
correct and had to stay exactly as they were. Only the surrounding status prose
was wrong.

---

## 2. Exact before → after (scope A and B)

`docs/task-ledger/FND-003C1-FIX-002-completion-report.md`, §4's correction
blockquote — one hunk, 14 insertions, 4 deletions:

```diff
-> quotation into a misquotation or falsify recorded output. The phrase originates
-> in `docs/contracts/permission-matrix.md` line 8 — a contract document this task
-> is **not authorized to change** — so it is recorded as **outstanding** debt in
-> the ledger and needs its own task.
+> quotation into a misquotation or falsify recorded output.
+>
+> **Status of the root wording, time-scoped.** At the time of the
+> **FND-003D1-BOOKKEEPING-FIX-002** task the phrase still stood in the canonical
+> `docs/contracts/permission-matrix.md` header — a contract document that task was
+> **not authorized to change** — so the root wording remained **outstanding** and
+> was deliberately outside that task's scope, recorded in the ledger for a later
+> one. **FND-003D1-BOOKKEEPING-FIX-003** later corrected that canonical wording,
+> replacing the ordinal with the total-count transition and adding a guard against
+> its return, and **FND-003D1-BOOKKEEPING-FIX-003-FIX-001** then time-scoped this
+> annotation. The quotation above and the probe output below are **unchanged**:
+> they remain accurate evidence of the repository as it stood when *this* task ran,
+> which is exactly why they were never edited. Task and commit history, not this
+> paragraph, is the authority on when each change landed.
```

Against each requirement:

- **historical state distinguished from final state** — every status claim now
  names the task it belongs to: FIX-002 (root wording outstanding, out of scope),
  FIX-003 (canonical wording corrected), FIX-003-FIX-001 (this relabelling);
- **the quotation is not called false evidence** — it is called *"accurate
  evidence of the repository as it stood when this task ran"*, which is why it was
  never edited;
- **no history rewritten** — nothing was deleted; the paragraph gained time scope;
- **no mutable publication claim** — the words *published*, *not published*,
  *pending publication*, *awaiting publication* and *local only* appear nowhere in
  the added text, and the paragraph ends by naming **task and commit history** as
  the authority rather than any branch location;
- **the ordinal correction is preserved verbatim** — the explanation that
  `agent.return.record_receipt` sits at zero-based index 12, the 13th declared
  value, with the 38th being `admin.cash.record_reconciliation` and the 39th
  `admin.release.view_health`, is untouched;
- **the raw line pointer is gone** — *"line 8"* became *"the canonical
  `permission-matrix.md` header"*.

---

## 3. Proof the preserved evidence was not altered

Hashed before any edit and again afterwards:

```text
verbatim quotation of the old permission-matrix header
  before : 05ef90d7b1f707488486d6e6f11709b93a1f9e6dda748e2eb322c82d45d73b71
  after  : 05ef90d7b1f707488486d6e6f11709b93a1f9e6dda748e2eb322c82d45d73b71
  diff   : (empty) — BYTE-IDENTICAL

captured probe/command output block
  before : 5b92b3ca9c75bb9d3cdee4863ec2ec88e372ad7ed9de27ef91bdca9781f17175
  after  : 5b92b3ca9c75bb9d3cdee4863ec2ec88e372ad7ed9de27ef91bdca9781f17175
  diff   : (empty) — BYTE-IDENTICAL
```

Corroborated structurally: the whole file changed in **exactly one hunk**, and
that hunk lies between the two preserved blocks — the quotation ends before it and
the probe output begins after it. Nothing was removed from either; the probe block
simply sits ten lines further down the file.

---

## 4. The FIX-003 report (scope C)

Two places in
`docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-completion-report.md` carried a
claim that would go stale the moment this follow-up landed.

§7, *"Outstanding defect"* → a historical, follow-up-aware paragraph:

```diff
-**Outstanding defect:** the FND-003C1-FIX-002 report's §4 opening block now
-reproduces a **superseded** header verbatim, and its correction blockquote still
-describes the root wording as outstanding. Both remain accurate as history, and
-this task is **prohibited from editing that report** — it is on the do-not-change
-list — so the re-labelling is recorded in the ledger as a fresh debt needing its
-own bounded task. No other defect, and none introduced here.
+**Relabelling debt, recorded by this task and since discharged.** Correcting the
+canonical header left the FND-003C1-FIX-002 report's §4 opening block quoting a
+**superseded** header, with a correction blockquote that described the root
+wording as outstanding. **During this implementation task, editing that report was
+outside the authorized file list** — it was on the do-not-change list — so the
+debt was recorded rather than scope silently widened.
+**FND-003D1-BOOKKEEPING-FIX-003-FIX-001** subsequently time-scoped that
+annotation's status prose, naming the task each statement belongs to. The
+quotation and the captured probe output were **not** touched by either task and
+remain byte-identical historical evidence. **No follow-up remains required for
+this debt.** No other defect, and none introduced here.
```

§11 *"What remains"* → the row is marked discharged and `closed`:

```diff
-| The FND-003C1-FIX-002 report's §4 quotation now reproduces a superseded `permission-matrix.md` header, … the re-labelling is prohibited to this task. | needs its own bounded task |
+| Relabelling the FND-003C1-FIX-002 report's §4 status annotation, which this implementation task was not authorized to edit. **Discharged by FND-003D1-BOOKKEEPING-FIX-003-FIX-001**, … | closed |
```

Both statements are scoped to the **implementation task** and to the **follow-up
task** by name. Neither encodes whether either commit sits on any branch; git
history remains the authority on integration and publication.

---

## 5. Ledger (scope D)

- **FND-003D1-BOOKKEEPING-FIX-003 row:** the discovery record is preserved — it
  still states what correcting the header left behind and that editing the older
  report was outside that task's authorized file list — and now ends
  **RELABELLING DEBT — DISCHARGED by FND-003D1-BOOKKEEPING-FIX-003-FIX-001**,
  explicitly noting that the quotation and captured output were left
  byte-identical and **neither was edited by either task**.
- **One new row** for `FND-003D1-BOOKKEEPING-FIX-003-FIX-001`.
- One hunk, `@@ -54 +54,2 @@`. No unrelated task status, no unrelated debt and no
  owner-action row touched. **O7 remains OUTSTANDING** (zero diff lines on the O7
  row).
- No mutable publication-state prose introduced.

Reproducible row comparison, same extraction the FIX-002 report now documents:

```text
task rows: 39 at a011add4, 40 in the worktree
37a38
> FND-003D1-BOOKKEEPING-FIX-003-FIX-001 :: **DONE**
```

Exactly one new row; every pre-existing `ID :: Status` pair byte-identical.

---

## 6. Semantic sweep and classification

Across the three pre-existing writable documents:

| Occurrence | Where | Class |
|---|---|---|
| `still outstanding`, `still unauthorized to change`, `still awaiting its own task` | new FIX-003-FIX-001 ledger row | **explicit correction** — quoted as the false assertion being repaired, followed by *"all three false once the header was fixed"* |
| `remained outstanding`, `not authorized to change` | FIX-002 report §4 annotation | **explicitly historical** — both name the FND-003D1-BOOKKEEPING-FIX-002 task explicitly |
| `needs its own task` / `needs its own bounded task` ×2 | ledger, ADR-index and root-ordinal discovery records | **explicitly historical** — each sits inside a preserved discovery record and is immediately followed by `DISCHARGED by …` |
| `remains outstanding` | FIX-002 report §13; ledger O7 row | **accurate durable current fact** — O7, unchanged |
| `## 12. Out of scope — recorded, not fixed` | FIX-002 report §12 | **explicitly historical** — that section's heading scopes it to the FND-003C1-FIX-002 task |
| `the 39th` in the quoted header, and in the probe output | FIX-002 report §4 | **preserved quotation** and **captured historical output** — byte-identical |
| `the 39th declared value`, `13th declared` | FIX-002 report §4 annotation; ledger rows | **accurate durable current fact** — verified by live probe |
| `published` | FIX-003 row (*"the published pre-fix document"*), FIX-003 report §3/§5 | **accurate durable current fact** — describes what `origin/main` contained, not this candidate's state |
| `pending` ×3, `not published` ×1 | pre-existing unrelated ledger rows | out of this task's scope, untouched |

**Zero defects introduced.** One pre-existing item is reported rather than fixed,
below.

### Recorded, not fixed — outside this task's authorized scope

The FIX-002 report's **§12** opens *"`docs/contracts/delivery-proof-boundary.md`
still asserts the **old permission count in the present tense**"*. That is stale:
`grep -nE '\b38\b'` over that document now returns only correct `38 → 39`
transitions and explicit corrections, because
**FND-003D1-BOOKKEEPING-FIX-001** fixed it. The section's own heading scopes it to
the FND-003C1-FIX-002 task, so it reads as that task's finding — but the sentence
itself is present-tense.

This task's authorization for that file is *"only correct the surrounding
present-state annotation"* about the **root wording**, and §12 concerns a
different document and a different debt that this task's own change did not make
stale. Widening scope silently is worse than recording the debt, so it is recorded
here and in no way claimed as fixed. It needs its own bounded task.

---

## 7. Files changed — exactly four

| # | File | Change |
|---|---|---|
| 1 | `docs/task-ledger/FND-003C1-FIX-002-completion-report.md` | §4 annotation status prose time-scoped (one hunk); preserved blocks byte-identical |
| 2 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-completion-report.md` | §7 paragraph and §11 row re-tensed to historical/discharged |
| 3 | `docs/task-ledger/TASK_LEDGER.md` | FIX-003 debt note discharged; one new row |
| 4 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-003-FIX-001-completion-report.md` | this report (new) |

Prohibited surfaces, mechanically confirmed untouched: `permission-matrix.md`,
`permission_matrix_doc_consistency_test.dart`, every Dart, test and `lib/` file,
`AGENTS.md`, every ADR, `SHARED_BLUEPRINT.md`, `CONSTRAINTS.md`, `CONTRIBUTING.md`
and every other contract document.

---

## 8. What was verified

```text
$ git status --short          # before edits
(empty — clean)

$ git rev-parse origin/main
4b22173227957b86994a3b95a6232ff03f766527
$ git ls-remote origin refs/heads/main
4b22173227957b86994a3b95a6232ff03f766527	refs/heads/main

$ git rev-parse HEAD          # before edits
a011add4d01fa5073e958b24021d4b6d9045e10f
$ git rev-list --parents -n 1 a011add4
a011add4d01fa5073e958b24021d4b6d9045e10f 4b22173227957b86994a3b95a6232ff03f766527

$ git diff --check
CLEAN
```

Contract facts, probed live:

```text
ContractVersion.current  = 0.11
Permission.values.length = 39
permissionMatrix.length  = 39
```

Tests — unchanged by this task, re-run to prove the documentation edits break
nothing:

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
- **No push.** Nothing was pushed, force-pushed, amended, rebased, merged,
  squashed or cherry-picked; `a011add4` is unamended and remains this commit's
  parent. No tag or release was created. No deployment, no Firebase or live-data
  access, no settings change.
- **Migration / rollback: not applicable.** No schema, contract or behaviour
  changed. Rollback is `git revert` of this single commit.

---

## 10. What remains

| Item | Owner |
|---|---|
| FIX-002 report §12's present-tense *"still asserts the old permission count"* about `delivery-proof-boundary.md`, already fixed by FND-003D1-BOOKKEEPING-FIX-001 — outside this task's authorized scope (§6) | needs its own bounded task |
| O7 — hosted CI does not exist (no `.github`) | FND-004 |

---

## 11. Owner actions needed

One fresh independent read-only review of the local chain

```text
4b22173227957b86994a3b95a6232ff03f766527
→ a011add4d01fa5073e958b24021d4b6d9045e10f
→ <this commit>
```

before any publication decision. No owner action is required for the content
itself: zero executable, test and contract change, and the full gate passes.
