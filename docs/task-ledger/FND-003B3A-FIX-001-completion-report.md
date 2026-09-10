# FND-003B3A-FIX-001 completion report

- **Task:** Close the final-review gaps in FND-003B3A without redesigning the
  accepted custody model
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `c29df0f7c6144f4c03a832713a23219a2408ba14`, branch
  `fnd/FND-003B3A-custody-handoff-contracts`, working tree clean
- **Reviewed base main:** `bfec4bea5dbfbc7316d10db9a898673111a4db68`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.6 candidate, corrected in place** (no bump)
- **Status:** **DONE**

`c29df0f` was not amended. One new commit on the same branch. The tree was
clean, so **no `git reset --hard` was used**, and no history was rewritten.

## 1. Root causes

**1. No canonical resource/shop binding.** The evaluator compared custody, the
picker slot and the rider slot against **each other**, which proves they agree —
not that they are about the right order. `OrderLifecycleFacts` carries no
resource identity, and shop custody was never bound to the order's shop, so
custody could name shop B on an order belonging to shop A with both strings
individually valid.

**2. No assignment-slot revision CAS.** Custody and order revisions were pinned;
the picker and rider `slotRevision` were not. A caller holding a stale view of a
slot that still happened to name the same attempt went undetected.

**3. Initialisation was create-once only in prose.**
`CustodyFacts.initialAtShop` is a shape, and nothing stopped it being applied to
an order that already had custody — which on paper moves goods back to the shop
and erases the fact that a picker or rider is carrying them.

**4. Receipt provenance under-specified.** "Receiver-side" was stated without
saying plainly that this is an **authorized rider assertion**, not proof.

**5. Exported state metadata contradicted itself.**
`OrderState.notYetImplemented` still listed `inDelivery`, and
`AssignmentState.notYetImplemented` said `completed` was unimplemented, after
this slice made both reachable.

**6. Evidence error.** See §11.

## 2. Resource / shop binding

New `CustodyResourceContext { resourceId, shopId }` — the canonical identity the
backend resolved the command against, now a **required** argument to
`evaluateCustodyTransition`.

Enforced, before any effect:

- `resourceId` valid opaque id; `shopId` **non-blank** — else
  `resourceBindingMismatch`;
- custody, picker slot and (when present) rider slot all name that
  `resourceId` — else `resourceBindingMismatch`;
- **shop custody names that exact `shopId`** — else the new
  `shopBindingMismatch`.

**Compared exactly.** `trim()` is used only to *reject* blank shop ids; neither
side is trimmed or normalised into equality, and a test asserts a padded
` shop_alpha ` is a **different** shop id.

`OrderLifecycleFacts` was deliberately **not** given a resource field — that
would spread a change through FND-003B1 for no gain. The context establishes
that the lifecycle snapshot handed in is the one for this resource; the backend
owns having loaded it from one consistent read-set. **The pure evaluator cannot
prove storage provenance beyond the identities it receives**, and the report
does not claim otherwise — that is **CA19** and **CA20**.

**ShopId format remains DEFERRED.** No grammar was invented: nothing in the
repository governs shop ids, and `shop_alpha` would fail the opaque-id rule. A
test pins that `isValidOpaqueId('shop_alpha')` is false **and** that the flow
still succeeds. The fixture was not changed to look opaque.

## 3. Concurrency

| Command | Pinned revisions |
|---|---|
| `custody.record_shop_pickup` | custody, order, **picker slot** |
| `custody.record_rider_receipt` | custody, order, **picker slot**, **rider slot** |

`CustodyRequest` gained `expectedPickerSlotRevision` (required) and
`expectedRiderSlotRevision` (**required-named nullable**, so every call site
states its intent). A receipt with a null rider expectation **fails closed**
with `riderSlotRevisionConflict`.

All four are checked **before any transition is constructed**. This is
**additional** protection, not a replacement: exact `assignmentId`, generation,
accepted state, assignee and `SourcePickerBinding` checks are all unchanged, and
a test proves correct revisions with a wrong attempt are still refused.

A *missing* rider slot is still reported `noAcceptedRiderAssignment`, not as a
revision conflict — that is a semantic fact, not a concurrency one, and letting
CAS preempt it would have degraded an accepted denial.

**Races.** Pickup vs picker revoke and receipt vs rider revoke are both pinned:
the loser fails on the revision, and — even at the current revision — on the
state. Every denial yields `transition == null`, therefore **no partial custody,
order, assignment, projection or event**. Retry-reload is **CA21**;
serialisation is **CA23**. Both NOT RUN.

## 4. Initialisation

`initialiseCustodyAtShop({resource, existingCustody})` — server-side, pure,
testable:

| `existingCustody` | Result |
|---|---|
| null | **allow** — holder `shop`, revision **1** |
| at `shop`, revision 7 | **deny** `custodyAlreadyInitialised`, nothing created — **cannot reset to 1** |
| with `picker` | **deny** — a pickup cannot be undone |
| with `rider` | **deny** — a receipt cannot be undone |

