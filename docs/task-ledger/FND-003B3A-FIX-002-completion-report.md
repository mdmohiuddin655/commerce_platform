# FND-003B3A-FIX-002 completion report

- **Task:** Reconcile the FND-003B3A candidate's documentation and source
  comments with what it actually implements
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `18ad7504a7a84abcca526532305dffb5f2c68081`, branch
  `fnd/FND-003B3A-custody-handoff-contracts`, working tree clean
- **Reviewed base main:** `bfec4bea5dbfbc7316d10db9a898673111a4db68`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.6, unchanged**
- **Status:** **DONE**

**Documentation and source-comment only. Zero executable Dart changed** —
proven mechanically, see §7.

Neither `c29df0f` nor `18ad750` was amended. One new commit. The tree was clean,
so **no `git reset --hard` was used**, and no history was rewritten. Parent
chain verified before editing: `18ad750^ = c29df0f`, `c29df0f^ = bfec4be`.

## 1. Root cause

FND-003B3A made two previously-declared states reachable and FIX-001 corrected
the exported metadata, but the surrounding prose and comments were still
describing a pre-B3A world. Every finding below is a **false statement in
shipped documentation or source**, not a behaviour defect — the code was right
and the words were wrong.

## 2. Picker contract

| Was | Now |
|---|---|
| "`completed` is not range-checked; this slice does not implement it, so its cost is unknown" | `completed` **is** range-checked for the picker, through the role-aware form; the default role-less call still returns null |
| unqualified "No mutation cost is invented for `completed`" | cost is **role-specific**: the **picker** cost is defined by FND-003B3A (offer + accept + completion = 3, same per-generation cost as accept-then-revoke); **no cost for *rider* completion was invented** |
| **B3-C1 — NOT RUN / FUTURE**, "FND-003B3 has not started" | **B3-C1 — SATISFIED BY FND-003B3A CONTRACT TESTS**, with the closure evidence named (generations 1–3, revisions 3/6/9, from real evaluator-produced histories) and an explicit note that it is **not** persistence evidence (**CA9**, NOT RUN) |
| "`inDelivery` / `delivered` are not implemented anywhere" | `inDelivery` **is** reachable via rider receipt and is excluded from assignment-eligible states for a different reason; `delivered` remains unimplemented |
| "FND-003B3 will map real custody facts onto it" | FND-003B3A **now supplies those facts** via `reassignmentSafetyFor`; backend serialisation remains **CA23**, NOT RUN |
| out-of-scope: custody "delivered by FND-003B3A" | same, plus **FND-003B3 is PARTIAL** — acquisition and handoff done, delivery/refusal/returns not |

**P1–P17 untouched.**

## 3. Rider contract

§21 previously asserted **both** that B3-C1 was NOT RUN / FUTURE **and** that
FND-003B3A had satisfied it. That contradiction is resolved explicitly:

- **B3-C1 — SATISFIED BY FND-003B3A CONTRACT TESTS, picker completion only.**
  Contract-test evidence; the atomic commit is **CA9**, NOT RUN.
- **B3-C2 — NOT RUN / FUTURE**, rider completion only. Rider `completed`
  remains unreachable: excluded from `executableForRole(rider)`, reported by
  `notYetImplementedForRole(rider)`, null from the range helper, **no cost
  invented**.

Stale forward-looking language corrected in three further places: "FND-003B3
will map real facts onto it" and two instances of "once FND-003B3 exists" now
say that custody facts **exist since FND-003B3A**, while noting that custody
*after* dispatch — delivery, refusal, return — remains future and that backend
serialisation is still NOT RUN.

**FND-003B2B's own historical scope claims were not rewritten**: B2B genuinely
did not implement custody. The wording distinguishes "this slice" from current
repository state. **RA1–RA18 untouched.**

## 4. Order contract

| Was | Now |
|---|---|
| state table: `in_delivery` "Declared for enum stability; owned by a later slice" | **"not from this evaluator" — reachable since FND-003B3A**, produced only by rider custody receipt |
| canonical pair table ended at `cancelled` | **`in_delivery ↔ committed` added**, with a note that it is produced by the custody slice and is listed so `validateAggregate` rejects a malformed `in_delivery` aggregate |
| events section listed only the seven pre-dispatch ids | **`order.in_delivery` documented** as present in `LifecycleEventType.all` but emitted by rider receipt, **not** by `evaluateOrderTransition` |
| "`in_delivery` and `delivered` are declared but unreachable" | `delivered` unreachable; `in_delivery` reachable **through rider receipt only**, with no pre-dispatch edge invented |

