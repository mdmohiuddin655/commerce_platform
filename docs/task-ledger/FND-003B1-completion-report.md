# FND-003B1 completion report

- **Task:** First bounded lifecycle slice of FND-003B — pre-dispatch order and
  inventory reservation lifecycle
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `main` @ `517f879fe809f4e4c43dd3dc16f3ff028ab5b509`
- **Branch:** `fnd/FND-003B1-order-reservation-lifecycle`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.2 → **0.3**
- **Status:** **DONE** — as corrected by **FND-003B1-FIX-001** (2026-09-10).
  See [§15 Recheck](#15-recheck-fnd-003b1-fix-001). `697d170` alone is not the
  accepted state.

## 1. Baseline

`main` matched the expected SHA exactly. Working tree was **clean**, so per the
task's Git-safety rule **no `git reset --hard` was used** — the branch was
created directly with `git switch -c`.

## 2. Contract version

**0.2 → 0.3.** `isVersionCompatibleWith` keys on major only, and the ledger
rule is "minor for additive, backward-readable". 0.2 contained no lifecycle
types at all, so nothing could be reinterpreted; every addition is new surface.

**No payload-compatibility claim is made.** `cp_contracts` still has no
serialization — no envelope or lifecycle type has `toJson`/`fromJson` — so a
0.2 build could not decode a 0.3 lifecycle payload even in principle. Version
policy and payload decoding remain separate concepts, and tests assert only the
former.

## 3. Order state model

Executable: `placed`, `accepted`, `preparing`, `ready`, `rejected`,
`cancelled`.

Terminal: `rejected` and `cancelled` — closed in every direction, with no
un-reject, reopening or reactivation invented.

Declared but **not executable**: `inDelivery`, `delivered`. They exist so a
later slice is not a breaking enum change. No edge into or out of them is
enumerated, and a test enumerates every command against every reachable state
to prove **no transition can produce them**.

## 4. Reservation model

`active` (held, expirable) → `committed` (held, **not** expirable) → terminal
`released` or `expired` (units already returned).

**The invariant:** the same reserved units are restored to available stock **at
most once**. Restoration is exactly the transition *into* `released` or
`expired`, both terminal — so a duplicate cancellation, duplicate rejection or
retried expiry worker finds no held reservation and produces no effect at all.

`released` and `expired` are distinguished for audit ("someone acted" vs
"nobody did"); their inventory effect is identical.

## 5. Transition matrix

Full matrix with preconditions, revision rules, effects and events:
[order-reservation-lifecycle.md](../contracts/order-reservation-lifecycle.md).

| Command | From → To | Permission | Inventory | Financial |
|---|---|---|---|---|
| `order.place` | — → `placed` | `customer.checkout.submit` | reserve *n* (−*n*) | none |
| `order.accept` | `placed` → `accepted` | `agent.order.accept` | commit (**0**) | none |
| `order.reject` | `placed` → `rejected` | `agent.order.reject` | restore *n* (+*n*) | **deferred** |
| `order.start_preparing` | `accepted` → `preparing` | `agent.fulfillment.record_progress` | none | none |
| `order.mark_ready` | `preparing` → `ready` | `agent.fulfillment.record_progress` | none | none |
| `order.cancel` | `placed`/`accepted` → `cancelled` | `customer.order.request_cancellation` | restore *n* | **deferred** |
| `reservation.expire` | `placed` → `placed` | **none — worker** | restore *n* | none |

Every applied transition advances the order revision, which is what makes a
stale `expectedRevision` detectable. Acceptance's available-stock delta is
exactly `0` — the decrement happened at placement.

## 6. Cancellation policy boundary

**Executable:** `placed`, `accepted`. No physical shop work is committed yet,
so releasing the reservation is the whole effect and the blueprint's rule
covers it.

**DECISION REQUIRED (denies with `policyDeferred`):** `preparing`, `ready`.
From `preparing` the shop is assembling goods; whether a customer may cancel
unilaterally, whether shop or admin approval is required, and who bears the
cost are business questions the repository does not answer. They need **O6**
and **FND-003C**.

Those deny with `policyDeferred` rather than `unknownTransition` specifically
so a backend can tell "not decided yet" from "never allowed" — and so nobody
fills the gap with a guessed rule.

**No fee, refund, commission or settlement value was invented anywhere.**
Rejection and cancellation carry `deferredToFinancialSlice`, which the type
documentation makes explicitly *not* zero.

## 7. Expiry and concurrency

Expiry is a **trusted worker transition**: its `requiredPermission` is `null`,
and `evaluateAuthorization` denies a `systemWorker` every human-role
permission, so a worker cannot borrow one. It is **not** a TTL deletion — the
documentation states plainly that deleting a reservation document is not an
inventory transaction and must never restore stock on its own. **No expiry
duration was invented**; that is configuration outside the state machine.

**The race, closed structurally.** Acceptance requires an `active` reservation
and moves it to `committed`, which is not expirable. So:

- *Acceptance first:* later expiry is denied (`wrongSourceState`), restores
  nothing.
- *Expiry first:* units restored once; later acceptance denied
  (`reservationAlreadyFinal`).

An accepted order and restored inventory from the same reservation **cannot
coexist** — there is no path producing both. Tested in both orderings with
stock-conservation assertions (delta `0` vs `+n`, one effect each).

## 8. Forbidden edges

Eleven explicit denials tested, each asserting *no transition object at all* so
no inventory effect can leak: `rejected → accepted`, `cancelled → accepted`,
`cancelled → preparing`, `rejected → ready`, `preparing → accepted`,
`ready → accepted`, `accepted → rejected`, `ready → preparing` (backwards),
`rejected → cancelled`, `cancelled → rejected`, expiring an accepted order.

Plus: every command from every terminal state reports `alreadyTerminal`; every
command from a future state reports `unknownTransition`. **Unlisted edges fail
closed.**

**No generic status setter exists.** `LifecycleRequest` carries no target
state; a test asserts no command type contains `status` or `set_state`.

## 9. Backend future acceptance

**Required atomic transaction boundary** (documented, not implemented): order +
revision, reservation state, inventory mutation, command dedupe result and
outbox event must commit together. **No push is sent inside the retryable
transaction.**

Twelve new future backend tests **L1–L12** added to the lifecycle document —
last-unit concurrency, release-exactly-once for reject and cancel, duplicate
reject/cancel, both race orderings, retried expiry worker, stale revision,
command retry, reordered commands, and that a TTL deletion alone does not
restore stock.

**All L1–L12 are NOT RUN**, as are the existing **R33–R40**. No backend exists.
None is marked PASS, and none was treated as a blocker to this contract task.

## 10. Validation

| # | Command | Result |
|---|---|---|
| V1 | `git status --short` before work | **PASS** — clean; no `reset --hard` |
| V2 | branch / HEAD | **PASS** — main @ `517f879`, matched expected |
| V3 | `dart test test/order_lifecycle_test.dart` | **PASS** — **22** |
| V4 | `dart test test/order_lifecycle_race_test.dart` | **PASS** — **16** |
| V5 | `dart test test/order_lifecycle_forbidden_test.dart` | **PASS** — **18** |
| V6 | `dart test` (all `cp_contracts`) | **PASS** — **183** (was 126) |
| V7 | `dart run tool/print_permission_matrix.dart` + drift check | **PASS** — no drift (matrix untouched) |
| V8 | `flutter analyze` | **PASS** — `No issues found!` |
| V9 | `./tools/check_layering.sh` | **PASS** — 8 rules |
| V10 | `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| V11 | repository total | **PASS** — **224 tests across 10 of 15 members** (was 167) |

No FND-002 device/browser/platform check was rerun. No accepted FND-003A
focused suite was rerun for reassurance — they ran only as part of the standard
gate.

**Three pre-existing tests failed on first full run** and were updated: they
pinned `'0.2'`, which the deliberate version bump changed. A new test covering
0.2 ↔ 0.3 version policy was added alongside, still making no payload claim.

## 11. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/order_state.dart` | **new** — order states, executable vs declared-future |
| `packages/contracts/lib/src/reservation_state.dart` | **new** — reservation states and the at-most-once invariant |
| `packages/contracts/lib/src/lifecycle_effect.dart` | **new** — typed `InventoryEffect`, `FinancialClassification` |
| `packages/contracts/lib/src/lifecycle_command.dart` | **new** — named commands, permissions, event ids |
| `packages/contracts/lib/src/order_lifecycle.dart` | **new** — facts, request, outcome, deterministic evaluator |
| `packages/contracts/lib/cp_contracts.dart` | export the new surface |
| `packages/contracts/lib/src/contract_version.dart` | 0.2 → 0.3 with history |
| `packages/contracts/test/order_lifecycle_test.dart` | **new** — 22 |
| `packages/contracts/test/order_lifecycle_race_test.dart` | **new** — 16 |
| `packages/contracts/test/order_lifecycle_forbidden_test.dart` | **new** — 18 |
| `packages/contracts/test/{contract_version,command_envelope}_test.dart` | version pin 0.2 → 0.3 |
| `docs/contracts/order-reservation-lifecycle.md` | **new** — canonical lifecycle doc |
| `docs/contracts/README.md`, `version-history.md` | index and 0.3 history |
| `docs/task-ledger/TASK_LEDGER.md` | FND-003B1/B2/B3 entries |
| `docs/task-ledger/FND-003B1-completion-report.md` | this report |

Untouched: apps, backend, infra, all other packages, `pubspec.yaml`,
`pubspec.lock`. **No new dependency**; no Flutter or Firebase reference.

## 12. Out of scope

Not defined, guessed or partially implemented: picker/rider assignment
lifecycle, custody, delivery attempts, returns, delivery confirmation,
proof/dispute, payment and COD, cash journal, fees, commissions, settlement.

## 13. Ledger

FND-003B1 **DONE**; **FND-003B parent PARTIAL** (not done). Recorded without
starting: **FND-003B2** (assignment lifecycle) and **FND-003B3** (custody,
delivery-attempt, return). FND-003C remains **BLOCKED on O6**; FND-003D
unchanged; FND-004 unchanged; R33–R40 remain NOT RUN.

## 14. Scope statement

Contract and tests only. No backend handler, no Firestore rule, no application
feature, no platform dependency. Nothing merged to `main`, nothing pushed,
nothing deployed. **FND-003B2 not started.**

## 15. Recheck (FND-003B1-FIX-001, 2026-09-10)

The lifecycle design in this report is accepted and unchanged: the cancellation
split, the acceptance-versus-expiry race, financial deferral and the
unreachability of `in_delivery`/`delivered` all stand.

**One hole was found.** §7 of this report said the race outcome was safe
"structurally". That was true of the **transition graph** — it can never
*create* an impossible order/reservation pair — but the evaluator did not check
the facts it was *given*. `OrderLifecycleFacts` arrives from storage, and
nothing validated that the order state, reservation state, revision and unit
count formed a pair this lifecycle could ever have produced.

Reproduced against `697d170`:

| Malformed facts | Result before the fix |
|---|---|
| `placed + committed`, reject | **allowed**, restored 3 units |
| `accepted + active`, cancel | **allowed**, restored 3 units |
| `placed + active`, `reservedUnits: 0`, reject | **allowed**, zero-unit effect |
| `placed + active`, `reservedUnits: -5`, reject | **allowed**, `availableStockDelta = -5` |

The last is the worst: a negative unit count produced an inventory mutation
that would have **destroyed** stock rather than restoring it.

FND-003B1-FIX-001 adds one narrow aggregate-integrity boundary that runs before
any transition helper can produce an effect, makes the release paths
pair-specific, and corrects this report's "structurally" claim to state
precisely what the transition graph guarantees and what it does not. Full
detail: [FND-003B1-FIX-001 report](FND-003B1-FIX-001-completion-report.md).