Still **no `CustodyCommand`, no permission, no commandType** for it; tests
assert no command type contains `init`/`create` and no permission id contains
`custody.initial`. Storage must use **create-if-absent** and never overwrite —
**CA1**, tightened, and **CA22**.

## 5. Rider receipt semantics

`custody.record_rider_receipt` records an **authorized rider assertion** that
the accepted rider has received and now holds the goods. The contract accepts
that assertion as the state-changing custody record **after** every aggregate,
identity, binding and revision check passes.

Documented explicitly as **not**: independent cryptographic proof, a picker
acknowledgement, customer delivery proof, dispute-proof evidence, or an
OTP/QR/signature/photo/biometric/GPS check. **None was invented.** A future
handoff-proof protocol may add stronger evidence.

`picker.custody.record_handoff` remains reserved and **non-executable** — a
picker-side assertion alone still does not transfer custody. No proof or dispute
semantics were moved into this slice.

## 6. State metadata

**Order.** `notYetImplemented` narrowed to `{delivered}` — the only order state
no slice implements. The "this evaluator cannot act from it" claim got its own
name, `outsideThisSliceEvaluator = {inDelivery, delivered}`, which together with
`executableInThisSlice` **partitions the enum**. `aggregateShapeKnown` is
unchanged. The two existing suites that used `notYetImplemented` were switched to
`outsideThisSliceEvaluator` — same members, identical coverage, and the name no
longer lies.

**Assignment.** Added `notYetImplementedForRole(role)`: **empty** for the picker,
`{completed}` for the rider. The role-neutral `notYetImplemented` is retained and
re-documented as "not implemented for *every* role", which remains true.

**Neither evaluator gained anything.** `executableInThisSlice` is unchanged, no
command type contains `complete`, and no assignment command may act *from*
`completed`.

## 7. Regression safety — unchanged

**B3-C1** still satisfied by real evaluator-produced histories across
generations 1–3 (revisions 3, 6, 9) — contract-test evidence, **not** persistence
evidence. **B3-C2** still NOT RUN / FUTURE, rider `completed` unreachable, no
cost invented.

`SourcePickerBinding` immutable; `reassignmentSafetyFor` unchanged in behaviour
and fail-closed meaning; `in_delivery + committed` canonical; pre-dispatch
evaluator still refuses to act from `in_delivery`; `ready` cancellation still
`policyDeferred`; **inventory NONE, financial NONE**; **no post-pickup stock
restoration, money policy, direct agent→rider route or admin override added**.
ADR-0006 and ADR-0007 **byte-for-byte unmodified**; permissions and the generated
matrix **untouched and not regenerated**.

## 8. Future backend acceptance

**CA1–CA18 unchanged, CA19–CA23 added — all NOT RUN**, continuing the series
without renumbering:

| # | Criterion |
|---|---|
| CA19 | One canonical `CustodyResourceContext` per command; all four aggregates loaded for **that** resource in one consistent read-set. |
| CA20 | A mixed-order read-set is rejected; shop custody whose `shopId` differs from the order's canonical shop fails closed. |
| CA21 | A transaction retry **reloads and re-evaluates** every participating aggregate; a previously computed transition is never replayed against new facts. |
| CA22 | Custody initialisation uses **create-if-absent** and can never overwrite, reset or roll back an existing aggregate. |
| CA23 | Picker/rider slot revisions are revalidated inside the transaction; pickup/receipt racing a revoke serialises so exactly one commits and the loser writes nothing. |

**R33–R40, L1–L13, P1–P17, RA1–RA18 unchanged and NOT RUN. B3-C2 NOT RUN /
FUTURE.** P13/P14 and RA14/RA15 remain real persistence evidence. **No Dart
fixture result is offered as persistence evidence**, and none is marked PASS.

## 9. Evidence correction

| | |
|---|---|
| Accepted baseline at `bfec4be` (FND-003B2B-FIX-001 report) | **520** |
| B3A report claimed branch point | ~~522~~ → **corrected to 520** |
| Actual B3A candidate total | **601** |
| This fix's total | **631** |

522 was a **real** number, but from a mid-task run taken *after* two tests had
already been added in B3A — the 0.5↔0.6 policy test, and the split of the
`completed` picker test into a canonical and a malformed case: 520 + 2 = 522. It
was never the branch point. **No rerun was invented to explain it**, and the
finding is recorded in the B3A report's §17 rather than quietly overwritten.

## 10. Validation

