# FND-003C1 completion report

- **Task:** Resolve owner action **O6** under the ADMIN standing delegation and
  implement the first bounded FND-003C financial slice — the normal-path COD
  collection contract with balanced cash-journal effects.
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-11
- **Starting remote `main`:** `79cdfe18996ba5382e727a328226ac3eaa5fce43`
- **Branch:** `fnd/FND-003C1-cod-journal-foundation` (new, from that commit)
- **ContractVersion:** **0.10 → 0.11** (additive)
- **Permissions:** **39 → 39** — none added, none widened
- **ADR:** **ADR-0011**, resolving **O6**
- **Status:** **DONE — NOT ACCEPTED.** One local commit, **not pushed**,
  returned for one independent final review.

## 1. O6, decided

**ADR-0011** records the delegated decision in full. In summary:

| Question | Decision |
|---|---|
| Currency | **BDT only in v1**, with the ISO-4217 code still **explicit on every value**. **No FX** — a non-BDT or mixed read fails closed |
| Customer price | Immutable quoted snapshot: `merchandiseSubtotal + deliveryCharge` |
| Commission | An **allocation out of merchandise proceeds**, never added to what the customer pays |
| Missing policy | **Never zero.** Amounts and policy references are required, so silence cannot be constructed; a published zero can |
| Refusal default | The order's quoted delivery charge, under its versioned policy — with **nonpayment representable**, no fee for mere delivery failure, and **fault cases unresolved rather than charged or waived** |
| Ownership | Shop owns merchandise proceeds net of commission; platform owns commission and the delivery charge; **worker pay is a separate payable, never inferred** |
| Rider cash | **Custody, not ownership.** `delivered != collected != remitted != reconciled` |
| Journal | Integer minor units, one currency, unique business reference, postings summing to **exactly zero**, reversal-only correction, **no balance setter** |

## 2. What is executable, and what it touches

```text
rider reports cash actually received
  payment  due | partially_collected  ->  partially_collected | collected
  journal  ONE balanced entry for exactly the amount received
  order, custody, attempt, assignment, reservation, inventory   ALL UNCHANGED
```

One command, `cash.report_cod_collection`, under the **accepted, unchanged**
`rider.cash.report_collection`.

**The transition type has no field** for an order-state change, inventory
effect, custody movement, rider completion, assignment change, proof
assessment, remittance or settlement — so a collection cannot produce one by
mistake. `changesOrder`, `changesCustody` and `completesRider` are permanently
false and are tested.

## 3. The journal, and the sign convention

Fixed once, pinned by tests, and proven by a negative control:

```text
customerCodReceivable   -A      the customer owes A less
riderCashInTransit      +A      the rider holds A more
                        ────
                          0     balanced
```

Only the two accounts an implemented operation needs exist. Settlement, payout,
refund and commission accounts are **absent** — declaring them would invite
posting to them before any policy says what they mean, and a caller-selected
account string would be a balance-edit primitive in disguise.

## 4. Files changed

**New production (12):** `money_policy.dart`, `order_financial_snapshot.dart`,
`payment_state.dart`, `payment_facts.dart`, `cash_journal_entry.dart`,
`cod_collection_command.dart`, `cod_collection_denial.dart`,
`cod_collection_authorization.dart`, `cod_collection_request.dart`,
`cod_collection_transition.dart`, `cod_collection_evaluator.dart`,
`cash_and_payments.dart`.

**Modified production (2):** `cp_contracts.dart` (one export),
`contract_version.dart` (0.11 + history).

**New tests (4):** `support/cod_collection_fixtures.dart`,
`cod_collection_test.dart`, `cash_journal_test.dart`,
`cod_collection_authority_test.dart`.

**Modified tests (5):** version pins only, in
`attempt_return_forbidden_test.dart`, `command_envelope_test.dart`,
`contract_version_test.dart`, `delivery_proof_assessment_regression_test.dart`,
`delivery_proof_dispute_regression_test.dart`. Each kept its original intent;
no forbidden-surface guard was touched.

**Docs:** new `cash-and-payments.md`, new **ADR-0011**; updated
`docs/contracts/README.md`, `version-history.md`, `TASK_LEDGER.md`, and this
report.

**No new dependency.** `cp_core` was already a dependency of `cp_contracts`, so
`Money` needed no pubspec change.

## 5. A deliberate non-change worth recording

