# FND-003B3B completion report

- **Task:** Delivery attempt and return lifecycle — the bounded **non-success**
  path after dispatch, plus safe post-dispatch inventory disposition.
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Base:** `main` @ `8210323f3037e4bd193e93d7300234412a5ce272`
- **Branch:** `fnd/FND-003B3B-attempt-return-contract` (new, from that commit)
- **Contract version:** **0.9 → 0.10** (additive)
- **Status:** **DONE — NOT ACCEPTED.** One local commit, **not pushed**,
  returned for a separate read-only final review.

## 1. Scope, and what it deliberately excludes

**This task did not make successful delivery executable, and could not have.**
`CONSTRAINTS.md` invariant 13 is **not discharged**.

Implemented:

```text
attempt:  pending ──▶ out_for_delivery ──▶ refused
                                       └─▶ failed
return:   not_required ──(refusal)──▶ required ──▶ in_transit
                                   ──▶ received ──▶ inspected ──▶ closed
custody:  rider → shop, exactly once, on shop receipt
stock:    restored exactly once, ONLY on receipt + restockable inspection
```

## 2. Attempt and return are separate dimensions from the order

The order does not move at all in this slice. Folding either dimension into
`OrderState` would make *"refused once, back at the shop, inspected and
unsellable"* indistinguishable from *"cancelled before it ever left"*, and would
force a post-dispatch order state to be invented — which is inventing the
commercial outcome.

Attempt and return each carry **their own opaque id / revision**, independent of
the order, custody and rider-slot revisions. Five aggregates change at different
rates; sharing a counter would report a conflict on every unrelated write and
hide the real one.

## 3. Refusal opens the return atomically

One transition carries both halves:

| | |
|---|---|
| attempt | `out_for_delivery → refused`, revision +1 |
| return | `not_required → required`, revision +1 |
| order | **unchanged** |
| custody | **unchanged**, still the rider's |
| rider assignment | **unchanged**, not completed |
| reservation | still `committed` |
| inventory | **NONE** |
| financial | `deferredToFinancialSlice` — **UNKNOWN, never zero** |
| events | `delivery.attempt_refused`, `return.required` |

Splitting the two would permit a refusal with nothing saying the goods must come
back, and a return nobody asked for.

## 4. Failure invents no policy — enforced structurally

The blueprint says a failed attempt *may* require a return. Nothing accepted says
**when**, who decides, how many retries are allowed, or who bears the cost.

- `evaluateRecordDeliveryFailure` **has no return parameter at all.** It cannot
  open a return even if someone later added the code — the facts are not in
  scope, so a future edit must change the signature, which is a reviewable
  event. This is the contract, not a comment.
- `evaluateFailedAttemptReturnDecision()` is enumerated and always refused with
  `failureReturnPolicyDeferred`.

## 5. The restock invariant, and how double-restore is made impossible

> Reserved units may become available stock again only after the shop has the
> goods back **AND** has looked at them, and then exactly once.

Both halves are checked **independently** — the return must be `received` *and*
custody must actually be at the canonical shop — rather than one being inferred
from the other's state name.

| Disposition | Reservation | `availableStockDelta` | Events |
|---|---|---|---|
| `restockable` | → `returned` | **+units** | `return.inspected`, `return.stock_restored` |
| `damaged` | → `returned` | **0** | `return.inspected` |
| `quarantined` | → `returned` | **0** | `return.inspected` |

Three independent guards against a second restore:

1. inspection requires the return to be exactly `received`; a replay finds
   `inspected` and is refused;
2. inspection requires the reservation to be `committed`; after the first it is
   `returned`, so even a forged `received` return cannot restore again;
3. `return.close` requires the reservation to be **already** `returned`, so
   closing can never be the transition that ends a live reservation and can
   never carry an inventory effect.

A sweep test enumerates **all nine** executable transitions and asserts exactly
one increases available stock and exactly one moves custody.

## 6. `ReservationState.returned` is not `released`

`released` carries a promise — *its units were restored to available stock* —
that every path into it honours and that code and audit both rely on.

A returned reservation cannot make that promise: it depends on the disposition.
Overloading `released` would either make its promise **false for damaged goods**,
silently turning breakage into sellable stock in every downstream reader, or
force every reader to re-derive the disposition before trusting a state name.

`canonicalAggregatePairs[in_delivery]` becomes `{committed, returned}` — after an
inspected return the order is still `in_delivery` while its reservation has
ended. Recorded in **ADR-0010**.

## 7. Authorization

Every executable operation requires FND-003A's unforgeable `AuthorizationGrant`,
checked by `checkAttemptReturnAuthorization` against the actor, the operation's
permission and the resource. `expectedResourceId` is taken from the **read-set**,
never from `grant.resourceId` — that tautology was shipped and removed by
FND-003D2B-FIX-003, and restoring it would prove only the principal binding.

**One permission added:** `agent.return.record_receipt` (agent, `ownShop`,
reason required). Shop-side receipt authority did not exist.
`agent.fulfillment.record_progress` was **not** widened — its own rule says it
never writes trusted stock, order status or cash fields, and a return receipt is
the fact the whole restock invariant hangs from. No admin custody override.

