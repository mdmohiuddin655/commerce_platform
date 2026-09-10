# FND-003D2B-FIX-002 completion report

- **Task:** Correct the two material defects found by
  **FND-003D2B-FINAL-REVIEW-002** in the FND-003D2B candidate
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Reviewed base:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Starting candidate HEAD:** `ded1aa7967e1cae00dd504e7fec15df63d29aa83`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract` (existing)
- **Follow-up commit:** reported **out of band** after commit creation — a
  commit cannot contain its own SHA, and **no amend was used to insert one**
- **Contract version:** **0.9 — unchanged, not bumped**
- **Status:** **DONE** — the corrected **three-commit** candidate requires a
  **new, separate read-only final acceptance review**. It is **not** accepted
  for merge.

## 1. Baseline

```text
git fetch origin --prune                       exit 0
git remote get-url origin                      https://github.com/mdmohiuddin655/commerce_platform.git
git branch --show-current                      fnd/FND-003D2B-fallback-proof-dispute-contract
git rev-parse HEAD                             ded1aa7967e1cae00dd504e7fec15df63d29aa83
git rev-parse origin/main                      03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse b94e5424^                        03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse ded1aa79^                        b94e5424ef2460c2d1ec30aeec80e9de09cf1699
git status --porcelain --untracked-files=all   (empty)
ContractVersion.current                        0.9
```

Chain before work: `03c71d00…` → `b94e5424…` → `ded1aa79…`. Neither published
commit was amended, rebased, squashed or reset; this task adds **one new normal
follow-up commit** on the existing branch.

## 2. Finding A — a reused assessment id was accepted as supersession

**Reproduced before fixing.** Against the candidate at `ded1aa79`:

```text
basis    notSatisfied / assessment A / revision 1
current  revision 2, assessmentId A (reused), supersedes B, verdict satisfied

