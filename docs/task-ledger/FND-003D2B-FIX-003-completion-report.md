# FND-003D2B-FIX-003 completion report

- **Task:** Close the material defect found by **FND-003D2B-FINAL-REVIEW-003**,
  and reconcile the documentation drift left by FND-003D2B-FIX-002
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Reviewed base:** `main` @ `03c71d00b89a2018d1a18631d8e36c40238c0b57`
- **Starting candidate HEAD:** `f04d453781fb4aa88cf73d4d73bf0b3e79c425b1`
- **Branch:** `fnd/FND-003D2B-fallback-proof-dispute-contract` (existing)
- **Follow-up commit:** reported **out of band** after commit creation — a
  commit cannot contain its own SHA, and **no amend was used to insert one**
- **Contract version:** **0.9 — unchanged, not bumped**
- **Status:** **DONE** — the corrected **four-commit** candidate requires a
  **new, separate read-only final acceptance review**. It is **not** accepted
  for merge.

## 1. Baseline

```text
git fetch origin --prune                       exit 0
git status --porcelain --untracked-files=all   (empty)
git branch --show-current                      fnd/FND-003D2B-fallback-proof-dispute-contract
git rev-parse HEAD                             f04d453781fb4aa88cf73d4d73bf0b3e79c425b1
git rev-parse main / origin/main               03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse b94e5424^                        03c71d00b89a2018d1a18631d8e36c40238c0b57
git rev-parse ded1aa79^                        b94e5424ef2460c2d1ec30aeec80e9de09cf1699
git rev-parse f04d453^                         ded1aa7967e1cae00dd504e7fec15df63d29aa83
ContractVersion.current                        0.9
```

Chain before work: `03c71d00…` → `b94e5424…` → `ded1aa79…` → `f04d453…`. No
published commit was amended, rebased, squashed or reset; this task adds **one
new normal follow-up commit**.

## 2. The defect, reproduced before fixing

The accepted `OrderLifecycleFacts` was inspected first, as instructed:

```dart
final OrderState? state;        final int revision;
final ReservationState? reservationState;   final int reservedUnits;
```

**No resource id.** That is correct for the pre-dispatch evaluator, which is
handed one order and asked about that order. It is not sufficient for a dispute
raise, which must prove that *four* independently supplied things describe the
**same** delivery.

Reproduced against `f04d453`:

```text
grant       = order A
dispute     = order A
assessment  = order A
order read  = "order B"   (in_delivery, revision 5, reservation committed)

allowed = true
record resource = ord_Xa91ZZ0plQ7rTt4B      <-- A, on the strength of B's facts
```

A dispute was recorded against order A while its lifecycle evidence could have
come from any order with matching scalars. **Numeric equality is not identity** —
the third time this slice has had to apply that lesson, after the same-revision
verdict contradiction (FIX-001) and the higher-revision id reuse (FIX-002).

## 3. Correction

### An operation-scoped, resource-bound order read

`DeliveryProofDisputeOrderRead` carries a canonical `resourceId` and the
accepted `OrderLifecycleFacts` for that resource. It is deliberately minimal:

- **a read, not a second order aggregate** — no state, no transition, no
  revision arithmetic, no lifecycle rule;
- **the accepted `OrderLifecycleFacts` API is untouched.** Changing that shared,
  already-accepted contract would have been a far larger decision needing its
  own ADR and version analysis; it was not required, so it was not done;
- fails closed through the canonical opaque-id rule, with a `belongsToResource`
  that refuses two identically-malformed values — the FND-003D1 lesson;
- fail-safe `toString`: a malformed read renders no field;
- no actor, role, permission, membership, reason, approval, money, proof
  material or mutable state.

> **Binding is not provenance.** Saying which resource a read claims to be for
> does not prove it came from trusted storage or was consistent with the rest of
> the read-set. That the backend loads every aggregate for one canonical
> resource in **one consistent transaction** remains **DPD3**, and revalidation
> inside it **DPD4** — both **NOT RUN**.

### Complete resource binding before transition construction

Raise now requires all four identities to agree, checked before any order
revision, state or reservation fact can authorize anything:

```text
dispute.resourceId          <- the canonical anchor, from the read-set
  == grant                  (grant.covers, checked first)
  == assessment.resourceId
  == orderRead.resourceId
```

The resulting record and event identity remain that same canonical resource.

### The self-referential resource claim is gone

`checkDisputeAuthorization` previously called:

```dart
grant.covers(principalId: actor.id, resourceId: grant.resourceId)
```

The resource half is **tautological** — the grant's own resource handed back to
itself always matches — so the call proved only the principal binding while
being documented as proving the resource binding too. I noted this in the
FIX-002 push report and did not act on it then; this closes it.

**Option A was taken:** the helper now takes `expectedResourceId`, supplied from
the read-set, and `grant.covers` is called against that. The anchor is the
**stored dispute aggregate's** resource, never the grant's. The parameter's
documentation states plainly that passing `grant.resourceId` would restore the
tautology.

