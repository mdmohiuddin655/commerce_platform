# FND-003D1-BOOKKEEPING-FIX-001 completion report

**Branch:** `fnd/FND-003D1-bookkeeping-fix-001-proof-boundary-count`
**Baseline:** `734863c62afa1dac166c7f328a015f1606640ef0` (= `origin/main`, verified twice)
**Scope:** documentation correctness + one new regression test.
**ZERO executable change** — no file under any `lib/` directory is added or modified.

---

## Preconditions

```text
$ git rev-parse origin/main
734863c62afa1dac166c7f328a015f1606640ef0

$ git ls-remote origin refs/heads/main
734863c62afa1dac166c7f328a015f1606640ef0	refs/heads/main

$ git status --porcelain
                                                                   (empty)

$ git checkout -b fnd/FND-003D1-bookkeeping-fix-001-proof-boundary-count 734863c6...
Switched to a new branch 'fnd/FND-003D1-bookkeeping-fix-001-proof-boundary-count'
```

Both the local ref and the remote ref equal the required baseline, so the task
was **not** BLOCKED.

---

## What was created

| Path | Status |
|---|---|
| `packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart` | **NEW** — the derived guard (2 tests) |
| `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-001-completion-report.md` | **NEW** — this report |
| `docs/contracts/delivery-proof-boundary.md` | modified — four corrections + one machine-readable anchor |
| `docs/task-ledger/TASK_LEDGER.md` | modified — new row, FIX-002 debt discharged, new debt recorded |

Nothing else. The full change set:

```text
$ git status --porcelain
 M docs/contracts/delivery-proof-boundary.md
 M docs/task-ledger/TASK_LEDGER.md
?? packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart
```

---

## What was changed in `delivery-proof-boundary.md`

### (a) §1 — the false present-tense count

Was: *"**Neither FND-003D2A nor FND-003D2B added a permission**: `Permission.values`
remains **38**."*

The first clause is **true and was kept**. The count is corrected to **39**, and
the paragraph now states the distinction that made the drift easy to miss:
*"neither D2A nor D2B added a permission"* is **not the same claim** as the
total count. The count moved **38 → 39** at **0.10** when FND-003B3B added
`agent.return.record_receipt`; FND-003C1 (0.11) added none. Because this
document carries a **fixed-origin** header, **a count newer than the document's
own 0.7–0.9 slice is normal, not a defect** — and that sentence is now in the
document, so the next reader does not have to re-derive it.

### (b) §5 — the false guard claim

Was: *"a test pins the count at **38** for both `Permission.values` and
`permissionMatrix`."* — wrong on the number **and** vague on the guard.

Verified first, then written: **seven** test files carry the count. **Six** pin
the literal `39` for both vocabularies; the seventh derives it.

```text
$ grep -n "Permission.values.length\|permissionMatrix.length" packages/contracts/test/*.dart
packages/contracts/test/attempt_return_authority_test.dart:160:      expect(Permission.values.length, 39);
packages/contracts/test/attempt_return_authority_test.dart:161:      expect(permissionMatrix.length, 39);
packages/contracts/test/cod_collection_authority_test.dart:111:      expect(Permission.values.length, 39);
packages/contracts/test/cod_collection_authority_test.dart:112:      expect(permissionMatrix.length, 39);
packages/contracts/test/delivery_proof_assessment_regression_test.dart:137:      expect(Permission.values.length, 39);
packages/contracts/test/delivery_proof_assessment_regression_test.dart:138:      expect(permissionMatrix.length, 39);
packages/contracts/test/delivery_proof_dispute_authority_test.dart:52:      expect(Permission.values.length, 39);
packages/contracts/test/delivery_proof_dispute_authority_test.dart:53:      expect(permissionMatrix.length, 39);
packages/contracts/test/delivery_proof_test.dart:850:      expect(Permission.values.length, 39);
packages/contracts/test/delivery_proof_test.dart:851:      expect(permissionMatrix.length, 39);
packages/contracts/test/permission_matrix_doc_consistency_test.dart:101:      expect(Permission.values.length, 39);
packages/contracts/test/permission_matrix_doc_consistency_test.dart:102:      expect(permissionMatrix.length, 39);
packages/contracts/test/permission_matrix_test.dart:18:      expect(ids.length, Permission.values.length);
```

