# Task ledger

Single source of truth for task status across all five ChatGPT Projects. The
Projects cannot see each other's conversations, so this file — not a chat
history — records what is actually done.

**Update rule:** a task moves to DONE only when an executor completion report
with real command output exists in `docs/task-ledger/`. Sending a task prompt
is not completion. If a check could not be run, it is recorded **NOT RUN**, and
the task stays BLOCKED or PARTIAL.

Legend: `DONE` · `IN PROGRESS` · `BLOCKED` · `TODO` · `PARTIAL`

## Foundation

| ID | Owner | Deliverable | Depends on | Status | Evidence |
|---|---|---|---|---|---|
| FND-001 | ADMIN | Inspect/bootstrap repository, task ledger, pinned toolchain and constraints | — | **DONE** | [FND-001 report](FND-001-completion-report.md) |
| FND-001-FIX-001 | ADMIN | Recheck `e82e932`; close foundation evidence gaps (AGENTS.md, ADR-0002, workspace coverage, ledger accuracy) | FND-001 | **DONE** | [FND-001-FIX-001 report](FND-001-FIX-001-completion-report.md) |
| FND-002 | ADMIN | Platform/auth/notification compatibility spikes, proven matrix and blockers | FND-001 | **PARTIAL** | parent task; documentation/static/host portion delivered by FND-002A. Device/Windows/emulator portions outstanding |
| FND-002A | ADMIN | Host-available capability spike: upstream recheck, capability contracts, dated matrix, runtime test plan | FND-001 | **DONE** | [FND-002A report](FND-002A-completion-report.md) · [evidence register](../platform-matrix/FND-002A-capability-evidence.md) |
| FND-002B | ADMIN | Device/runner execution of the runtime test plan | FND-002A, **D1–D3**, O2/O3/O5 | **BLOCKED** | needs a decision *and* hardware — see [runtime test plan](../platform-matrix/FND-002-runtime-test-plan.md) |
| FND-003 | ADMIN | Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants | FND-001 | **PARTIAL** | parent task; command/authorization slice delivered by FND-003A. Lifecycle is **PARTIAL** — pre-dispatch order/reservation, the assignment lifecycle, custody/dispatch and the delivery-attempt/return **non-success** path are delivered and integrated, and post-dispatch inventory restoration is defined (gated on shop receipt **and** inspection); **successful delivery is not executable**. **Money is PARTIAL** — **O6 is resolved** (ADR-0011) and FND-003C1 delivers the COD collection and cash-journal foundation, while the remaining money lifecycles and **the proof-satisfaction policy remain outstanding** |
| FND-003A | ADMIN | Command and event envelopes, identity/membership/scope, permission matrix, authorization invariants | FND-001 | **DONE** (as corrected three times) | Accepted state = **`de19dc9` + `228409d` + `25e6186` + the FND-003A-FIX-003 commit**. Reports: [FND-003A](FND-003A-completion-report.md) + [FIX-001](FND-003A-FIX-001-completion-report.md) + [FIX-002](FND-003A-FIX-002-completion-report.md) + [FIX-003](FND-003A-FIX-003-completion-report.md) · contract **0.2**. **No earlier commit alone is the accepted contract.** |
| FND-003A-FIX-003 | ADMIN | Require fresh authorization before replay; separate type/trust/request-lifetime boundaries; command-router and stale-grant backend tests (R33–R40) | FND-003A-FIX-002 | **DONE** | [FND-003A-FIX-003 report](FND-003A-FIX-003-completion-report.md) |
| FND-003A-FIX-002 | ADMIN | Make successful authorization unforgeable and request-bound before idempotency replay | FND-003A-FIX-001 | **DONE** | [FND-003A-FIX-002 report](FND-003A-FIX-002-completion-report.md) |
| FND-003A-FIX-001 | ADMIN | Fix offer-vs-assignment scope, approval binding, idempotency principal isolation, version-compatibility semantics | FND-003A | **DONE** | [FND-003A-FIX-001 report](FND-003A-FIX-001-completion-report.md) |
| FND-003B | ADMIN | Lifecycle slice: order, assignment, custody, attempt and return transitions with inventory effects | FND-003A | **PARTIAL** | parent task; pre-dispatch order/reservation (B1), the full assignment lifecycle (B2), custody acquisition + picker→rider handoff (B3A) and the delivery-attempt/return non-success path (B3B) delivered — **all accepted and integrated**. **Successful delivery is still not executable.** **Outstanding — rest of FND-003B3** |
| FND-003B1 | ADMIN | Pre-dispatch order + reservation lifecycle: placement, acceptance/rejection, preparing/ready, cancellation, expiry and inventory race invariants | FND-003A | **DONE** (as corrected) | Accepted state = **`697d170` + the FND-003B1-FIX-001 commit**. Reports: [FND-003B1](FND-003B1-completion-report.md) + [FIX-001](FND-003B1-FIX-001-completion-report.md) · contract **0.3**. `697d170` alone is **not** the accepted contract |
| FND-003B1-FIX-001 | ADMIN | Validate canonical order/reservation aggregate before any lifecycle effect; pair-specific release paths | FND-003B1 | **DONE** | [FND-003B1-FIX-001 report](FND-003B1-FIX-001-completion-report.md) |
| FND-003B2 | ADMIN | Assignment lifecycle: picker and rider offer/accept/decline/expire edges | FND-003B1 | **DONE** (as corrected) | both sub-slices complete: picker by FND-003B2A, rider by FND-003B2B as corrected by FND-003B2B-FIX-001. Custody, delivery and returns are **not** part of this task — they are FND-003B3 |
| FND-003B2A | ADMIN | Picker assignment offer/accept/decline/expiry/revoke and controlled reassignment lifecycle | FND-003B1 | **DONE** (as corrected) | Accepted state = **`355aaa7` + `ce44b29` + the FND-003B2A-FIX-002 commit**. Reports: [FND-003B2A](FND-003B2A-completion-report.md) + [FIX-001](FND-003B2A-FIX-001-completion-report.md) + [FIX-002](FND-003B2A-FIX-002-completion-report.md) · contract **0.4**. **No earlier commit alone is the accepted contract** |
| FND-003B2A-FIX-001 | ADMIN | Deny assignment-id reuse; enforce reachable generation/revision coherence; record ADR-0006 admin-override governance | FND-003B2A | **DONE** | [FND-003B2A-FIX-001 report](FND-003B2A-FIX-001-completion-report.md) |
| FND-003B2A-FIX-002 | ADMIN | Pin transition-closure over the aggregate validator; couple executable states to the revision model; record B3-C1 | FND-003B2A-FIX-001 | **DONE** | [FND-003B2A-FIX-002 report](FND-003B2A-FIX-002-completion-report.md) |
| FND-003B2B | ADMIN | Picker-originated rider assignment: offer/accept/decline/expiry/controlled-revoke, source-picker binding, shared revision model | FND-003B2A | **DONE** (as corrected) | Accepted state = **`9d1e262` + the FND-003B2B-FIX-001 commit**. Reports: [FND-003B2B](FND-003B2B-completion-report.md) + [FIX-001](FND-003B2B-FIX-001-completion-report.md) · [ADR-0007](../decisions/ADR-0007-admin-rider-assignment-override.md) · contract **0.5**. Adds **RA1–RA18** and **B3-C2**, all **NOT RUN**. **`9d1e262` alone is not the accepted contract** |
| FND-003B2B-FIX-001 | ADMIN | Require the canonical opaque-id rule for assignment principal identities, in eligibility **and** stored aggregates, for both roles | FND-003B2B | **DONE** | [FND-003B2B-FIX-001 report](FND-003B2B-FIX-001-completion-report.md) |
| FND-003B3 | ADMIN | Custody, delivery-attempt and return lifecycle, including post-dispatch inventory restoration | FND-003B2 | **PARTIAL** | parent; custody acquisition and the picker→rider handoff delivered by FND-003B3A, and the delivery-attempt + refused-order return lifecycles by **FND-003B3B** (contract 0.10) — which also delivers post-dispatch inventory restoration, gated on shop receipt **and** inspection. **Both are accepted and integrated.** **Still outstanding:** successful delivery (`OrderState.delivered`), customer custody, rider assignment `completed` (**B3-C2**, FUTURE), the failed-attempt retry/return consequence and the via-picker return route — B3B enumerates and refuses the last two rather than guessing. Successful delivery additionally needs the **proof-satisfaction policy**, which is undefined, so `CONSTRAINTS.md` invariant 13 is **not discharged** |
| FND-003B3A | ADMIN | Physical custody: shop initialisation, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion | FND-003B2B | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = **`c29df0f` + `18ad750` + `e8dacfc`**, on `main` since FND-003B3A was merged. Reports: [FND-003B3A](FND-003B3A-completion-report.md) + [FIX-001](FND-003B3A-FIX-001-completion-report.md) + [FIX-002](FND-003B3A-FIX-002-completion-report.md) · [custody lifecycle](../contracts/custody-lifecycle.md) · contract **0.6**. Adds **CA1–CA23** (NOT RUN); **satisfies B3-C1** by contract test; **B3-C2 stays FUTURE**. **No earlier commit alone is the accepted contract** |
| FND-003B3A-FIX-001 | ADMIN | Bind custody to canonical resource/shop identity, add picker/rider slot-revision CAS, make custody initialisation create-once, correct exported state metadata and the test-count evidence | FND-003B3A | **DONE** | [FND-003B3A-FIX-001 report](FND-003B3A-FIX-001-completion-report.md) |
| FND-003B3A-FIX-002 | ADMIN | Reconcile contract status across the picker, rider and order documents, the package docs and source comments with what FND-003B3A actually implements | FND-003B3A-FIX-001 | **DONE** | [FND-003B3A-FIX-002 report](FND-003B3A-FIX-002-completion-report.md) · **documentation and source-comment only — zero executable Dart changed** |
| FND-003B3B | ADMIN | Delivery attempt and return lifecycle: `pending → out_for_delivery → refused \| failed`, the refusal-opened return `required → in_transit → received → inspected → closed`, and post-dispatch inventory disposition | FND-003B3A | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = the **two-commit** chain **`8ccb5aa8` + `cdb5f35b`**, accepted by FND-003B3B-FINAL-REVIEW-002 and integrated into `main` by **FND-003B3B-PUBLISH-001** (normal fast-forward from `8210323`; no merge, squash, rebase, amend or cherry-pick commit exists, and the feature branch was never published). **`8ccb5aa8` alone is NOT accepted** — FND-003B3B-FINAL-REVIEW-001 returned **FIX REQUIRED** on two material documentation/evidence defects in it (a stale authoritative `ReservationState` invariant, and undocumented whole-order-only return scope); the executable contract passed that review unchanged, and both defects are corrected by **FND-003B3B-FIX-001** (`cdb5f35b`) with **zero executable production change**. Later documentation-only descendants of `cdb5f35b` are **not** part of the accepted contract chain. Contract **0.9 → 0.10** (additive). Implements the bounded **non-success** path and nothing else. A canonical refusal after dispatch **atomically** opens the return requirement — attempt `refused` + return `required` in one transition — while the order, custody, the rider assignment and the reservation are all untouched, the inventory effect is **NONE**, and the financial classification is `deferredToFinancialSlice`: **unknown, never zero**. A **failed** attempt records the fact and stops; `evaluateRecordDeliveryFailure` does not even take the return facts as a parameter, so it structurally cannot open one, and the post-failure consequence is enumerated and refused (`failureReturnPolicyDeferred`) because no accepted contract decides it. The direct `rider → shop` route is executable; **shop receipt** moves custody `rider → shop` exactly once as the second receiver-side custody edge, and restores **no** stock. **Stock is restored only after shop receipt AND a `restockable` inspection, exactly once** — `damaged` and `quarantined` end the reservation with an available-stock delta of **zero**. The terminal `ReservationState.returned` is deliberately distinct from `released`, which promises the units went back to available stock. **One permission added** — `agent.return.record_receipt` — so `Permission.values` and `permissionMatrix` go **38 → 39**; `agent.fulfillment.record_progress` was **not** widened into a custody or stock lever and no admin custody override was added. **Successful delivery remains NOT executable**: `recordDelivered` is enumerated and always refused with `deliveryProofPolicyDeferred`, a `satisfied` assessment is **not** consumed as authority, and `OrderState.delivered`, customer custody and rider `completed` stay unreachable — **B3-C2 remains FUTURE** and `CONSTRAINTS.md` invariant 13 is **not discharged**. The via-picker return route is enumerated and refused (`returnRouteNotImplemented`) for an **authority** reason, not a state-machine one: the picker assignment is `completed` at dispatch and its scope removed — see [ADR-0010](../decisions/ADR-0010-direct-rider-to-shop-return-route.md). No fee, refund, liability, compensation, commission or settlement rule; no proof mechanism; no serialization; no persistence. Adds **ATT1–ATT9** and **RET1–RET8**, all **NOT RUN**. Reports: [FND-003B3B](FND-003B3B-completion-report.md) · [delivery attempt/return](../contracts/delivery-attempt-return-lifecycle.md) |
| FND-003B3B-FIX-001 | ADMIN | Correct the two material findings from FND-003B3B-FINAL-REVIEW-001: the stale authoritative `ReservationState` class doc, and the undocumented whole-order-only return scope | FND-003B3B | **DONE** | **Documentation, source-comment and test only; zero executable Dart changed.** **M1** — the enum's own *"invariant this enum exists to protect"* block still said there were **four** states and that restoration happens *"exactly on the transition into `released` or `expired`"*. FND-003B3B had already falsified both: there are five states, and a `restockable` inspection producing `returned` is a **third** restoration site. A reader consulting the authoritative block to find every place stock can be restored would have found two of three. It now lists all three sites and states that *terminal* and *restored* are separate claims — `returned` carries only the first. **M2** — the return is **whole-order only** and nothing said so: one `ReturnDisposition` covers the entire committed reservation, `restore` always moves the canonical `order.reservedUnits`, and a **mixed** return (*"three fine, two broken"*) is **not representable**. Left implicit, a reader could assume per-item dispositions exist; the only two representable answers for a mixed return both corrupt stock — over-restock or over-write-off. Now normative in the contract doc and recorded as **ADR-0010 Decision 4**, with four regression tests pinning canonical quantity across several reserved counts, the absence of any caller-controlled quantity field (static constructor tear-off type pins plus a field-declaration scan), and the single-disposition shape. **ContractVersion stays 0.10**, permissions stay **39**, and every accepted B3B behaviour is unchanged. **FIX-001 is the second commit of the accepted two-commit B3B chain**, accepted by FND-003B3B-FINAL-REVIEW-002 and integrated by FND-003B3B-PUBLISH-001. Report: [FND-003B3B-FIX-001](FND-003B3B-FIX-001-completion-report.md) |
| FND-003D1-FIX-001 | ADMIN | Bound the proof-policy reference at 64, stop its `toString` reproducing the raw value, make evidence `belongsTo` fail closed, and correct the stale package version header | FND-003D1 | **DONE** | [FND-003D1-FIX-001 report](FND-003D1-FIX-001-completion-report.md) · [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md) |
| FND-003D1-FIX-002 | ADMIN | Alias the proof-policy ceiling to the canonical `maxIdLength` instead of repeating its literal, and make `DeliveryEvidenceRef.toString` fail safe for malformed instances | FND-003D1-FIX-001 | **DONE** | [FND-003D1-FIX-002 report](FND-003D1-FIX-002-completion-report.md) · [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md) amended |
| FND-003D2A | ADMIN | Mechanism-neutral, trusted-server-produced delivery-proof **assessment** result | FND-003D1 | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = **`6bb23710` + `03c71d0`**, and `main` is now **`03c71d0`** — the FND-003D2A-FIX-001 commit. *(Reconciled by FND-003D2B: the wording below described the pre-merge candidate and was stale. No historical report was rewritten, and the process exception stands unchanged.)* **`6bb23710` alone is NOT accepted**: FND-003D2A-FINAL-REVIEW-001 found technical, maintainability, security and process-evidence defects, all corrected by FND-003D2A-FIX-001. **Known process exception, recorded separately and NOT part of the accepted chain:** a local-only commit `a9f3db98` was amended into `6bb23710` before first publication, so FND-003D2A acceptance criterion 48 (no amend) = **FAIL**; no shared history or CI result was rewritten, and it is a one-time pre-publication exception only — see the process-correction section of the [FND-003D2A report](FND-003D2A-completion-report.md). Reports: [FND-003D2A](FND-003D2A-completion-report.md) + [FIX-001](FND-003D2A-FIX-001-completion-report.md) · [delivery-proof assessment](../contracts/delivery-proof-assessment.md) · [ADR-0009](../decisions/ADR-0009-trusted-immutable-proof-assessment.md) · contract **0.8**. Adds **DPA1–DPA18**, all **NOT RUN** (DPA17 verifier authorization, DPA18 reassessment audit basis, both added by FIX-001). **No command and no permission added** (`Permission.values` stays 38); every order/reservation/inventory/financial/custody/assignment effect is **NONE**. Successful delivery remains **not executable** |
| FND-003D2B | ADMIN | Fallback dispute workflow for a missing, superseded or `notSatisfied` assessment | FND-003D2A | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = the **seven-commit** chain **`b94e5424` + `ded1aa79` + `f04d453` + `202a8a9` + `45d21e9` + `cc0c1ae` + `743e157`**, and the accepted contract tip is **`743e157`**, integrated into `main` by **FND-003D2B-MERGE-001**. A later documentation-only bookkeeping commit **`c99a0e5`** was published as a **separate child** of that tip; **`c99a0e5` is not part of the accepted seven-commit contract chain**, and `main` advances past `743e157` for documentation without changing what was accepted. **No prefix of that chain is accepted alone** — accepted by FND-003D2B-FINAL-REVIEW-006 and integrated by **FND-003D2B-MERGE-001** (fast-forward from `03c71d00`; no merge, squash, rebase, amend or cherry-pick commit exists, and the feature branch was preserved at the same tip). *(The wording below described the pre-merge candidate as it evolved and is retained as history; no historical report was rewritten.)* **Neither `b94e5424` nor `ded1aa79` alone was ever acceptable.** FND-003D2B-FINAL-REVIEW-001 found three material defects — a basis standing that certified a **verdict contradiction** as `current`, an **invented `reviewerIsRaiser`** separation-of-duties denial with no accepted contract behind it, and a **record-review-started path coupled to current assessment/order facts it never reads**, which could freeze a validly raised dispute out of review. All three are corrected by **FND-003D2B-FIX-001** (`ded1aa79`). **FND-003D2B-FINAL-REVIEW-002 then found two more**: a basis standing that reported **`superseded` for a higher revision reusing the basis's assessment id** — impossible history under ADR-0009, on a structurally canonical aggregate — and executable evaluators that took a bare `Principal` while only *documenting* that authorization had run, so a **non-owner customer could raise** and a **customer-only principal could review** by calling them directly. Both are corrected by **FND-003D2B-FIX-002** (`f04d453`). **FND-003D2B-FINAL-REVIEW-003 then found one more**: `evaluateRaiseDeliveryProofDispute` could not structurally prove its `OrderLifecycleFacts` belonged to the same order as the grant, dispute and assessment — that accepted type carries **no resource id** — so an order-B read with matching scalars was indistinguishable from order A's. Corrected by **FND-003D2B-FIX-003** (`202a8a9`), whose publication was then **correctly blocked** by FND-003D2B-FIX-003-PUSH-001 over two obsolete current-tense statements about the resource anchor — corrected, documentation-only, by **FND-003D2B-FIX-004** (`45d21e9`). **FND-003D2B-FINAL-REVIEW-004 then found one more**: a current-tense evaluator doc comment still saying the canonical resource *comes from the grant* — missed because the FIX-004 sweep was line-based and the sentence wraps. Corrected, documentation-only, by **FND-003D2B-FIX-005** (`cc0c1ae`). **FND-003D2B-FINAL-REVIEW-005 then found one more**: the canonical review integrity table documented a `resourceBindingMismatch` step the review evaluator does not have, plus a stale test comment. Corrected, documentation-only, by **FND-003D2B-FIX-006**. Accepted chain = **`b94e5424` + `ded1aa79` + `f04d453` + `202a8a9` + `45d21e9` + `cc0c1ae` + `743e157`** on `fnd/FND-003D2B-fallback-proof-dispute-contract`, branched from `main` @ `03c71d0` and **now integrated into `main` by fast-forward**. **No prefix is accepted alone.** **That required review was performed — FND-003D2B-FINAL-REVIEW-006 accepted the seven-commit candidate, and FND-003D2B-MERGE-001 integrated it.** Reports: [FND-003D2B](FND-003D2B-completion-report.md) + [FIX-001](FND-003D2B-FIX-001-completion-report.md) + [FIX-002](FND-003D2B-FIX-002-completion-report.md) + [FIX-003](FND-003D2B-FIX-003-completion-report.md) + [FIX-004](FND-003D2B-FIX-004-completion-report.md) + [FIX-005](FND-003D2B-FIX-005-completion-report.md) + [FIX-006](FND-003D2B-FIX-006-completion-report.md) · [delivery-proof dispute](../contracts/delivery-proof-dispute.md) · contract **0.9** (unchanged by the fix — an in-place correction to an unreleased candidate, not a release event). Adds **DPD1–DPD12**, all **NOT RUN**. **No permission added** (`Permission.values` stays 38); both executable operations use the accepted `customer.dispute.raise` and `admin.dispute.administer` rules unchanged. **No dispute outcome, fault, fee, refund, compensation, liability, return or delivery consequence is decided** — `resolve` is enumerated and always refused `resolutionPolicyDeferred`. Every order/reservation/inventory/financial/custody/assignment **and assessment** effect is **NONE**. Successful delivery remains **not executable** |
| FND-003C | ADMIN | Money slice: payment/COD, cash journal, fees, refusal policy, commissions, settlement | FND-003A, FND-003B | **PARTIAL** | **O6 is resolved** — see [ADR-0011](../decisions/ADR-0011-o6-currency-fees-commission-and-cash-custody.md), decided under the ADMIN standing delegation: **BDT-only v1 with the currency still explicit on every value and no FX**, the customer price an **immutable quoted snapshot** whose commission is an **allocation out of merchandise proceeds and never a customer charge**, the voluntary-refusal default the order's quoted delivery charge with **nonpayment representable** and fault cases left **unresolved rather than charged or waived**, and rider cash as **custody, not ownership**. **FND-003C1** then delivers the first executable slice: normal-path COD collection with balanced journal effects. **Still outstanding:** remittance, settlement, reconciliation, refusal-fee collection, refunds, compensation, commission payout, worker pay and the COD/cash-journal backend (**CJ1–CJ12**, all **NOT RUN**) |
| FND-003C1 | ADMIN | First money slice: normal-path **COD collection** and balanced cash-journal effects | FND-003C (O6), FND-003B3B | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED (2026-09-11).** Accepted state = the **two-commit** chain **`789682c` + `cfed2c70`**, accepted by **FND-003C1-FINAL-REVIEW-002** and integrated into `main` by **FND-003C1-PUBLISH-001** (normal fast-forward from `79cdfe18`; no merge, squash, rebase, amend or cherry-pick commit exists, and the feature branch was not published). **`789682c` alone is NOT accepted** — FND-003C1-FINAL-REVIEW-001 returned **FIX REQUIRED** on one material documentation defect (the ledger asserting both `PARTIAL` and `BLOCKED on O6` for FND-003C); the executable contract passed that review unchanged, and the defect is corrected by **FND-003C1-FIX-001** (`cfed2c70`) with **zero executable change**. Later documentation-only descendants are **not** part of the accepted chain. Contract **0.10 → 0.11** (additive). One operation, `cash.report_cod_collection`, under the **accepted, unchanged** `rider.cash.report_collection` — **no permission was added**, so `Permission.values` and `permissionMatrix` stay **39**. A rider records **only cash actually received**: the payment moves `due`/`partially_collected` → `partially_collected`/`collected` derived from canonical totals, and **exactly one balanced journal entry** records the movement (`customerCodReceivable` −A, `riderCashInTransit` +A, summing to zero). **Over-collection is impossible**, partial collection is representable and a second collection can complete it. Money is `cp_core.Money` — integer minor units with an explicit ISO-4217 currency; **BDT only in v1 and no FX**, so a mixed or non-BDT read fails closed with a denial before any arithmetic. **Absence is never zero**: every amount and both policy references are required, so a snapshot with a missing fee or commission policy cannot be constructed, while an explicitly published zero **can**. **No balance setter, journal editor or deleter, generic payment-state setter or caller-selected account exists**; corrections are reversal entries referencing the original. **Collecting cash is not delivering**: the transition has no field for an order, custody, attempt, assignment, inventory or proof effect, so `OrderState.delivered`, customer custody and rider `completed` remain unreachable, **B3-C2 stays FUTURE** and `CONSTRAINTS.md` invariant 13 is **not discharged**. `disputed` is enumerated and **not producible here**, which is what keeps **nonpayment representable**. Adds **CJ1–CJ12**, all **NOT RUN**. Reports: [FND-003C1](FND-003C1-completion-report.md) · [cash and payments](../contracts/cash-and-payments.md) · [ADR-0011](../decisions/ADR-0011-o6-currency-fees-commission-and-cash-custody.md) |
| FND-003C1-FIX-002 | ADMIN | Correct the permission-matrix version header and guard it with a regression test | FND-003C1 | **DONE** (accepted) | **Technically accepted.** Accepted state = the single commit **`e90f2ec16ac4c1b2997052f242127be452284955`**, accepted by **FND-003C1-FIX-002-FINAL-REVIEW-002**, which returned **ACCEPTED** with no material defect. **Publication state is deliberately not encoded as prose here** — a mutable current-state claim in a durable row is exactly the class of defect this task exists to remove. **Git history is the authority**: `git merge-base --is-ancestor e90f2ec origin/main` answers whether the accepted commit has reached `main`, and it answers correctly whenever it is run. `docs/contracts/permission-matrix.md` still declared **Contract version 0.10** after FND-003C1 moved the contract to **0.11**, so the canonical permission document contradicted `ContractVersion.current`. The header now declares **0.11** and states the distinction that made the drift easy to miss: **0.11 is the overall contract version**, the **permission vocabulary itself last changed at 0.10** (FND-003B3B added `agent.return.record_receipt` at 0.10, taking the count **38 → 39**), and **FND-003C1 added no permission** — so a header newer than the last vocabulary change is normal, not a defect. The 39-row table is **unchanged and re-verified**: identical to the table at `cdb5f35b` where 0.10 introduced it, and reproduced exactly by `tool/print_permission_matrix.dart`. `Permission.values` and `permissionMatrix` remain **39**. **Documentation and test only — zero executable contract change**, and `ContractVersion.current` is **not** touched (0.11 was already correct; the document was wrong). The new `permission_matrix_doc_consistency_test.dart` derives its expectation from `ContractVersion.current` and **hard-codes no version literal**, so the next bump fails it until the document follows. It was **proven to fail before the fix** (document `0.10` vs current `0.11`) and to fail clearly when the document is **missing**, its declaration **malformed**, or **ambiguous**. Suite **1151 → 1153**, the two new tests and nothing else. **Known remaining debt, recorded and out of this task's scope — now DISCHARGED by FND-003D1-BOOKKEEPING-FIX-001 (the debt is kept on the record, not deleted):** at the time this row was written, `docs/contracts/delivery-proof-boundary.md` still asserted the old count in the **present tense** in two places — *"`Permission.values` remains **38**"* (§2) and *"a test pins the count at 38 for both `Permission.values` and `permissionMatrix`"* (§5, now false: the test pins **39**). Stale since 0.10 and **not** corrected here. **Discharged 2026-09-11** by **FND-003D1-BOOKKEEPING-FIX-001**, which corrected both places to **39**, advanced that document's inline *"Still true at 0.9"* marker to **0.11** after re-verifying every claim in it, and added `packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart` so the claim cannot silently go stale again. Note the repository runs **two header conventions**: that document stamps *"Introduced at contract version 0.7"* — a fixed origin marker that is correct as written — whereas `permission-matrix.md` carries a **running current-version** header, which is why only the latter could drift and why the new guard deliberately targets **only** that document. **ORDINAL-WORDING DEBT — DISCHARGED.** This row and the report's prose called `agent.return.record_receipt` *"the 39th"*, conflating **the permission that took the count to 39** with **the 39th declared value**. They differ: it sits at **zero-based index 12 — the 13th declared**, while the 38th declared is `admin.cash.record_reconciliation` and the 39th is `admin.release.view_health` (`Permission.values.indexOf`, probed). Corrected by **FND-003D1-BOOKKEEPING-FIX-002**; the chronological fact (**38 → 39** at **0.10**) was always correct and is unchanged. Two further copies of the phrase inside that report are **deliberately preserved** — one is a **verbatim quotation** of `permission-matrix.md` and one is **recorded probe output**; editing either would turn a faithful quotation into a misquotation or falsify recorded evidence. Report: [FND-003C1-FIX-002](FND-003C1-FIX-002-completion-report.md) |
| FND-003D | ADMIN | Proof and dispute slice: proof-satisfaction contract and fallback dispute workflow | FND-003B | **PARTIAL** | parent; the mechanism-neutral proof/evidence **reference** boundary delivered by FND-003D1, the trusted immutable proof **assessment result** by FND-003D2A, and the **fallback dispute workflow** by FND-003D2B (**as corrected by FND-003D2B-FIX-001 through FIX-006, accepted and integrated**). **The proof-satisfaction policy itself is still undone**, so CONSTRAINTS invariant 13 is **not discharged** and delivery confirmation may not be coded. **How a dispute resolves** is separately undecided — it needs the remaining **FND-003C** money work (**O6 itself is resolved** by ADR-0011) and a resolution slice; FND-003B3B is **done** and decides no dispute outcome |
| FND-003D1 | ADMIN | Mechanism-neutral delivery-proof policy reference, resource-bound evidence reference and the privacy boundary | FND-003B3A | **DONE** (as corrected) | **ACCEPTED AND INTEGRATED.** Accepted state = **`913b1ac` + `f615ea6` + `f03fc99`**, fast-forwarded onto `main` by FND-003D1-MERGE-001 (2026-09-10) with no merge, squash, rebase or amend commit. `main` is now **`f03fc99`**. Reports: [FND-003D1](FND-003D1-completion-report.md) + [FIX-001](FND-003D1-FIX-001-completion-report.md) + [FIX-002](FND-003D1-FIX-002-completion-report.md) · [delivery-proof boundary](../contracts/delivery-proof-boundary.md) · [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md) · contract **0.7**. **No earlier commit alone is the accepted contract.** **References only** — no proof mechanism, no satisfaction rule, no command, state, event or permission. Successful delivery remains **not executable** |
| FND-003D1-BOOKKEEPING-FIX-001 | ADMIN | Remove the false present-tense permission-count claims from the delivery-proof boundary document and guard the claim with a derived regression test | FND-003D1, FND-003C1-FIX-002 | **DONE** | **Documentation and test only — ZERO executable change**; no file under any `lib/` directory is touched, `ContractVersion.current` stays **0.11**, and `Permission.values` / `permissionMatrix` stay **39**. `docs/contracts/delivery-proof-boundary.md` asserted `Permission.values` **38** in the **present tense** in two places (§1 line 68 and §5 line 212), stale since FND-003B3B took the vocabulary **38 → 39** at **0.10**. Both are corrected to **39**, and each now states the distinction that made the drift easy to miss: *"neither D2A nor D2B added a permission"* is true and is **not the same claim** as the total count, and because this document carries a **fixed-origin** header (*"Introduced at contract version 0.7"*) rather than a running-current-version one, **a count newer than the document's own slice is normal, not a defect**. The fixed-origin header is deliberately **left as is** — it is correct, and converting it would destroy the distinction. §5 now names the actual guards: **seven** test files carry the count, **six** pinning the literal 39 for both vocabularies (`delivery_proof_test.dart` lines 850–851, `delivery_proof_assessment_regression_test.dart`, `delivery_proof_dispute_authority_test.dart`, `attempt_return_authority_test.dart`, `cod_collection_authority_test.dart`, `permission_matrix_doc_consistency_test.dart`) and the seventh (`permission_matrix_test.dart`) deriving it. The inline **"Still true at 0.9"** marker is advanced to **0.11** only after **re-verifying every claim in it** against the 0.11 tree — the two references still carry no verdict field, `DeliveryProofDisputeState` is still `open`/`underReview` **plus the unreachable `resolved`** (declared for enum stability only; no command transitions into it and `reachableDisputeRevisionFor` returns null for it), `dispute.resolve_delivery_proof` is still always refused `resolutionPolicyDeferred`, no `order.delivered` event exists, and `OrderState.delivered`, customer custody and rider `completed` remain unreachable — and the re-check is written into the document rather than the marker merely restamped. §7's dispute-outcome bullet now records that **O6 is RESOLVED** ([ADR-0011](../decisions/ADR-0011-o6-currency-fees-commission-and-cash-custody.md)) and **FND-003B3B is DONE and integrated**, leaving only the remaining **FND-003C** money work; **the outcome itself stays UNDECIDED** — discharging a prerequisite is not deciding the question. New guard `packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart` derives its expectation from `Permission.values.length` and **hard-codes no count literal** (proven by a comment-stripped grep), so a 40th permission fails it until the document follows. It was **proven to fail against the pre-fix document**, naming both stale lines (68 and 212), and to fail with a distinct, specific message when the document is **missing**, its claim **malformed**, or **ambiguous**. Suite **1153 → 1155** in `packages/contracts`, the two new tests and nothing else; `./tools/run_checks.sh` **ALL CHECKS PASSED**; `tool/print_permission_matrix.dart` still emits **39** rows, **byte-identical** to the committed `permission-matrix.md` table. **GitHub CI: NOT RUN** — no `.github` directory exists and **O7 remains OUTSTANDING**. **Newly found debt, NOT fixed here and out of scope:** `AGENTS.md` **§11**'s ADR index stops at **ADR-0008** and omits **ADR-0009** (trusted immutable proof assessment), **ADR-0010** (direct rider-to-shop return route) and **ADR-0011** (O6 currency, fees, commission and cash custody) — all three exist in `docs/decisions/` and are referenced elsewhere in this ledger, so the canonical index under-reports the accepted decisions. It needs its own task. **DISCHARGED by FND-003D1-BOOKKEEPING-FIX-002**: §11 now lists **ADR-0001 → ADR-0011**, each appearing exactly once, with ADR-0005 marked *Proposed — blocked on an owner decision* and ADR-0009 *Accepted; amended by FND-003D2A-FIX-001*. The discovery record above is kept as history, not deleted. **REVIEWED AND CORRECTED:** candidate **`64930e3`** was independently reviewed by **FND-003D1-BOOKKEEPING-FIX-001-FINAL-REVIEW-001**, which returned **FIX REQUIRED** on **two documentation-accuracy defects** — (1) a **new** false present-tense claim in the re-stamped *"Still true at 0.11"* box, *"`DeliveryProofDisputeState` … with **no** resolved state"*, when the enum in fact declares a third, **unreachable** `resolved` value (contradicting `delivery-proof-dispute.md` and the tests pinning `DeliveryProofDisputeState.values.length == 3`), and (2) a **declaration-ordinal error in the completion report**, *"the 38th declared value"*, which read a `grep -n` **file line number** as an ordinal (the true ordinal is **index 12 — the 13th declared**), together with a claim that the document avoided *"added the 39th permission"* wording that the committed document still contained. **Both defects were documentation accuracy only — no technical contract, executable code or test was wrong, and none changed.** They are corrected by the follow-up commit **FND-003D1-BOOKKEEPING-FIX-001-FIX-001**, which touches four documentation files, amends nothing, and leaves `64930e3` on the record with its review failure intact. Reports: [FND-003D1-BOOKKEEPING-FIX-001](FND-003D1-BOOKKEEPING-FIX-001-completion-report.md) · [FND-003D1-BOOKKEEPING-FIX-001-FIX-001](FND-003D1-BOOKKEEPING-FIX-001-FIX-001-completion-report.md) |
| FND-003D1-BOOKKEEPING-FIX-002 | ADMIN | Correct the inaccurate "39th permission" ordinal wording carried by the FND-003C1-FIX-002 report and complete the stale `AGENTS.md` §11 ADR index | FND-003D1-BOOKKEEPING-FIX-001 (`734863c` → `64930e3` → `5385935`; ancestry is answerable from git history, which is the authority) | **DONE** | **Documentation-only bookkeeping — ZERO executable change.** No Dart file, no file under any `lib/`, no test, no ADR body, no contract and no policy is touched; `ContractVersion.current` stays **0.11** and `Permission.values` / `permissionMatrix` stay **39 / 39** (probed, not asserted). Exactly four documentation files change. **Discharges two debts recorded against earlier tasks, both kept as history rather than deleted.** **(1) Ordinal conflation.** `agent.return.record_receipt` was called *"the 39th"* in the FND-003C1-FIX-002 report and in that task's ledger row. It is the permission that took the **count** from 38 to 39 at **0.10**, but it is **not** the 39th declared value: it sits at **zero-based index 12 — the 13th declared**, the 38th declared is `admin.cash.record_reconciliation` and the 39th is `admin.release.view_health`. Both the row and the report's own prose are corrected; the chronological **38 → 39** fact is preserved because it was always true. **(2) ADR index.** `AGENTS.md` §11 stopped at **ADR-0008**, omitting **ADR-0009**, **ADR-0010** and **ADR-0011**. §11 now carries the complete canonical inventory **ADR-0001 → ADR-0011**, each identifier appearing **exactly once**, in ascending order, with the three additions under their **exact canonical titles**, ADR-0005 marked *Proposed — blocked on an owner decision; not accepted* and ADR-0009 *Accepted; amended by FND-003D2A-FIX-001*. No ADR file is modified, and `docs/decisions/` is named as the authority over the index. **Newly found debt, NOT fixed here and out of scope:** the same ordinal conflation originates in **`docs/contracts/permission-matrix.md` line 8** (*"`agent.return.record_receipt`, the 39th"*), a contract document this task is not authorized to change; because the FND-003C1-FIX-002 report **quotes that header verbatim** and also carries the phrase inside **recorded probe output**, those two copies are deliberately left intact — correcting a quotation or recorded evidence would be falsification, not a fix. The permission-matrix wording needs its own bounded task. **ROOT ORDINAL DEBT — DISCHARGED by FND-003D1-BOOKKEEPING-FIX-003** (the discovery record above is kept as history, not deleted): that header sentence now reads *"`agent.return.record_receipt`, which took the total from **38 → 39**"*, and a prose guard rejects any declaration ordinal in that document's prose, so the conflation cannot silently return. **Two further evidence debts in this task's own report — raised as non-blocking observations by the independent FND-003D1-BOOKKEEPING-FIX-002-FINAL-REVIEW-001, deferred at FND-003D1-BOOKKEEPING-FIX-002-PUBLISH-001, and also DISCHARGED by FND-003D1-BOOKKEEPING-FIX-003:** (a) §7 pointed at *"the recorded probe output at line 101"* although its committed position was line 123 — now a durable section/content pointer that no later edit can invalidate; (b) §4's *"base rows: 42 now rows: 43"* totals were unreproducible because no extraction filter was stated — now the exact command with its real output (**37 → 38** task rows). Neither preserved quotation nor recorded output was altered. `./tools/run_checks.sh` **ALL CHECKS PASSED**. **GitHub CI: NOT RUN** — no `.github` directory exists; **O7 remains OUTSTANDING**. Report: [FND-003D1-BOOKKEEPING-FIX-002](FND-003D1-BOOKKEEPING-FIX-002-completion-report.md) |
| FND-003D1-BOOKKEEPING-FIX-003 | ADMIN | Correct the root `permission-matrix.md` ordinal wording, guard against its return, and repair two unreproducible evidence claims in the FND-003D1-BOOKKEEPING-FIX-002 report | FND-003D1-BOOKKEEPING-FIX-002 (`4b22173`; ancestry is answerable from git history, which is the authority) | **DONE** | **Documentation and test only — ZERO production change.** No production Dart, no file under any `lib/`, no ADR, no `AGENTS.md`, no `SHARED_BLUEPRINT.md`/`CONSTRAINTS.md` and no other contract document; `ContractVersion.current` stays **0.11** and `Permission.values` / `permissionMatrix` stay **39 / 39**, probed with `Permission.values.indexOf`, not grepped. Exactly **five** files change. **Discharges three debts, all kept on the record rather than deleted.** **(1) Root ordinal conflation.** `permission-matrix.md`'s vocabulary-history sentence called `agent.return.record_receipt` *"the 39th"*. It is the permission that took the **count** from 38 to 39 at **0.10**, but it sits at **zero-based index 12 — the 13th declared**; the 38th declared is `admin.cash.record_reconciliation` and the 39th is `admin.release.view_health`. It now reads *"which took the total from **38 → 39**"*. The 0.10 attribution, the **39 permissions** total and all historical version information are preserved, and no declaration-order claim replaces the old one. **(2) Unstable line pointer** and **(3) unreproducible row totals**, both in the FIX-002 report — see that task's row for what each said and what replaced it. **New guard.** `permission_matrix_doc_consistency_test.dart` gains a prose-pattern guard: that document's prose — generated table and fenced code excluded — may carry **no declaration ordinal**, and must record a **total-count transition ending at the live `Permission.values.length`**. The expected total is derived, so no current count is hard-coded as the source of truth, nothing depends on a source-file declaration position, and nothing is tied to one Markdown line number. The existing derived count, table-row and version checks are preserved unchanged. **Negative controls, proved on temporary material outside the repository worktree:** the published pre-fix document (blob `c12ba13`) **FAILS** both halves of the guard; the corrected document **PASSES** both; `38 → 39`, `38 to 39` and `38 -> 39` are **not** treated as ordinal errors; `0.10 to 0.11` is not misread as a count transition; and the generated table is not searched for ordinals. **Newly found debt, NOT fixed here and out of scope:** the FND-003C1-FIX-002 report's §4 opening block now reproduces a **superseded** `permission-matrix.md` header verbatim, and its correction blockquote still describes the root wording as outstanding. Both remain accurate as history and neither was altered, but the re-labelling they now need is **prohibited to this task** — that report is on this task's do-not-change list — so it needs its own bounded task. `./tools/run_checks.sh` **ALL CHECKS PASSED**. **GitHub CI: NOT RUN** — no `.github` directory exists; **O7 remains OUTSTANDING**. Report: [FND-003D1-BOOKKEEPING-FIX-003](FND-003D1-BOOKKEEPING-FIX-003-completion-report.md) |
| FND-004 | ADMIN | CI/platform runners, emulator security tests, design system, auth, cache/queue/API shell | FND-002, FND-003 | **TODO** | needs Firebase CLI (not installed) |