`Permission.values` and `permissionMatrix`: **38 → 39**.

`rider.delivery.record_attempt` (attempt edges) and `admin.return.administer`
(transit, inspection, close) were reused **unchanged**, and tests assert their
rules were not widened.

## 8. Per-operation read-sets, enforced by the type system

| Operation | attempt | return | order | custody | rider assignment |
|---|:-:|:-:|:-:|:-:|:-:|
| out for delivery | ✓ | — | ✓ | ✓ | ✓ |
| refusal | ✓ | ✓ | ✓ | ✓ | ✓ |
| **failure** | ✓ | **—** | ✓ | ✓ | ✓ |
| begin transit | ✓ | ✓ | ✓ | ✓ | — |
| shop receipt | — | ✓ | ✓ | ✓ | ✓ |
| inspection | — | ✓ | ✓ | ✓ | — |
| close | — | ✓ | ✓ | — | — |

FND-003D2B shipped one evaluator with a shared read-set and FND-003D2B-FIX-001
had to split it, because **a shared read-set silently becomes a shared
precondition**. This slice starts split.

## 9. Files changed

**New production (13):** `delivery_attempt_state.dart`, `return_state.dart`,
`delivery_attempt_command.dart`, `return_command.dart`,
`delivery_attempt_return_denial.dart`, `delivery_attempt_return_facts.dart`,
`delivery_attempt_return_authorization.dart`,
`delivery_attempt_return_validation.dart`, `delivery_attempt_return_effect.dart`,
`delivery_attempt_return_transition.dart`,
`delivery_attempt_return_request.dart`,
`delivery_attempt_return_evaluator.dart`, `delivery_attempt_return.dart`.

**Modified production (6):** `cp_contracts.dart` (one export),
`contract_version.dart` (0.10 + history), `permission.dart` (+1),
`permission_matrix.dart` (+1 rule), `reservation_state.dart` (+`returned`),
`order_lifecycle.dart` (`in_delivery` pairing).

**New tests (6):** `support/attempt_return_fixtures.dart`,
`delivery_attempt_test.dart`, `return_lifecycle_test.dart`,
`attempt_return_authority_test.dart`, `attempt_return_forbidden_test.dart`,
`attempt_return_inventory_test.dart`.

**Modified tests (6):** version and permission-count pins in
`command_envelope_test.dart`, `contract_version_test.dart`,
`delivery_proof_assessment_regression_test.dart`,
`delivery_proof_dispute_authority_test.dart`,
`delivery_proof_dispute_regression_test.dart`, `delivery_proof_test.dart`. Each
kept its original intent — the forbidden-id guards are untouched — and records
that FND-003B3B is the one later addition.

**Docs:** new `delivery-attempt-return-lifecycle.md`, new **ADR-0010**;
updated `README.md`, `custody-lifecycle.md`,
`order-reservation-lifecycle.md`, `permission-matrix.md` (**regenerated from
source** with `tool/print_permission_matrix.dart`, 39 rows),
`version-history.md`, `TASK_LEDGER.md`, and this report.

## 10. Validation — real output

```text
$ git status --porcelain --untracked-files=all      (clean before work)
$ git rev-parse main                                8210323f3037e4bd193e93d7300234412a5ce272
$ git rev-parse origin/main                         8210323f3037e4bd193e93d7300234412a5ce272  (ls-remote agrees)

$ cd packages/contracts && dart analyze
No issues found!                                    EXIT=0

$ dart test
00:01 +1081: All tests passed!                      EXIT=0    (baseline 989 + 92 new)

$ dart test test/delivery_attempt_test.dart         +26  All tests passed!
$ dart test test/return_lifecycle_test.dart         +19  All tests passed!
$ dart test test/attempt_return_authority_test.dart +14  All tests passed!
$ dart test test/attempt_return_forbidden_test.dart +22  All tests passed!
$ dart test test/attempt_return_inventory_test.dart +11  All tests passed!

$ flutter analyze                  # workspace root
No issues found! (ran in 2.0s)                      EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS                                EXIT=0

$ ./tools/run_checks.sh
WORKSPACE CHECK: PASS (15 declared members)
LAYERING CHECK: PASS
ALL CHECKS PASSED                                   EXIT=0

$ git diff --check                                  EXIT=0
```

### `dart format` — the honest result

```text
$ dart format --output=none --set-exit-if-changed <the 19 new files>
EXIT=0   — all new files are format-clean
```

**The repository as a whole is not `dart format` clean, and was not before this
task.** Verified against a pristine export of the base commit:

```text
baseline 8210323, packages/contracts: 57 of 96 files would be reformatted
```

Running a repo-wide format would have produced a ~67-file diff unrelated to this
slice, so only the new files were formatted. This is reported rather than
silently normalised or silently skipped.

## 11. Negative controls

Each mutation was applied to production source, the **named** test was run, and
the file was restored from a pre-mutation copy with its SHA-256 re-verified.

