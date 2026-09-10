# FND-003D2B-MERGE-001 completion report

- **Task:** Integrate the exact FND-003D2B seven-commit candidate accepted by
  **FND-003D2B-FINAL-REVIEW-006** into `main`, preserving the reviewed history
  exactly. **Integration only — no implementation.**
- **Owner project:** ADMIN / shared foundation
- **Date:** 2026-09-11
- **Pre-merge `main`:** `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Accepted feature tip:** `743e157fe090d4abe42df05f492854601fd68b65`
- **Integrated `main`:** `743e157fe090d4abe42df05f492854601fd68b65`
- **Method:** **fast-forward only**
- **Contract version:** **0.9 — unchanged**
- **Status:** **DONE**

## 1. Pre-merge verification

Every value below was read live, and the tracking refs were cross-checked
against `git ls-remote` so a stale local ref could not satisfy the gate.

```text
git status --porcelain --untracked-files=all   (empty)
git fetch origin --prune                       exit 0

origin/main    tracking  03c71d00b89a2018d1a18631d8e36c40238c0b57
origin/main    ls-remote 03c71d00b89a2018d1a18631d8e36c40238c0b57   == required   PASS
feature        tracking  743e157fe090d4abe42df05f492854601fd68b65
feature        ls-remote 743e157fe090d4abe42df05f492854601fd68b65   == required   PASS
merge-base                03c71d00b89a2018d1a18631d8e36c40238c0b57  == required   PASS
behind / ahead            0 / 7                                                   PASS
merge commits in candidate 0                                                      PASS
commits in candidate       7                                                      PASS
```

## 2. Parent walk — the exact accepted chain

Each commit has exactly one parent; the chain is linear and matches the accepted
list commit for commit.

```text
743e157fe090d4abe42df05f492854601fd68b65 <- cc0c1ae7d69b4493eb8c420ae40d088f99d5f108
cc0c1ae7d69b4493eb8c420ae40d088f99d5f108 <- 45d21e9c6908b32079bee1d9fba408f0902721ca
45d21e9c6908b32079bee1d9fba408f0902721ca <- 202a8a9661b4ac31e2d8d0e59a605fe618de517c
202a8a9661b4ac31e2d8d0e59a605fe618de517c <- f04d453781fb4aa88cf73d4d73bf0b3e79c425b1
f04d453781fb4aa88cf73d4d73bf0b3e79c425b1 <- ded1aa7967e1cae00dd504e7fec15df63d29aa83
ded1aa7967e1cae00dd504e7fec15df63d29aa83 <- b94e5424ef2460c2d1ec30aeec80e9de09cf1699
b94e5424ef2460c2d1ec30aeec80e9de09cf1699 <- 03c71d00b89a2018d1a18631d8e36c40238c0b57
```

**No prefix of this chain is accepted alone.** `b94e5424` shipped an
authorization bypass and a fail-open basis standing; FIX-001 through FIX-006
are what make the contract acceptable. The accepted unit is all seven.

## 3. Pre-integration gate

Run against the candidate tree before touching `main`. Required tooling was
present, so nothing had to be recorded NOT RUN:

```text
dart    Dart SDK version: 3.13.2 (stable) on "macos_arm64"
flutter Flutter 3.47.2 - channel stable
tools/run_checks.sh      present + executable
tools/check_layering.sh  present + executable

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
LAYERING CHECK: PASS
ALL CHECKS PASSED                                     EXIT=0
```

## 4. Integration — fast-forward only

```text
$ git checkout main
local main before  03c71d00b89a2018d1a18631d8e36c40238c0b57   == required   PASS
ff-only possible   YES (main is an ancestor of the feature tip)

$ git merge --ff-only 743e157fe090d4abe42df05f492854601fd68b65
Updating 03c71d0..743e157
Fast-forward
 40 files changed, 10261 insertions(+), 56 deletions(-)
                                                      EXIT=0

local main after   743e157fe090d4abe42df05f492854601fd68b65
merge commits created                                 0
commits on main above 03c71d00                        7
working tree                                          clean
```

Git itself reported **`Fast-forward`**. All seven accepted SHAs resolve
unchanged after the operation.

## 5. Push and remote verification

```text
$ git push --dry-run origin main
   03c71d0..743e157  main -> main                     EXIT=0

$ git push origin main
   03c71d0..743e157  main -> main                     EXIT=0