### FND-002 status after FND-002A

FND-002 is a **parent** capability task, split so that the evidence not
requiring hardware could be produced immediately.

**FND-002A — DONE (2026-09-09).** Rechecked every material platform claim
against current upstream primary sources; built platform-neutral capability
contracts in `cp_notifications`, `cp_auth` and `cp_local_store` with tests;
produced a dated evidence register, an evidence-classed platform matrix and a
concrete runtime test plan. Host-runnable checks were executed, including a
browser capability probe in Chrome 152.

**FND-002B — BLOCKED.** Device, Windows-runner and emulator execution. Blocked
on hardware *and* on an owner decision, so hardware alone does not unblock it.

| Blocked check | Missing | Owner action |
|---|---|---|
| Android/iOS push behaviour | physical devices; Firebase project + APNs key | O3, O5 |
| Windows build, auth REST/PKCE, toast, Drift native | Windows machine or CI runner | O2 |
| Windows closed-app push | Azure/Entra or Store registration | **D3** |
| Firestore rules / emulator suites | Firebase CLI, FlutterFire CLI | O4 |
| Web FCM delivery | Firebase project, VAPID key, generated `web/` folders | O5, FND-004 |

**Headline finding.** The blueprint's *mandatory* `firebase_messaging` +
`awesome_notifications` coexistence is **DECISION REQUIRED**, not merely
untested: the `awesome_notifications` vendor deprecates `firebase_messaging`
support and `awesome_notifications_fcm` states users "MUST not use
`firebase_messaging`" with it. No dependency was substituted. See
[ADR-0005](../decisions/ADR-0005-notification-stack-decision-required.md).

