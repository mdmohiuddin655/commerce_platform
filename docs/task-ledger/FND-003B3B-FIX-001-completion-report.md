# FND-003B3B-FIX-001 completion report

- **Task:** Correct exactly the two material findings from
  **FND-003B3B-FINAL-REVIEW-001**. **Documentation, source-comment and test
  only.**
- **Owner project:** ADMIN / shared foundation / `cp_contracts`
- **Date:** 2026-09-11
- **Branch:** `fnd/FND-003B3B-attempt-return-contract` (existing, **unpushed**)
- **Starting HEAD:** `8ccb5aa8e51598c2a2be8da7a3493c818c90af8c`
- **Base of the candidate:** `8210323f3037e4bd193e93d7300234412a5ce272`
- **Contract version:** **0.10 — unchanged**
- **Status:** **DONE** — the corrected **two-commit** candidate requires a
  **new, separate read-only final review**. It is **not** accepted.

## 1. Baseline

```text
git status --porcelain --untracked-files=all   (empty)
git branch --show-current                      fnd/FND-003B3B-attempt-return-contract
git rev-parse HEAD                             8ccb5aa8e51598c2a2be8da7a3493c818c90af8c
git rev-parse HEAD^                            8210323f3037e4bd193e93d7300234412a5ce272
git rev-parse origin/main                      8210323f3037e4bd193e93d7300234412a5ce272
remote feature branch                          ABSENT (unpushed)
```

**The review found no defect in the executable contract.** Both findings are
documentation/evidence defects, and both are corrected without changing
behaviour.

## 2. M1 — the enum's own invariant block had been falsified by its own commit

`ReservationState`'s class-level section, titled *"The invariant this enum
exists to protect"*, still read:

```text
cannot distinguish the four situations that matter
Restoration happens exactly on the transition into [released] or [expired]
```

FND-003B3B had already made both false. There are **five** states, and a
`restockable` inspection producing `returned` is a **third** restoration site.

**Why this mattered more than a typo.** That block is where a reader goes to
learn every place stock can be restored. It said there were two, authoritatively
and in the present tense, in the same commit that added a third — so a future
implementer auditing restoration paths would have found two of three and stopped
looking. That is how a missed or doubled restore gets written.

The commit had corrected `isFinal`'s doc seventy lines below, which made the
file *read* as though it had been reconciled. It had not been.

### The correction

The block now enumerates all three restoration sites explicitly:

```text
-> released   pre-dispatch: rejected or cancelled     stock IS restored
-> expired    pre-dispatch: the expiry worker acted   stock IS restored
-> returned   post-dispatch: restored ONLY for a restockable disposition;
                             damaged and quarantined restore NOTHING
```

and states the distinction the rest of the file depends on: **"this reservation
is final" must never be read as "available stock increased"**, because for a
damaged or quarantined return those are opposite answers. The count is corrected
to five, and the note records that the earlier text was falsified rather than
quietly rewriting history.

**Comments only.** Comment-stripped SHA-256 is identical before and after:

```text
013b1932aebeea1a1c01a9969ba5ceef3ab59b681a5bc921287523a6cee813d8   (26 code lines)
```

## 3. M2 — the return is whole-order only, and nothing said so

The limit was real in the code and stated nowhere: one `ReturnDisposition`
covers the entire committed reservation, `restore` always moves the canonical
`order.reservedUnits`, and no request carries a quantity.

**Why the silence was the defect.** `ReturnDisposition` reads naturally as a
judgement about *goods*, so a backend author could reasonably assume a mixed
return — *"three of the five items are fine, two are broken"* — is expressible.
It is not. And with one disposition per reservation, a mixed return has exactly
two representable answers, **both wrong**:

```text
restockable -> over-restocks the whole order, putting broken goods back on sale
damaged     -> writes off items that were perfectly sellable
```

The first is precisely the failure the restock invariant exists to prevent.
Refusing to represent the case is safer than representing it badly: an
unrepresentable case fails visibly at design time, a silently-wrong one fails as
bad stock.

### The correction

`docs/contracts/delivery-attempt-return-lifecycle.md` gains a normative
**"Scope: whole-order returns only"** section stating that partial, per-line,
per-item and per-quantity dispositions are **not modelled**, that a caller
cannot choose the quantity, that `restockable` restores exactly
`order.reservedUnits` and `damaged`/`quarantined` restore zero, that a mixed
outcome is **not representable**, and that future partial-return support needs
its own additive contract and **must not reinterpret this API**.

It is framed as *the contract cannot represent this*, not as *a backend rejects
it* — there is no backend.

**ADR-0010** gains **Decision 4** recording the same durable decision with the
over-restock reasoning, the reason quantity is not caller-supplied, and the
expansion path. Two rows were added to its rejected-alternatives table. No
unrelated ADR decision was touched.

## 4. Tests added — four, in `attempt_return_inventory_test.dart`

| Test | What it pins |
|---|---|
| `restockable restores exactly the canonical reservedUnits` | Sweeps `reservedUnits` ∈ {1, 3, 7, 42} and asserts `inventoryEffect.units`, `availableStockDelta` and `reservationEffect.units` all equal **N** — a hardcoded constant matching one fixture cannot pass |
| `damaged and quarantined restore zero whatever the reserved count` | Both dispositions × {1, 7, 42}: delta **0**, while the reservation still records the full count it held |
| `no public request type carries a caller-controlled quantity` | **Static type pins** — the `ReturnInspectionRequest.new` and `ReturnShopReceiptRequest.new` tear-offs must stay assignable to their exact signatures — **plus** a scan restricted to the `final X y;` **field declarations** of the request source |
| `exactly one disposition covers the whole reservation` | The return aggregate declares exactly `final ReturnDisposition? disposition;` — one nullable value, never a collection — and one disposition covers all five reserved units |

