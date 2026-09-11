# FND-003D1-BOOKKEEPING-FIX-001-FIX-001 completion report

**Branch:** `fnd/FND-003D1-bookkeeping-fix-001-proof-boundary-count`
**Baseline (`origin/main`):** `734863c62afa1dac166c7f328a015f1606640ef0`
**Starting HEAD / parent of this commit:** `64930e365a25bceb2e2129ed42d3668174291c59`
**Chain:** `734863c` → `64930e3` → *this commit*
**Scope:** documentation accuracy only — **four Markdown files, zero executable change**.

---

## Why this task exists

**FND-003D1-BOOKKEEPING-FIX-001-FINAL-REVIEW-001** independently reviewed
candidate `64930e3` and returned **FIX REQUIRED**, with two material
documentation-accuracy defects. **That review failure is not hidden**: `64930e3`
stays on the branch exactly as committed — not amended, not rebased, not
recreated — and this is a normal follow-up commit on top of it. The original
completion report keeps its text, with the corrections added inline as clearly
marked blocks.

Neither defect was in executable code. The contract tree at `64930e3` was, and
remains, correct.

### Defect 1 — a false present-tense claim in the re-stamped "Still true at 0.11" box

`64930e3` added to [`delivery-proof-boundary.md`](../contracts/delivery-proof-boundary.md):

> `DeliveryProofDisputeState` is still `open` / `underReview` with **no**
> resolved state;

`DeliveryProofDisputeState` declares **three** values. `resolved` **exists** —
declared for enum stability, and **unreachable**. The sentence therefore stated
something false about the 0.11 tree, inside the one box whose marker this very
task advanced to 0.11 on the strength of a claim-by-claim re-check, and it
contradicted [`delivery-proof-dispute.md`](../contracts/delivery-proof-dispute.md)
(line 149: *"`open` / `underReview`, plus unreachable `resolved`"*) and the two
tests pinning `DeliveryProofDisputeState.values.length == 3`.

### Defect 2 — a declaration ordinal read off a grep line number

The original report stated, in §A5 and again in its honesty statement, that
`agent.return.record_receipt` is *"the **38th declared** value"*. The `38` was
the **file line number** printed by `grep -n`. The declaration ordinal is
**index 12 — the 13th declared value**. The same passage also asserted that the
document had been worded *"took it to 39"* rather than *"added the 39th"*, while
the committed document still read *"B3B did add the **39th permission** at
0.10"*.

---

## What was created

| # | File | Change |
|---|---|---|
| 1 | [`docs/contracts/delivery-proof-boundary.md`](../contracts/delivery-proof-boundary.md) | **M** — dispute-state sentence corrected (defect 1); *"added the 39th permission"* replaced with the chronological formulation (defect 2) |
| 2 | [`docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-001-completion-report.md`](FND-003D1-BOOKKEEPING-FIX-001-completion-report.md) | **M** — review-outcome banner; §(c) table row; §A5 ordinal correction; §A6 change-set count; honesty-statement correction |
| 3 | [`docs/task-ledger/TASK_LEDGER.md`](TASK_LEDGER.md) | **M** — the existing FND-003D1-BOOKKEEPING-FIX-001 row only: dispute-state clause corrected, review outcome and this follow-up recorded |
| 4 | `docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-001-FIX-001-completion-report.md` | **A** — this report |

Nothing else. No Dart file, no `lib/` file, no ADR, no other task's row.

---

## A. The dispute-state correction (defect 1)

**Before** (`64930e3`, `delivery-proof-boundary.md` lines 40–41):

```text
> `resourceId` and `evidenceId`); `DeliveryProofDisputeState` is still
> `open` / `underReview` with **no** resolved state;
```

**After:**

```text
> `resourceId` and `evidenceId`); `DeliveryProofDisputeState` remains
> `open` / `underReview` **plus the unreachable `resolved`** — that third value
> **does exist**, declared for enum stability only, and it stays unreachable:
> **no command transitions into it** and `reachableDisputeRevisionFor` returns
> **null** for it, exactly as
> [delivery-proof-dispute.md](delivery-proof-dispute.md) records. **No
> resolution policy exists**, and none is implied by the value being declared;
```

The sentence continues, unchanged, into *"`dispute.resolve_delivery_proof` is
still enumerated and always refused `resolutionPolicyDeferred`"*, so the
enumerated-but-refused command and the declared-but-unreachable state are now
described the same way — which is what made the original asymmetry a defect.

**Requirements met:** `resolved` is stated to exist; stated to remain
unreachable; **no resolution policy is invented or implied** (the text says
explicitly that none exists); nothing became executable; the wording now matches
`delivery-proof-dispute.md` and the enum and reachability tests; and the
"Still true at 0.11" marker is true again.

### Evidence