`FinancialClassification` was **not** extended. An accepted regression test
(`delivery_proof_dispute_regression_test.dart`) pins
`FinancialClassification.values.length == 2`, and that pin encodes real intent:
the enum means *"this slice moves no money"* or *"unknown, deferred"*. C1 now
actually moves money, so rather than widening accepted vocabulary and breaking
that guard, **the balanced journal effect is the financial statement**. Nothing
downstream changed meaning.

## 6. The stale ledger summary, reconciled

The ledger's wire-contract cell read **0.9** while the executable
`ContractVersion.current` was **0.10** — it was never updated when FND-003B3B
shipped. It now reads **0.11**, and the drift is **recorded in the cell itself**
rather than silently fixed, because a summary that drifts unnoticed is exactly
what that table exists to prevent.

## 7. Validation — real output

```text
$ cd packages/contracts && dart analyze
No issues found!                                            EXIT=0

$ dart test
00:01 +1151: All tests passed!                              EXIT=0   (1085 + 66 new)

$ dart test test/cod_collection_test.dart            +26  All tests passed!
$ dart test test/cash_journal_test.dart              +21  All tests passed!
$ dart test test/cod_collection_authority_test.dart  +19  All tests passed!

$ cd packages/core && dart test
00:00 +8: All tests passed!                                 EXIT=0   (Money)

affected regression suites, all green:
  authorization_test 46 · permission_matrix_test 23 · contract_version_test 14
  order_lifecycle_test 22 · custody_lifecycle_test 62 · rider_assignment_test 53
  delivery_attempt_test 26 · return_lifecycle_test 19
  attempt_return_forbidden_test 22 · delivery_proof_dispute_evaluator_test 38

$ flutter analyze                     # workspace root, five apps
No issues found! (ran in 2.0s)                              EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS                                        EXIT=0

$ ./tools/run_checks.sh
ALL CHECKS PASSED                                           EXIT=0

$ git diff --check                                          EXIT=0

ContractVersion.current   ContractVersion(0, 11)
Permission.values / permissionMatrix / generated doc rows   39 / 39 / 39
```

`dart format --set-exit-if-changed` passes on all **16** new files. The
repository's pre-existing format debt (57 of 96 files at the FND-003B3B
baseline) was left untouched, as before.

**GitHub CI: NONE.** No `.github` directory exists; the local gate is **not**
CI.

## 8. Negative controls

Each mutation was applied to production source, the **named** test run, and the
file restored from a pre-mutation copy with its SHA-256 re-verified.

| # | Mutation | Named test | Result | Revert |
|---|---|---|---|---|
| NC1 | remove the over-collection guard | `over-collection is impossible…` | **failed as required** | byte-identical |
| NC2 | drop the journal balance check | `an unbalanced entry is rejected` | **failed as required** | byte-identical |
| NC3 | bypass the authorization binding | `authorization cannot be bypassed` | **failed as required** | byte-identical |
| NC4 | remove the custody→attempt binding | `custody bound to another attempt…` | **failed as required** | byte-identical |
| NC5 | allow collection on a refused attempt | `cash may only be collected while out for delivery` | **failed as required** | byte-identical |
| NC6 | add commission to the customer total | `commission is NOT added…` | **failed as required** | byte-identical |
| NC7 | drop the payment-revision CAS | `two collections against one payment revision…` | **failed as required** | byte-identical |

**No probe marker is committed** (grep = 0), and the full suite passes at 1151
after revert.

## 9. Backend criteria — CJ1–CJ12, all NOT RUN

Listed in full in
[cash-and-payments.md](../contracts/cash-and-payments.md) §10. **Pure Dart tests
are contract evidence, not persistence evidence.** In particular **CJ1**
(concurrent collections on one payment revision), **CJ3** (payment + journal +
dedupe + outbox in one transaction), **CJ4** (unique journal business reference)
and **CJ5/CJ6** (idempotency replay and key reuse) are **NOT RUN**: no backend
exists, and FND-004 owns the API shell.

The pure evaluator exposes everything such a transaction needs — the expected
revisions for every aggregate it reads, the resulting payment revision, and the
journal entry with its business reference.

**Migration: N/A — contract-only; no persistence exists yet.**
**Firestore rules: N/A — contract-only; no persistence exists yet.**
**Indexes: N/A — contract-only; no persistence exists yet.**
**Deployment: NOT RUN.**

## 10. Security, concurrency, offline and platform evidence

- **Authorization:** every executable path requires FND-003A's unforgeable
  `AuthorizationGrant`, with the expected resource taken from the read-set, not
  the grant. Wrong permission, wrong principal, wrong resource and a
  system-worker actor are all explicit denials with tests.
