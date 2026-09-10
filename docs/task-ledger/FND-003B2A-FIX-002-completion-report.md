# FND-003B2A-FIX-002 completion report

- **Task:** Close the final regression-safety gaps in the picker assignment
  contract
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `ce44b292d6c9a4259f3f690d016bf95c4f1784de`, branch
  `fnd/FND-003B2A-picker-assignment-lifecycle`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.4 — no wire change**
- **Status:** **DONE**

Neither published commit was amended. One new commit. The tree was clean, so
**no `git reset --hard` was used**.

**This is a test-and-documentation change. Zero production code was modified**
— verified: `git diff --name-only -- packages/contracts/lib/` is empty. The
closure suite exposed no defect; the evaluator and the validator already
agreed.

## 1. Transition-closure guard

The invariant now pinned:

> apply(successful transition) → `validatePickerAssignmentAggregate` → **null**

Testing `reachableSlotRevisionRange` directly only proves the helper agrees
with itself. This ties the **actual evaluator output** to the validator, so if
either drifts the other catches it. Every fact comes from a real transition —
nothing hand-fabricated, because a fabricated pair could accidentally satisfy a
rule the lifecycle no longer produces.

Helper `closes(label, outcome)` asserts the operation was allowed, applies it
via the shared `apply()` fixture, requires the validator to return null, and
returns the next facts so a caller can chain a genuine history. Validation is
**not** hidden inside a production constructor.

| Case | History | Ends at |
|---|---|---|
| initial offer | empty slot | gen 1, rev 1 |
| accept | offer → accept | gen 1, rev 2 |
| decline | offer → decline | gen 1, rev 2 |
| expiry | offer → expire | gen 1, rev 2 |
| revoke | offer → accept → revoke | gen 1, rev 3 |
| re-offer after decline | + offer | gen 2, rev 3 |
| re-offer after expiry | + offer | gen 2, rev 3 |
| re-offer after revoke | + offer | gen 2, **rev 4** |
| gen-3 mixed | g1 revoked (3) → g2 declined (2) → offer | gen 3, rev 6 |
| gen-3 cheapest | g1 declined (2) → g2 expired (2) → offer | gen 3, **rev 5** |

The last two matter: they exercise the **maximum** and **minimum** of the
generation-3 range from real transitions rather than assertion. A further test
pins the command set, so adding a command without closure coverage fails.

## 2. Executable-state ↔ revision-model coupling

A structural test requires **every** state in
`AssignmentState.executableInThisSlice` to have a non-null
`reachableSlotRevisionRange`. Its failure message names the remedy:

> "If a state becomes executable, `reachableSlotRevisionRange` and
> transition-cost tests must be updated in the same contract change — otherwise
> every aggregate in that state fails closed as inconsistent."

Currently covers `offered`, `accepted`, `declined`, `expired`, `revoked`.
`completed` stays **outside** the executable set and correctly returns null; a
test asserts both, with the reason that its cost is unknown until FND-003B3
defines it and **guessing would corrupt the model**.

## 3. Both guards proven to fire

A guard that has never failed proves nothing, so each was deliberately broken:

| Negative control | Result |
|---|---|
| Range helper altered — `revoked` cost 3 → 4 | **FAILED as intended**, exit 1: *"revoke produced gen=1 rev=3 state=revoked, which the aggregate validator rejects — reachableSlotRevisionRange and the evaluator have drifted apart"* |
| `completed` added to `executableInThisSlice` without a cost | **FAILED as intended**, exit 1, with the maintenance message above |

Production code was restored byte-for-byte afterwards (verified by
`git diff --quiet`), and the suite returned to 89 passing.

## 4. Future `completed` maintenance rule

`docs/contracts/picker-assignment-lifecycle.md` now states that
`reachableSlotRevisionRange` is **arithmetic over the currently executable
transitions**, not an independent rule — and that the symptom of drift is
*valid histories failing closed*.

Any future change that makes `completed` executable, adds an executable state,
adds/removes a transition changing per-generation cost, or changes whether a
transition increments `slotRevision`, **must in the same change**: update the
helper; update the derivation and table; update the canonical/impossible range
tests; update the closure test; and prove every newly successful transition
still closes over the validator.

