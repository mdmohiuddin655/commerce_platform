# FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-002 completion report

- **Task:** correct the one current canonical status defect FIX-001 found in
  `docs/contracts/cash-and-payments.md`, and correct FIX-001's own classification
  which implied that two dated historical records also needed future tasks.
- **Owner:** ADMIN / shared contract documentation.
- **Baseline `origin/main`:** `81c623ec1537b99a86e57b6572f9d6cce3a06c3b`,
  verified by both `git rev-parse origin/main` and
  `git ls-remote origin refs/heads/main`, and unchanged by this task.
- **Starting HEAD / parent of this commit:**
  `f946c9788a92046af548df0860490d86b69fa7c2`.
- **Branch:** `fnd/FND-003D3-proof-satisfaction-policy-001`.
- **Scope:** documentation status accuracy only. **Zero executable change.**

**The distinction this task exists to make, stated once:**

> The proof-satisfaction **policy** is **defined** by ADR-0012.
> The executable proof-satisfaction **mechanism** is **unimplemented and
> unreachable**.
> The dated `version-history.md` 0.10 entry and `ADR-0010` statements are
> **accurate historical snapshots** and require **no** correction.

---

## 1. Preconditions

```text
$ git status --short          # before any edit
(empty — clean)

$ git rev-parse HEAD
f946c9788a92046af548df0860490d86b69fa7c2
$ git rev-parse origin/main
81c623ec1537b99a86e57b6572f9d6cce3a06c3b
$ git ls-remote origin refs/heads/main
81c623ec1537b99a86e57b6572f9d6cce3a06c3b        refs/heads/main
                                        ↑ both agree

single-parent topology, zero merges:
  6c4c25a2…  ->  81c623ec…
  f946c978…  ->  6c4c25a2…
```

---

## 2. Files changed — exactly four

| # | File | Change |
|---|---|---|
| 1 | `docs/contracts/cash-and-payments.md` | §8 status list: the **policy** replaced by the **executable mechanism**, plus the explicit distinction naming ADR-0012 |
| 2 | `docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-001-completion-report.md` | §4 conclusion corrected; discovery evidence preserved |
| 3 | `docs/task-ledger/TASK_LEDGER.md` | FIX-001 row's finding classified and closed; one new FIX-002 row |
| 4 | `docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-002-completion-report.md` | **NEW** — this report |

**Not touched:** `ADR-0010` · `ADR-0012` · every other ADR ·
`docs/contracts/version-history.md` · `docs/contracts/README.md` · all three
delivery-proof documents · `AGENTS.md` · `CONSTRAINTS.md` ·
`SHARED_BLUEPRINT.md` · every Dart, test and `lib/` file.

---

## 3. The correction — `docs/contracts/cash-and-payments.md` §8

**Before** (§8 *"What a collection cannot do"*):

```text
Still unreachable and untouched: `OrderState.delivered`,
`CustodyHolderKind.customer`, rider `AssignmentState.completed` (**B3-C2
FUTURE**), the proof-satisfaction policy, dispute resolution, refusal-fee
collection, refunds, compensation, commission payout, worker pay, reconciliation
and FX.
```

**After:**

```text
Still unreachable and untouched: `OrderState.delivered`,
`CustodyHolderKind.customer`, rider `AssignmentState.completed` (**B3-C2
FUTURE**), the **executable proof-satisfaction mechanism**, dispute resolution,
refusal-fee collection, refunds, compensation, commission payout, worker pay,
reconciliation and FX.

**The proof-satisfaction *policy* is decided; its *mechanism* is not.**
[ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md)
(2026-09-12, owner decision **O8**) defines what a delivery-proof policy
requires. It adds no challenge lifecycle, evaluator, command, event, state or
permission, so the **executable proof-satisfaction mechanism and the
successful-delivery transaction remain unimplemented and unreachable**,
`CONSTRAINTS.md` invariant 13 remains **not discharged**, and nothing in this
document becomes reachable because of it. **Collecting cash still does not
satisfy a proof policy** — ADR-0012 keeps the two facts separate in both
directions, exactly as this section already says.
```