### `dart:mirrors` was tried first and rejected

Reflection would have enumerated the declared fields directly, and it **runs**
correctly on the VM. But the analyzer rejects the import in this package —
`Target of URI doesn't exist: 'dart:mirrors'`, 19 errors — which would have
failed the clean-analyze gate. The static tear-off pins plus the
field-declaration scan are the analyzer-clean equivalent, and the scan is
deliberately narrowed to declaration lines so prose in a doc comment can neither
trigger nor mask it. **No partial-return type was invented in order to assert
its absence.**

## 5. Negative control

```text
mutation : final int units = orderRead.order.reservedUnits;
        -> final int units = 3;                   (independently supplied)
test     : restockable restores exactly the canonical reservedUnits
result   : FAILED as required — Expected: <1>  Actual: <3>  at reservedUnits=1
revert   : BYTE-IDENTICAL
           948e07bf35bc10e78ab22996e8d92a961c9fc13f8a18d9f2de6fc56297fb9684
residue  : grep "NC PROBE" -> 0
after    : 00:00 +15: All tests passed!
```

The failure is for the intended reason, and the multi-value sweep is what
catches it: a single-fixture assertion would have passed against the constant.

## 6. Zero executable change

```text
changed .dart under lib/ : packages/contracts/lib/src/reservation_state.dart  (comments only)
comment-stripped sha256  : IDENTICAL before and after
non-comment +/- lines in the lib/ range diff : 0
ContractVersion.current  : ContractVersion(0, 10)
Permission.values        : 39      permissionMatrix : 39
```

No evaluator, facts, request, transition, effect, permission, authorization,
attempt/return state, order, custody or assignment behaviour changed. No
dependency, config, app, backend, infra or Firebase file was touched. No
historical completion report was rewritten.

## 7. Validation

```text
$ cd packages/contracts && dart analyze
No issues found!                                        EXIT=0

$ dart test
00:01 +1085: All tests passed!                          EXIT=0   (1081 + 4 new)

$ dart test test/attempt_return_inventory_test.dart     +15  All tests passed!
$ dart test test/return_lifecycle_test.dart             +19  All tests passed!
$ dart test test/delivery_attempt_test.dart             +26  All tests passed!
$ dart test test/attempt_return_forbidden_test.dart     +22  All tests passed!
$ dart test test/attempt_return_authority_test.dart     +14  All tests passed!

$ flutter analyze                     # workspace root
No issues found! (ran in 2.0s)                          EXIT=0

$ ./tools/check_layering.sh
LAYERING CHECK: PASS                                    EXIT=0

$ ./tools/run_checks.sh
ALL CHECKS PASSED                                       EXIT=0

$ git diff --check                                      EXIT=0
```

`dart format` was run in write mode on **only** the one test file this task
changed; no unrelated baseline file was reformatted, and the repository-wide
pre-existing format debt recorded in the FND-003B3B report is untouched.

**GitHub CI: NONE** — no `.github` directory exists. The local gate is not CI.

## 8. Preserved

Attempt graph `pending → out_for_delivery → refused | failed`; `delivered`
non-executable; refusal still atomically opens the required return; failed
attempt still defers; return route `rider → shop` only with
`required → in_transit → received → inspected → closed`; via-picker still
refused; custody receipt still `rider → shop` exactly once;
`agent.return.record_receipt` unchanged; **ContractVersion 0.10**; permissions
**39**.

**Successful delivery, customer custody, rider completion and dispute
resolution all remain unavailable. B3-C2 remains FUTURE. The
proof-satisfaction policy remains undefined and `CONSTRAINTS.md` invariant 13 is
NOT discharged.** No fee, refund, liability, commission or settlement behaviour
was added; **O6** is unresolved.

## 9. Evidence status — unchanged, none promoted

**DPD1–DPD12 · DPA1–DPA18 · CA1–CA23 · R33–R40 · L1–L13 · P1–P17 · RA1–RA18 all
NOT RUN.** **ATT1–ATT9 and RET1–RET8 remain NOT RUN.** B3-C1 remains
contract-test evidence only; **B3-C2 FUTURE**. **D2A criterion 48 remains FAIL**
under its recorded one-time pre-publication exception, not used as precedent —
this task performed no amend. Migration **NOT APPLICABLE / NOT RUN**; rules and
indexes **NOT IMPLEMENTED / NOT RUN**; deployment **NOT RUN**.

FND-003B **PARTIAL** · FND-003D **PARTIAL** · FND-003C **BLOCKED on O6** ·
FND-004 **TODO** · **O6 / O7 outstanding**.

## 10. Process

Exactly one new normal commit on top of `8ccb5aa8…`. **No** amend, rebase,
squash, cherry-pick, merge, `reset --hard`, force-push or push; the branch
remains **local only**. No PR, tag, release, GitHub-setting change, deployment
or Firebase/live-data access. **No later roadmap task started.**

## Owner actions needed

None new. **O6** and **O7** remain outstanding, unchanged.