`authorizationGrantMismatch` remains a single generic internal value; no
detailed authorization reason is exposed.

### Review and resolve untouched

Review still takes **grant + dispute only**; its resource binding is `grant`
covering the stored dispute's resource, with no second comparison and no second
source of resource truth. Resolve still takes **zero arguments**. A call passing
assessment or order facts to review, or any argument to resolve, does not
compile.

### Documentation reconciliation

Stale post-FIX-002 wording describing a "server-resolved context" in the D2B
module — after `DeliveryProofDisputeContext` was deleted — was corrected in
`delivery_proof_dispute.dart`, `docs/contracts/delivery-proof-dispute.md` and
the **0.9** source-history entry in `contract_version.dart`. The identical
wording in the **D2A** module is accurate — `DeliveryProofAssessmentContext`
still exists — and was left alone. Historical descriptions elsewhere remain,
clearly marked as historical.

## 4. Files changed

| Path | Change |
|---|---|
| `…/lib/src/delivery_proof_dispute_facts.dart` | **new** `DeliveryProofDisputeOrderRead` |
| `…/lib/src/delivery_proof_dispute_authorization.dart` | `expectedResourceId` replaces the self-referential resource argument |
| `…/lib/src/delivery_proof_dispute_evaluator.dart` | anchor from the read-set; order read bound; review/resolve unchanged in shape |
| `…/lib/src/delivery_proof_dispute.dart` | module map corrected; stale "context" wording removed |
| `…/lib/cp_contracts.dart` | surface description mentions the bound read-set |
| `…/lib/src/contract_version.dart` | 0.9 history wording (**version unchanged**) |
| `…/test/support/delivery_proof_dispute_fixtures.dart` | `orderRead(...)` fixture; raise takes the bound read |
| `…/test/delivery_proof_dispute_evaluator_test.dart` | **+3** FIX-003 regressions; two denials updated |
| `…/test/delivery_proof_dispute_authority_test.dart` | wrong-grant-resource denial updated |
| `…/test/delivery_proof_dispute_concurrency_test.dart` | order arguments use the bound read |
| `…/test/delivery_proof_dispute_regression_test.dart` | helper call takes `expectedResourceId` |
| `docs/contracts/delivery-proof-dispute.md` | new binding section; tables and module map corrected |
| `docs/contracts/README.md` | FIX-003 summary + a new binding rule |
| `docs/contracts/version-history.md` | third in-place correction recorded under 0.9 |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-003 narrative; four-commit candidate |
| `docs/task-ledger/FND-003D2B-FIX-002-completion-report.md` | **appended** partial-supersession note |
| `docs/task-ledger/FND-003D2B-FIX-003-completion-report.md` | **new** — this report |

**Not touched:** `apps/`, `backend/`, `infra/`, `.github/`, any pubspec or
lockfile, `docs/decisions/`, `permission.dart`, `permission_matrix.dart`, the
generated `permission-matrix.md`, `authorization.dart`, `delivery_proof.dart`,
**every** `delivery_proof_assessment_*.dart` source, `order_lifecycle.dart` and
every other lifecycle/custody/assignment state machine.

## 5. Validation — real commands, real output

```text
$ cd packages/contracts && dart analyze
No issues found!                                          EXIT=0

$ dart test <the nine dispute suites>
00:00 +182: All tests passed!                             EXIT=0

$ dart test <authorization, forgery_probe, permission_matrix,
             delivery_proof, all delivery_proof_assessment_*,
             contract_version, command_envelope>
00:00 +271: All tests passed!                             EXIT=0

$ cd packages/contracts && dart test
00:00 +989: All tests passed!                             EXIT=0

$ flutter analyze                       # workspace root
No issues found! (ran in 2.0s)                            EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS                                      EXIT=0

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
No issues found! (ran in 2.0s)
--- packages/contracts ---
00:00 +989: All tests passed!
LAYERING CHECK: PASS
ALL CHECKS PASSED                                         EXIT=0
```

Dispute suites 179 → **182**; package total 986 → **989**.

**This is the local repository gate, not GitHub CI.** No CI ran; FND-004 has not
landed and **O7** is outstanding.

## 6. Negative controls

All applied, run, and **fully reverted** — each verified byte-identical by
`diff`, with no marker left anywhere in `lib/` or `test/`.

| # | Change | Result |
|---|---|---|
| **NC6** | removed the order-read resource equality | `an order read from another resource is refused — FIX-003` **FAILED**, plus `a malformed order-read resource fails closed` |
| **NC4** (re-verified) | bypassed `checkDisputeAuthorization` | **9** tests failed |
| **NC5** (re-verified) | restored unconditional `superseded` | 1 test failed |
| **NC1** (re-verified) | removed the same-revision verdict check | 2 tests failed |
| **NC2** (re-verified) | re-added the `reviewerIsRaiser` rule | 1 test failed |
| **NC3** (re-verified) | passed assessment/order to review, any argument to resolve | **3 compile errors** |