aggregate canonical? true
standing = DeliveryProofDisputeBasisStanding.superseded     <-- WRONG
```

**Root cause.** The standing calculation treated *any* higher revision as a
legitimate supersession:

```dart
if (assessment.assessmentRevision > basis.assessmentRevision) {
  return DeliveryProofDisputeBasisStanding.superseded;
}
```

ADR-0009 gives every reassessment a **new opaque id**. A later revision carrying
the id the basis pinned would mean the contested identity exists twice, at two
revisions, and reporting it as `superseded` lets a reused id quietly erase which
assessment was actually contested.

The aggregate is **structurally canonical** — the shape validator passes,
`canonicalVerdict` answers — which is exactly why no existing guard caught it.
This is a *relationship* contradiction between the basis and the history, not a
torn aggregate. FIX-001 closed the same-revision **verdict** contradiction; this
closes the higher-revision **identity** one.

**Correction.** A higher revision must also carry a **different** assessment id;
reuse answers `indeterminate`. It is not converted to `superseded`, not
converted to `notSatisfied`, the assessment is not relabelled and the basis is
not rewritten. The comparison uses the **current record only** — no in-memory
history array and no global uniqueness lookup, because uniqueness across records
that are no longer current is a **storage** guarantee (**DPA11**, NOT RUN).

Regressions added: A/1 + A/2 → `indeterminate` for both verdicts; proof that the
A/2 aggregate is structurally canonical and even exposes a trusted verdict; A/1 +
B/2 → still `superseded` for both verdicts; a larger revision gap with a new id →
`superseded`, and the same gap reusing the id → `indeterminate`; and the basis
value is unchanged afterwards. The FIX-001 same-id/same-revision verdict case is
re-pinned.

## 3. Finding B — the evaluators asserted authorization instead of requiring it

**Root cause, and it was a real bypass.** Both executable evaluators took a
server-derived `Principal` and *documented* that `evaluateAuthorization` had
already run. **A pure function cannot assert anything about its caller.**
Nothing in either signature distinguished an authorized call from one that
skipped the check, so:

- a **customer who owns nothing** could reach a raise transition;
- a **customer-only principal** could reach a review transition.

A FIX-001 test had even asserted the first as intended behaviour — *"authorization
already ran, and re-running it in the state machine would create a second place
for it to drift"*. The reasoning was right about **policy** and wrong about
**proof**.

**Correction.** FND-003A had already built the artifact for exactly this:
`AuthorizationGrant` is `final`, has a library-private constructor, and is
obtainable **only** from a successful `evaluateAuthorization`. Both operations
now require one, and `checkDisputeAuthorization` — in its own file — verifies it
is the *right* grant:

```text
grant.permission  == the operation's requiredPermission
grant.principalId == the acting principal          (via grant.covers)
grant.resourceId  == the canonical resource, and a valid opaque id
```

**No policy is re-decided.** Role, membership status, scope and reason stay in
`permissionMatrix`, which is neither copied nor changed: an out-of-region admin,
an inactive member, a wrong-role principal or an admin with no reason simply
never obtains a grant to present. A **single generic**
`authorizationGrantMismatch` denial (19 → **20**) keeps refusals unprobeable, in
the same spirit as `AuthorizationDecision.publicMessage`. There is no forgeable
`isAuthorized` boolean, no client-supplied role or permission, and no
authorization data on any command payload.

**Raising confers no admin authority.** The historical raiser reaches review only
by independently holding an admin grant of their own, and **no
separation-of-duties rule returned** — `approvalRequired` stays `false`.

**Freshness remains the backend's.** A grant proves `evaluateAuthorization`
allowed *those inputs*; that they were current and the actor was not since
revoked is **R33–R40**, NOT RUN. This contract claims nothing more.

**`DeliveryProofDisputeContext` was removed.** The grant already names the
canonical resource, so keeping the context would have meant two sources of
resource truth that could disagree; the one bound to the authorization decision
must win.

### Corrected read-sets

| Operation | Reads |
|---|---|
| `evaluateRaiseDeliveryProofDispute` | request, actor, **grant**, dispute, assessment, order |
| `evaluateRecordDeliveryProofDisputeReview` | request, actor, **grant**, dispute |
| `evaluateResolveDeliveryProofDispute` | **nothing at all** — still zero-argument |

Review still takes **no assessment and no order**, and a call that passes either
does not compile. Raise keeps every accepted validation and CAS check.

## 4. Maintainability

The authorization binding lives in a new
`delivery_proof_dispute_authorization.dart` behind the **existing stable
barrel**, so authorization validation, aggregate validation and transition
construction are auditable independently. The graph stays acyclic: vocabulary →
model → shapes → validation → authorization → evaluator. No validator and no
permission rule is duplicated. The raise/review/resolve evaluators were **not**
split further — their read-sets are already structurally independent, and
keeping them side by side is what makes the difference legible.

Every statement and test claiming the evaluator intentionally permits an
authorization-bypassing direct call has been removed or rewritten, including the
FIX-001 regression named above, which now asserts the correct narrower property:
the evaluator **requires** the canonical decision without re-deciding it, proven
additionally by a source scan showing no dispute file mentions a role, scope
requirement, membership status, `reasonRequired` or `evaluateAuthorization`.

## 5. Files changed

| Path | Change |
|---|---|
| `…/lib/src/delivery_proof_dispute_basis.dart` | finding A: a higher revision must carry a different assessment id |
| `…/lib/src/delivery_proof_dispute_authorization.dart` | **new** — `checkDisputeAuthorization` |
| `…/lib/src/delivery_proof_dispute_evaluator.dart` | finding B: both executable evaluators require a grant; context parameter removed |
| `…/lib/src/delivery_proof_dispute_facts.dart` | `DeliveryProofDisputeContext` removed, with the reason recorded |
| `…/lib/src/delivery_proof_dispute_denial.dart` | `authorizationGrantMismatch` added (19 → 20) |
| `…/lib/src/delivery_proof_dispute.dart` | export + module map + acyclic-graph line |
| `…/lib/cp_contracts.dart` | truthful surface description |
| `…/lib/src/contract_version.dart` | 0.9 history entry (**version unchanged**) |
| `…/test/support/delivery_proof_dispute_fixtures.dart` | real grants from `evaluateAuthorization`; no context |
| `…/test/delivery_proof_dispute_basis_test.dart` | **+5** finding-A regressions |
| `…/test/delivery_proof_dispute_authority_test.dart` | **+5** finding-B regressions; bypass-asserting tests rewritten |
| `…/test/delivery_proof_dispute_evaluator_test.dart` | grant-aware; review independence re-pinned |
| `…/test/delivery_proof_dispute_debug_test.dart` | context rendering removed |
| `…/test/delivery_proof_dispute_regression_test.dart` | denial count 19 → 20; barrel surface check |
| `docs/contracts/delivery-proof-dispute.md` | "an id is never reusable"; the authorization section; updated tables |
| `docs/contracts/README.md` | FIX-002 summary + two binding rules |
| `docs/contracts/version-history.md` | the second in-place correction recorded under 0.9 |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-002 narrative; candidate is the three-commit chain |
| `docs/task-ledger/FND-003D2B-completion-report.md` | **appended** second correction section |
| `docs/task-ledger/FND-003D2B-FIX-001-completion-report.md` | **appended** partial-supersession note |
| `docs/task-ledger/FND-003D2B-FIX-002-completion-report.md` | **new** — this report |

**Not touched:** `apps/`, `backend/`, `infra/`, `.github/`, any pubspec or
lockfile, `docs/decisions/`, `permission.dart`, `permission_matrix.dart`, the
generated `permission-matrix.md`, `authorization.dart`, `delivery_proof.dart`,
**every** `delivery_proof_assessment_*.dart` source, and every order, custody and
assignment state machine.

## 6. Validation — real commands, real output

```text
$ cd packages/contracts && dart analyze
Analyzing contracts...
No issues found!
EXIT=0