| Command | Result |
|---|---|
| branch / HEAD / `git status` before work | **PASS** — `c29df0f`, clean, no reset |
| `dart test test/custody_lifecycle_test.dart` | **PASS** — **62** (was 42) |
| `dart test test/custody_integrity_test.dart` | **PASS** — **47** (was 37) |
| `dart test test/order_lifecycle_aggregate_test.dart` | **PASS** — **41** |
| `dart test test/order_lifecycle_forbidden_test.dart` | **PASS** — **18** |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **96** |
| `dart test test/rider_assignment_integrity_test.dart` | **PASS** — **71** |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unmodified |
| `dart test test/authorization_test.dart` | **PASS** — **46**, unmodified |
| `dart test test/contract_version_test.dart` | **PASS** — **11** |
| negative control — resource/shop binding disabled | **PASS (fired)** |
| negative control — rider slot CAS disabled | **PASS (fired)** |
| negative control — create-once protection bypassed | **PASS (fired)** |
| `dart test` all `cp_contracts` | **PASS** — **631** (was 601) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **672 across 10 of 15 members** (was 642) |

**Negative controls.** Removing the resource/shop binding failed the
different-resource, different-shop and mixed-order tests. Removing the rider CAS
failed the stale-rider-revision, omitted-expectation and rider-revoke-race
tests. Bypassing create-once failed all three re-initialisation tests.
Production restored **byte-for-byte** after each — `lib/` checksum returned to
`1c6fae264556a2fa…`.

**NOT RUN:** FND-002 platform/device checks, Firebase/emulator, Firestore rules,
indexes, backend persistence, deployment, and CA/R/L/P/RA. **BLOCKED:** none.
Nothing backend, Firebase, device or platform is labelled PASS.

## 11. Files

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/custody_state.dart` | **new** `CustodyResourceContext` |
| `packages/contracts/lib/src/custody_lifecycle.dart` | 4 new denials; slot-revision fields; `resource` argument; binding + CAS checks; `initialiseCustodyAtShop` + outcome |
| `packages/contracts/lib/src/order_state.dart` | `notYetImplemented` → `{delivered}`; new `outsideThisSliceEvaluator` |
| `packages/contracts/lib/src/assignment_state.dart` | `notYetImplementedForRole` |
| `packages/contracts/test/support/custody_fixtures.dart` | `resourceContext`; slot-revision and resource plumbing |
| `packages/contracts/test/custody_lifecycle_test.dart` | +20 — binding, initialisation, CAS |
| `packages/contracts/test/custody_integrity_test.dart` | +10 — metadata honesty, slot-revision races, mixed-order read-set |
| `packages/contracts/test/order_lifecycle_{forbidden,aggregate}_test.dart` | use `outsideThisSliceEvaluator`; pin the corrected `notYetImplemented` |
| `docs/contracts/custody-lifecycle.md` | resource context, CAS table, create-once, receipt-as-assertion, CA19–CA23 |
| `docs/contracts/order-reservation-lifecycle.md` | metadata set table + correction note |
| `docs/contracts/picker-assignment-lifecycle.md` | role-aware metadata |
| `docs/contracts/rider-assignment-lifecycle.md` | B3-C2 wording |
| `docs/contracts/version-history.md` | 0.6 corrected-in-place note |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-001 row; two-commit candidate chain |
| `docs/task-ledger/FND-003B3A-completion-report.md` | §17 recheck + **522 → 520** correction |
| `docs/task-ledger/FND-003B3A-FIX-001-completion-report.md` | this report |

**Untouched:** `permission.dart`, `permission_matrix.dart`, the generated
permission matrix, ADR-0006, ADR-0007, `ids.dart`, `custody_command.dart`,
`custody_effect.dart`, `picker_assignment.dart`, `rider_assignment.dart`,
`assignment_integrity.dart`, `order_lifecycle.dart`, `contract_version.dart`,
apps, backend, infra, Firebase config, `pubspec.yaml`, `pubspec.lock`. **No
dependency added.**

## 12. Ledger

**FND-003B3A candidate chain: `c29df0f` + this commit** — `c29df0f` alone is not
the candidate contract. **This slice is NOT yet accepted for merge**; that is the
next review's call.

**FND-003B3 PARTIAL. FND-003B PARTIAL.** Delivery, refusal and return slice
**NOT STARTED**. **FND-003C BLOCKED on O6.** FND-003D unchanged.

## 13. Contract version

**0.6, corrected in place. No bump.** These are edits to an **unreleased
candidate**: `origin/main` is `bfec4be`, which predates 0.6; no app has a build;
no Firebase project exists; nothing has consumed it. A review finding is not a
release event. **No payload-decoding compatibility claim** — `cp_contracts` still
has no serialization.

**Migration NOT APPLICABLE / NOT RUN. Firestore rules NOT IMPLEMENTED. Indexes
NOT IMPLEMENTED. Backend persistence NOT IMPLEMENTED. Deployment NOT RUN.** No
Firebase resource created, no live operation performed.

## 14. Scope statement

Contract and tests only. Nothing merged, pushed, force-pushed or deployed; no PR
created. **FND-003B3B not started.**