### FND-003 status after FND-003A

FND-003 is a **parent** contract task, split into slices so the work not
needing owner decisions could land immediately.

**FND-003A — DONE (2026-09-09), as corrected by FND-003A-FIX-001
(2026-09-10).** Command and event envelopes, idempotency semantics,
identity/membership/scope vocabulary, 35 stable permission ids, one canonical
least-privilege matrix, and a pure-Dart authorization evaluator with deny-path
tests. Contract version **0.1 → 0.2** (additive), corrected **in place**.

Review of `de19dc9` found four defects, all fixed by `228409d`: assignment accept/decline
was authorized by region alone (any same-region worker could take another's
offer); `ApprovalEvidence` was not bound to requester/permission/resource;
idempotency replay was not principal-isolated; and version-number
compatibility was being presented as proof of payload readability.

A further review of `228409d` found a fifth defect, fixed by
**FND-003A-FIX-002**: `AuthorizationDecision.allow()` was public and the class
was not `final`, so the documented "authorization cannot be skipped" guarantee
did not exist — callers, including the contract's own tests, could fabricate
success, and an allow carried no binding to what had been authorized.
Successful authorization is now an unforgeable, request-bound
`AuthorizationGrant`.

A third review of `25e6186` found the remaining gap, fixed by
**FND-003A-FIX-003**: unforgeable is not the same as *current*. The grant's
private constructor proves only that `evaluateAuthorization` allowed the inputs
it was given — not that those inputs were verified, authoritative or fresh —
and nothing stopped an application retaining a grant across requests, so a
revoked actor's earlier success could still replay. The contract now requires
**fresh authorization on every request including replays**, forbids caching or
reusing a grant, assigns command-type → permission mapping to the trusted
backend router, and adds backend checklist items **R33–R40** (all NOT RUN).