**No mutation cost for `completed` was invented.**

## 5. B3-C1 — future contract acceptance

Recorded under a new **"Future contract acceptance criteria"** heading,
deliberately separate from the backend P-series because it is a **contract
evolution** requirement checked by whoever changes the contract, not a
deployment test:

> **B3-C1** — If picker `completed` becomes executable, the implementing task
> updates the reachable slot-revision model, its derivation and range tests, and
> proves every newly successful transition closes over
> `validatePickerAssignmentAggregate`.

**Status: NOT RUN / FUTURE.** FND-003B3 has not started. It guards a future
change and is not a blocker to FND-003B2A.

## 6. P17 — unchanged

Ownership and status untouched: the evaluator rejects reuse of the **current**
attempt's id; uniqueness against **all archived** attempts needs
server-generated ids plus create-if-absent storage; **P17 remains NOT RUN**
until backend/storage exists. Both references in the lifecycle doc are intact.

## 7. Governance — unchanged

ADR-0006 is **byte-for-byte unmodified**. `agent.assignment.revoke_picker`
remains agent-only, `ownShop`, active membership, reason required.
`admin.assignment.override_picker` remains RESERVED/PROPOSED — **absent from
`Permission.values` and `permissionMatrix`** (verified, count 0). No new admin
permission was added.

## 8. Prior safety — no regression

Re-verified by the unchanged suites: same-id terminal reuse denial, stale
`assignmentId`, stale `generation`, stale `slotRevision`, accept-vs-expiry
exactly-one, unknown-custody revoke denial. All intact — and necessarily so,
since no production code changed.

## 9. Validation

| Command | Result |
|---|---|
| branch / HEAD / `git status` before work | **PASS** — `ce44b29`, clean, no reset |
| `git diff --name-only -- packages/contracts/lib/` | **PASS** — empty; test/docs only |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **89** (was 75) |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unchanged (ADR-0006 intact) |
| Negative control — broken range helper | **PASS (fired)** — exit 1 |
| Negative control — `completed` made executable | **PASS (fired)** — exit 1 |
| `dart test` all `cp_contracts` | **PASS** — **362** (was 348) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **403 across 10 of 15 members** (was 389) |

The full gate was run because **`AGENTS.md` §6 requires it before any task is
declared done**. It naturally re-executes accepted FND-002/FND-003A/FND-003B1
suites; that is **not** offered as new evidence for those completed tasks.

## 10. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/test/picker_assignment_integrity_test.dart` | +14 tests: transition closure across generations 1–3, executable-state coupling guard |
| `docs/contracts/picker-assignment-lifecycle.md` | maintenance invariant; B3-C1 under a new future-contract-criteria heading |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-002 entry; three-commit evidence chain |
| `docs/task-ledger/FND-003B2A-FIX-001-completion-report.md` | §11 recheck — annotated, not erased |
| `docs/task-ledger/FND-003B2A-FIX-002-completion-report.md` | this report |

Unchanged: **all** of `packages/contracts/lib/`, the shared test fixture,
ADR-0006, `Permission` values, `permissionMatrix`, `contract_version.dart`,
apps, backend, infra, `pubspec.yaml`, `pubspec.lock`.

## 11. Ledger

FND-003B2A evidence chain: **`355aaa7` + `ce44b29` + this commit** — no earlier
commit alone is the accepted contract. **FND-003B2 parent PARTIAL**;
**FND-003B2B NOT STARTED**; **FND-003B3 NOT STARTED**; FND-003C **BLOCKED on
O6**; FND-003D unchanged.

R33–R40, L1–L13, P1–P17 and B3-C1 all remain **NOT RUN**.

## 12. Contract version

**0.4, unchanged. No wire change**, no new serializer, no payload-compatibility
claim — this task added tests and documentation only.

## 13. Scope statement

No rider lifecycle, custody, delivery, return, proof/dispute or money rule was
introduced. No admin override implemented. **FND-003B2B and FND-003B3 remain
NOT STARTED.** Nothing merged to `main`, pushed, force-pushed or deployed.
