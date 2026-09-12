# FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-001 completion report

- **Task:** correct the five findings **FND-003D3-PROOF-SATISFACTION-POLICY-001-FINAL-REVIEW-001**
  raised against `6c4c25a`, as one normal follow-up commit.
- **Owner:** ADMIN / shared delivery contracts.
- **Baseline `origin/main`:** `81c623ec1537b99a86e57b6572f9d6cce3a06c3b`,
  verified by both `git rev-parse origin/main` and
  `git ls-remote origin refs/heads/main`, and unchanged by this task.
- **Starting HEAD / parent of this commit:**
  `6c4c25a2bbc7a555b01447fa790d0c64b4ce2c7d` (single parent
  `81c623ec…`; **not amended**).
- **Branch:** `fnd/FND-003D3-proof-satisfaction-policy-001`.
- **Scope:** policy clarification and documentation only. **Zero executable
  change.**

> **Source of the findings.** No `FINAL-REVIEW-001` result document is committed
> to this repository; the five findings were supplied in this task's brief, and
> each was **independently re-derived against the tree** before being corrected —
> every one reproduced, and F5's README claim reproduced with a larger count than
> reported (three statements, not two). Where the brief and the tree disagreed,
> the tree is what this report records.

---

## 1. Preconditions

```text
$ git status --short          # before any edit
(empty — clean)

$ git rev-parse HEAD
6c4c25a2bbc7a555b01447fa790d0c64b4ce2c7d
$ git rev-list --parents -n 1 6c4c25a2…
6c4c25a2bbc7a555b01447fa790d0c64b4ce2c7d 81c623ec1537b99a86e57b6572f9d6cce3a06c3b

$ git rev-parse origin/main
81c623ec1537b99a86e57b6572f9d6cce3a06c3b
$ git ls-remote origin refs/heads/main
81c623ec1537b99a86e57b6572f9d6cce3a06c3b        refs/heads/main
                                        ↑ both agree
```

---

## 2. Files changed — exactly eight

| # | File | Change |
|---|---|---|
| 1 | `docs/decisions/ADR-0012-delivery-proof-satisfaction-policy.md` | F1–F4: Decision 9 rewritten, Decision 1 gains the retrieval channel class and corrected route-2 rationale, **new Decision 11**, and Decisions 4/5/6/10, the deferral table, alternatives, consequences and the supersession rule aligned |
| 2 | `docs/contracts/delivery-proof-boundary.md` | exception boundary, retrieval-surface deferral, mandatory-participation clause, inherited fail-closed list |
| 3 | `docs/contracts/delivery-proof-assessment.md` | participation and override rows sharpened; **new fail-closed policy-version row** |
| 4 | `docs/contracts/delivery-proof-dispute.md` | same three changes |
| 5 | `docs/contracts/README.md` | F5: three stale current-state statements corrected |
| 6 | `docs/task-ledger/TASK_LEDGER.md` | FND-003D3 row records the review verdict and findings; one new FIX-001 row; out-of-scope debt recorded |
| 7 | `docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-completion-report.md` | review outcome recorded, sweep overclaim corrected, exception wording re-stated |
| 8 | `docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-001-completion-report.md` | **NEW** — this report |

**Not touched:** every Dart, test and `lib/` file · `AGENTS.md` ·
`CONSTRAINTS.md` · `SHARED_BLUEPRINT.md` · `CONTRIBUTING.md` · **every ADR
except ADR-0012** · every other contract document.

---

## 3. The five findings and their corrections

### F1 — MAJOR — exception review could conclude satisfaction

**The defect.** Decision 9 opened *"An ADMIN exception review may conclude
satisfaction for such a case"*, and listed a lost or dead handset and a customer
unable to read a value among those cases. Decision 1 simultaneously said customer
participation is **mandatory**. Both could not be true: an administrator could
convert customer absence into `satisfied`, which is mandatory participation in
name and optional in practice.

**The correction.** Decision 9 is retitled *"exception review records an
unresolved case; it cannot conclude satisfaction"* and now opens with the rule in
a block quote:

> A customer-side fulfilment is **REQUIRED** for proof satisfaction under this
> ADR. **No** ADMIN exception review, and no other administrative act, may
> produce `DeliveryProofAssessmentVerdict.satisfied` for a delivery where no
> customer-side fulfilment occurred.

The withdrawn wording is **named in the ADR**, not deleted silently. Exception
review may now **record, classify and audit**; it may **not** mark proof
satisfied, mark an order delivered, waive the requirement, assign customer fault,
create a fee, resolve a dispute, or substitute a photograph, GPS fix, timestamp,
unbound signature, rider statement, cash collection or administrator judgement
for a customer act. An unresolved case **stays unresolved** — canonical absence,
and Decision 6 governs it.