**Cite all three commits; no earlier one alone is the accepted contract.** No
lifecycle, inventory or money rule was guessed at any point.

**FND-003B1 — DONE (2026-09-10).** Pre-dispatch order and reservation
lifecycle: six executable order states, four reservation states, seven named
commands, a deterministic transition evaluator, typed inventory effects and a
financial classification that makes "undecided" impossible to read as zero.
Contract **0.2 → 0.3** (additive). Cancellation from `preparing`/`ready` is
recorded as **DECISION REQUIRED** rather than guessed — it needs O6 and
FND-003C.

Review of `697d170` found one hole, fixed by **FND-003B1-FIX-001**: the
transition graph never *creates* an impossible order/reservation pair, but the
evaluator did not validate the facts it was **given**. Malformed trusted
aggregates — `placed + committed`, `accepted + active`, or a reservation with
zero or negative units — could reach inventory-producing paths; a negative
count produced a stock-*destroying* mutation. An aggregate-integrity boundary
now runs before any effect, and release paths are pair-specific. **Cite both
commits.**

**FND-003B2B — DONE (2026-09-10).** Picker-originated rider assignment: the
order's **current accepted picker** offers delivery work to one rider, with
accept, decline, worker-driven expiry and controlled revoke. Contract
**0.4 → 0.5** (additive).