**Preserved unchanged:** the evaluator owns pre-dispatch commands only and still
cannot act from `in_delivery`; `ready` cancellation stays `policyDeferred`;
`rejected`/`cancelled` terminal behaviour; no post-pickup cancellation decision;
**no inventory restoration after physical pickup**; no financial policy.

## 5. Contract index

- custody checklist **CA1–CA18 → CA1–CA23**;
- the B3A row now names create-once initialisation, canonical resource/shop
  binding and the four-aggregate compare-and-set, and records that the slice is
  a **candidate not yet accepted for merge**, corrected by FIX-001 and FIX-002;
- version-history row **"0.1 → 0.2 → 0.3"** → **"0.1 → 0.2 → 0.3 → 0.4 → 0.5 →
  0.6"**.

Prior task descriptions were not opportunistically redesigned.

## 6. Package and source comments

`cp_contracts.dart` announced **"Contract version 0.2"** and claimed the order,
assignment and custody lifecycles were undefined — false for this package. The
library doc now describes the 0.6 surface (envelopes, idempotency, identity,
authorization, order/reservation, picker and rider assignment, custody
acquisition and handoff) and lists what is still future (delivery, refusal,
returns and post-dispatch restoration, customer custody, rider completion,
direct shop→rider, handoff proof, payment/COD, cash/fees/commission/settlement,
proof/dispute). It states plainly that **there is no serialization and no
payload-compatibility claim at any version**. **No export changed.**

Four source comments corrected:

| File | Was | Now |
|---|---|---|
| `order_state.dart` — `inDelivery` | "no transition into it exists yet" | not executable by the pre-dispatch evaluator; **reachable since FND-003B3A**; shape known; cross-refers `outsideThisSliceEvaluator` and `aggregateShapeKnown` |
| `assignment_state.dart` — `completed` | "NOT EXECUTABLE — neither picker nor rider … no mutation cost guessed" | no command transitions into it **for either role**; **picker reachable** via custody receipt with a defined cost (B3-C1 discharged); **rider still future** with no cost (B3-C2) |
| `picker_assignment.dart` — `assignmentEligibleOrderStates` | "`inDelivery`/`delivered` are not implemented anywhere yet" | `inDelivery` is reachable but past the point where assignment work may be offered; `delivered` unimplemented |
| `assignment_effect.dart` — `ReassignmentSafety` | "FND-003B3 will map real custody state onto it" | **FND-003B3A now does**, via `reassignmentSafetyFor`, without weakening fail-closed; backend serialisation is **CA23** |

> **Scope note.** The last two files were **not** on this task's expected file
> list. They contained exactly the class of false statement this task exists to
> remove, and correcting them changed **only comments**. I extended slightly
> rather than knowingly leave two false claims in production source, and record
> the deviation here rather than passing it off as in-scope.

**Deliberately left alone:** `docs/contracts/{authorization-invariants,
command-and-event-envelopes, identity-membership-and-scope,
privacy-and-security-boundaries}.md` each open with "Contract version 0.2
(FND-003A)". That is an **introduced-at** statement — the same form as the
picker document's "Introduced at contract version 0.4" — not a claim about the
current version. Rewriting them would have destroyed legitimate history.
`version-history.md` needed no correction; its 0.6 semantics were already right.

## 7. Proof of zero behaviour change

```
git diff -U0 -- packages/contracts/lib \
  | grep -E "^[+-]" | grep -vE "^[+-][+-]" \
  | grep -vE "^[+-]\\s*(///|//)" | grep -vE "^[+-]\\s*$"
  → (ZERO non-comment Dart lines changed)
```

`git diff --name-only` over `packages/contracts/test/`, `permission.dart`,
`permission_matrix.dart`, `docs/contracts/permission-matrix.md`,
`docs/decisions/`, `apps/`, `backend/` and `infra/` is **empty**. No
constructor, field, enum member, set membership, condition, evaluator,
validation rule, permission, event value, revision formula or fixture behaviour
changed. No export changed. `ContractVersion.current` is still `0.6`.

The identical test counts in §10 are the corroborating evidence.

## 8. Future acceptance — all unchanged

**R33–R40 NOT RUN · L1–L13 NOT RUN · P1–P17 NOT RUN · RA1–RA18 NOT RUN ·
CA1–CA23 NOT RUN.**

**B3-C1 — SATISFIED BY CONTRACT TESTS ONLY** (picker completion). Not backend
persistence evidence. **B3-C2 — NOT RUN / FUTURE** (rider completion).