```text
$ dart run bin/probe.dart            # out-of-tree probe, path dep on packages/contracts
DisputeState.values.length           = 3
DisputeState.values                  = [open, underReview, resolved]
notYetImplemented                    = [resolved]
executableInThisSlice                = [open, underReview]
reachableDisputeRevisionFor(resolved)= null
reachableDisputeRevisionFor(open)    = 1
reachableDisputeRevisionFor(underRev)= 2
```

```text
$ sed -n '27,41p' packages/contracts/lib/src/delivery_proof_dispute_state.dart
  /// **NOT EXECUTABLE, and unimplemented by every slice.**
  ///
  /// Declared for enum stability only, exactly as `OrderState.delivered` is.
  ...
  /// No command transitions into it ([DeliveryProofDisputeCommand.resolve] is
  /// enumerated and refused), no revision cost for it was invented
  /// ([reachableDisputeRevisionFor] returns null), and a stored record holding
  /// it is **corruption**, not a state this contract can read.
  resolved;

$ grep -n 'DeliveryProofDisputeCommand.resolve =>' packages/contracts/lib/src/delivery_proof_dispute_transition.dart
73:    DeliveryProofDisputeCommand.resolve => const <String>[],   # no edge

$ grep -n 'evaluateResolveDeliveryProofDispute' -A3 packages/contracts/lib/src/delivery_proof_dispute_evaluator.dart
DeliveryProofDisputeOutcome evaluateResolveDeliveryProofDispute() =>
    const DeliveryProofDisputeOutcome.deny(
      DeliveryProofDisputeDenial.resolutionPolicyDeferred,
    );

$ grep -n 'DeliveryProofDisputeState' docs/contracts/delivery-proof-dispute.md | sed -n '1p'
149:| `DeliveryProofDisputeState` | `open` / `underReview`, plus unreachable `resolved` |
```

**`delivery-proof-dispute.md` itself is not modified** — it was already correct
and is byte-identical to `64930e3`.

---

## B. The chronological permission correction (defect 2, document side)

**Before** (`64930e3`, lines 45–47):

```text
> unreachable, so `CONSTRAINTS.md` invariant 13 is still undischarged. B3B did
> add the **39th permission** at 0.10 — that changes the *count* (§1, §5), not
> any claim above.
```

**After:**

```text
> unreachable, so `CONSTRAINTS.md` invariant 13 is still undischarged. B3B did
> take the permission count **38 → 39** at 0.10 by adding
> `agent.return.record_receipt` — that changes the *count* (§1, §5), not any
> claim above.
```

No ordinal, no declaration-order claim, and it now matches §1 and §5, which
already used the chronological form (*"moved **38 → 39** at contract 0.10"*,
*"took it to 39 at 0.10"*) and are unchanged. The true statement that **D2A and
D2B added no permission** is preserved verbatim in §1; the current count stays
**39**; nothing about `admin.release.view_health` — still last in declaration
order — was touched anywhere.

---

## C. The declaration-ordinal correction (defect 2, report side)

Three numbers were being conflated. The corrected report keeps them apart:

| Quantity | Value | Obtained by |
|---|---|---|
| File line number in `permission.dart` | **38** | `grep -n` — a text position, no ordinal meaning |
| **Declaration ordinal** of `agent.return.record_receipt` | **index 12 = 13th declared** | `Permission.values.indexOf(...)` |
| Chronological effect on the total | count **38 → 39** at **0.10** | the vocabulary grew by one at FND-003B3B |

```text
$ dart run bin/probe.dart
indexOf(agentRecordReturnReceipt)    = 12  => 13th declared
Permission.values[37].id (38th decl) = admin.cash.record_reconciliation
Permission.values.last.id            = admin.release.view_health

$ grep -n "agentRecordReturnReceipt" packages/contracts/lib/src/permission.dart
38:  agentRecordReturnReceipt('agent.return.record_receipt'),     # line 38, NOT ordinal 38
```

Corrections applied to
[`FND-003D1-BOOKKEEPING-FIX-001-completion-report.md`](FND-003D1-BOOKKEEPING-FIX-001-completion-report.md):

1. **Review-outcome banner** at the top: FIX REQUIRED, both defects named, and
   the follow-up that corrects them.
2. **§(c) marker table**, the *"No dispute resolves"* row: now records the
   unreachable `resolved`, and flags that the wording committed at `64930e3`
   wrongly said the value does not exist.
3. **§A5**: a marked correction block replacing *"It is the **38th declared**
   value"* — the misreading is named as a `grep -n` line number read as an
   ordinal, the three quantities are tabulated, and the 38th declared value is
   identified as `admin.cash.record_reconciliation`. The block also records that
   the claim about avoiding *"added the 39th"* wording was inaccurate as
   committed, and that **FIX-001 changes the document to "took the count from 38
   to 39 at 0.10"**, making that stated intent true of the committed text.