`delivery_proof_test.dart:850-851` — the guard that belongs to this document —
is named explicitly in §5, as required.

§5 also gained **one machine-readable anchor**, `**Permission count: 39**`,
written in a fixed form so the new guard can distinguish *missing*, *malformed*
and *ambiguous* from *wrong*. Prose alone cannot support those four distinct
failures. This is the only addition beyond the four listed corrections, and it
is the mechanism that makes acceptance criterion **A4** achievable.

### (c) Line 11 — the "Still true at 0.9" marker

**Advanced to 0.11, and only because it is still true.** The marker was
re-verified claim by claim against the 0.11 tree rather than restamped:

| Claim in the box | Re-check at 0.11 | Verdict |
|---|---|---|
| The two references gained no verdict | `DeliveryProofPolicyRef` holds only `value`; `DeliveryEvidenceRef` only `resourceId`, `evidenceId` | **still true** |
| No dispute resolves | `DeliveryProofDisputeState` = `open`, `underReview` only — no resolved state | **still true** |
| `resolve` is never executable | `evaluateResolveDeliveryProofDispute` still always refuses `resolutionPolicyDeferred` | **still true** |
| Successful delivery not executable | no `order.delivered` event exists; `OrderState.delivered`, customer custody and rider `completed` unreachable at both 0.10 and 0.11 | **still true** |

```text
$ git grep -n "order.delivered" -- packages/contracts/lib
                                                          (no output — no such event)
```

The two slices since 0.9 — FND-003B3B (0.10) and FND-003C1 (0.11) — are now
named inside the box together with what was re-checked, so a future reader can
see the marker was tested, not assumed. B3B's added permission changes the
*count* (§1, §5), not any claim in the box, and the box now says so.

### (d) §7 — the dispute-outcome bullet

Was: *"the outcome needs **O6**, FND-003C and FND-003B3B"*. Two of those three
are discharged, so the bullet now records **O6 RESOLVED** (ADR-0011, 2026-09-11)
and **FND-003B3B DONE and integrated** (0.10), leaving only the remaining
**FND-003C** money work. **The outcome itself stays UNDECIDED** — the bullet
says so explicitly, because discharging a prerequisite is not deciding the
question.

---

## What was verified

### A5 — the contract did not move

Run from an out-of-tree probe package (a path dependency on
`packages/contracts`), so no scratch file ever entered the repository tree:

```text
$ dart run bin/probe.dart
ContractVersion.current   = 0.11
Permission.values.length  = 39
permissionMatrix.length   = 39
39th permission (index 38)= admin.release.view_health
```

**A correction to the task prose, per AGENTS.md §7.** The task brief says *"the
39th permission is `agent.return.record_receipt`"*. That is true
**chronologically** — it is the 39th permission ever added, and it took the
count 38 → 39 at 0.10 — but it is **not** last in declaration order:

```text
$ grep -n "agentRecordReturnReceipt" packages/contracts/lib/src/permission.dart
38:  agentRecordReturnReceipt('agent.return.record_receipt'),
```

It is the **38th declared** value; `admin.release.view_health` is last. The
document wording was tightened to *"took it to 39"* rather than *"added the
39th"* so this correction does not get re-introduced as a new positional error.

### A6 — zero executable change

```text
files in change set          : 3
    docs/contracts/delivery-proof-boundary.md
    docs/task-ledger/TASK_LEDGER.md
    packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart
under any lib/ directory     : NONE
.dart files                  : ['packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart']
.dart files that are TESTS   : ['packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart']

Comment-stripped executable delta for tracked .dart files:
   (no tracked .dart file was modified — the only .dart file in this
    commit is a NEW test, so there is no executable delta to strip)

$ git diff --name-only -- '*.dart'
                                                (empty — no tracked .dart modified)
```

The comment-stripping step is vacuous here **by construction, not by luck**: the
commit modifies no `.dart` file at all. `ContractVersion.current`, `Permission`,
`permissionMatrix` and every permission id are untouched.

### A2 — every surviving `38`, justified one by one

