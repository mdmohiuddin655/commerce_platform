# FND-003B3B-PUBLISH-BOOKKEEPING-FIX-001 completion report

- **Task:** Correct exactly the three material findings from
  **FND-003B3B-PUBLISH-BOOKKEEPING-FINAL-REVIEW-001**. **Documentation only.**
- **Owner project:** ADMIN / shared foundation
- **Date:** 2026-09-11
- **Branch:** `fnd/FND-003B3B-publish-bookkeeping` (existing, **unpushed**)
- **Starting HEAD:** `23aec66b7bde701c5ca8935c4ceef59111235f76`
- **Its parent / published contract tip:** `cdb5f35b6e6a7ec33e7170b0db8efb2e8c477010`
- **Contract version:** **0.10 — unchanged**
- **Status:** **DONE** — the two-commit bookkeeping chain requires a **new,
  separate read-only final review**.

## 1. Baseline

```text
git status --porcelain --untracked-files=all   (empty)
git branch --show-current                      fnd/FND-003B3B-publish-bookkeeping
git rev-parse HEAD                             23aec66b7bde701c5ca8935c4ceef59111235f76
git rev-parse HEAD^                            cdb5f35b6e6a7ec33e7170b0db8efb2e8c477010
git rev-parse origin/main                      cdb5f35b6e6a7ec33e7170b0db8efb2e8c477010
git ls-remote origin refs/heads/main           cdb5f35b6e6a7ec33e7170b0db8efb2e8c477010
remote bookkeeping branch                      ABSENT
```

**The accepted B3B contract chain `8210323 → 8ccb5aa8 → cdb5f35b` was not
touched.** This task edits documentation only.

## 2. F1 — invented roadmap scope, removed

The bookkeeping commit had added **"partial / per-item returns"** to the
canonical table **"Not yet defined — later FND-003 slices"**, whose header
reads *"No feature may guess any of these. If it is not written down, the work
is blocked"*, with a **Blocked on** value of *"A separate additive contract
(ADR-0010)"*.

**Nothing canonical requires partial returns.** Verified mechanically:

```text
occurrences of partial / per-item / per-line / split return in
  SHARED_BLUEPRINT.md            0
  CONSTRAINTS.md                 0
  AGENTS.md                      0
  CLAUDE.md                      0
  docs/release-policy/README.md   0

blueprint Return lifecycle:
  not_required / required -> in_transit -> received -> inspected -> closed;
  damaged/quarantined disposition separate
```

That is exactly the five-state model FND-003B3B implemented — no per-item
concept anywhere. The only "partial" in the blueprint is `partially_collected`
in the **Payment** lifecycle, which is unrelated.

ADR-0010 says only that **if** partial support is ever added it must be a
separate additive contract that does not overload `ReturnDisposition` — an
**expansion constraint, not a roadmap commitment**. Promoting it into a
required-but-blocked slice created phantom scope in the one table other
projects read to decide what they may not build.

**The row is now about post-dispatch cancellation only**, which *is*
canonically deferred: FND-003B3A recorded that no post-pickup cancellation
behaviour was invented, and FND-003B3B lists the post-dispatch cancellation
consequence among the things it does not decide. Its blocker is stated
truthfully — the cancellation policy itself, with the fee/liability half owned
by **O6** and **FND-003C** — and **not** as "blocked on ADR-0010", which never
owned that dependency.

**The whole-order limit is still documented, in the right place**: the
*Delivered — FND-003B3B* section states the return is whole-order only, one
disposition covers the entire committed reservation, a caller cannot choose the
quantity, and a mixed return is not representable. That is a **property of the
accepted contract**, not outstanding work — which is the distinction this fix
restores.

## 3. F2 — stale dependency, removed

The dispute-resolution row's **Blocked on** cell still read
`**Owner decision O6**, FND-003C, FND-003B3B`, listing an accepted and
integrated slice as an unresolved blocker — while the sibling row written by
the same commit already used the repository's convention
`FND-003B3B (**done**)`.

It now reads:

> **Owner decision O6**, FND-003C. FND-003B3B (**done**) defines the
> refused-order return and decides **no** dispute outcome, fault or money.

**Dispute resolution is not implied to be unblocked** — O6 and FND-003C remain,
and no outcome, liability, fee, refund or delivery consequence is invented.

## 4. F3 — permission count, scoped