P13/P14, RA14/RA15 and the CA persistence/transaction criteria remain backend
evidence. **Fixtures are test infrastructure, not persistence proof.** No
Firebase, platform or backend criterion became PASS.

## 9. Evidence history — nothing erased

| Point | Value | Status |
|---|---|---|
| Branch-point baseline (`bfec4be`) | **520** | preserved, as corrected by FIX-001 |
| `c29df0f` candidate | **601** cp_contracts / **642** repository | preserved |
| `18ad750` FIX-001 | **631** cp_contracts / **672** repository | preserved |
| This commit | **631** / **672** — *identical*, as expected for a docs-only change | newly executed |

The original B3A report, its §17 annotation, the 522→520 correction and the
FIX-001 report all remain in place. FIX-001 gained a **§15 recheck** recording
that FINAL-REVIEW-002 found this drift; it was annotated, not rewritten.

## 10. Validation

Consistency sweeps (`git grep`) for `FND-003B3 has not started`, `not
implemented anywhere`, `not range-checked`, `once FND-003B3 exists`,
`FND-003B3 will map`, `CA1–CA18`, `Contract version 0.2` and the version-history
row — **all clear** across `docs/contracts` and `packages/contracts/lib`, with
the four legitimate historical `0.2` headers deliberately retained (§6).

| Command | Result |
|---|---|
| branch / HEAD / parent chain / `git status` before work | **PASS** — `18ad750`, chain intact, clean, no reset |
| `dart test test/order_lifecycle_aggregate_test.dart` | **PASS** — **41** |
| `dart test test/order_lifecycle_forbidden_test.dart` | **PASS** — **18** |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **96** |
| `dart test test/rider_assignment_integrity_test.dart` | **PASS** — **71** |
| `dart test test/custody_lifecycle_test.dart` | **PASS** — **62** |
| `dart test test/custody_integrity_test.dart` | **PASS** — **47** |
| `dart test test/contract_version_test.dart` | **PASS** — **11** |
| `dart test` all `cp_contracts` | **PASS** — **631**, unchanged |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **672 across 10 of 15 members**, unchanged |

Every count is **identical to FIX-001's**, which is the expected result for a
documentation-only change and is itself corroboration of §7. These were
**actually executed**, not copied forward.

**NOT RUN:** FND-002 platform/device checks, Firebase/emulator, Firestore rules,
indexes, backend persistence, deployment, and CA/R/L/P/RA. **BLOCKED:** none.

**GitHub CI:** there is **no CI evidence** for this candidate — the repository
has no configured checks. Local executor gate evidence and GitHub CI evidence
are distinct, and nothing here claims the latter.

## 11. Files

**Documentation (6):** `docs/contracts/README.md`,
`order-reservation-lifecycle.md`, `picker-assignment-lifecycle.md`,
`rider-assignment-lifecycle.md`; `docs/task-ledger/TASK_LEDGER.md`,
`FND-003B3A-FIX-001-completion-report.md` (§15 annotation).

**Source comments only (5):** `packages/contracts/lib/cp_contracts.dart`
(library doc), `lib/src/order_state.dart`, `lib/src/assignment_state.dart`,
`lib/src/picker_assignment.dart`, `lib/src/assignment_effect.dart`.

**New (1):** `docs/task-ledger/FND-003B3A-FIX-002-completion-report.md`.

**Unchanged:** `version-history.md` (already correct), every test file, every
fixture, `custody_*.dart`, `rider_assignment.dart`, `assignment_integrity.dart`,
`order_lifecycle.dart`, `contract_version.dart`, `permission.dart`,
`permission_matrix.dart`, the generated matrix, ADR-0006, ADR-0007, apps,
backend, infra, Firebase config, `pubspec.*`. **No dependency added.**

## 12. Ledger

**Candidate chain: `c29df0f` + `18ad750` + this commit.** Neither `c29df0f`
alone nor `c29df0f` + `18ad750` alone is the candidate contract after
FINAL-REVIEW-002, and **FND-003B3A-FIX-002 itself still requires final
read-only acceptance before merge.**

**FND-003B3 PARTIAL · FND-003B PARTIAL · delivery/refusal/return slice
(FND-003B3B) NOT STARTED · FND-003C BLOCKED on O6 ·** FND-003D unchanged.
Contract **0.6**.

## 13. Contract

**0.6, unchanged.** No command, state, transition, denial, effect, permission,
event, migration or serialization was added. **No payload-decoding
compatibility claim** — `cp_contracts` still has no serialization.

## 14. Scope statement

Documentation and source comments only. Nothing pushed, merged, rebased,
amended, force-pushed or deployed; no PR created. **FND-003B3B not started.**
