# FND-003B2B-FIX-001 completion report

- **Task:** Close the assignment principal-identity integrity defect found in
  the final review of FND-003B2B
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `9d1e2626e69f7d3a7cef01a506c22febd217f34d`, branch
  `fnd/FND-003B2B-rider-assignment-lifecycle`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.5, corrected in place** (no bump)
- **Status:** **DONE**

`9d1e262` was not amended. One new commit on the same branch. The tree was
clean, so **no `git reset --hard` was used**.

## 1. Root cause — reproduced before changing anything

`RiderEligibility.qualifiesAsActiveRider` required a human principal,
`membershipPrincipalId == principalId`, `CommerceRole.rider` and
`MembershipStatus.active` — but **never that the identity was a well-formed
opaque principal id**.

Reproduced against `9d1e262`:

```text
qualifiesAsActiveRider = true          // principalId = '', membership = ''
offer outcome          = Allow(RiderAssignmentTransition(assignment.offer_rider:
                           - -> offered, id=asg_Rr11Bb22Cc33Dd44, gen=1, rev=1))
recipient              = ""
validator on applied   = AssignmentDenial.aggregateInconsistent
```

A malformed trusted target therefore produced a **successful** transition,
carrying `offerRecipientPrincipalId = ''` and a `ScopeProjectionEffect` adding
that empty identifier to offered scope — and the resulting aggregate was one
`validateRiderAssignmentAggregate` correctly refuses.

That breaks the invariant the FND-003B2B report claims in §14:

> successful evaluator transition → applied aggregate → validator accepts

for malformed trusted eligibility facts. A sequential-looking id
(`'1234567890123456'`, which `isValidOpaqueId` rejects as a counter) qualified
the same way.

**`PickerEligibility.qualifiesAsActivePicker` carried the identical weakness**
— also reproduced, also `true` for an empty principal.

## 2. Identity invariant

The rule is **not new**. Principal ids are opaque ids everywhere else in this
contract: `Principal` validates `subjectId` and `workerId` with
`validateOpaqueId`, and `CommandEnvelope` and `EventEnvelope` validate
`commandId`, `eventId` and `resourceId` the same way. The assignment
eligibility boundary was simply not applying it. **`ids.dart` is reused; no
second identity rule was created.**

| Boundary | Rule now enforced |
|---|---|
| `RiderEligibility.qualifiesAsActiveRider` | `isValidOpaqueId(principalId)` **and** `isValidOpaqueId(membershipPrincipalId)`, plus their equality, plus human / `rider` / `active` |
| `PickerEligibility.qualifiesAsActivePicker` | identical, with `picker` |
| Picker aggregate — stored `offerRecipientPrincipalId` | `isValidOpaqueId`, replacing an `isEmpty` check |
| Rider aggregate — stored `offerRecipientPrincipalId` | `isValidOpaqueId`, replacing an `isEmpty` check |
| Rider aggregate — `SourcePickerBinding.pickerPrincipalId` | `isValidOpaqueId`, replacing an `isEmpty` check |
| Both aggregates — `resourceId` | `isValidOpaqueId` (picker had **no** check; rider had `isEmpty`) |

**Accepted/revoked assignees inherit the guarantee** rather than getting a
separate rule: both validators already require `assignee == recipient`, so an
invalid assignee can only appear by also being an invalid recipient. Both
shapes are pinned by test anyway.

**Fails closed. Nothing is trimmed or repaired.**

### `resourceId` — subsection D, confirmed not invented

Checked before acting: `CommandEnvelope` (line 60) and `EventEnvelope` (line
61) both call `validateOpaqueId(resourceId)`. The repository's existing
contract already governs resource ids, so applying it here makes picker and
rider aggregates **consistent with the envelopes**, not with a new format. No
identifier redesign.

## 3. Rider fix

A malformed target now denies `targetNotEligible` with `transition == null` —
therefore **no offered projection, no assigned projection, no event, no
inventory effect, no financial effect, no custody effect**.

Tested for: empty, too short, overlong (74 chars), illegal character,
sequential-looking, and an invalid `membershipPrincipalId` (empty, short,
sequential). A valid target with a membership naming a *different valid*
principal still denies, as before.

Malformed stored aggregates — invalid recipient, invalid source-picker
principal, invalid `resourceId` — return `aggregateInconsistent`, and no
evaluator command produces a transition from them.

## 4. Picker root-cause fix