The distinctive risk in this slice is **cross-aggregate**, and it is the first
time a lifecycle has had one. A rider attempt is meaningless except relative to
the picker assignment that created it, so each attempt stores an immutable
`SourcePickerBinding` (picker principal + picker assignment id + picker
generation). Acceptance re-checks that the binding is still the order's current
accepted picker assignment, which closes this hole:

```text
picker A offers rider R -> A is revoked -> picker B becomes accepted
                        -> R's stale offer accepted as though B created it
```

That is denied `sourcePickerAssignmentMismatch`. Revoke deliberately does
**not** require the *original* picker — only the current one — so a
replacement picker can resolve a rider slot that would otherwise be
permanently orphaned; the binding is still never rewritten.

Shared, not copied: `AssignmentState`, `AssignmentRole`,
`ScopeProjectionEffect`, `CustodyClassification`, `ReassignmentSafety`,
`assignmentEligibleOrderStates`, and the role-neutral `AssignmentDenial` and
`reachableSlotRevisionRange`, which moved into `assignment_integrity.dart`
unchanged. A negative control proved the sharing is real: breaking the helper
fails the picker **and** rider closure suites.

`agent.assignment.offer_rider` was **not** used, deleted or renamed. It stays
reserved for a future direct shop-to-rider pickup — a different custody source
— and a test asserts no command maps to it.
[ADR-0007](../decisions/ADR-0007-admin-rider-assignment-override.md) records
that admin rider intervention must be a separate audited override;
`admin.assignment.override_rider` is RESERVED and absent from
`Permission.values`, `permissionMatrix` and `AssignmentCommand`.

New backend criteria **RA1–RA18** and contract criterion **B3-C2** — all
**NOT RUN**. **FND-003B2 is now DONE**; FND-003B stays **PARTIAL** because
custody, delivery and returns (FND-003B3) are outstanding.

**FND-003B2B-FIX-001 — DONE (2026-09-10).** Final review of `9d1e262` found one
identity-integrity defect, reproduced before any change was made: rider target
eligibility qualified on presence and equality but never on the repository's
canonical opaque-id rule, so an empty or sequential principal id could qualify,
produce a **successful** offer transition with `offerRecipientPrincipalId = ''`,
and yield an aggregate the validator refuses — breaking transition closure for
malformed trusted facts.

`PickerEligibility` carried the identical weakness and was corrected at the same
boundary rather than leaving the two assignment roles with different identity
guarantees. The aggregate validators now apply the canonical rule to stored
recipients, the rider source-picker principal and `resourceId` — the same rule
`Principal`, `CommandEnvelope` and `EventEnvelope` already enforce, reused, not
reinvented.

Contract stays **0.5**: a correctness tightening of an existing invariant on an
unmerged, unreleased slice. No state, transition, revision formula, command
mapping, permission or ADR changed.

**FND-003B3A — DONE (2026-09-10).** Physical custody made explicit from shop to
rider. Contract **0.5 → 0.6** (additive).

Custody is its own aggregate with its own revision, and **absence is never read
as "the shop still has it"** — that shortcut is how goods go untracked between
the counter and a rider's bag. A worker custodian is bound to an assignment
*attempt* (principal + assignment id + generation), not to a projection of who
is assigned now, for the same reason `SourcePickerBinding` is.

Two transitions only. `shop → picker` pickup is physical acquisition and
**leaves the order `ready`** — collection is not dispatch. `picker → rider`
receipt is the **dispatch boundary**: one command atomically moves custody,
takes the order `ready → in_delivery`, completes the picker assignment and
removes its `assignedResource`, while the rider assignment stays accepted.

Picker completion is a **consequence, never a command** — there is no
`completePickerAssignment`, because a target state a client can select is
exactly the arbitrary status patch this contract forbids. **B3-C1 is satisfied
by contract tests**, proven from real evaluator output across generations 1–3.
**B3-C2 stays FUTURE**: rider `completed` remains unreachable and no cost for
it was invented.

`reachableSlotRevisionRange` gained an **optional** `role` that defaults to the
pre-0.6 answer, so no existing caller changed behaviour.
`reassignmentSafetyFor` finally derives `ReassignmentSafety` from real custody
without weakening it — unknown and corrupt custody stay unsafe.

Deferred deliberately: `picker.custody.record_handoff` keeps its id but stays
**non-executable**, because making it transfer custody would need a proof
protocol and **no QR, OTP, signature or photo was invented**. Direct
agent→rider pickup remains deferred and RA18 is unreinterpreted. Shop ids were
**not** opaque-validated — nothing in the repository governs them that way, and
existing fixtures use `shop_alpha`, which the rule would reject.

New backend criteria **CA1–CA23**, all **NOT RUN** (CA19–CA23 added by
FND-003B3A-FIX-001).

**FND-003B3A-FIX-001 — DONE (2026-09-10).** Final review of `c29df0f` found five
real gaps and one evidence error, all closed here without redesigning the
accepted custody model. The evaluator compared the three aggregates against each
other but nothing bound them to a **canonical** order, and shop custody was never
bound to the order's shop; the picker and rider **slot revisions** were not
compare-and-set; initialisation was create-once only by documentation; receipt
provenance was under-specified; and exported metadata still called `in_delivery`
and picker `completed` unimplemented after both became reachable. The B3A
report's *"was 522 at branch point"* is corrected to the accepted **520** — 522
was a real mid-task number taken after two tests had already been added, never
the branch point, and no rerun was invented to explain it.

**FND-003D1 — DONE (2026-09-10).** The smallest dependency-safe prerequisite for
delivery confirmation: a way to *refer to* proof policy and protected evidence
without embedding proof material in events, treating a reference as proof, or
committing the platform to a method. Contract **0.6 → 0.7** (additive).

`DeliveryProofPolicyRef` says **which** immutable policy applies, never that it
was satisfied, and imposes **no grammar** — the repository has no policy
vocabulary to reuse, and inventing one would be inventing a contract.
`DeliveryEvidenceRef` carries an opaque evidence id **bound to its order**, so
evidence cannot be presented against a different one; it holds **no material**
and is not a storage locator. Both preserve exact values and repair nothing.

**Nothing became executable.** No command, state, transition, event or
permission was added; `OrderState.delivered`, `CustodyHolderKind.customer` and
rider `AssignmentState.completed` all remain unreachable, re-pinned by
regression test. A source-level test strips doc comments and asserts no proof
mechanism — OTP, QR, barcode, signature, photo, video, GPS, biometric,
attestation — and no material, locator or status vocabulary appears in the code.

**Dependency note.** FND-003D was previously recorded as depending on the whole
of FND-003B, which was a coarser dependency than the work requires: this
reference boundary needs only the accepted FND-003B3A custody contract, so the
slice was safely taken now rather than waiting on delivery/refusal/return.
**FND-003D is now PARTIAL, not complete** — proof satisfaction and the fallback
dispute workflow are still undone and remain required by `CONSTRAINTS.md`
invariant 13 before delivery confirmation may be coded.

Retention, visibility, deletion/legal-hold, satisfaction policy, the dispute
workflow and whether customer participation is required are all recorded
**DEFERRED, never defaulted**. Financial consequences remain **UNKNOWN /
DEFERRED TO FND-003C**, blocked on **O6**.

**FND-003D1 — ACCEPTED AND INTEGRATED (2026-09-10).** FND-003D1-MERGE-001
fast-forwarded `main` from `e8dacfc` to **`f03fc99`**, preserving the reviewed
three-commit linear history — no merge, squash, rebase or amend commit exists,
and the feature branch was preserved. Live GitHub inspection at merge time found
`main` **unprotected with no rulesets**, which is why a direct fast-forward was
permitted; that is not a substitute for **O7**, which stays outstanding.

**FND-003D2A — DONE (2026-09-10).** The missing half of the proof prerequisite:
somewhere to record **whether** the referenced policy was satisfied. Contract
**0.7 → 0.8** (additive).

An assessment is a **trusted-server-produced, immutable result**, not a claim.
`executableProofAssessorKinds` is exactly `{PrincipalKind.systemWorker}`, and
**no command and no permission was added** — `Permission.values` stays at 38.
There is no `customer.proof.accept`, no `rider.proof.mark_satisfied`, no
`admin.proof.override` and no generic proof-status setter, because a
client-selectable "declare proof satisfied" operation would be exactly the
arbitrary status patch this contract forbids, aimed at the one status that gates
delivery, custody handover and eventually money. The precedent is
`initialiseCustodyAtShop`, which has no command either.