`tools/check_layering.sh` was not modified, so its own negative controls were not
re-run — AGENTS.md requires that only when the guard changes.

## 7. What was NOT run, and why

**No backend, persistence, Firebase project, emulator or device exists here.**

| Evidence | Status |
|---|---|
| **DPD1–DPD12** (incl. **DPD3**/**DPD4**, the read-set consistency this correction can only *shape*, not prove) | **NOT RUN** |
| **DPA1–DPA18** (incl. **DPA11**) | **NOT RUN** |
| **CA1–CA23, R33–R40, L1–L13, P1–P17, RA1–RA18** | **NOT RUN** |
| **B3-C1** | contract-test evidence only, picker only |
| **B3-C2** | **NOT RUN / FUTURE** |
| Firebase project / Rules / indexes / emulator | **NOT RUN** — CLIs not installed (O4), no project (O5), none created |
| Backend persistence | **NOT IMPLEMENTED / NOT RUN** |
| Physical device / Android / iOS / Windows | **NOT RUN** — O1, O2, O3 |
| GitHub CI | **NOT RUN** — FND-004 not landed, **O7** outstanding |
| Deployment | **NOT RUN** |

**A grant is not freshness evidence.** It proves `evaluateAuthorization` allowed
those inputs; that they were current remains **R33–R40**, NOT RUN.

## 8. Confirmations

- **ContractVersion remains 0.9**; no serialization and no migration claim.
- `Permission.values` and `permissionMatrix` remain **38**; raise →
  `customer.dispute.raise`, review → `admin.dispute.administer`; no permission
  rule copied or reimplemented; `AuthorizationGrant` remains FND-003A's
  unforgeable artifact.
- No `reviewerIsRaiser`, no separation-of-duties invention.
- FIX-001's per-operation read-set split intact: raise reads grant/dispute/
  assessment/order read; review reads grant + dispute; resolve takes **zero
  arguments** and always returns `resolutionPolicyDeferred`.
- `basisFrom` remains absent; same-revision verdict contradiction and
  higher-revision id reuse both remain `indeterminate`; a genuine newer
  assessment remains `superseded`; the dispute basis remains immutable.
- Every order/reservation/inventory/financial/custody/picker/rider/assessment/
  scope effect remains NONE; only the two dispute events exist; `delivered`,
  customer custody and rider completion remain unreachable.
- **DPA11 remains NOT RUN**; no history array or global uniqueness lookup was
  invented.
- Current docs contain **no obsolete `DeliveryProofDisputeContext` claim**.
- **No amend, rebase, squash, reset, force-push or history rewrite occurred.**
  Nothing was merged, pushed without authorization, deployed, tagged or turned
  into a PR; no GitHub setting or Firebase resource was touched.
- No TODO, stub or fake-completion path exists.

## 9. Status after this task

| Task | Status |
|---|---|
| **FND-003D2B** | **PARTIAL / FIX REQUIRED / NOT ACCEPTED** — four-commit chain awaiting a new separate read-only final review |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — **O6**, FND-003C, FND-003B3B |
| Separation of duties (raiser vs reviewer) | **NOT DECIDED** — own permission + ADR |
| FND-003B3B | **NOT STARTED** |
| FND-003C | **BLOCKED on O6** |
| FND-004 | unchanged (**TODO**) |
| O7 | **outstanding** |

`CONSTRAINTS.md` invariant 13 is still **not** discharged.

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.

---

# RECHECK — DOCUMENTATION GAP FOUND AT PUBLICATION

**Appended by FND-003D2B-FIX-004 (2026-09-11). Nothing above is rewritten.**

**FND-003D2B-FIX-003-PUSH-001 declined to publish `202a8a9`, and was correct to
do so.** That push task gated publication on a documentation check — "current
docs contain no obsolete `DeliveryProofDisputeContext` claim" — and the check
failed. Two current-tense statements still said the **authorization grant**
supplies the canonical resource:

```text
docs/contracts/delivery-proof-dispute.md
  "The grant carries the canonical resource…"
packages/contracts/lib/src/delivery_proof_dispute_facts.dart
  "The canonical resource comes from the authorization grant."
```

Both contradicted this report's own §3, and the code it describes:

```dart
final String resourceId = dispute.resourceId;   // raise AND review
```

**This was a drafting omission in FIX-003, not a defect in its code.** §3 added
the new binding section but left the superseded FIX-002 paragraphs in place, so
the module and contract documentation told a reader the opposite of the shipped
behaviour, two paragraphs apart.

`FND-003D2B-FIX-004` corrects both statements, documentation and
source-comment only, with **zero executable Dart changed**. Everything else in
this report stands: the resource-bound order read, the completed raise binding,
the removal of the tautological `grant.covers` argument, the negative controls
and the NOT RUN classifications were all re-verified.

Full detail: [FND-003D2B-FIX-004 report](FND-003D2B-FIX-004-completion-report.md).