The same defect, at the same boundary, corrected in the same change. Leaving it
would mean two assignment roles with different identity guarantees while
sharing a state vocabulary, a revision model and a denial vocabulary — exactly
the drift the shared extraction in FND-003B2B existed to prevent.

**This is not a redesign of the accepted picker lifecycle.** No picker state,
transition, revision formula, command mapping, permission or event changed, and
every pre-existing picker test passed unmodified.

## 5. Transition closure

Both positive closure suites are **unchanged in meaning** and still pass: every
valid picker and rider history still applies into a validator-valid aggregate,
including both generation-3 boundaries.

Added a regression pinning the defect itself, as a **property** rather than a
single case, in each role's integrity suite:

> for each malformed target — either the evaluator denies it, or the applied
> aggregate must still validate.

It fails if the eligibility rule is weakened *and* closure breaks, which is
precisely the defect. The rider version's failure message names the cause:
*"the FIX-001 defect has recurred"*.

## 6. Negative controls — all fired

| Control | Result |
|---|---|
| Revert `qualifiesAsActiveRider` to the pre-fix form | **FIRED** — the rider closure regression failed with *"malformed target "" produced gen=1 rev=1 whose aggregate the validator rejects — the FIX-001 defect has recurred"*, plus the eligibility tests |
| Revert the picker stored-recipient check to `isEmpty` | **FIRED** — *"a malformed stored offer recipient id is corruption"* and *"an accepted assignee cannot bypass the recipient id rule"* both failed |

Production restored **byte-for-byte** afterwards: the `lib/` checksum returned
to `f192d9dd384179bc…`.

## 7. Trust boundary — documented accurately

`PickerEligibility` and `RiderEligibility` are shapes the backend fills from
**trusted current server-loaded facts**. "Loaded from trusted storage" answers
*where the facts came from*, not *whether they are well-formed*; conflating the
two is what produced this defect. Backend trust and pure-contract structural
validation are **complementary**, not substitutes.

Unchanged, and stated in both lifecycle documents so it cannot be misread:

- these value objects **authenticate nobody**, and assert nothing about
  session, revocation or freshness;
- a client still cannot authoritatively supply eligibility — it never reaches
  the evaluator;
- **fresh authorization on every request, including replays, remains
  FND-003A's and the backend's.**

## 8. Approved asymmetries and prior safety — unchanged

Both owner-approved rider asymmetries are untouched, and both remain strictly
downstream of every mandatory check (aggregate integrity → state ownership →
slot revision → order scope → command dispatch → `_requireCurrentAttempt`):

1. **Revoke** requires the **current** accepted picker, may be performed by a
   replacement current picker, requires `provenNoCustody`, and preserves the
   immutable original `SourcePickerBinding`.
2. **Decline** is exact-recipient only, does **not** require source-picker
   currency, preserves the binding, and grants no authority or custody.

| Behaviour | Status |
|---|---|
| Current-picker authority for offer and revoke | **unchanged** |
| Recipient vs accepted assignee separation | **unchanged** |
| Independent picker / rider slot revisions | **unchanged** |
| Accept-vs-expiry exactly-one | **unchanged** |
| Revoke → new generation, new opaque id | **unchanged** |
| Current-terminal `assignmentId` reuse denial | **unchanged** |
| Stale id / generation / slotRevision denial | **unchanged** |
| `SourcePickerBinding` immutable across states | **unchanged** |
| Cross-role `unknownTransition` | **unchanged** |
| Shared `reachableSlotRevisionRange` | **unchanged** |
| `completed` unreachable, no invented cost | **unchanged** |
| `agent.assignment.offer_rider` non-executable | **unchanged** |
| `admin.assignment.override_rider` absent | **unchanged** |
| ADR-0006, ADR-0007 | **byte-for-byte unmodified** |
| Generated permission matrix | **unchanged** — no permission code changed |

## 9. Future backend acceptance

**R33–R40 NOT RUN. L1–L13 NOT RUN. P1–P17 NOT RUN. B3-C1 NOT RUN / FUTURE.
RA1–RA18 NOT RUN. B3-C2 NOT RUN / FUTURE.** All unchanged; none treated as a
blocker; nothing marked PASS.

**RA14/RA15** remain real rider persistence and reconciliation requirements;
**P13/P14** remain the picker equivalents. The fixture `apply` / `applyRider`
helpers are test infrastructure and **do not replace** them. Unit tests passing
is not deployment evidence.

## 10. Validation