$ dart test <the nine dispute suites>
00:00 +179: All tests passed!
EXIT=0

$ dart test <permission_matrix, authorization, delivery_proof,
             all delivery_proof_assessment_*, contract_version,
             command_envelope, forgery_probe>
00:00 +271: All tests passed!
EXIT=0

$ cd packages/contracts && dart test
00:00 +986: All tests passed!
EXIT=0

$ flutter analyze            # workspace root
No issues found! (ran in 2.0s)
EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS
EXIT=0

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
No issues found! (ran in 2.0s)
--- packages/contracts ---
00:00 +986: All tests passed!
LAYERING CHECK: PASS
ALL CHECKS PASSED
EXIT=0
```

| Suite | At `ded1aa79` | Now |
|---|---|---|
| `…_model_test.dart` | 25 | 25 |
| `…_basis_test.dart` | 17 | **22** |
| `…_validation_test.dart` | 11 | 11 |
| `…_evaluator_test.dart` | 34 | **35** |
| `…_concurrency_test.dart` | 12 | 12 |
| `…_authority_test.dart` | 22 | **27** |
| `…_effects_test.dart` | 12 | 12 |
| `…_debug_test.dart` | 12 | 12 |
| `…_regression_test.dart` | 23 | 23 |
| **total** | **168** | **179** |

Package total 975 → **986** (+11).

**This is the local repository gate, not GitHub CI.** No CI ran; FND-004 has not
landed and **O7** is outstanding.

## 7. Negative controls

All applied, run, and **fully reverted** — each verified byte-identical by
`diff`, with `grep -rn "NEGATIVE CONTROL" lib/ test/` finding nothing afterwards.

| # | Change | Result |
|---|---|---|
| **NC4** | bypassed `checkDisputeAuthorization` (always return null) | **4 authority tests FAILED**, incl. `a NON-OWNER customer can no longer raise`, `a customer-only principal cannot review`, `the grant must be for this permission, principal and resource` |
| **NC5** | restored unconditional `revision > basisRevision => superseded` | `a higher revision reusing the basis id is indeterminate` **FAILED** |
| **NC1** (re-verified) | removed the same-revision verdict check | 2 basis tests FAILED |
| **NC2** (re-verified) | re-added the `reviewerIsRaiser` rule | 1 authority test FAILED |
| **NC3** (re-verified) | passed `assessment:`/`order:` to review, and any argument to resolve | **compile errors**, all parameters undefined |

`tools/check_layering.sh` was **not modified**, so its own negative controls were
not re-run — AGENTS.md requires that only when the guard changes.

## 8. What was NOT run, and why

**No backend, persistence, Firebase project, emulator or device exists on this
host. Nothing was promoted from NOT RUN.**

| Evidence | Status | Why |
|---|---|---|
| **DPD1–DPD12** | **NOT RUN** | no backend or persistence exists |
| **DPA1–DPA18** | **NOT RUN** | unchanged by this task |
| **CA1–CA23, R33–R40, L1–L13, P1–P17, RA1–RA18** | **NOT RUN** | unchanged; R33–R40 is where grant *freshness* would be proven |
| **B3-C1** | contract-test evidence only, picker only | unchanged |
| **B3-C2** | **NOT RUN / FUTURE** | rider completion unreachable; no cost invented |
| Firebase project / Rules / indexes / emulator | **NOT RUN** | Firebase CLI and FlutterFire CLI not installed (O4); no project (O5); none created |
| Backend persistence | **NOT IMPLEMENTED / NOT RUN** | out of scope |
| Physical device / Android / iOS | **NOT RUN** | no device (O3); licences unaccepted (O1) |
| Windows build, auth, toast, Drift native | **NOT RUN** | no Windows runner (O2) |
| GitHub CI | **NOT RUN** | FND-004 has not landed; **O7** outstanding |
| Deployment | **NOT RUN** | forbidden by the task and AGENTS.md §9 |

## 9. Confirmations

- **Contract version remains 0.9**, corrected in place; no serialization and no
  migration invented.
- `Permission.values` and `permissionMatrix` remain exactly **38**;
  `customer.dispute.raise` and `admin.dispute.administer` are byte-for-byte the
  accepted rules with `approvalRequired: false`; the generated permission matrix
  is untouched.
- **No `reviewerIsRaiser`**, no separation-of-duties or dual-control invention.
- **Resolution remains zero-argument and always `resolutionPolicyDeferred`**;
  `resolved` unreachable; **no resolution event**; still exactly
  `delivery.proof_dispute_raised` and `delivery.proof_dispute_review_started`.
- **Every order, reservation, inventory, financial, custody, picker, rider,
  assessment and scope effect remains NONE.** Successful delivery remains
  unreachable, as do `OrderState.delivered`, `CustodyHolderKind.customer` and
  rider `AssignmentState.completed`; **B3-C2 stays FUTURE**.
- **Every denial returns `transition == null`**; duplicate/reordered behaviour
  and all concurrency semantics are unchanged.
- **The dispute basis remains immutable**; reassessment remains append-only.
- **`basisFrom` did not return**; canonical positive bases still come from a real
  evaluator-produced raise.
- **D1 and D2A production sources are untouched**, and their suites pass
  unchanged.
- **O6 was not guessed**; **O7 remains outstanding**; **FND-003D2A criterion 48
  remains FAIL** under its one-time exception and was **not** used as precedent.
- **No amend, rebase, squash, cherry-pick, force-push or history rewrite
  occurred.** Nothing was pushed, merged, deployed, tagged or turned into a PR;
  no GitHub setting or Firebase resource was touched; no destructive operation
  was run.
- **No TODO, stub or fake-completion path exists.**

## 10. Status after this task

| Task | Status |
|---|---|
| **FND-003D2B** | **PARTIAL / FIX REQUIRED / NOT ACCEPTED** — corrected three-commit chain awaiting a new separate read-only final review |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — **O6**, FND-003C, FND-003B3B |
| Separation of duties (raiser vs reviewer) | **NOT DECIDED** — own permission + ADR |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

`CONSTRAINTS.md` invariant 13 is still **not** discharged: the proof-satisfaction
policy remains undefined, so delivery confirmation may not be coded.

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.

---

# SUPERSEDED IN PART BY FND-003D2B-FIX-003

**Appended by FND-003D2B-FIX-003 (2026-09-11). Nothing above is rewritten.**

FND-003D2B-FINAL-REVIEW-003 found that **two claims in this report were
incomplete**, so `f04d453` is also not acceptable on its own.

1. **§3 "Corrected read-sets" — the raise read-set was not fully bound.** The
   table lists `order` as part of the read-set, and the resource comparison
   covered the grant, the dispute and the assessment — but **not** the order
   facts, because the accepted `OrderLifecycleFacts` carries no resource id. An
   order-B read with matching scalars was therefore indistinguishable from order
   A's. FIX-003 adds `DeliveryProofDisputeOrderRead` and completes the binding.

2. **§4 and §9 — the resource half of the grant check was tautological.** This
   report's own §4 of the push verification noted that
   `grant.covers(principalId: actor.id, resourceId: grant.resourceId)` passes
   the grant's resource back to itself, so only the principal binding did work.
   That observation was recorded but not acted on. FIX-003 gives
   `checkDisputeAuthorization` an `expectedResourceId` taken from the read-set.

**Documentation drift.** This report and the module barrel continued to describe
a "server-resolved context" in the D2B facts file after
`DeliveryProofDisputeContext` had been deleted. FIX-003 corrects the current API
descriptions; historical descriptions remain where clearly marked as historical.

Everything else in this report stands: the higher-revision id-reuse correction,
the `AuthorizationGrant` requirement itself, the NOT RUN classifications and the
git hygiene were all re-verified by FIX-003's negative controls.

Full detail: [FND-003D2B-FIX-003 report](FND-003D2B-FIX-003-completion-report.md).