An accessibility-compatible alternative may be designed later, but it must remain
**an act attributable to the customer side under authenticated, server-verified
rules**: changing the *presentation* of a customer act is inside this ADR;
removing the act is not. Any future substitution requires a **superseding ADR and
contract migration, accepted BEFORE implementation** — explicitly not a policy
version, a configuration change, an implementation detail, or a widening of
`executableProofAssessorKinds`.

Aligned in the same commit: the canonical-definitions row for *Exception review*;
Decision 4's *"may be shown in an exception review"* → *"may be recorded"*;
Decision 10's allowed list (exception-**recording** path) and forbidden list;
the alternatives table, which gains a row rejecting **any** admin override that
concludes satisfaction, audited or not; the consequences bullet; and the
supersession rule.

### F2 — MAJOR — no secure retrieval channel for the challenge

**The defect.** Route 1 required the customer to read a value to the rider, but
the ADR said only that the customer "receives the challenge value through a
channel the platform controls" — naming no channel class — while Decision 5
forbade the value in any notification payload and the deferral table listed
*"Notification transport for delivering a challenge to a customer"*. Read
together, the only named transport was one the ADR itself prohibited.

**The correction.** Decision 1 gains *"How the customer obtains the challenge —
the required channel class"*:

- an **authenticated, customer-scoped pull/retrieval surface controlled by the
  platform** — the customer's own session asks, the server returns only to that
  session;
- **authentication binds the exact customer and the exact resource**; a session
  may retrieve only for an order its principal owns;
- normally a future **authenticated User-app screen or equivalent first-party
  customer session**; no UI, API shape or transport is chosen;
- **the rider must never retrieve the customer's raw challenge** —
  `rider.delivery.submit_proof` confers submit, not read, and no rider-facing
  surface may display it;
- **a notification may signal availability** and deep-link into the surface, and
  **never carries the value**;
- events, logs, crash reports and audit records never carry it.

It closes: *"This is a specification of what a compliant channel must be, not a
claim that one exists."* **Route 1 is not executable until the surface is built
and accepted.** Decision 5 gains the matching clause — the customer's own session
*displays* and performs no comparison, and **the absence of a notification
transport is not a licence to deliver the secret some less safe way**.

The deferral row is renamed to *"Notification transport for **signalling
challenge availability**"*, links [ADR-0005](../decisions/ADR-0005-notification-stack-decision-required.md)
as the governing decision (still *Proposed — blocked on an owner decision*), and
states that notification is optional signalling, never secret delivery. A new
deferral row records the authenticated retrieval surface itself.

### F3 — MINOR — route 2's rationale was not true

**The defect.** Route 2 was justified by *"a customer without their phone to
hand, a shared handset, a doorstep with no signal on the customer side"* — none
of which route 2 can help, since it *is* an authenticated confirmation made from
the customer's connected device.

**The correction.** The rationale now states plainly that **both routes require
an authenticated session on a working, connected device**, and gives honest
reasons: not reading a value aloud at the door in front of whoever else is there;
removing rider transcription and keypad error; a **direct authenticated customer
act** with one less hop; and a customer already signed in who can confirm without
fetching the value. It adds that a customer with no usable device, session or
connectivity produces no fulfilment on **either** route, and Decision 9 governs
that — by recording the case, **not** by someone else satisfying the policy.

### F4 — MINOR — no fail-closed rule for an unresolvable policy version

**The defect.** Every rule was stated relative to *the policy named by the
order's `DeliveryProofPolicyRef`*, and nothing said what happens when that name
cannot be turned into a loaded, verified policy version.

**The correction — new Decision 11**, *"a policy that cannot be resolved cannot
be satisfied"*, with five distinct conditions each yielding **not satisfied**:
reference **missing**; version **unknown**; version **unresolvable**; version
**unsupported** by the verifying build; version **unverifiable** (corrupt,
truncated, failing its own integrity check).

**No default policy is inferred, ever** — no built-in fallback, no silent
substitution of the **latest** version, no reuse of a previous attempt's or a
neighbouring resource's version, no treating an unresolvable reference as "no
policy required", no downgrading an unsupported version to a weaker understood
one. The reason is stated: an order keeps the version it was quoted under, so
evaluating it under another decides it by rules it was never quoted — worse than
refusing. These failures are **operational, not fault-bearing**.

Mirrored into Decision 6's fail list, Decision 10's forbidden-configuration list,
the supersession rule, and all three delivery-proof contract documents.

### F5 — MINOR — sweep overclaim, and stale README wording