**Why this was a genuine defect.** `cash-and-payments.md` carries a
**running-current header** — *"Contract 0.11. Additive."* — and §8's sentence is a
**present-tense list of what is still unreachable and untouched**. It is not a
per-slice record of what FND-003C1 did; it is a claim about the repository now.
Listing the *policy* there stopped being true when ADR-0012 was accepted. The
list itself is otherwise accurate and is unchanged.

**Requirements met.**

| Requirement | How |
|---|---|
| Distinguish policy from executable mechanism | Both the list entry and the new paragraph say it explicitly |
| Name ADR-0012 | Linked, with its date and owner decision |
| Invariant 13 stays undischarged | Stated in the new paragraph; §1's *"invariant 13 remains **not discharged**"* is untouched |
| Successful delivery stays unreachable | Stated; `OrderState.delivered` remains first in the unreachable list |
| Customer custody and rider completion stay unreachable | `CustodyHolderKind.customer` and rider `AssignmentState.completed` (**B3-C2 FUTURE**) remain in the list, unchanged |
| Do not imply cash collection satisfies proof | The new paragraph says the opposite in terms, and reinforces §8's existing separation |
| No financial semantics changed | No COD, journal, fee, commission, settlement, reconciliation, FX, `PaymentState`, posting or balance rule is touched — the diff is confined to §8's status list plus the appended paragraph |
| No executable specification added | No type, field, command, event, state or permission is named as existing; the paragraph states what does **not** exist |
| No unrelated cash/payment documentation rewritten | The rest of the document is byte-identical |

---

## 4. Historical classification — verified, and left untouched

Both records were checked **structurally**, not by reading their prose in
isolation.

### `docs/contracts/version-history.md:553` — historical, not debt

```text
nearest preceding heading  ->  line 516: ## 0.10 — FND-003B3B — delivery attempt
                                         and return lifecycles
subsection                 ->  **Not added, and not decided**
statement                  ->  "Successful delivery is still not executable: the
                                proof-satisfaction policy is undefined, …"
```

The document is a **per-version record** — its own opening frames it as the
history of `ContractVersion` — and this statement lives inside the **0.10**
entry's *"Not added, and not decided"* subsection. It records what contract 0.10
did **not** decide. That was true then and remains true: the policy was undefined
throughout that slice, and ADR-0012 came two contract versions later without
changing what 0.10 did.

FIX-001 called the present tense *"borderline"*. On inspection that was an
over-reading of a per-version record, and the correct classification is
**accurate historical record**. **No correction is required, and none was made.**

### `ADR-0010:191` — historical, not debt

```text
front matter  ->  Status: Accepted · Date: 2026-09-11 · Task: FND-003B3B
                  Contract: 0.9 → 0.10 (additive)
section       ->  ## Consequences
statement     ->  "Successful delivery remains non-executable — the
                   proof-satisfaction policy is still undefined and
                   CONSTRAINTS.md invariant 13 is not discharged."
```

This is the *Consequences* section of a **dated, Accepted decision record**,
describing the state at the time that decision was taken. ADRs are dated
decision records, not running status pages — the same reading the repository
already applies to ADR-0008's *"no proof mechanism, satisfaction policy … was
added by either"* and to ADR-0009's deferrals. Rewriting an accepted ADR's
consequences to match a later decision would destroy the record of what was known
when it was made.

Its first clause is also **still literally true**: successful delivery does remain
non-executable, and invariant 13 does remain undischarged.

**No correction is required, and none was made.** Changing it is additionally
prohibited to this task.

**Neither record asserts current repository status outside its historical scope**,
so no BLOCKED condition arose.

---

## 5. Repository-wide semantic sweep