**A pure Dart record cannot authenticate its own origin**, and a test proves a
forged `satisfied` record is structurally well formed — because it is. The
backend must ignore client-supplied assessments; only one loaded from trusted
state may later authorize progression. That honesty is criteria **DPA1**/**DPA2**,
NOT RUN.

Two verdicts, `satisfied` and `notSatisfied`, and **no `pending`**: absence
already means *not assessed*, and a verifier's job queue is backend operational
state rather than domain truth. `notSatisfied` means only that the policy was
not satisfied — **not** fraud, refusal, cancellation, delivery failure, a lost
dispute, a fee, a refund or financial default.

Reassessment is **append-only**: a new opaque `assessmentId`, revision `r → r+1`,
and a `supersedesAssessmentId` backward pointer. Nothing is mutated, relabelled
or erased — there is no `setAssessmentStatus`, `overrideVerdict` or `copyWith` —
because FND-003D2B has to be able to point at "the assessment that was current
when X happened" and have that mean something.

The assessment has its **own** `assessmentRevision`, and the request pins four
revisions (assessment, order, custody, rider slot) because the decision depends
on all four. **Correct revisions never bypass identity, state, reference or
binding checks** — a test supplies every correct revision alongside the wrong
rider and still gets a denial.

**Every commercial effect is NONE, structurally**: the transition type has no
order, custody or assignment effect field, so one that moves them cannot be
constructed. `OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable, and **no rider completion
cost was invented** — **B3-C2** stays FUTURE. The financial classification
describes the *recording*; whether a `notSatisfied` outcome ever costs anyone
anything is **UNKNOWN and deferred to FND-003C**, blocked on **O6**, never zero.

**No proof mechanism was selected** — no OTP, QR, barcode, signature,
photograph, video, GPS, biometric or attestation — and **no evidence cardinality
was invented**: the record carries the single D1 `DeliveryEvidenceRef`. Customer
participation stays **POLICY-DEFINED / DEFERRED**, with no `customerConfirmed`
flag that would default the answer, and `customer.delivery.confirm_proof` keeps
its exact participation-only meaning.

New backend criteria **DPA1–DPA16**, all **NOT RUN**. **FND-003D stays PARTIAL**
— the satisfaction *policy* and the dispute workflow (**FND-003D2B**) are
undone, so `CONSTRAINTS.md` invariant 13 is **not** discharged and delivery
confirmation still may not be coded.

**FND-003D2A-FIX-001 — DONE (2026-09-10).** FND-003D2A-FINAL-REVIEW-001 found
five real defects in the unreleased 0.8 candidate plus one process-evidence
failure. All are corrected in one follow-up commit; **the contract stays at
0.8**, because this is an in-place correction to an unmerged, unreleased
candidate, not a release event.

The security defect was the important one. **`PrincipalKind.systemWorker` is a
broad infrastructure class** — the outbox drain, reservation expiry and
scheduled reconciliation all hold it — and the evaluator accepted *any*
structurally valid system worker. That made the verdict which later gates
delivery mintable by an unrelated job. The evaluator now takes the assessor as a
**separate server-derived `Principal`** and requires it to equal the resource's
`authorizedAssessorPrincipalId`, resolved from trusted state, with a distinct
`assessorAuthorityMismatch` denial. The request's assessor fields were
**removed** rather than kept for compatibility: a payload that names its own
authorizer is not a check.

Three public accessors failed **open** and now fail closed: `bindsRiderAttempt`
matched identically-malformed values; `currentVerdict` read straight off raw
facts so a **torn aggregate could expose `satisfied`** (replaced by
`canonicalVerdict`, which requires the validator to accept the facts, and which
never downgrades corruption to `notSatisfied`); and `toString` echoed raw fields
of malformed values before validation. `events` was a caller-supplied list and
is now a fixed `const` single-element getter. Each fix carries a **negative
control** — reverting it makes a specific named test fail.

The 980-line module and 1455-line test file were split by responsibility behind
a **stable barrel**, so the public `cp_contracts` surface is unchanged. New
criteria **DPA17** (backend must authorize an explicit proof-verifier service
identity; generic worker status insufficient) and **DPA18** (a verdict-changing
reassessment retains an immutable audit basis) are both **NOT RUN**.

**Process exception, recorded and not repeated.** Before this branch was first
published, a local-only commit `a9f3db98` was amended into `6bb23710` to remove
a `<D2A>` ledger placeholder. FND-003D2A acceptance criterion 48 (no amend) is
therefore **FAIL** and must never be cited as PASS. No shared history, reviewer
history or CI result was rewritten — `a9f3db98` was never pushed. It is accepted
as a **one-time, pre-publication** exception and grants no licence to amend
anything else; FIX-001 itself used one new normal commit.

**FND-003D2B — DONE (2026-09-11).** The other half of `CONSTRAINTS.md`
invariant 13: what happens when the assessment a delivery would need is
**missing, superseded or `notSatisfied`**. Contract **0.8 → 0.9** (additive).

A dispute is raised by the order's customer against the **current canonical**
proof situation, and pins an **immutable basis** — an assessment id and revision,
or canonical absence — that is never rewritten afterwards. That is exactly what
ADR-0009 made append-only history for: `resolveDeliveryProofDisputeBasis
Standing` can then report `current`, `superseded` or `indeterminate` **without
touching anything**, so a reassessment makes supersession *observable* rather
than making the disputed verdict unfindable. A later `satisfied` assessment does
**not** dismiss the dispute — deciding that would be deciding the outcome.

**The five proof situations stay distinct**, and that is the slice's central
negative: canonical absence, current `notSatisfied`, a superseded basis, a
**torn** aggregate and current `satisfied` each have their own answer.
Corruption denies `assessmentAggregateInconsistent` and is **never** laundered
into `notSatisfied` or into a valid dispute basis; a `satisfied` assessment
denies `assessmentSatisfied`, because contesting a satisfied verdict is a
different workflow no slice defines — refusing it is what keeps this from
becoming general support-case infrastructure.

**Nothing resolves.** `DeliveryProofDisputeCommand.resolve` is enumerated and
always refused `resolutionPolicyDeferred` **before any fact is read**, and
`DeliveryProofDisputeState.resolved` is unreachable with **no revision cost
invented** — the same discipline as rider `completed` and **B3-C2**. Resolution
would mean deciding who prevails, whether the order is delivered, refused or
returned, whether a fee, refund, compensation or liability follows and who bears
it, whether stock is restored, and whether customer participation is optional,
mandatory, sufficient or a veto. **None of those is decided anywhere**, so none
was guessed. Withdrawal, closure, expiry, escalation and SLAs are equally absent.

**No permission was added** — `Permission.values` stays **38**. Both executable
operations map to the accepted `customer.dispute.raise` (`ownResource`, reason
required) and `admin.dispute.administer` (`ownRegion`, reason required) rules,
unchanged, and `customer.delivery.confirm_proof` is **not** reinterpreted. The
dispute record holds **no free text**: the required reason stays with the
audited command in FND-003A, because a second copy is a second place to drift
and a customer-supplied string on a wire-facing value is the one route by which
a description of proof material could reach an event payload.

Custody and the rider assignment are deliberately **not** in the read-set. A
dispute asserts nothing about a rider, and requiring current custody would make
the fallback unavailable exactly when custody has gone wrong — the opposite of a
fallback. Possession is not an authorization source in either direction.

Every order, reservation, inventory, financial, custody, assignment **and
assessment** effect is **NONE**, structurally: the transition type has no field
for any of them. `OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain unreachable. New backend criteria
**DPD1–DPD12**, all **NOT RUN**.

**FND-003D stays PARTIAL**: the proof-satisfaction **policy itself** is still
undone, so invariant 13 is **not** discharged and delivery confirmation still
may not be coded.

**FND-003D2B-FIX-001 — DONE (2026-09-11).** FND-003D2B-FINAL-REVIEW-001 found
three material defects in the unreleased 0.9 candidate. All are corrected in one
follow-up commit; **the contract stays at 0.9**, because this is an in-place
correction to an unmerged, unaccepted candidate rather than a release event.

**Two of the three were the contract asserting more than it had been told.**

The first was a fail-open. `resolveDeliveryProofDisputeBasisStanding` compared
only the assessment **id and revision**, so a basis recorded as `notSatisfied`
against assessment A revision 1 was reported as **`current`** even when the
canonical A/1 now read `satisfied`. ADR-0009 gives every reassessment a new id
and the next revision, so that pairing is a contradiction the history cannot
produce — and certifying it as current is exactly the wrong direction to fail on
the value a dispute is anchored to. The same-revision comparison now also
requires the canonical verdict to still be `notSatisfied`; a mismatch is
`indeterminate`, is **not** converted to `superseded` (nothing superseded it) or
to `notSatisfied` (nobody reached that verdict), and the basis is not rewritten.

The second was an **invented rule**. The candidate denied `reviewerIsRaiser`
when the reviewing principal had earlier raised the dispute, and the D2B report
flagged it as a "deliberate tightening" with the dual-control precedent. That
reasoning does not survive contact with the accepted matrix:
`admin.dispute.administer` requires an active admin membership, `ownRegion`
scope and a stored reason, and carries **`approvalRequired: false`**. Nothing
asks for separation of duties, so refusing on identity alone was a policy
decided nowhere — precisely what this repository forbids. It is removed from the
evaluator, the record validator, the denial vocabulary (**20 → 19**), the tests
and the documentation, and recorded as **DEFERRED**: if separation of duties is
ever wanted it needs its own permission and ADR.

The third was **hidden coupling**. A single evaluator took every aggregate for
every operation, and a shared read-set silently becomes a shared *precondition*:
recording that review started required a canonical current assessment, a
canonical current order, the order revision, `in_delivery` and `committed` —
**none of which it reads or changes**. A reassessment or a torn assessment read
after a validly raised dispute could therefore freeze it out of review, which is
the opposite of what a fallback is for. There is now **one evaluator per
operation, each taking only its own read-set**: raise (resource, dispute,
assessment, order), review (resource, dispute) and resolve (**no arguments at
all** — a deferred edge consumes nothing). The independence is enforced by the
type system: a call that hands review an assessment or an order does not
compile. **Nothing about delivery, refusal or return may be inferred from it.**

The test helper `basisFrom` was also removed: it mirrored production eligibility
logic and would manufacture a `notSatisfied` basis from a **satisfied**
assessment — a state the evaluator can never produce, and the very contradiction
the standing calculation now rejects. Canonical positive bases come from a real
evaluator-produced raise.

Each correction carries a negative control, and all evidence classifications are
unchanged: **DPD1–DPD12 remain NOT RUN**, `Permission.values` stays **38**,
resolution stays non-executable, every effect stays NONE, and `delivered`,
customer custody and rider `completed` stay unreachable. **The corrected
two-commit candidate is not accepted for merge** — it requires a new, separate
read-only final acceptance review.

**FND-003D2B-FIX-002 — DONE (2026-09-11).** FND-003D2B-FINAL-REVIEW-002 found
two further defects in the same unreleased 0.9 candidate. Both are corrected in
one follow-up commit; **the contract stays at 0.9**.

**The second one is the serious one, and it was a real bypass.** The executable
evaluators took a server-derived `Principal` and *documented* that
`evaluateAuthorization` had already run — but a pure function cannot assert
anything about its caller. Nothing in either signature distinguished an
authorized call from one that skipped the check, so a customer who owned nothing
could reach a raise transition, and a customer-only principal could reach a
review transition. A FIX-001 test had even *asserted* that bypass as intended
behaviour ("authorization already ran, and re-running it here would create a
second place for it to drift") — the reasoning was right about policy and wrong
about proof.

FND-003A had already built the artifact that closes this, for exactly this
purpose: `AuthorizationGrant` is `final`, has a library-private constructor and
is obtainable **only** from a successful `evaluateAuthorization`. Both operations
now require one, and `checkDisputeAuthorization` verifies it is bound to **this
principal, this permission and this resource** — the same three bindings
`ApprovalEvidence` needs. **No policy is re-decided**: role, membership status,
scope and reason stay in `permissionMatrix`, which is neither copied nor
changed, and an out-of-region admin or one with no reason simply never obtains a
grant to present. One generic `authorizationGrantMismatch` denial (19 → **20**)
keeps refusals unprobeable. **Raising confers no admin authority** — the
historical raiser reaches review only by independently holding an admin grant,
and no separation-of-duties rule returned. Freshness remains **R33–R40**, NOT
RUN: a grant proves the decision was made, not that it is still current.

`DeliveryProofDisputeContext` was **removed** rather than kept alongside it: the
grant already names the canonical resource, and two sources of resource truth
could disagree.

The first defect was the standing calculation again, in the other direction.
FIX-001 stopped a same-revision **verdict** contradiction; this stops a
**higher-revision identity** one. Any revision above the basis was reported
`superseded`, including a revision-2 record that reused the exact assessment id
the basis pinned. ADR-0009 gives every reassessment a new opaque id, so that is
impossible history — and the aggregate is **structurally canonical**, which is
why no shape check caught it. It now answers `indeterminate`, using the current
record only: no in-memory history array and no global uniqueness lookup, because
uniqueness across superseded records is **DPA11**, NOT RUN.

Both corrections carry negative controls (**NC4**, **NC5**), and the earlier
NC1–NC3 protections were re-verified after the restructure. All evidence
classifications are unchanged: **DPD1–DPD12 remain NOT RUN**,
`Permission.values` stays **38**, resolution stays non-executable and
zero-argument, every effect stays NONE, and `delivered`, customer custody and
rider `completed` stay unreachable. **The corrected three-commit candidate is
not accepted for merge.**

**FND-003D2B-FIX-003 — DONE (2026-09-11).** One material defect, plus the
documentation drift FIX-002 left behind. **Contract stays 0.9.**

**The accepted `OrderLifecycleFacts` carries no resource id.** That is correct
for the pre-dispatch evaluator, which is handed one order and asked about that
order — but a dispute raise must prove that *four* independently supplied things
describe the **same** delivery, and the order read was the one that could not
say which order it was for. An order-B read whose scalars matched order A —
`in_delivery`, revision 5, reservation `committed` — was indistinguishable from
A's own facts, so a dispute could be recorded against A on the strength of B's
lifecycle. **Numeric equality is not identity**, and this is the third time this
slice has had to learn that identity must be checked in every direction.

A small D2B-scoped `DeliveryProofDisputeOrderRead` binds the facts to the order
they were read for. It is a **read, not a second order aggregate**: no state, no
transition, no revision arithmetic, no lifecycle rule, and **the accepted
`OrderLifecycleFacts` contract is untouched** — changing it would have been a
far larger, ADR-bearing decision than this correction needs.

The same commit removes a **tautology**: `checkDisputeAuthorization` compared
the grant's resource against a value the grant itself supplied, while being
documented as proving the resource binding. The helper now takes an
`expectedResourceId` from the read-set, and the canonical anchor is the **stored
dispute aggregate's** resource, which the grant must cover.

Review is untouched and still reads only the grant and the dispute; resolve is
untouched and still takes zero arguments. **Binding is not provenance** — that
the backend loads every aggregate for one resource in one consistent transaction
is **DPD3**/**DPD4**, both **NOT RUN**. `Permission.values` stays **38**, every
effect stays NONE, and `delivered`, customer custody and rider `completed` stay
unreachable. **NC6** proves the new binding can fail; **NC1–NC5** were
re-verified. **The corrected four-commit candidate is not accepted for merge.**