```text
$ git grep -n '38' docs/contracts/delivery-proof-boundary.md
docs/contracts/delivery-proof-boundary.md:86:let this paragraph go stale: `Permission.values` is **39**, not 38. The count
docs/contracts/delivery-proof-boundary.md:87:moved **38 → 39** at contract **0.10**, when FND-003B3B added
docs/contracts/delivery-proof-boundary.md:237:is not 38 either: FND-003B3B took it to 39 at 0.10 by adding
```

| Line | Text | Why it is correct |
|---|---|---|
| 86 | "`Permission.values` is **39**, not 38" | An **explicit negation** of the dead figure, with the live value stated first and in bold. It asserts the count is *not* 38. |
| 87 | "moved **38 → 39** at contract **0.10**" | **Historical**, past tense, and true: that transition happened at 0.10 under FND-003B3B. Deleting it would remove the explanation of *why* the document drifted. |
| 237 | "is not 38 either: FND-003B3B took it to 39" | Another **explicit negation**, in §5, for the same reason. |

**No present-tense claim that the count *is* 38 survives** (A1). The new guard
enforces this independently — see A4.

### A3 — the guard derives, and hard-codes nothing

```text
$ python3 -c "<strip // comments, then grep multi-digit literals>" \
      packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart
(no multi-digit numeric literal in comment-stripped code)
```

The expectation is `Permission.values.length` at both assertion sites. The only
digits anywhere in the file are in **explanatory comments** describing the
historical 38 → 39 move; none is read by the test. A 40th permission therefore
fails this guard until the document follows.

### A4 — negative controls, all four proven

Each control was produced by temporarily substituting the document, running the
guard, and restoring the document byte-identically.

**(0) Against the PRE-FIX document** (`git show 734863c:docs/contracts/delivery-proof-boundary.md`) — **FAILS, as required**:

```text
00:00 +0 -1: ... its canonical count claim equals Permission.values.length [E]
  Expected: <1>
    Actual: <0>
  malformed claim: no "**Permission count: <n>**" declaration found in
  docs/contracts/delivery-proof-boundary.md. ...

00:00 +0 -2: ... no stale present-tense count claim survives in the prose [E]
  Expected: empty
    Actual: [
              'line 68 claims 38: "**Neither FND-003D2A nor FND-003D2B added a permission**: `Permission.values`"',
              'line 212 claims 38: "**No permission was added** — a test pins the count at 38 for both"'
            ]
  stale present-tense permission-count claim in docs/contracts/delivery-proof-boundary.md —
  Permission.values.length is 39, but:
    line 68 claims 38: ...
    line 212 claims 38: ...
00:00 +0 -2: Some tests failed.
```

The guard independently located **both** stale claims, at **exactly** the two
lines the task named (68 and 212). This is the strongest evidence available that
the guard tests the real defect.

**(i) Document MISSING** — **FAILS with a specific message**:

```text
  Expected: true
    Actual: <false>
  document missing: expected the delivery-proof boundary document at
  /Users/mohiuddin/Projects/commerce_platform/docs/contracts/delivery-proof-boundary.md.
  The repository root WAS found, so this is a missing or moved document, not a
  broken root search. If it was renamed, update kDocumentPath in this test and
  say so in the task report.
```

This is exactly why `findRepositoryRoot()` uses `AGENTS.md` + `packages/contracts`
and **not** the document under test: the failure reads "document missing", not
"root not found".

**(ii) Claim MALFORMED** (`**Permission count: thirty-nine**`) — **FAILS clearly**:

```text
  Expected: <1>
    Actual: <0>
  malformed claim: no "**Permission count: <n>**" declaration found in
  docs/contracts/delivery-proof-boundary.md. The guard cannot verify a count it
  cannot locate, and silently passing would recreate the exact drift this test
  exists to prevent. Restore the canonical form in §5.
```

**(iii) Claim AMBIGUOUS** (a second, disagreeing declaration added) — **FAILS clearly**:

```text
  Expected: <1>
    Actual: <2>
  ambiguous claim: found 2 "**Permission count: <n>**" declarations in
  docs/contracts/delivery-proof-boundary.md (39, 38). Exactly one authoritative
  count claim is allowed — two claims can disagree, and a reader cannot tell
  which is canonical.
```