4. **§A6**: the `files in change set : 3` line is annotated in place and
   followed by a correction note — **three implementation artifacts plus that
   completion report; four committed files total** at `64930e3`. The `.dart`
   file count, the "no `lib/` file" result and the vacuous comment-stripped
   delta are unaffected.
5. **Honesty statement**: the *"38th declared"* clause corrected to **index 12 /
   13th declared**, with the chronological fact restated as unchanged.

No original text was deleted or silently rewritten; every correction is a
visible, attributed block.

---

## What was verified

### Semantic sweeps

```text
$ git grep -nE 'no\*{0,2} resolved state|with no resolved' -- docs/
docs/task-ledger/TASK_LEDGER.md:52:  ... quoted inside the REVIEWED AND CORRECTED note, as the
                                     defect being described ...
```

The single remaining hit is the **quotation of the defect** in the ledger's
record of the review finding. No document asserts it.

```text
$ git grep -n '38th' -- docs/
FND-003D1-BOOKKEEPING-FIX-001-completion-report.md:24,194,205,773,776   corrections / the true 38th value
TASK_LEDGER.md:52                                                       quoted defect in the review record
```

```text
$ git grep -n '39th' -- docs/            # positional claims only
permission-matrix.md:8                          chronological, accurate, untouched
FND-003C1-FIX-002-completion-report.md:85,94,101 chronological, accurate, historical
FND-003D1-…-completion-report.md:180             probe output: "39th permission (index 38) = admin.release.view_health" — ACCURATE (0-based 38 is the 39th declared)
FND-003D1-…-completion-report.md:184,185,206,220 chronological, or the marked correction itself
FND-003D1-…-completion-report.md:27,210,211      quoting the corrected wording
TASK_LEDGER.md:49,52                             chronological / quoted defect
delivery-proof-boundary.md                       NO MATCH — no ordinal claim remains
```

```text
$ grep -n '38' docs/contracts/delivery-proof-boundary.md
51:> take the permission count **38 → 39** at 0.10 by adding      historical transition
92:let this paragraph go stale: `Permission.values` is **39**, not 38.   explicit negation
93:moved **38 → 39** at contract **0.10**, when FND-003B3B added  historical transition
243:is not 38 either: FND-003B3B took it to 39 at 0.10 by adding   explicit negation
```

Four occurrences, all historical or explicit corrections; **zero present-tense
claims that the count is 38**.

```text
$ git grep -n 'Permission count:' -- docs/contracts/
docs/contracts/delivery-proof-boundary.md:247:> **Permission count: 39**
```

Still exactly one canonical anchor, still **39**.

### Contract facts (mechanical)

```text
$ dart run bin/probe.dart
ContractVersion.current              = 0.11
Permission.values.length             = 39
permissionMatrix.length              = 39
DisputeState.values.length           = 3
DisputeState.values                  = [open, underReview, resolved]
reachableDisputeRevisionFor(resolved)= null
```

### Technical tree unchanged since `64930e3`

```text
$ git diff --name-only 64930e3 -- packages/ apps/ '*.dart' \
      docs/contracts/permission-matrix.md docs/contracts/delivery-proof-dispute.md \
      AGENTS.md docs/decisions/
                                                        (empty — byte-identical)

$ git diff --stat 64930e3 -- packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart
                                                        (empty — the guard test is untouched)

$ git status --porcelain          # before this commit was made
 M docs/contracts/delivery-proof-boundary.md
 M docs/task-ledger/FND-003D1-BOOKKEEPING-FIX-001-completion-report.md
 M docs/task-ledger/TASK_LEDGER.md
                                  # + the new, untracked FIX-001 report

$ git diff --check
                                                        (clean, exit 0)
```

### Tests

```text
$ cd packages/contracts && dart test \
    test/delivery_proof_boundary_doc_consistency_test.dart \
    test/delivery_proof_dispute_model_test.dart \
    test/delivery_proof_dispute_regression_test.dart \
    test/delivery_proof_dispute_authority_test.dart \
    test/permission_matrix_test.dart \
    test/permission_matrix_doc_consistency_test.dart \
    test/delivery_proof_test.dart
00:00 +148: All tests passed!

$ cd packages/contracts && dart test
00:01 +1155: All tests passed!
```

**1155, unchanged from `64930e3`** — this commit adds no test and removes none.
The derived guard added at `64930e3` still passes against the edited document:
its anchor is untouched and no stale present-tense claim was introduced.

### Full gate