**FND-003D2B-FIX-004 — DONE (2026-09-11). Documentation and source-comment
only; zero executable Dart changed.** FND-003D2B-FIX-003-PUSH-001 refused to
publish `202a8a9`, and it was right to: the push task gated publication on a
documentation check, and that check failed. Two current-tense statements still
said the **authorization grant** supplies the canonical resource — wording
FIX-002 had been correct to write and FIX-003 had already superseded, because
comparing a grant against a value the grant itself supplied proves nothing.

The shipped code says `final String resourceId = dispute.resourceId;` in both
evaluators: **the persisted dispute aggregate anchors the canonical operation
resource, and the grant must cover it.** For a raise the assessment aggregate
and the resource-bound order read must identify that same anchor before any
order fact can produce a transition. The two statements — in
`docs/contracts/delivery-proof-dispute.md` and the
`delivery_proof_dispute_facts.dart` doc comment — now say that, and the
superseded framing is retained only where explicitly labelled **Historical**.

**No behaviour changed.** A comment-stripped diff of the one modified Dart file
is byte-identical, and `ContractVersion.current` stays **0.9**. Every accepted
invariant is untouched: `Permission.values` **38**, review still grant +
dispute, resolve still zero-argument, all effects NONE, two events, and
`delivered`, customer custody and rider `completed` unreachable. All
DPD/DPA/CA/R/L/P/RA criteria remain **NOT RUN**. **The five-commit candidate is
still not accepted for merge.**

**FND-003D2B-FIX-005 — DONE (2026-09-11). Documentation, source-comment and
evidence only; zero executable Dart changed.** FND-003D2B-FINAL-REVIEW-004 found
one surviving current-tense doc comment in
`delivery_proof_dispute_evaluator.dart` — *"The canonical resource comes from
the grant."* — under the review evaluator's own **"What it does check"** heading,
directly above an implementation that reads `final String resourceId =
dispute.resourceId;`.

**The interesting part is why FIX-004's sweep missed it.** Not a file it forgot:
FIX-004 listed that very file. Its sweep was a **line-based `grep`**, and the
sentence **wraps across two lines**. Its own regex matches the sentence when
unwrapped and cannot match it across a newline — demonstrated mechanically, 0
matches line-based versus 1 unwrapped. A prose sweep that cannot see past a line
break will keep missing wrapped prose, which is most prose. FIX-005 therefore
re-ran the sweep with comment markers stripped and whitespace collapsed, and
against **semantic ideas** — *comes from / supplies / provides / chooses /
anchors / selects / determines the resource*, *resource identity from the
grant*, *grant is the source of resource truth* — rather than two literal
strings.

That broader sweep found **six** remaining matches across the sixteen current
D2B locations, **all** in explicitly historical or descriptive material: two
under `**Historical.**` markers, three inside dated FIX-002/FIX-003/FIX-004
changelog blocks in `version-history.md`, and none in a current API description.
The evaluator now states that the **stored dispute aggregate anchors** the
canonical resource and the grant must **cover** it.

The FIX-004 report's sweep claim is **annotated, not rewritten**: its assertion
was true of the two literal strings it searched and incomplete as a general
claim, and that is recorded in place.

**No behaviour changed.** The comment-stripped source of the one modified Dart
file has an **identical SHA-256** before and after, and `ContractVersion.current`
stays **0.9**. Every accepted invariant holds: `Permission.values` **38**, the
four-way raise binding, review as grant + dispute only, resolve zero-argument,
all effects NONE, two events, and `delivered`, customer custody and rider
`completed` unreachable. All DPD/DPA/CA/R/L/P/RA criteria remain **NOT RUN**.
**The six-commit candidate is still not accepted for merge.**

**FND-003D2B-FIX-006 — DONE (2026-09-11). Documentation and source-comment
only; zero executable Dart changed.** FND-003D2B-FINAL-REVIEW-005 found that the
canonical review integrity table in `delivery-proof-dispute.md` documented a
step the implementation does not have: *"it names the canonical order →
`resourceBindingMismatch`"*. **That denial is unreachable from
`evaluateRecordDeliveryProofDisputeReview`** — the function's only resource
logic is `resourceId = dispute.resourceId` followed by the grant covering it.

**The row was removed, not implemented.** Adding a runtime check to satisfy
stale prose would have added a comparison of `dispute.resourceId` against
itself — the same tautology FIX-003 removed from `checkDisputeAuthorization`.
Raise needs that binding because it has other independently supplied read-set
members (assessment, order read); review has none. Documentation was corrected
to match the code, never the reverse.

Two further stale statements were corrected at the same time: a test comment
saying the canonical resource *"arrives on the authorization grant"*, and
`resourceBindingMismatch`'s own doc, which still spoke of a "canonical resource
context" — naming the type FIX-002 deleted — and did not say the denial is
raise-only. Both now describe the actual reachable semantics.

The review table was then reconciled **mechanically** against source: all ten
documented denials map to a real reachable path (six direct returns, one via
`checkDisputeAuthorization`, two via `_checkActorAndTime`, one via
`validateDeliveryProofDisputeAggregate`), and the two sets match exactly with
`resourceBindingMismatch` in neither. The semantic sweep was extended to **D2B
test and support comments**, which earlier sweeps had not covered — seven
remaining matches, all explicitly historical or descriptive.

**No behaviour changed.** Both modified Dart files are byte-identical after
comment stripping, and `ContractVersion.current` stays **0.9**. Every accepted
invariant holds. **The seven-commit candidate is still not accepted for merge.**

**FND-003D2B — ACCEPTED AND INTEGRATED (2026-09-11).** FND-003D2B-MERGE-001
fast-forwarded `main` from `03c71d00` to **`743e157`**, preserving the reviewed
**seven-commit** linear history exactly:

```text
03c71d00
  -> b94e5424  FND-003D2B: add the fallback delivery-proof dispute contract
  -> ded1aa79  fix: correct FND-003D2B dispute boundaries          (FIX-001)
  -> f04d453   fix: close FND-003D2B final review gaps             (FIX-002)
  -> 202a8a9   fix: bind D2B raise order read to resource          (FIX-003)
  -> 45d21e9   docs: correct D2B resource anchor wording           (FIX-004)
  -> cc0c1ae   docs: finish D2B resource anchor reconciliation     (FIX-005)
  -> 743e157   docs: finish D2B review binding reconciliation      (FIX-006)
```

**No prefix of that chain is accepted alone.** The first commit shipped an
authorization bypass and a fail-open basis standing; the accepted contract is
the whole chain.

**The accepted contract chain ends at `743e157`, and nothing after it is part
of it.** `main` has since advanced to the documentation-only bookkeeping commit
**`c99a0e5`** (published 2026-09-11 by FND-003D2B-MERGE-BOOKKEEPING-PUSH-001),
whose sole parent is `743e157` and which changes only files under
`docs/task-ledger/`. Read "`main` is at the accepted tip **plus documentation**",
never "`main` equals the accepted tip". The feature branch is preserved at
`743e157` as the immutable record of exactly what was accepted. **No merge, squash, rebase, amend or cherry-pick commit
exists**, no accepted SHA changed, and the feature branch was preserved at the
same tip rather than deleted.

**Nothing was re-implemented at merge.** `ContractVersion.current` stays **0.9**,
the stored dispute aggregate remains the resource anchor, the `AuthorizationGrant`
only proves coverage of it, the four-way raise binding and the narrow review
read-set are unchanged, `resolve` is still zero-argument and always
`resolutionPolicyDeferred`, there are **20** dispute denials, `Permission.values`
and `permissionMatrix` stay **38**, exactly two dispute events exist, and every
commercial/order/custody/assignment/assessment/scope effect remains **NONE**.
There is **no serialization and no migration**. **Successful delivery, customer
custody, rider completion, dispute resolution, fee, refund, liability, return and
stock restoration all remain non-executable.**