**The defect.** The original report said its semantic sweep ran *"across the
changed files and the repository"*. It did not: it covered the changed files plus
a phrase-level `grep` whose filters excluded `docs/contracts/README.md`, and
stale current-state wording survived there.

**The correction, recorded rather than hidden.** §4 of the original report now
opens with a marked correction naming the overclaim, what the sweep actually
covered, and that the review found what it missed. The claim beneath is narrowed
to *"the eight files this task changed, plus a phrase-level `grep` over the
repository"*.

`docs/contracts/README.md` is corrected in **three** places — one more than the
review reported, and the discrepancy is stated rather than rounded down:

| Line | Was | Now |
|---|---|---|
| §"FND-003D is PARTIAL" | *"the proof-satisfaction policy itself is still undefined"* | policy **DECIDED** by ADR-0012 (O8), **no executable proof satisfaction exists**, invariant 13 **still not discharged**, implementation must conform |
| roadmap row — successful delivery | *"needs the proof-satisfaction policy, which is undefined"* | *"which is **decided** … and **not implemented**"* |
| roadmap row — **Proof policy** | *"The proof-satisfaction policy itself — what a policy requires … "* framed as outstanding | policy **DECIDED**; what remains is **executable** — challenge lifecycle, retrieval surface, verifier evaluation, delivery transaction |

Unrelated README roadmap content is untouched.

---

## 4. Out-of-scope staleness — found and recorded here; classified by FIX-002

A wider re-sweep found three further stale statements. **None of the three files
is in this task's authorized list**, so they are recorded rather than silently
widening scope:

| File | Statement | Assessment |
|---|---|---|
| `docs/contracts/cash-and-payments.md:176` | lists *"the proof-satisfaction policy"* among things *"Still unreachable and untouched"* | **A current-state claim in a canonical contract document, and now wrong** — the policy is decided. The strongest of the three. File not authorized. |
| `docs/contracts/version-history.md:553` | 0.10 entry: *"the proof-satisfaction policy is undefined"* | Slice-scoped historical record of what 0.10 did not decide; present tense makes it borderline. File not authorized. |
| `ADR-0010:191` | *"the proof-satisfaction policy is still undefined"* | Consequences of a dated, accepted decision record. **Every ADR except ADR-0012 is explicitly prohibited to this task.** |

> **Outcome, recorded by FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-002.** The
> discovery evidence above is preserved exactly as this task captured it; only
> its **conclusion** is corrected. The sentence that stood here — *"They need
> their own bounded task"* — was right about **one** of the three and wrong about
> the other two, because it classified dated historical records as open debt.
>
> - **`docs/contracts/cash-and-payments.md`** — a genuine **current** canonical
>   status defect, and **DISCHARGED by FIX-002**, which replaced *"the
>   proof-satisfaction policy"* in §8's unreachable list with *"the **executable
>   proof-satisfaction mechanism**"* and added the explicit
>   policy-versus-mechanism distinction naming ADR-0012. No financial, COD,
>   journal, fee, commission, settlement or reconciliation semantics changed.
> - **`docs/contracts/version-history.md:553`** — **an accurate historical
>   record, not debt.** It sits under the heading `## 0.10 — FND-003B3B —
>   delivery attempt and return lifecycles`, in that entry's *"Not added, and not
>   decided"* subsection. It states what contract **0.10** did not decide, which
>   is true and stays true: the policy was undefined throughout that slice. This
>   task's *"present tense makes it borderline"* was an over-reading of a
>   per-version record. **No correction is required, and none was made.**
> - **`ADR-0010:191`** — **an accurate historical record, not debt.** It is the
>   *Consequences* section of a dated, Accepted decision (2026-09-11, FND-003B3B,
>   contract 0.9 → 0.10), describing the state at the time that decision was
>   taken. ADRs are dated decision records, not running status pages. **No
>   correction is required, and none was made.**
>
> **No current documentation debt remains from these three sweep results.**
> Publication state is determined by git history, not by this or any other report
> paragraph.

---

## 5. Four-document semantic comparison

The same three rules now appear, consistently, in all four policy documents:

| Rule | ADR-0012 | boundary | assessment | dispute |
|---|---|---|---|---|
| Customer-side fulfilment is **mandatory**; no route to satisfaction without it | Decision 1, Decision 9 | §7 participation bullet | §13 participation row | deferred-table participation row |
| Exception review **records/classifies/audits only**; cannot conclude satisfaction, mark delivered, waive, assign fault, create a fee or resolve a dispute; substitution needs a **superseding ADR + migration** | Decision 9 | §7 exception bullet | §13 override row | deferred-table override row |
| **Missing / unknown / unresolvable / unsupported / unverifiable** policy version **fails closed**; no default inferred | Decision 11 | §8 inherited fail-closed list | new fail-closed row | new fail-closed row |

