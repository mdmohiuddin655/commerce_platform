# FND-003B2A-FIX-001 completion report

- **Task:** Close the remaining FND-003B2A integrity and governance gaps
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `355aaa7dd7831d7b9c2a5657719780ae70e6a10d`, branch
  `fnd/FND-003B2A-picker-assignment-lifecycle`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.4, corrected in place** (no bump)
- **Status:** **DONE**

`355aaa7` was not amended. One new commit on the same branch. The tree was
clean, so **no `git reset --hard` was used**.

## 1. Assignment id uniqueness

**Defect, reproduced against `355aaa7` before changing anything:** re-offering
after a terminal attempt with that attempt's **own** `assignmentId` was
**allowed**, producing generation 2 carrying generation 1's identifier.

```text
re-offer same id after declined: ALLOWED gen=2 id=asg_Aa11Bb22Cc33Dd44
re-offer same id after expired:  ALLOWED gen=2 id=asg_Aa11Bb22Cc33Dd44
```

Two attempts would have been indistinguishable in every event stream, audit
record and stored document.

**Fixed:** a new offer whose `newAssignmentId` equals the current terminal
attempt's id denies with the new `AssignmentDenial.assignmentIdReuse`. Tested
for `declined`, `expired` and `revoked`; a genuinely new id remains allowed and
still advances the generation. Advancing the generation is explicitly **not** a
substitute for a distinct identity, and a test says so.

**Historical boundary, stated rather than papered over.** The evaluator sees
only the attempt currently in the slot, so it cannot prove a proposed id was
never used by an older *archived* attempt. Proving that in pure Dart would mean
carrying every historical id in the order aggregate — the unbounded array the
storage note warns against. It is a storage guarantee: server-generated ids,
create-if-absent attempt records, reuse of any prior id rejected, history never
overwritten.

**P17** records it, and remains **NOT RUN**.

## 2. Generation and revision coherence

**Overclaim, reproduced:** the FND-003B2A report listed "slot-revision
coherence" among validated invariants. The code checked only `generation >= 1`
and `slotRevision >= 1`, so all of these **validated**:

```text
gen2 offered at rev1:  ALLOWED
gen2 offered at rev2:  ALLOWED
gen1 offered at rev99: ALLOWED
```

**Fixed** with `reachableSlotRevisionRange(generation, state)`, derived from the
state machine rather than asserted: every attempt costs at least two mutations
(offer + decline/expiry) and at most three (offer + accept + revoke), so the
`g-1` prior attempts consumed `2(g-1)`…`3(g-1)` revisions and the current
attempt adds one, two or three.

| State | Reachable `slotRevision` |
|---|---|
| `offered` | `2g-1` … `3g-2` |
| `accepted` / `declined` / `expired` | `2g` … `3g-1` |
| `revoked` | `2g+1` … `3g` |

Validated **before any effect**. Thirteen impossible pairs fail closed —
including three **above** the maximum (`gen1 offered at rev2`, `rev99`,
`gen1 accepted at rev5`), not merely below the minimum. Eleven canonical pairs
remain valid, covering gen 2 offered at both rev 3 (prior attempt declined or
expired) and rev 4 (prior attempt revoked).

`completed` is deliberately **not** range-checked: this slice does not
implement it, so its cost is unknown and inventing one would be a guess.

**Generation stays distinct from `slotRevision`** — a full offer→accept→revoke
cycle ends at generation 1, revision 3, asserted by test.

The helper is exported so a backend reconciliation job applies the identical
rule rather than reimplementing it.

## 3. Stale command safety — unchanged and extended

`expectedSlotRevision`, exact `assignmentId` and exact `generation` are all
still checked, identity before generation before state. New combinations
tested: old id + old generation; old id carrying the **new** generation; new id
carrying the **old** generation. All produce `transition == null` — therefore no
projection effect, no event, no inventory, financial or custody effect.

## 4. Governance decision — ADR-0006

`agent.assignment.revoke_picker` **remains agent-only**: active membership,
`ownShop`, reason required, controlled reassignment only, proven-no-custody
still mandatory. **`CommerceRole.admin` was not added.**