The *Delivered — FND-003D2A* section read *"adds no command and no permission
(`Permission.values` stays at 38)"* — a bare present-tense claim in the
canonical contract index, contradicting the executable code, while the D2B twin
had already been scoped. The file asserted both 38 and 39 as current.

It now reads:

> adds **no command and no permission** — `Permission.values` was **38** at the
> end of FND-003D2A, and is **39** today only because FND-003B3B later added
> `agent.return.record_receipt`, which changed nothing about D2A

matching the D2B pattern. **D2A history is not rewritten**, and nothing implies
B3B changed D2A semantics.

## 5. Post-correction scan — no material stale hit remains

```text
partial / per-item / per-line / split return as future work   GONE
FND-003B3B as an unresolved dispute-resolution blocker        GONE
`Permission.values` stays at 38                               GONE
current global permission count 38                            GONE
B3B not accepted                                              GONE
B3B awaiting publication                                      GONE
current contract version 0.9                                  GONE
```

Every surviving `38` is explicitly slice-scoped — *"was 38 at the end of
FND-003D2A"*, *"was 38 across the whole of FND-003D2B"*, *"go 38 → 39"*.
`FND-003B3B (**done**)` or equivalent appears 5 times; **0** occurrences
describe it as blocked, unresolved or outstanding.

No contradiction survives: the README does not simultaneously claim 38 and 39
as current, B3B done and unresolved, or partial returns both unsupported and
mandatory.

## 6. Files changed

| Path | Change |
|---|---|
| `docs/contracts/README.md` | F1, F2 and F3 — the only semantic corrections |
| `docs/task-ledger/FND-003B3B-PUBLISH-BOOKKEEPING-FIX-001-completion-report.md` | **new** — this report |

`TASK_LEDGER.md` was **not** touched: this FIX corrects documentation inside an
unpublished bookkeeping candidate and changes no task status, roadmap
dependency or evidence state, so no ledger row is warranted. Recording one
would have been the "unrelated status edit" this task forbids.

**Deliberately not corrected** (out of scope, recorded as observations by the
review): `version-history.md`'s pre-existing 0.6 present-tense candidacy
wording, and `delivery-proof-dispute.md`'s FND-003B3B owner-pointers.

## 7. No policy invented

No command, state, permission, dependency, lifecycle rule, commercial policy or
roadmap obligation was created. The corrections **remove** an invented
obligation and **scope** two claims; nothing was added.

## 8. Validation

```text
$ git diff --check                                   EXIT=0
changed files                                        2, both under docs/
changes under packages/ apps/ backend/ infra/,
  tests or config                                    0

ContractVersion.current                              ContractVersion(0, 10)
Permission.values                                    39
permissionMatrix                                     39
README current contract version                      0.10

$ ./tools/run_checks.sh
ALL CHECKS PASSED                                    EXIT=0
```

**`run_checks.sh` is LOCAL evidence only. It is not GitHub CI**, and no CI
success is claimed — no workflow exists in the repository.

**Migration: NOT APPLICABLE / NOT RUN. Firestore rules: NOT IMPLEMENTED / NOT
RUN. Indexes: NOT IMPLEMENTED / NOT RUN. Deployment: NOT RUN.**

## 9. Preserved

Accepted B3B contract = **`8ccb5aa8` + `cdb5f35b`**; `8ccb5aa8` alone is **not**
accepted. Successful delivery, customer custody and rider completion remain
**unavailable**; **B3-C2 FUTURE**; the proof-satisfaction policy is undefined
and **`CONSTRAINTS.md` invariant 13 is NOT discharged**; the failed-attempt
consequence, via-picker return authority and dispute resolution remain
deferred; all financial policy is deferred and **FND-003C is BLOCKED on O6**.
FND-003B, FND-003B3 and FND-003D remain **PARTIAL**; FND-004 **TODO**;
**O6 and O7 outstanding**; ATT/RET and all backend criteria remain **NOT RUN**;
B3-C1 stays contract-test evidence only.

## 10. Process

Exactly one normal local child commit on top of `23aec66b…`. **No** amend,
rebase, squash, cherry-pick, merge, `reset --hard`, force-push or push — the
branch remains **local only**. No PR, tag, release, GitHub-setting change,
deployment or Firebase/live-data access. **No later roadmap task started.**

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.