```

The range is two-dot with no `+` forced marker and names exactly one ref. **No
`--force`, `--force-with-lease` or `-f` was used at any point.**

```text
remote main (ls-remote)   743e157fe090d4abe42df05f492854601fd68b65   PASS
remote main (tracking)    743e157fe090d4abe42df05f492854601fd68b65   PASS
merge commits on main     0
feature branch tip        743e157fe090d4abe42df05f492854601fd68b65   preserved, not deleted
```

`main` ends at the accepted tip **before** this documentation-only bookkeeping
commit, which is recorded separately in §8.

## 6. Post-integration gate

```text
$ cd packages/contracts && dart analyze
No issues found!                                      EXIT=0

$ cd packages/contracts && dart test
00:01 +989: All tests passed!                         EXIT=0   (baseline 989)

$ ./tools/check_layering.sh
LAYERING CHECK: PASS                                  EXIT=0

$ ./tools/run_checks.sh
ALL CHECKS PASSED                                     EXIT=0
```

989 matches the recorded baseline exactly — a fast-forward that changed no code
must not move it.

## 7. Contracts preserved, verified on the integrated tree

```text
ContractVersion.current                     ContractVersion(0, 9)
dispute denials                             20
Permission.values / permissionMatrix        38 / 38
dispute events                              2
resource anchor  dispute.resourceId         evaluator l.119 (raise), l.333 (review)
four-way raise binding                      evaluator l.164-165
review read-set    request + actor + AuthorizationGrant + dispute
resolve            zero-argument, always resolutionPolicyDeferred
DeliveryProofDisputeContext in API          0
OrderState.delivered                        still in notYetImplemented
```

Two greps needed a second look rather than a pass mark. `reviewerIsRaiser`
matched **once** and `toJson`/`fromJson` matched **five** times in `lib/` — both
counts are **comment-only**: comment-stripped, each file yields **0**. The
`reviewerIsRaiser` line is the historical note recording its removal by FIX-001,
and every serialization mention is a doc comment asserting that no serialization
exists. **No serialization, no migration.**

## 8. Bookkeeping — documentation only, separate from the accepted chain

The accepted contract chain ends at `743e157`. This report and the ledger update
are a **separate documentation-only commit on top of it**, and touch only:

| Path | Change |
|---|---|
| `docs/task-ledger/TASK_LEDGER.md` | FND-003D2B recorded ACCEPTED AND INTEGRATED; accepted chain and "no prefix alone" stated explicitly; blockers preserved |
| `docs/task-ledger/FND-003D2B-MERGE-001-completion-report.md` | **new** — this report |

**No contract, source, test, fixture, dependency, app, backend, infra or policy
file is touched by it.** No historical report was rewritten.

## 9. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 all
remain NOT RUN.** B3-C1 remains contract-test evidence only; **B3-C2 FUTURE**.
FND-003D remains **PARTIAL**; FND-003B3B **NOT STARTED**; FND-003C **BLOCKED on
O6**; FND-004 **TODO**; **O7 outstanding**. **FND-003D2A criterion 48 remains
FAIL** under its recorded one-time pre-publication exception, and was not used
as precedent — this task performed no amend.

**GitHub CI: NONE.** `ls .github` → *No such file or directory*; no workflow is
defined and none ran. The local gate is **not** CI. Branch-protection and
ruleset state were **NOT INSPECTED** — `gh` is not installed here — so no claim
is made about them; the only supported statement is that the remote accepted the
fast-forward push.

## 10. What integration does not mean

`CONSTRAINTS.md` **invariant 13 is still not discharged.** The
proof-satisfaction policy itself is undone, so delivery confirmation may not be
coded. Dispute **resolution** remains enumerated and always refused
`resolutionPolicyDeferred`, blocked on **O6**, FND-003C and FND-003B3B.
Successful delivery, customer custody, rider completion, fee, refund, liability,
return and stock restoration all remain **non-executable**.

## 11. Process confirmations

- **No** merge commit, squash, rebase, amend, cherry-pick reconstruction,
  force-push, `reset --hard` or history rewrite.
- **No** accepted SHA changed; the feature branch was **preserved**, not deleted.
- **No** PR, tag, release, deployment, GitHub-setting change or Firebase /
  live-data access.
- **No** later roadmap task started.

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.