- **Concurrency (contract level):** CAS on payment, order, attempt, custody and
  rider-slot revisions, with a test showing two collections against one payment
  revision cannot both apply. **Storage-level atomicity is CJ1–CJ3, NOT RUN.**
- **Offline / restart / device / emulator / Firestore rules:** **NOT RUN /
  BLOCKED** — requires FND-004 infrastructure, Firebase CLI (**O4**), Firebase
  projects (**O5**), a Windows runner (**O2**) and physical devices (**O3**),
  none of which exist. No Firebase CLI was installed, no credentials were
  requested and no live environment was touched.

## 11. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 ·
ATT1–ATT9 · RET1–RET8 all remain NOT RUN**, and **CJ1–CJ12** are added as NOT
RUN. B3-C1 remains contract-test evidence only; **B3-C2 remains FUTURE**.
**FND-003D2A criterion 48 remains FAIL** under its recorded one-time exception.

## 12. Status

| Task | Status |
|---|---|
| **FND-003C1** | **DONE — NOT ACCEPTED**, awaiting one independent final review |
| **FND-003C** | **PARTIAL** — O6 resolved; remittance, settlement, reconciliation, refusal-fee collection, refunds, compensation, commission payout and worker pay outstanding |
| FND-003B / FND-003B3 | **PARTIAL** — successful delivery still outstanding |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| FND-004 | **TODO** |
| O6 | **RESOLVED** (ADR-0011) |
| O7 | **outstanding** |

## 13. Explicitly still unavailable

**Successful delivery, customer custody, rider completion, remittance,
settlement, reconciliation, refusal-fee collection, refunds, compensation,
commission payout, worker pay, dispute resolution, stock changes and FX
conversion all remain outside this task.** `CONSTRAINTS.md` invariant 13 is
**not discharged**, and the proof-satisfaction policy is untouched.

## 14. Process

One normal local commit. **No** push, merge, deploy, amend, rebase, squash,
cherry-pick, force-push, branch deletion, PR, tag, release, GitHub-setting
change or Firebase/live-data access. **No new third-party dependency.** No later
roadmap task started.

## Owner actions needed

**O6 is resolved.** **O7** remains outstanding, unchanged. **O2–O5** remain
outstanding and are the reason the backend/platform criteria above are NOT RUN.

---

# PUBLICATION — FND-003C1-PUBLISH-001

**Appended 2026-09-11. Nothing above is rewritten.**

**FND-003C1-FINAL-REVIEW-002 returned `ACCEPTED`** for candidate head
**`cfed2c70b5dbdddc9048f019644d34ccc85052eb`**. Publication is performed by the
bounded task **FND-003C1-PUBLISH-001** as an ordinary **non-force fast-forward**
of `main` from `79cdfe18996ba5382e727a328226ac3eaa5fce43`.

## The accepted chain

```text
79cdfe18   base
  -> 789682c   implementation
  -> cfed2c70  FND-003C1-FIX-001 (documentation only, zero executable change)
```

**The accepted FND-003C1 contract is both commits together. `789682c` alone is
not accepted:** FINAL-REVIEW-001 returned **FIX REQUIRED** on one material
documentation defect — the ledger simultaneously asserting `PARTIAL` and
`BLOCKED on O6` for FND-003C — which FIX-001 closed. The **executable contract
passed that review unchanged**, and FINAL-REVIEW-002 confirmed the
implementation tree was byte-identical (`b678c4ea…`) and not amended.

## What publication does not change

**No evidence was promoted by publishing.** `CJ1–CJ12` remain **NOT RUN** —
no backend exists, and FND-004 owns the API shell. **Migration, Firestore rules
and indexes remain `N/A — contract-only; no persistence exists yet`.
Device, offline, emulator and deployment remain NOT RUN. No hosted CI ran** —
the repository has no `.github` directory, and `./tools/run_checks.sh` is local
evidence only.

**ContractVersion stays 0.11** and **permissions stay 39 / 39**. Successful
delivery, the proof-satisfaction policy (`CONSTRAINTS.md` invariant 13 **not
discharged**), customer custody, rider completion, remittance, settlement,
reconciliation, refusal-fee collection, refunds, compensation, worker pay,
commission payout, dispute resolution, stock changes and FX all remain
**unavailable**.

**FND-003C remains PARTIAL** — O6 is resolved, the COD collection and journal
foundation is integrated, and every other money lifecycle is unimplemented.
**O7 remains OUTSTANDING.**