```text
$ ./tools/run_checks.sh
==> flutter pub get (workspace root)
==> workspace membership (source of truth: pubspec.yaml workspace:)
==> declared workspace members: 15
==> every declared member exists and sets 'resolution: workspace'
==> no on-disk package under apps/ or packages/ is undeclared
==> declared set matches the resolved package_config.json
WORKSPACE CHECK: PASS (15 declared members)
==> flutter analyze (workspace root, covers every member)
No issues found! (ran in 2.0s)
==> tests for each of the 15 declared workspace members
    ... packages/contracts: 00:01 +1155: All tests passed! ...
==> layering + secret guard rails
==> packages must not import apps
==> an app must not import another app
==> backend must not be imported by client code
==> feature domain/ must not import Flutter, Firebase or UI packages
==> feature presentation/ must not import data/
==> feature application/ must not import presentation/
==> no direct notification-vendor SDK import outside an adapter
==> no committed secrets in tracked source
LAYERING CHECK: PASS
==> summary
workspace members declared : 15
members with tests run     : 10
members with NO TESTS      : 5
ALL CHECKS PASSED

EXIT=0
```

**Disclosure about the paste above.** It is a **real run on this branch with
all four files in place**, made after the last edit. The per-test progress
counter lines — `HH:MM +n: <test name>`, which overwrite themselves in a
terminal — were elided: **1207 of the 1423 log lines**, leaving 216. Every
member's **final** counter (`+1155: All tests passed!` at log line 1324, and
the others) is retained, and the block above is further condensed to the step
headers. Nothing reporting a failure, skip or warning was removed: a
`grep -cE '\[E\]|FAIL|Some tests failed|error •'` over the **unfiltered** log
returns **0**. The full log is reproducible by re-running the command.

---

## Zero executable change

```text
files changed by this commit : 4   (all .md)
.dart files                  : NONE
files under any lib/         : NONE
ContractVersion.current      : 0.11   (unchanged)
Permission.values.length     : 39     (unchanged)
permissionMatrix.length      : 39     (unchanged)
```

No permission, ADR, command, event, state, journal account, proof-satisfaction
policy, dispute outcome, delivery confirmation, settlement, remittance, refund,
commission or FND-004 work was added, changed or implied.

---

## What was NOT run

| Check | Status | Why |
|---|---|---|
| **GitHub CI** | **NOT RUN** | No `.github` directory exists anywhere in the tree; there is no workflow to run. **O7 remains OUTSTANDING.** The local gate is not CI and is not recorded as one. |
| CJ1–CJ12 | **NOT RUN** | Contract/documentation-only change; no journey surface is touched. |
| Migration / rules / indexes | **N/A** | No schema, Firestore rule or index is involved. |
| Firebase / emulator | **NOT RUN** | Out of scope, blocked on O4/O5; no Firebase surface touched. |
| Device / platform / deployment | **NOT RUN** | Out of scope, blocked on O2/O3; documentation-only change. |
| `git push` / merge / tag | **NOT RUN — prohibited by the task** | One normal follow-up commit was made on the existing branch. Nothing was amended, rebased, squashed, cherry-picked, pushed, force-pushed, deployed, tagged or released. |

---

## What remains

- **Independent review.** The chain `734863c` → `64930e3` → *this commit* goes
  back to ADMIN for one fresh read-only review before any publication decision.
  Publication state is deliberately not written into prose anywhere: **git
  history is the authority** (`git merge-base --is-ancestor <sha> origin/main`).
- **`AGENTS.md` §11 ADR-index debt — still outstanding, still unfixed here.**
  The index stops at **ADR-0008** and omits **ADR-0009**, **ADR-0010** and
  **ADR-0011**, all of which exist in `docs/decisions/`. `AGENTS.md` is not an
  authorized file for this task and is byte-identical to `64930e3`. It needs its
  own task.
- **O7** — branch protection / CI governance on `main`.

---

## Owner actions needed

| # | Action | Why it matters here |
|---|---|---|
| **O7** | **Configure branch protection / CI governance on `main`.** | **OUTSTANDING.** No CI ran for this change and none can; the local gate is the only evidence. |
| — | Review the three-commit chain. | This task forbids publication; ADMIN decides after an independent review. |
| — | Schedule a task for the `AGENTS.md` §11 ADR index. | ADR-0009, ADR-0010 and ADR-0011 are missing from the canonical decision index. |

---

## Honesty statement (AGENTS.md §7)

- Every **PASS** above means *ran here, on this branch, with these edits,
  succeeded, output available*.
- **The earlier review failure is recorded, not hidden.** `64930e3` returned
  **FIX REQUIRED** and stays on the branch unmodified; the original report keeps
  its text with visible correction blocks; the ledger row records the finding.
- **Both defects were documentation accuracy.** Nothing executable was wrong at
  `64930e3`, and nothing executable changed here.
- **No lint was weakened, no guard deleted, no ignore comment added.** The guard
  test added at `64930e3` is byte-identical and still passing.
- **GitHub CI is recorded as NOT RUN**, never as a pass.
- **No publication claim is made** in any file this task touched, and no mutable
  publication-state prose was written into the ledger.
