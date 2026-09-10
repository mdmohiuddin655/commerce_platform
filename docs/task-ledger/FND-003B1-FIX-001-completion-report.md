# FND-003B1-FIX-001 completion report

- **Task:** Close the aggregate-consistency hole found reviewing FND-003B1
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `697d1706fead7e708941c979770ec2cb183c9d0c`, branch
  `fnd/FND-003B1-order-reservation-lifecycle`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.3, corrected in place** (no bump)
- **Status:** **DONE**

`697d170` was not amended. One new commit on the same branch. The tree was
clean, so **no `git reset --hard` was used**.

## 1. Root cause

`evaluateOrderTransition` trusted `OrderLifecycleFacts` completely.

The transition **graph** is internally consistent — it can never *create* an
impossible order/reservation pair. But facts arrive from **storage**, and
nothing checked that the order state, reservation state, revision and unit
count formed a combination this lifecycle could ever have produced. The release
paths used a generic `_requireHeldReservation` helper that accepted *any*
non-final reservation, so an impossible pair sailed through.

Reproduced against `697d170` before changing anything:

| Malformed facts | Result before the fix |
|---|---|
| `placed + committed`, `order.reject` | **allowed** — restored 3 units |
| `accepted + active`, `order.cancel` | **allowed** — restored 3 units |
| `placed + active`, `reservedUnits: 0`, reject | **allowed** — zero-unit effect |
| `placed + active`, `reservedUnits: -5`, reject | **allowed** — `availableStockDelta = -5` |

The last one is worse than the review described: a negative unit count produced
an inventory mutation that would have **destroyed** stock rather than restoring
it.

## 2. Canonical aggregate model

`canonicalAggregatePairs` is now an explicit table:

| Order state | Valid reservation states |
|---|---|
| `placed` | `active` **or** `expired` |
| `accepted` | `committed` |
| `preparing` | `committed` |
| `ready` | `committed` |
| `rejected` | `released` |
| `cancelled` | `released` |

- **`placed + expired` is canonical** — it is exactly the expiry-wins race
  outcome. Treating it as corruption would have broken that outcome, so it is
  called out in the code and covered by its own test.
- **`rejected`/`cancelled` pair only with `released`, never `expired`**: the
  units came back because someone acted, not because time passed.

**Canonical absence** for placement is exact: `state == null` **and**
`revision == 0` **and** `reservationState == null` **and**
`reservedUnits == 0`. A "non-existent" order carrying a revision or reservation
is a partial load — treating it as absent would place a duplicate order.

**Revision invariant:** existing order `revision >= 1`; absent order
`revision == 0` exactly.

**Unit invariant:** any existing reservation record has `reservedUnits > 0`.
Malformed quantities are never clamped or absolute-valued — **the aggregate is
denied**.

New denial: `aggregateInconsistent`, documented as *corruption, not a race*.

## 3. Release-path fix

Pair-specific instead of generic:

| Command | Required source pair |
|---|---|
| `order.reject` | exactly `placed + active` |
| `order.cancel` from `placed` | exactly `placed + active` |
| `order.cancel` from `accepted` | exactly `accepted + committed` |

A malformed pair is caught by aggregate validation before it reaches these; a
canonical-but-wrong reservation (`placed + expired`) denies with
`reservationAlreadyFinal`, which is accurate — the units are already back.

## 4. Two denial reasons removed

`reservationMissing` and `reservationNotActive` became **unreachable** once
aggregate validation ran first, so they were removed rather than left in the
enum. A denial reason a backend can never observe is worse than none: it
invites handling for a case that cannot occur.

This is a deliberate change beyond the minimum, and I am flagging it rather
than burying it. Three existing tests asserted the old reasons and were updated
— each had been encoding the weaker behaviour:

- `placed + released` accept → now `aggregateInconsistent` (the spec lists this
  pair as invalid);
- `accepted + released` preparation → now `aggregateInconsistent`;
- an existing order with a null reservation → now `aggregateInconsistent`.

Genuine `reservationAlreadyFinal` coverage is preserved through the canonical
`placed + expired` case.

## 5. Inventory safety

- Restoration remains **exactly once**: it is the transition into a terminal
  reservation state, and nothing leaves those.
- **No zero or negative stock mutation is reachable.** A sweep test runs every
  command over every canonical aggregate and asserts any stock-touching effect
  moves a strictly positive unit count.
- Every denied outcome yields `transition == null`, so no inventory effect
  exists at all — asserted directly rather than inferred.

## 6. Race regression

Unchanged and re-verified. Acceptance-first: `placed + active` →
`accepted + committed`, later expiry denied, nothing restored. Expiry-first:
`placed + active` → `placed + expired`, units restored once, later acceptance
denied. Conservation asserted both ways (delta `0` vs `+n`).

The new validation had to recognise `placed + expired` as canonical or it would
have broken the expiry-wins path — covered by an explicit test.