**What integration does *not* mean.** `CONSTRAINTS.md` invariant 13 is still
**not** discharged: the **proof-satisfaction policy itself** is undone, so
delivery confirmation still may not be coded. **How a dispute resolves** stays
undecided and blocked on **O6**, FND-003C and FND-003B3B. All **DPD1–DPD12**,
**DPA1–DPA18**, **CA1–CA23**, **R33–R40**, **L1–L13**, **P1–P17** and
**RA1–RA18** criteria remain **NOT RUN**; **B3-C1** remains contract-test
evidence only and **B3-C2** remains **FUTURE**. **FND-003D2A acceptance
criterion 48 remains FAIL** under its recorded one-time pre-publication
exception, which was not used as precedent here — this merge performed no amend.

**GitHub CI: NONE.** No `.github` directory exists in the integrated tree, so no
workflow is defined and none ran; the local gate is **not** CI. Branch-protection
and ruleset state were **NOT INSPECTED** this time — `gh` is not installed on this
machine — so the FND-003D1 observation that `main` was unprotected is **not**
re-asserted here. The fast-forward push was accepted by the remote, which is the
only claim the evidence supports. **O7 remains outstanding.**

> **Superseded on 2026-09-11 (not rewritten).** The governance inspection that
> could not be run here was completed during
> FND-003D2B-MERGE-BOOKKEEPING-PUSH-001 via the authenticated GitHub REST API:
> `main` is **unprotected**, **0** rulesets, **0** effective branch rules, **0**
> workflows and **0** runs. See the **O7** row. **O7 stays outstanding.**

Report: [FND-003D2B-MERGE-001](FND-003D2B-MERGE-001-completion-report.md).

**Remaining slices:**

| Slice | Owns | Status |
|---|---|---|
| FND-003B lifecycle | Order, assignment, custody, attempt, return transitions; inventory effects per edge | **PARTIAL** — B1, **all of B2**, **B3A** and **B3B** (attempt + refused-order return) done, **all accepted and integrated**; **successful delivery is still outstanding** — it needs the proof-satisfaction policy — and so are customer custody, rider `completed` (**B3-C2**), the failed-attempt retry/return consequence, the via-picker return route and the post-dispatch cancellation consequence |
| FND-003C money | Payment/COD, cash journal, fees, refusal policy, commissions, settlement | **PARTIAL** — **O6 resolved** by ADR-0011; FND-003C1 delivers the COD collection and cash-journal foundation and is **ACCEPTED AND INTEGRATED**; remittance, settlement, reconciliation, refusal-fee collection, refunds, compensation, commission payout and worker pay remain **unimplemented** |
| FND-003D proof/dispute | Proof-satisfaction policy and fallback dispute workflow | **PARTIAL** — the reference/privacy boundary (FND-003D1), the trusted assessment **result** (FND-003D2A) and the **fallback dispute workflow** (FND-003D2B) are done; the **proof-satisfaction policy itself** is **not**, and is still needed before delivery confirmation is coded |
| Dispute resolution | How a fallback dispute resolves, and any delivery/refusal/return/money consequence | **NOT STARTED / DEFERRED** — enumerated and refused by FND-003D2B; needs the remaining **FND-003C** money work and a dedicated resolution slice (**O6 itself is resolved** by ADR-0011). FND-003B3B is accepted and integrated and defines the refused-order return, but decides **no** dispute outcome, fault or money |

FND-003A depended on FND-001 only. It did **not** require FND-002 runtime
evidence, notification decisions D1–D3, devices, a Windows runner, Firebase
credentials or the emulator — and none were used.

## End-to-end proof

| ID | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| E2E-001 | ADMIN coordinates all | One seeded shop/SKU: checkout → assignment → handoff → COD → settlement, plus the refusal/return branch | FND-003, FND-004 | **TODO** |

## Role features

Each ROLE-* task is owned by its own ChatGPT Project and is gated on tested
shared contracts. None may begin before FND-003 lands.

| ID | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| ROLE-ADMIN-* | ADMIN | Admin role features | FND-003, FND-004 | **TODO** |
| ROLE-USER-* | USER | Customer role features | FND-003, FND-004 | **TODO** |
| ROLE-AGENT-* | AGENT | Shop agent role features | FND-003, FND-004 | **TODO** |
| ROLE-PICKER-* | PICKER | Picker role features | FND-003, FND-004 | **TODO** |
| ROLE-RIDER-* | RIDER | Rider role features | FND-003, FND-004 | **TODO** |

## Hardening and release

| ID | Owner | Deliverable | Depends on | Status |
|---|---|---|---|---|
| HARD-* | ADMIN coordinates | Concurrency, auth/revocation, offline/restart, notifications, adaptive UI, profiling | E2E-001 | **TODO** |
| REL-* | ADMIN coordinates | Capacity/cost evidence, recovery drills, signing/distribution, runbooks, launch gates | HARD-* | **TODO** |

## Contract version

| Contract | Version | Owner task | Notes |
|---|---|---|---|
| Wire contract (`cp_contracts`) | **0.11** | FND-003 | *(This cell read **0.9** until FND-003C1 corrected it. It was not updated when FND-003B3B shipped 0.10, so the ledger summary and the executable `ContractVersion.current` disagreed for the life of that slice — recorded here rather than quietly fixed, because a summary that silently drifts is exactly what this table exists to prevent.)* Baseline **SHARED-BASELINE-v1.0**. 0.2 (FND-003A) added command/event envelopes, identity, membership, scope, 35 permissions and the authorization model. 0.3 (FND-003B1) adds the pre-dispatch order and reservation lifecycle with typed inventory effects. 0.4 (FND-003B2A) adds the picker assignment lifecycle and the `agent.assignment.revoke_picker` permission. 0.5 (FND-003B2B) adds the picker-originated rider assignment lifecycle, the source-picker binding, the `picker.assignment.offer_rider` and `picker.assignment.revoke_rider` permissions, and moves the role-neutral `AssignmentDenial` and `reachableSlotRevisionRange` into a shared `assignment_integrity.dart` with no name, value or behaviour change. All additive, so minor only. 0.6 (FND-003B3A) adds physical custody — the shop/picker/rider/customer vocabulary, `shop→picker` pickup, `picker→rider` receipt as the dispatch boundary, picker assignment completion, a role-aware `reachableSlotRevisionRange` and custody-derived reassignment safety. All additive, so minor only. 0.7 (FND-003D1) adds mechanism-neutral delivery-proof **references** — `DeliveryProofPolicyRef`, `DeliveryEvidenceRef`, their structural validators and `DeliveryProofDenial`. 0.8 (FND-003D2A) adds the delivery-proof **assessment result** — `DeliveryProofAssessmentVerdict` (`satisfied` / `notSatisfied` only), the immutable `DeliveryProofAssessmentRecord`, its aggregate, context, request, transition, outcome and denial vocabulary, `validateDeliveryProofAssessmentAggregate`, `evaluateDeliveryProofAssessment`, `executableProofAssessorKinds` and one event id. All additive, so minor only. 0.9 (FND-003D2B) adds the **fallback delivery-proof dispute** — `DeliveryProofDisputeState` and `reachableDisputeRevisionFor`, the immutable `DeliveryProofDisputeBasis` with its `current`/`superseded`/`indeterminate` standing, three named commands of which `resolve` is **never executable**, two event ids, the record, aggregate, transition, outcome and denial vocabulary (**20** denials), and `validateDeliveryProofDisputeAggregate` with `canonicalState`/`canonicalBasis`. **As accepted at `743e157` the surface is per-operation, not shared:** `DeliveryProofDisputeRaiseRequest` and `DeliveryProofDisputeReviewRequest` are distinct, the resource-bound `DeliveryProofDisputeOrderRead` carries the order read, and there are three evaluators — `evaluateRaiseDeliveryProofDispute`, `evaluateRecordDeliveryProofDisputeReview` and the zero-argument `evaluateResolveDeliveryProofDispute`, which always defers. Authorization binds through `AuthorizationGrant` and `checkDisputeAuthorization`, which prove **coverage** of the resource anchored by `DeliveryProofDisputeFacts.resourceId`. *(An earlier draft of this row described a single shared request, a single `evaluateDeliveryProofDispute` and a `DeliveryProofDisputeContext`; **none of those exist in the accepted contract** — the context was removed by FIX-002 and the evaluator split by FIX-001.)* Canonical sources: [delivery-proof dispute](../contracts/delivery-proof-dispute.md) and the `cp_contracts` barrel. Additive: nothing defined at 0.8 changed meaning, and **no permission was added**. **No delivery, refusal, return, customer custody, direct agent-to-rider pickup, proof mechanism, proof-satisfaction policy, dispute outcome or money rules yet.** 0.10 (FND-003B3B) adds the delivery **attempt** and **return** lifecycles for the bounded non-success path, the terminal `ReservationState.returned` and one permission `agent.return.record_receipt` (**38 → 39**). 0.11 (FND-003C1) adds the first **money** surface — `CurrencyPolicy` (BDT-only, no FX), `OrderFinancialSnapshot`, `PaymentState`/`PaymentFacts`, the `CashJournalEntry` model with balanced-posting validation, and one COD collection operation with **no new permission**. Additive throughout: nothing defined earlier changed meaning. **No delivery confirmation, proof-satisfaction policy, remittance, settlement, refusal-fee collection, refund, dispute outcome or worker-pay rule yet.** See [version history](../contracts/version-history.md). |

Bump the minor version for additive, backward-readable changes; bump the major
version for a breaking one and update every Project before any app ships
against it.

## Owner actions outstanding

These need a human; no executor can do them.

| # | Action | Blocks |
|---|---|---|
| O1 | Run `flutter doctor --android-licenses` and accept | first Android build |
| O2 | Provide a Windows machine or CI runner | FND-002 (C2, C3, C4) |
| O3 | Attach a physical Android and iOS device | FND-002 (C6), push evidence |
| O4 | Install Firebase CLI + FlutterFire CLI | FND-004 emulator/security tests |
| O5 | Create Firebase projects per environment and supply config | FND-004 |
| O6 | ~~Decide currency, fee policy and commission ownership~~ — **RESOLVED 2026-09-11** under the ADMIN standing delegation, recorded in [ADR-0011](../decisions/ADR-0011-o6-currency-fees-commission-and-cash-custody.md). Widening the accepted currency set, or adding a compensation or settlement policy, each needs its **own** ADR and contract migration. | ~~FND-003 money invariants~~ — unblocked |
| O7 | **Configure branch protection / CI governance** on `main`. The remote and hosting are settled: `github.com/mdmohiuddin655/commerce_platform`, pushed 2026-09-09. **Verified unconfigured on 2026-09-11** by authenticated GitHub REST inspection during FND-003D2B-MERGE-BOOKKEEPING-PUSH-001: `main.protected = false`, the branch-protection endpoint returns **404 "Branch not protected"**, the repository **rulesets collection is empty**, `/rules/branches/main` reports **0 effective rules**, and there are **0 workflows and 0 workflow runs**. The negative is conclusive rather than a permissions artifact — the querying token holds `admin: true` on the repository, and the owner is a **User**, so no organization ruleset can apply. **O7 therefore remains OUTSTANDING precisely because branch protection and CI governance are absent — verifying their absence is not configuring them, and no CI passed.** | CI in FND-004 |
| D1 | **Decide: is web push required at launch?** Settles the notification stack (ADR-0005) | FND-002B, FND-004 |
| D2 | If the Awesome path is wanted: establish `awesome_notifications_fcm`'s license — it is not stated on its package page | FND-002B |
| D3 | **Decide Windows closed-app push:** fund a WNS route (Azure/Entra or Store registration, with lead time) or accept local-toast + durable-inbox only | FND-002B (C6) |