The failure message **names both conflicting values**, so the reader does not
have to search for the second claim.

After all four controls the document was restored and re-checked — only the
intended corrections remain, and the guard passes again:

```text
$ git diff --stat
 docs/contracts/delivery-proof-boundary.md | 82 +++++++++++++++++++++++++++----
 docs/task-ledger/TASK_LEDGER.md           |  3 +-
 2 files changed, 75 insertions(+), 10 deletions(-)
```

### A7 — suite delta is exactly the two new tests

`packages/contracts`: **1153 → 1155**, `N = 2`. Established by running the full
gate **before** any change and again after:

```text
before:  --- packages/contracts ---   00:01 +1153: All tests passed!
after:   --- packages/contracts ---   00:01 +1155: All tests passed!
```

Every other member is byte-identical across the two runs — `apps/admin` +1,
`apps/agent` +1, `apps/picker` +1, `apps/rider` +1, `apps/user` +1,
`packages/auth` +6, `packages/core` +8, `packages/local_store` +7,
`packages/notifications` +15 — so the delta is **only** in `packages/contracts`
and **only** +2.

The two new tests:

| # | Test | Asserts |
|---|---|---|
| 1 | *its canonical count claim equals `Permission.values.length`* | The document contains **exactly one** `**Permission count: <n>**` declaration (0 ⇒ *malformed*, >1 ⇒ *ambiguous*), that `<n>` equals `Permission.values.length`, and that `permissionMatrix.length` agrees — so one number may honestly be claimed for both vocabularies. |
| 2 | *no stale present-tense count claim survives in the prose* | No present-tense phrasing anywhere in the document (`Permission.values is/remains **N**`, `permissionMatrix is/remains **N**`, `pins the count at N`, `count is/remains N`) claims a number other than `Permission.values.length`. Reports the offending **line number and line text**. Historical prose such as "moved 38 → 39 at 0.10" is deliberately not matched — it is true and must stay. |

### Permission matrix generator — unchanged and byte-identical

```text
$ cd packages/contracts && dart run tool/print_permission_matrix.dart
| Permission id | Role | Membership | Scope | Reason | Approval | Restriction |
|---|---|---|---|---|---|---|
| `customer.checkout.submit` | customer | active | `ownResource` | no | no | ... |
...
| `admin.release.view_health` | admin | active | `none` | no | no | Aggregate operational metrics only. No personal data. |

$ grep -cE '^\| `[a-z][a-z0-9_.]*` \|' <generated>
39

$ cmp <table block of docs/contracts/permission-matrix.md> <generated>
                                        (identical — 41 lines each, diff empty)
```

**39 rows, byte-identical to the committed `permission-matrix.md` table.** That
document was not touched, as required.

### A8 — ledger, in the same commit

- New row **FND-003D1-BOOKKEEPING-FIX-001**, *Depends on: FND-003D1,
  FND-003C1-FIX-002*, placed directly after the FND-003D1 row.
- The **FND-003C1-FIX-002** row's *"Known remaining debt"* note is **amended,
  not deleted**: the original wording is preserved and reframed as *"at the time
  this row was written…"*, followed by an explicit **Discharged 2026-09-11 by
  FND-003D1-BOOKKEEPING-FIX-001** clause naming what was corrected. The history
  of the debt survives.
- **Newly found debt recorded, NOT fixed** — see *What remains*.
- **No other row's status was changed.**

---

## The full local gate