| Command | Result |
|---|---|
| branch / HEAD / `git status` before work | **PASS** — `9d1e262`, clean, no reset |
| defect reproduction probe (rider + picker) | **PASS** — both confirmed pre-fix |
| `dart test test/rider_assignment_test.dart` | **PASS** — **53** (was 49) |
| `dart test test/rider_assignment_integrity_test.dart` | **PASS** — **71** (was 65) |
| `dart test test/rider_assignment_race_test.dart` | **PASS** — **23**, unmodified |
| `dart test test/picker_assignment_test.dart` | **PASS** — **28** (was 24) |
| `dart test test/picker_assignment_integrity_test.dart` | **PASS** — **95** (was 91) |
| `dart test test/picker_assignment_race_test.dart` | **PASS** — **20**, unmodified |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unmodified |
| `dart test test/authorization_test.dart` | **PASS** — **46**, unmodified |
| negative control — rider eligibility reverted | **PASS (fired)** |
| negative control — picker aggregate reverted | **PASS (fired)** |
| permission-matrix drift check | **PASS** — table verbatim, **not regenerated** (no permission code changed) |
| `dart test` all `cp_contracts` | **PASS** — **520** (was 502) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **561 across 10 of 15 members** (was 543) |

**NOT RUN:** FND-002 platform/device checks — unrelated to this fix. No
accepted FND-003A/B1/B2A behaviour was re-reviewed; the picker suites are run
here as **regression coverage for this fix**, which is a different claim from
re-verifying those tasks.

## 11. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/picker_assignment.dart` | `qualifiesAsActivePicker` requires valid opaque ids; stored recipient and `resourceId` validated with the canonical rule |
| `packages/contracts/lib/src/rider_assignment.dart` | `qualifiesAsActiveRider` requires valid opaque ids; stored recipient, source-picker principal and `resourceId` validated with the canonical rule |
| `packages/contracts/test/picker_assignment_test.dart` | +4 — malformed target/membership eligibility, well-formed still qualifies |
| `packages/contracts/test/picker_assignment_integrity_test.dart` | +4 — malformed stored recipient, assignee bypass, malformed `resourceId`, closure regression |
| `packages/contracts/test/rider_assignment_test.dart` | +4 — same eligibility coverage |
| `packages/contracts/test/rider_assignment_integrity_test.dart` | +6 — malformed stored recipient, assignee bypass, malformed `resourceId`, malformed source-picker principal, closure regression, no-projection guarantee |
| `docs/contracts/picker-assignment-lifecycle.md` | trust-boundary subsection; identity invariant in aggregate integrity |
| `docs/contracts/rider-assignment-lifecycle.md` | same |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-001 row; two-commit evidence chain |
| `docs/task-ledger/FND-003B2B-completion-report.md` | §24 recheck — annotated, not erased |
| `docs/task-ledger/FND-003B2B-FIX-001-completion-report.md` | this report |

Untouched: `assignment_state.dart`, `assignment_command.dart`,
`assignment_effect.dart`, `assignment_integrity.dart`, `permission.dart`,
`permission_matrix.dart`, `contract_version.dart`, `ids.dart`, the generated
permission matrix, ADR-0006, ADR-0007, order/reservation lifecycle, the
fixtures, apps, backend, infra, `pubspec.yaml`, `pubspec.lock`. **No dependency
added.**

## 12. Contract version

**0.5, corrected in place.** No bump. This is a correctness tightening of an
**existing** opaque-principal invariant, not a new wire feature: no type,
field, command, event or permission was added or renamed.

Release evidence supports it: the branch has never been merged — `origin/main`
is `741328c`, which predates 0.5 — no app has a build, and no Firebase project
exists, so no client or stored datum has consumed 0.5. A review finding is not
a release event. **No payload-compatibility claim**: `cp_contracts` still has
no serialization.

## 13. Ledger

FND-003B2B evidence chain: **`9d1e262` + this commit** — `9d1e262` alone is not
the accepted contract. **FND-003B2B DONE (as corrected)**; **FND-003B2 DONE (as
corrected)**; **FND-003B stays PARTIAL**; **FND-003B3 NOT STARTED**; FND-003C
**BLOCKED on O6**; FND-003D unchanged.

## 14. Scope statement

Contract and tests only. No backend handler, no Firestore rule, no application
feature, no platform dependency. Nothing merged to `main`, pushed, force-pushed
or deployed. **FND-003B3 not started.**