| # | Mutation | Named test | Result | Revert |
|---|---|---|---|---|
| NC1 | remove the attempt resource binding | `a cross-resource read fails closed on every aggregate` | **failed as required** | byte-identical |
| NC2 | remove the rider custody binding | `custody bound to another attempt fails closed` | **failed as required** | byte-identical |
| NC3 | bypass the authorization binding | `authorization cannot be bypassed` (6 of 9 failed) | **failed as required** | byte-identical |
| NC4 | make shop receipt restore stock | `exactly one transition increases available stock` | **failed as required** | byte-identical |
| NC5 | restock damaged and quarantined goods | `damaged and quarantined never increase available stock` | **failed as required** | byte-identical |
| NC6 | let a duplicate inspection restore twice | `a replayed inspection cannot restore a second time` | **failed as required** | byte-identical |
| NC7 | make `delivered` executable | `recordDelivered is enumerated and always refused` | **failed as required** | byte-identical |

Post-revert SHA-256, matching the pre-mutation baseline exactly:

```text
0dd4e7323df9d522d0d0682125460859620e9741c0dfc0367c37eac1756f3825  delivery_attempt_return_evaluator.dart
ea34ea50eb004d56236107164dda64f6a920fffdba402532e5a0a101d6e90724  return_state.dart
a6859da82a042df67edafbea5df90212b5e5612b71b57d27111b4c4a7cda9409  delivery_attempt_command.dart
```

**No probe marker is committed** — `grep` for every NC marker across `lib/` and
`test/` returns **0**, and the full suite passes at 1081 afterwards.

### A process note worth recording

The first NC1/NC2 run used `git checkout --` to revert. The new files are
**untracked**, so the revert silently failed and left both probes applied. It
was caught by the byte-identical check, the file was repaired, the suite
re-verified at 1081, and every control was re-run with a copy-based restore.
**The verification caught it; a report that only claimed "reverted" would not
have.**

## 12. Semantic greps — comments stripped, code only

Across all 13 B3B production sources:

```text
OrderState.delivered            0
CustodyHolderKind.customer      0
AssignmentState.completed       0
ReservationState.released       0
DeliveryAttemptState.delivered  3   ← all three inside the enum's OWN declaration
                                      (id switch, notYetImplemented, isTerminal);
                                      the evaluator mentions "delivered" 0 times
otp / qr / signature / photo / gps / biometric        0 each
fee / refund / liability / commission / settlement /
amount / minorunits                                   0 each
toJson / fromJson / Firebase / Firestore / http       0 each
```

`minorunits` is scanned instead of `currency` because an earlier slice found
that `currency` also matches **con**curren**cy** in its own prose.

## 13. Counts

```text
ContractVersion.current    0.10
Permission.values          39        permissionMatrix   39
AttemptReturnDenial        32 values
attempt commands           4  (3 executable)
return commands            4
attempt events             3         return events      6
ReservationState.values    5  (+returned)
```

## 14. Backend criteria — ATT1–ATT9, RET1–RET8, all NOT RUN

Listed in full in
[delivery-attempt-return-lifecycle.md](../contracts/delivery-attempt-return-lifecycle.md)
§12. **Pure Dart tests are contract evidence, not persistence evidence.** In
particular **ATT1** — that the first attempt is created create-if-absent and
atomically with or causally bound to the dispatch boundary — is **NOT RUN**: a
Dart fixture cannot prove a storage transaction, and `initialiseDeliveryAttempt`
returning `allow` proves only that the facts handed in permit creation.

**Migration: NOT APPLICABLE / NOT RUN** — no persistence was added.
**Rules / indexes: NOT IMPLEMENTED / NOT RUN. Deployment: NOT RUN.**
**GitHub CI: NONE** — no `.github` directory exists; the local gate is not CI.

## 15. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 all
remain NOT RUN.** **B3-C1** remains contract-test evidence only; **B3-C2 remains
FUTURE / NOT RUN** — rider `completed` is still unreachable and its revision cost
is still not invented. **FND-003D2A criterion 48 remains FAIL** under its
recorded one-time pre-publication exception, and was not used as precedent: this
task performed no amend.

## 16. Status

| Task | Status |
|---|---|
| **FND-003B3B** | **DONE — NOT ACCEPTED**, awaiting a separate read-only final review |
| FND-003B / FND-003B3 | **PARTIAL** — successful delivery still outstanding |
| FND-003D | **PARTIAL** — the proof-satisfaction policy is still undone |
| Dispute resolution | **NOT STARTED / DEFERRED** — **O6**, FND-003C |
| FND-003C | **BLOCKED on O6** |
| FND-004 | **TODO** |
| O6 / O7 | **outstanding** |

`CONSTRAINTS.md` invariant 13 is **not discharged**: successful delivery,
customer custody, rider completion, the failed-attempt consequence, and every
money and dispute outcome remain **unavailable**.

Nothing was pushed, merged, amended, rebased, squashed, cherry-picked or
force-pushed; no branch was deleted; no PR, tag or release was created; no
GitHub setting was changed; no deployment happened and no Firebase or live data
was touched. **No later roadmap task was started.**

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.