```text
$ ./tools/run_checks.sh

======================================================
==> flutter pub get (workspace root)
======================================================
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

======================================================
==> workspace membership (source of truth: pubspec.yaml workspace:)
======================================================
==> declared workspace members: 15
  apps/admin
  apps/agent
  apps/picker
  apps/rider
  apps/user
  packages/auth
  packages/contracts
  packages/core
  packages/design_system
  packages/feature_flags
  packages/local_store
  packages/networking
  packages/notifications
  packages/observability
  packages/sync
==> every declared member exists and sets 'resolution: workspace'
==> no on-disk package under apps/ or packages/ is undeclared
==> declared set matches the resolved package_config.json
  resolver reports 15 member package(s) + 1 workspace-root package

WORKSPACE CHECK: PASS (15 declared members)

======================================================
==> flutter analyze (workspace root, covers every member)
======================================================
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing commerce_platform...
No issues found! (ran in 2.1s)

======================================================
==> tests for each of the 15 declared workspace members
======================================================
--- apps/admin ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +1: All tests passed!
--- apps/agent ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +1: All tests passed!
--- apps/picker ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +1: All tests passed!
--- apps/rider ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +1: All tests passed!
--- apps/user ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +1: All tests passed!
--- packages/auth ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +6: All tests passed!
--- packages/contracts ---
00:01 +1155: All tests passed!
--- packages/core ---
00:00 +8: All tests passed!
--- packages/design_system: NO TESTS ---
--- packages/feature_flags: NO TESTS ---
--- packages/local_store ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +7: All tests passed!
--- packages/networking: NO TESTS ---
--- packages/notifications ---
Resolving dependencies in `/Users/mohiuddin/Projects/commerce_platform`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (107.0.0 available)
  analyzer 13.3.0 (14.3.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies in `/Users/mohiuddin/Projects/commerce_platform`!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +15: All tests passed!
--- packages/observability: NO TESTS ---
--- packages/sync: NO TESTS ---

======================================================
==> layering + secret guard rails
======================================================
==> packages must not import apps
==> an app must not import another app
==> backend must not be imported by client code
==> feature domain/ must not import Flutter, Firebase or UI packages
==> feature presentation/ must not import data/
==> feature application/ must not import presentation/
==> no direct notification-vendor SDK import outside an adapter
==> no committed secrets in tracked source

LAYERING CHECK: PASS

======================================================
==> summary
======================================================
workspace members declared : 15
members with tests run     : 10
members with NO TESTS      : 5
    - packages/design_system
    - packages/feature_flags
    - packages/networking
    - packages/observability
    - packages/sync

NOTE: members listed as NO TESTS carry no implementation at FND-001.
      Any task adding code to one of them must add tests with it.

ALL CHECKS PASSED

EXIT=0
```

**`ALL CHECKS PASSED`, exit 0.** This is a **real run on this branch with the
change applied**, not a summary of an earlier one.

**Disclosure about the paste above.** The per-test progress lines were elided
and every other line is reproduced verbatim. `dart test` / `flutter test` emit
one `HH:MM +n: <test name>` line per test as a running counter that overwrites
itself in a terminal — 1208 such lines across the 1424-line log. Each member's
**final** counter line (`+1155: All tests passed!` and so on) is retained, which
is the line that carries the result. Nothing that reports a failure, a skip, a
warning or a step outcome was removed; `[E]` failure blocks were explicitly
preserved by the filter and there were none. One line — `flutter analyze`'s
`Analyzing commerce_platform...` — had its **trailing spaces** trimmed so
`git diff --check` stays clean; that padding is a progress-indicator artifact
and carries no information. The unfiltered 1424-line log was
produced by the command shown and is reproducible by re-running it.

---

## What was NOT run

| Check | Status | Why |
|---|---|---|
| **GitHub CI** | **NOT RUN** | No `.github` directory exists anywhere in the tree — there is no workflow to run. **O7 (branch protection / CI governance) remains OUTSTANDING.** The local gate above is **not** CI and is **not** recorded as a CI pass. |
| Firebase / emulator tests | **NOT RUN** | Out of scope, and blocked on O4/O5. This task touches no Firebase surface. |
| Device / platform runs | **NOT RUN** | Out of scope, and blocked on O2/O3. This is a documentation and test change with zero executable delta. |
| `git push` / merge | **NOT RUN — deliberately prohibited** | The task forbids push, merge, squash, rebase, amend, cherry-pick and force-push. One normal commit was made on the new branch and nothing was published. |

```text
$ ls .github
ls: .github: No such file or directory
```

No check was skipped and then reported as a pass.

---

## What remains

### Recorded in the ledger, NOT fixed here — `AGENTS.md` §11 ADR index is stale

`AGENTS.md` §11 indexes the accepted decisions and **stops at ADR-0008**:

```text
$ sed -n '203,207p' AGENTS.md
`docs/decisions/` — ADR-0001 modular monorepo · ADR-0002 pub workspaces without
Melos · ADR-0003 `cp_` package prefix · ADR-0004 strict analysis and guard
rails · ADR-0005 notification stack decision required · ADR-0006 / ADR-0007
admin assignment override governance · ADR-0008 bounded delivery-proof policy
reference. Read the relevant ADR before changing what it decided.

$ ls docs/decisions/
ADR-0001-modular-monorepo.md
ADR-0002-pub-workspace.md
ADR-0003-package-name-prefix.md
ADR-0004-strict-analysis.md
ADR-0005-notification-stack-decision-required.md
ADR-0006-admin-picker-assignment-override.md
ADR-0007-admin-rider-assignment-override.md
ADR-0008-bounded-delivery-proof-policy-reference.md
ADR-0009-trusted-immutable-proof-assessment.md
ADR-0010-direct-rider-to-shop-return-route.md
ADR-0011-o6-currency-fees-commission-and-cash-custody.md
```

**ADR-0009** (trusted immutable proof assessment), **ADR-0010** (direct
rider-to-shop return route) and **ADR-0011** (O6 — currency, fees, commission
and cash custody) all exist and are cited elsewhere in the ledger, but the
canonical index omits all three. The instruction *"read the relevant ADR before
changing what it decided"* therefore points at an index that under-reports the
accepted decisions — including ADR-0011, which this very task cites in §7.

**This was NOT fixed.** `AGENTS.md` is in this task's **PROHIBITED SCOPE**, in
terms that anticipate exactly this finding: *"its §11 ADR index IS stale, but
fixing it is OUT OF SCOPE. Record it in the ledger as outstanding debt and say
so explicitly in the report."* Recorded in the ledger row and stated here. **It
needs its own bounded task.**

### Unchanged and still open (not this task's work)

- The **proof-satisfaction policy** itself is still undefined, so
  `CONSTRAINTS.md` invariant 13 is **undischarged** and successful delivery
  stays non-executable.
- The **dispute outcome** is still **UNDECIDED**. Two of its three stated
  prerequisites are now discharged (O6 via ADR-0011; FND-003B3B done), but the
  remaining **FND-003C** money work — remittance, settlement, reconciliation,
  refusal-fee collection, refunds, compensation, commission payout — is
  unimplemented, and a dedicated resolution slice must still decide the outcome.
- The six test files that pin the literal `39` still pin a literal. That is
  intentional and was **left alone**: they are behavioural guards for their own
  slices, not document guards, and converting them was outside this task's file
  list.

### Nothing was left undone inside the authorized scope

All four authorized files were changed as specified, and **no required repair
fell outside the authorized file list**. The one thing that did — `AGENTS.md`
§11 — was explicitly prohibited, is recorded rather than silently widened into,
and is reported above.

---

## Owner actions needed

| # | Action | Why it matters here |
|---|---|---|
| **O7** | **Configure branch protection / CI governance on `main`.** | **OUTSTANDING.** No `.github` directory exists, so no CI ran for this change and none can. The local gate is the only evidence, and it is not CI. |
| — | Review and merge this branch. | The task forbids push and merge; the commit exists locally only. |
| — | Schedule a task for the `AGENTS.md` §11 ADR index. | ADR-0009, ADR-0010 and ADR-0011 are missing from the canonical decision index. |

---

## Honesty statement (AGENTS.md §7)

- Every **PASS** above means *ran here, on this branch, with this change,
  succeeded, output available*. The gate output is a real run.
- **GitHub CI is recorded as NOT RUN**, never as a pass, and **O7 remains
  OUTSTANDING**.
- **No lint was weakened, no guard deleted and no ignore comment added.** The
  change adds a guard; it removes none.
- **Repository evidence contradicting earlier prose was reported, not
  smoothed over:** the task brief's "the 39th permission is
  `agent.return.record_receipt`" is chronologically right but positionally
  wrong (it is the 38th *declared*), and that correction is recorded above and
  reflected in the document's wording.
- The **FND-003C1-FIX-002 report and ledger row were not rewritten.** That row
  correctly recorded this debt as known and deliberately out of its scope; the
  row is **amended to record the discharge**, and the original description of
  the debt is preserved rather than deleted.