## 7. Policy and money — unchanged

`executableCancellationSources` remains `{placed, accepted}`;
`policyDeferredCancellationSources` remains `{preparing, ready}`. Preparing and
ready cancellation still deny with `policyDeferred`, producing no transition
and therefore **no financial amount at all**.

Executable rejection and cancellation still carry
`deferredToFinancialSlice` — **UNKNOWN/DEFERRED, not zero, not free, not
"no liability"**. O6 is not resolved and no fee, commission, COD or cash rule
was introduced.

## 8. Future states

`inDelivery` and `delivered` remain unreachable. Aggregate validation
deliberately **skips** pair-checking them — validating their pairing would mean
inventing one — so they still report `unknownTransition`, verified by test.

## 9. Tests

| Suite | Count | Result |
|---|---|---|
| `order_lifecycle_aggregate_test.dart` (**new**) | **41** | PASS |
| `order_lifecycle_test.dart` | 22 | PASS |
| `order_lifecycle_race_test.dart` | 17 | PASS |
| `order_lifecycle_forbidden_test.dart` | 18 | PASS |
| all `cp_contracts` | **225** (was 183) | PASS |

The new suite covers 17 impossible pairs × 6 effect-producing commands, missing
reservation records, revision integrity (0, negative, absent-with-revision,
absent-with-reservation, absent-with-units), unit integrity (0 and −5 on both
`active` and `committed`), the stock-destruction regression, the
non-positive-effect sweep, future-state reachability, and the
duplicate/stale/reordered matrix required by §J — every case asserted through
the **public evaluator**, never the validator directly.

Command idempotency is **not** reimplemented; FND-003A still owns it. These
tests assert only that a denied evaluation yields nothing to apply.

## 10. Validation

| Command | Result |
|---|---|
| `git status --short` before work | **PASS** — clean; no `reset --hard` |
| branch / HEAD | **PASS** — `697d170`, matched expected |
| defect reproduction probe | **PASS** — all four malformed cases confirmed allowed pre-fix |
| focused suites (4) | **PASS** — 41 / 22 / 17 / 18 |
| `dart test` all `cp_contracts` | **PASS** — **225** |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **266 across 10 of 15 members** (was 224) |

No FND-002 platform/device check was rerun. No accepted FND-003A focused suite
was rerun for reassurance — they ran only as part of the standard gate, and
that gate is **not** offered as new evidence for unrelated completed tasks.

## 11. Backend future acceptance

**L1–L12 remain NOT RUN.** **R33–R40 remain NOT RUN and unchanged.**

Added **L13**: persisted order/reservation aggregates are reconciled for
canonical pair consistency, and an invalid pair never drives an inventory
mutation — the backend must never intentionally persist `accepted + active`,
`placed + committed` or any other non-canonical pair.

L13 is **NOT RUN** and is not a blocker to this contract fix. The evaluator's
check is a second line of defence; atomic persistence of the canonical pair
remains a backend obligation.

## 12. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/order_lifecycle.dart` | canonical pair table, `validateAggregate`, `aggregateInconsistent`, pair-specific release paths, removal of two unreachable denials and their helpers |
| `packages/contracts/test/order_lifecycle_aggregate_test.dart` | **new** — 41 tests |
| `packages/contracts/test/order_lifecycle_test.dart` | 3 assertions corrected to the accurate classification |
| `packages/contracts/test/order_lifecycle_race_test.dart` | expiry-retry case split into canonical vs corrupt |
| `docs/contracts/order-reservation-lifecycle.md` | aggregate-integrity section; corrected the "structurally" claim; denial list; pair-specific release note; L13 |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-001 entry; two-commit evidence chain |
| `docs/task-ledger/FND-003B1-completion-report.md` | §15 recheck — annotated, not erased |
| `docs/task-ledger/FND-003B1-FIX-001-completion-report.md` | this report |

Untouched: `order_state.dart`, `reservation_state.dart`, `lifecycle_effect.dart`,
`lifecycle_command.dart`, the permission matrix, authorization/idempotency,
apps, backend, infra, `pubspec.yaml`, `pubspec.lock`. **No dependency added.**

## 13. Contract version

**0.3, corrected in place.** The branch has never been merged — `origin/main`
is `517f879`, which predates 0.3 — no app has a build, and no Firebase project
exists, so no client or stored datum has consumed 0.3. These are edits to an
unreleased definition. A review finding is not a release event. No
payload-decoding claim is made; `cp_contracts` still has no serialization.

## 14. Scope statement

No lifecycle state beyond FND-003B1 was implemented. No assignment, custody,
delivery, return, proof/dispute, payment/COD, cash journal, fee, commission or
settlement rule was introduced. **FND-003B2 remains NOT STARTED.** Nothing was
merged to `main`, pushed, force-pushed or deployed.