No document states a weaker form of any of the three, and no new contradiction
was introduced.

---

## 6. Semantic sweep

Every term the brief listed was searched across ADR-0012 and the canonical
contract and index documents, and each occurrence classified.

| Term | Classification at HEAD |
|---|---|
| *no route to satisfaction*, *customer participation*, *customer-side fulfilment* | **accurate current policy** — consistent across all four documents; no occurrence implies an exception |
| *exception review* | **accurate current policy** — every occurrence is record/classify/audit; none claims it can conclude satisfaction |
| *substitute*, *waiver* | **accurate current policy** — every occurrence is a prohibition, each paired with the superseding-ADR requirement |
| *channel the platform controls* | **removed** — replaced by the specified channel class (F2) |
| *notification transport*, *signalling challenge availability* | **deferred implementation**, correctly labelled; ADR-0005 named as governing |
| *delivering a challenge* | **removed** from the deferral table heading (F2) |
| *raw challenge* | **accurate current policy** — every occurrence is a prohibition on where it may appear, plus the one permitted authenticated display |
| *unknown / missing / unresolvable policy* | **accurate current policy** — Decision 11 and its three mirrors |
| *policy undefined*, *still undefined* | **zero occurrences** in ADR-0012, the three delivery-proof documents and `docs/contracts/README.md`. Remaining repository occurrences are the three out-of-scope items in §4 and historical completion reports |
| *successful delivery* | **accurate current policy** — every occurrence states it remains unavailable/unreachable |
| *invariant 13* | **accurate current policy** — every occurrence states it is **not** discharged |

**Zero current-state defects within ADR-0012 and the current canonical
contract/index documents.**

---

## 7. Validation

```text
$ git status --short          # before edits
(empty — clean)

$ git diff --check
(clean, exit 0)

$ git diff --name-status 6c4c25a..HEAD
M  docs/contracts/README.md
M  docs/contracts/delivery-proof-assessment.md
M  docs/contracts/delivery-proof-boundary.md
M  docs/contracts/delivery-proof-dispute.md
M  docs/decisions/ADR-0012-delivery-proof-satisfaction-policy.md
A  docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-FIX-001-completion-report.md
M  docs/task-ledger/FND-003D3-PROOF-SATISFACTION-POLICY-001-completion-report.md
M  docs/task-ledger/TASK_LEDGER.md
                                  → exactly the eight authorized files
```

**Live probe — not grepped**

```text
ContractVersion.current        = 0.11
Permission.values.length       = 39
permissionMatrix.length        = 39
matrix missing keys            = 0
```

**Permissions unchanged** — `rider.delivery.submit_proof` and
`customer.delivery.confirm_proof` rows in `permission-matrix.md` are
byte-identical to `6c4c25a`, and no permission was added or widened.

**Executable surface**

```text
$ git diff --name-only 6c4c25a..HEAD -- '*.dart'          → (empty)
$ git diff --name-only 6c4c25a..HEAD -- '*/lib/*'         → (empty)
$ git diff --name-only 6c4c25a..HEAD -- docs/decisions    → only ADR-0012
```

No enum value, evaluator, transition, command, event, permission or denial
changed, so **no executable transition becomes reachable**.

**Unreachability** — `OrderState.delivered`, `DeliveryAttemptState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` all remain
unreachable. **Invariant 13 remains undischarged.** **O8 remains RESOLVED at
policy level only.** **O7 is untouched and remains OUTSTANDING.**

**Tests and gate**

```text
packages/contracts    → 1162 tests passed (unchanged)
./tools/run_checks.sh → ALL CHECKS PASSED, exit 0
```

**`6c4c25a` remains unamended** — it is this commit's parent, and its own parent
is still `81c623ec…`.

---

## 8. What this report does not claim

**Nothing here is self-certified.** This task ran no independent review of its
own corrections; acceptance is for a fresh, read-only review session. This report
records what was changed and what was verified, not that it was accepted.

**GitHub CI: NOT RUN / NONE** — no `.github` directory exists.

---

## 9. Confirmation — no push occurred

One normal follow-up commit. **Nothing was pushed.** No amend, rebase, merge,
squash, cherry-pick, reset or force; no tag or release; no deployment; no
Firebase, backend or live-data access; no repository, CI or branch-protection
change; the implementation slice was not started. `origin/main` is still
`81c623ec1537b99a86e57b6572f9d6cce3a06c3b`.

```text
81c623ec1537b99a86e57b6572f9d6cce3a06c3b
→ 6c4c25a2bbc7a555b01447fa790d0c64b4ce2c7d
→ <this commit>
```