| Term | Result at HEAD | Classification |
|---|---|---|
| *proof-satisfaction policy is undefined* / *policy still undefined* / *policy remains undefined* | **Zero** in active canonical overview/contract documents. Remaining: `version-history.md` 0.10 entry, `ADR-0010` Consequences | **explicitly historical / slice-scoped** |
| *policy untouched* / *policy unreachable* | **Zero** — the last one (`cash-and-payments.md` §8) is corrected by this task | **defect, now discharged** |
| *proof-satisfaction mechanism* | `cash-and-payments.md` §8 (new), and the equivalent distinction in ADR-0012, the boundary, assessment and dispute documents and `README.md` | **accurate current implementation fact** |
| *invariant 13* | Every occurrence in active documents states **not discharged** | **accurate current fact** |
| *successful delivery* | Every occurrence states **not executable / unavailable** | **accurate current fact** |
| *customer custody* / *rider `completed`* | Every occurrence states **unreachable** | **accurate current fact** |
| *ADR-0012* | ADR-0012 itself, `AGENTS.md` §11, `CONSTRAINTS.md` invariant 13, the three delivery-proof documents, `README.md`, `cash-and-payments.md` (new), the ledger and these reports | **accurate current policy fact**; every link resolves |

Occurrences inside completion reports that quote earlier states are **preserved
quotations** and were not touched.

**Zero stale current-state "policy undefined" claims remain in active canonical
overview or contract documents.** **No historical evidence was rewritten** — the
FIX-001 report's §4 discovery table, its captured command output and every
quotation are byte-identical; only the conclusion beneath them is corrected, by
addition.

---

## 6. Validation

```text
$ git status --short          # before edits
(empty — clean)

$ git diff --check
(clean, exit 0)

$ git diff --name-status f946c978..HEAD
M  docs/contracts/cash-and-payments.md
A  docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-002-completion-report.md
M  docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-001-completion-report.md
M  docs/task-ledger/TASK_LEDGER.md
                                  → exactly the four authorized files
```

**Live probe — not grepped**

```text
ContractVersion.current        = 0.11
Permission.values.length       = 39
permissionMatrix.length        = 39
matrix missing keys            = 0
```

**Untouched, mechanically confirmed**

```text
*.dart / */lib/* / tests   → no change
docs/decisions/            → no change (ADR-0010 and ADR-0012 included)
version-history.md         → no change
README.md                  → no change
delivery-proof-*.md        → no change
AGENTS.md / CONSTRAINTS.md / SHARED_BLUEPRINT.md → no change
O7 row                     → zero diff lines; still OUTSTANDING
O8 row                     → unchanged; still RESOLVED (policy level)
```

No enum value, evaluator, transition, command, event, permission or denial
changed, so **no executable transition becomes reachable**. `OrderState.delivered`,
`DeliveryAttemptState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable, and **invariant 13 remains
undischarged at the executable level**.

**Tests and gate**

```text
packages/contracts    → 1162 tests passed (unchanged)
./tools/run_checks.sh → ALL CHECKS PASSED, exit 0
```

**All previous commits remain unamended** — `6c4c25a2…` still has parent
`81c623ec…`, and `f946c978…` still has parent `6c4c25a2…`.

---

## 7. What this report does not claim

**Nothing here is self-certified.** This task ran no independent review of its
own corrections; acceptance is for a fresh, read-only cumulative review session.

**Publication state is determined by git history, not by report prose.** No
statement in this report says whether any commit is on any branch or remote.

**GitHub CI: NOT RUN / NONE** — no `.github` directory exists.

---

## 8. Confirmation — no push occurred

One normal follow-up commit. **Nothing was pushed.** No amend, rebase, merge,
squash, cherry-pick, reset or force; no tag or release; no deployment; no
Firebase, backend or live-data access; no repository, CI or branch-protection
change; the implementation slice was not started. `origin/main` is still
`81c623ec1537b99a86e57b6572f9d6cce3a06c3b`.

```text
81c623ec1537b99a86e57b6572f9d6cce3a06c3b
→ 6c4c25a2bbc7a555b01447fa790d0c64b4ce2c7d
→ f946c9788a92046af548df0860490d86b69fa7c2
→ <this commit>
```