[ADR-0006](../decisions/ADR-0006-admin-picker-assignment-override.md) records
why the one-line widening is wrong — the two operations differ in actor, scope,
normality, oversight and blast radius — and binds any future admin workflow to:
a separate permission and command family; scoped admin authority; reason;
**approval / dual control**; an audit record; no arbitrary status patch; no
silent assignee overwrite; and no bypass of custody safety.

`admin.assignment.override_picker` is **RESERVED / PROPOSED only** — absent from
`Permission.values` and `permissionMatrix`. Three tests pin this: the permission
is agent-only, it stays shop-scoped and reason-bearing, and the reserved
identifier stays unimplemented.

**No admin override permission, command or evaluator was added.**

## 5. Prior findings — unchanged

| Behaviour | Status |
|---|---|
| Offer recipient vs accepted assignee separation | **unchanged** |
| Same-region non-recipient accept/decline denied | **unchanged** |
| Accept-vs-expiry exactly-one outcome | **unchanged** |
| Revoke → NEW attempt with next generation | **unchanged** |
| Unknown custody fails revoke closed | **unchanged** |
| One live offer / one active accepted picker | **unchanged** |
| Timeout policy reference, no duration | **unchanged** |
| P15 order/assignment serialization boundary | **unchanged, NOT RUN** |
| Rider lifecycle | **not started** |

All 80 pre-existing picker tests passed unmodified after the fix — the new
range rule matched every fixture the lifecycle itself produces.

## 6. Future backend acceptance

**R33–R40 NOT RUN. L1–L13 NOT RUN. P1–P16 NOT RUN. P17 NOT RUN.** None was
treated as a blocker to this contract fix. Nothing is marked PASS.

## 7. Validation

| Command | Result |
|---|---|
| branch / HEAD / `git status` before work | **PASS** — `355aaa7`, clean, no reset |
| defect reproduction probe | **PASS** — both defects confirmed pre-fix |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **75** (was 36) |
| `dart test test/picker_assignment_test.dart` | **PASS** — **24**, unmodified |
| `dart test test/picker_assignment_race_test.dart` | **PASS** — **20**, unmodified |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23** (was 20) |
| `dart run tool/print_permission_matrix.dart` + drift check | **PASS** — **no drift** |
| `dart test` all `cp_contracts` | **PASS** — **348** (was 306) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **389 across 10 of 15 members** (was 347) |

No FND-002 platform/device check was rerun, and no accepted FND-003A or
FND-003B1 suite was rerun for reassurance. The repository gate naturally
re-executes them; that is **not** offered as fresh review evidence for those
completed tasks.

## 8. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/picker_assignment.dart` | `assignmentIdReuse` denial; `reachableSlotRevisionRange`; coherence enforced in the validator |
| `packages/contracts/test/picker_assignment_integrity_test.dart` | +39 tests: id reuse, reachable ranges, stale identity combinations |
| `packages/contracts/test/permission_matrix_test.dart` | +3 tests pinning ADR-0006 |
| `docs/decisions/ADR-0006-admin-picker-assignment-override.md` | **new** — governance decision |
| `docs/contracts/picker-assignment-lifecycle.md` | new-identity rule, reachable-range table, P17, ADR-0006 cross-reference |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-001 entry; two-commit evidence chain |
| `docs/task-ledger/FND-003B2A-completion-report.md` | §20 recheck — annotated, not erased |
| `docs/task-ledger/FND-003B2A-FIX-001-completion-report.md` | this report |

Untouched: `assignment_state.dart`, `assignment_command.dart`,
`assignment_effect.dart`, `permission.dart`, `permission_matrix.dart`,
`contract_version.dart`, order/reservation lifecycle, apps, backend, infra,
`pubspec.yaml`, `pubspec.lock`. **No dependency added.**

## 9. Contract version

**0.4, corrected in place.** The branch has never been merged — `origin/main`
is `d14c9e1`, which predates 0.4 — no app has a build, and no Firebase project
exists, so no client or stored datum has consumed 0.4. These are edits to an
unreleased definition; a review finding is not a release event. No
payload-decoding claim: `cp_contracts` still has no serialization.

## 10. Scope statement

No rider lifecycle, custody, pickup/handoff, delivery, return, proof/dispute,
payment/COD, fee, commission or settlement rule was introduced. No admin
override was implemented. **FND-003B2B and FND-003B3 remain NOT STARTED.**
Nothing merged to `main`, pushed, force-pushed or deployed.
