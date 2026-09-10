# FND-003D1-FIX-002 completion report

- **Task:** Close the final two acceptance defects in the corrected FND-003D1
  candidate
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `f615ea60c4ff8fc81da0010255a11b244b65da87`, branch
  `fnd/FND-003D1-delivery-proof-reference-boundary`, working tree clean
- **Reviewed main baseline:** `e8dacfce96b3bf2c52c6cc7b3c826bd674a365f9`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.7 candidate, corrected in place** (no bump)
- **Status:** **DONE**

Neither published feature commit was amended, and the chain is intact:
`f615ea6^ = 913b1ac5…`, `913b1ac^ = e8dacfce…`. One new commit on the same
branch. The tree was clean, so **no `git reset --hard` was used**, and no
history was rewritten.

**The delivery-proof boundary itself is unchanged.** References only, no proof
satisfaction, no mechanism, no command/event/state, no custody or assignment
change, no dispute or financial rule, no backend or storage implementation.

## 1. Root defects

**1. The bound repeated its literal instead of aliasing the canonical
constant.** FIX-001 argued — correctly — that 64 should be *reused* from
`maxIdLength` rather than invented. But it then wrote:

```dart
const int maxDeliveryProofPolicyRefLength = 64;
```

which recreates exactly what the decision was meant to avoid: **two numeric
sources of truth**, free to drift, with no runtime test able to tell them apart.
`maxDeliveryProofPolicyRefLength == maxIdLength` passes identically whether the
declaration reads `= 64` or `= maxIdLength`.

**2. `DeliveryEvidenceRef.toString` was safe only for *valid* instances.** For a
well-formed reference the claim "identifier-only and bounded" holds — both
fields are canonical opaque ids. But the constructor is public and `const`, and
malformed instances are **deliberately representable** so the validator can be
tested at all. For those, `toString` echoed the raw fields, making any `print`,
crash report or error message an amplification and log-injection surface
reachable **before** validation — which is precisely the window that matters.

## 2. Canonical bound

```dart
const int maxDeliveryProofPolicyRefLength = maxIdLength;
```

- **Declaration:** aliases the canonical constant; **no numeric literal**.
- **Runtime value:** still exactly **64** (`maxIdLength == 64`), so behaviour is
  unchanged.
- **Public name stays semantic** — callers depend on the *proof-policy* concept,
  not directly on an id rule — while the number has exactly one owner.
- **ADR-0008 amended** to name `maxIdLength` as **the** source of truth, record
  `CommandEnvelope.commandType` as *supporting precedent rather than a second
  source*, and require that any future divergence means deliberately replacing
  the alias with a separately justified bound, not editing a literal.

**No grammar impact.** The coupling is **numeric only**. A policy reference
still has no minimum length, no alphabet, no prefix, namespace or URI
requirement, and no sequential-looking rejection — a test drives five
mechanism-neutral shapes through the validator and requires all to pass.

## 3. Policy-reference regression — unchanged

| Property | Behaviour |
|---|---|
| blank / whitespace-only | `policyRefBlank`, **taking precedence** (65 spaces → blank) |
| length 1 / 64 / 65 | accepted / accepted / `policyRefTooLong` |
| exact value | preserved — never trimmed, case-folded or repaired |
| equality / `hashCode` | exact underlying value |
| `toString` | `DeliveryProofPolicyRef(length=N)` — raw value never appears, deliberately lossy |

## 4. Evidence-reference debug safety

| Instance | Rendering |
|---|---|
| well formed | `DeliveryEvidenceRef(<evidenceId> for <resourceId>)` — two canonical opaque ids, already bounded at `maxIdLength` |
| **malformed** | `DeliveryEvidenceRef(invalid)` — **neither field echoed** |

Tested with synthetic hostile content confined to these cases: a URL-like
resource with an embedded newline, tab and 68 characters of padding; an
evidence id containing `file:///etc/passwd\r` and a fake secret marker; and both
fields at 200 characters. In every case the rendering is the fixed
`DeliveryEvidenceRef(invalid)` string — **single line, under 64 characters**,
containing none of the hostile content, and **not even the valid field** when
only one side is broken.

**Nothing is thrown, trimmed, hashed or repaired.** A test asserts the fields
are unchanged after rendering, that `isWellFormed` is still `false`, that
`belongsTo` still returns `false`, and that
`validateDeliveryEvidenceRef` still reports `evidenceResourceIdInvalid` — **a
rendering is a debug representation, never a validity claim**, and the validator
remains authoritative.

## 5. Evidence binding — unchanged

`belongsTo` still requires **all three**: well-formed reference · valid target ·
exact equality. Precedence unchanged: stored resource → evidence id → target
resource → mismatch → null, with the stored side first so malformed stored data
is never masked. `evidenceResourceMismatch` is still reached only when both
resources are valid.

Equality and `hashCode` still include **both** identities.

## 6. Negative controls — both fired

**NC1 — bound coupling.** Reverting the declaration to `= 64` failed **only**
the source-shape guard:

> *"the proof-policy ceiling must alias the canonical constant, not repeat its
> literal — see ADR-0008"*

The numeric boundary test stayed **green**, exactly as expected — which is the
whole point: `= 64` and `= maxIdLength` are numerically indistinguishable, so
only the declaration itself carries the property. That is why a source-shape
assertion is the right instrument *here* and remains supplementary everywhere
else.

**NC2 — raw rendering.** Restoring unconditional
`'DeliveryEvidenceRef($evidenceId for $resourceId)'` failed exactly the **four
malformed-instance** tests, while the two **valid**-instance rendering tests
stayed green — the correct signature, since raw rendering is fine for a valid
reference and only unsafe for a malformed one.

> My first attempt at NC2 was faulty: shell escaping produced a
> non-interpolating Dart string, so the valid-instance tests failed too, for the
> wrong reason. I redid the control with a faithful mutation and verified the
> mutated line interpolates before trusting the result. The evidence above is
> from the corrected run.

Production source restored **byte-for-byte** after each — `delivery_proof.dart`
checksum returned to `6aee61534b987ccc…`, the declaration reads
`= maxIdLength`, and the `DeliveryEvidenceRef(invalid)` branch is present. **No
negative-control mutation remains in the committed diff.**

## 7. Permissions and executability — unchanged

`Permission.values` **38** · `permissionMatrix` **38**.
`rider.delivery.submit_proof`, `customer.delivery.confirm_proof` (participation
only — **does not settle cash, does not close a dispute**) and
`customer.dispute.raise` keep their exact rules. **A permission remains
authority to ask for an operation, never evidence that proof requirements were
satisfied.**

No command, event, state-machine, evaluator or revision change.
`OrderState.delivered`, `CustodyHolderKind.customer` and rider
`AssignmentState.completed` all remain **unreachable**; picker completion
unchanged; **B3-C2 NOT RUN / FUTURE**.

## 8. Proof and privacy boundary

Neither reference may authenticate, authorize, prove policy satisfaction, prove
delivery, move order state or custody, complete an assignment, resolve a
dispute, create or settle money, or imply customer participation. The strongest
successful validator statement is unchanged: **structurally well formed and
exactly bound to this resource.**

No mechanism added — no OTP, QR, barcode, signature, photo, video, GPS,
biometric, device attestation, mandatory customer confirmation, proof status,
`proofSatisfied`, `delivered` flag, proof command or delivery transition.

Raw evidence still never enters events or push; push remains non-authoritative;
evidence retrieval and storage remain **future**; no URL, path or signed-URL
field; no upload, retention, visibility or legal-hold default.

**This fix exists specifically so an invalid value object cannot become an
accidental log channel through its public debug representation.**

## 9. Deferred policy — unchanged

Proof satisfaction · evidence type and count · mandatory customer participation
· fallback dispute · evidence visibility · retention, deletion and legal hold ·
refusal and failure · retry count and window · return destination ·
post-dispatch stock restoration · COD and payment · fee · refund · liability ·
commission · settlement.

Financial consequence remains **UNKNOWN / DEFERRED TO FND-003C / O6**.
**Zero is never substituted.**

## 10. Future acceptance — unchanged

**CA1–CA23 NOT RUN · R33–R40 NOT RUN · L1–L13 NOT RUN · P1–P17 NOT RUN ·
RA1–RA18 NOT RUN.** **B3-C1** — contract-test evidence only. **B3-C2** — NOT
RUN / FUTURE. **No unit test becomes persistence or security-rule evidence.**

## 11. Version

**`ContractVersion.current` stays `0.7`.** Another correction to the same
unmerged, unreleased candidate — `origin/main` is `e8dacfce…`, which predates
it. **No 0.8.** No migration, **no serialization**, and **no payload-decoding or
unknown-field compatibility claim**.

`cp_contracts.dart` and its exports were **not** touched by this fix.

## 12. Validation

| Command | Result |
|---|---|
| branch / HEAD / chain / `git status` before work | **PASS** — `f615ea6`, chain intact, clean, no reset |
| `dart test test/delivery_proof_test.dart` | **PASS** — **46** (was 40) |
| `dart test test/contract_version_test.dart` | **PASS** — **12** |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unmodified |
| negative control — duplicate literal restored | **PASS (fired)** — source guard only |
| negative control — raw rendering restored | **PASS (fired)** — 4 malformed tests |
| `dart test` all `cp_contracts` | **PASS** — **678** (was 672) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **719 across 10 of 15 members** (was 713) |

Every count was **produced by these runs**; the previous 40 / 672 / 713 are
recorded as history, not restated.

**GitHub CI: NONE.** The repository has no configured workflow or status check —
these are **local executor gate** results and are not described as CI.

**NOT RUN:** FND-002 platform/device checks, Firebase/emulator, Firestore rules,
indexes, backend persistence, deployment, CA/R/L/P/RA. **NOT IMPLEMENTED:**
backend persistence, storage rules, retention. **BLOCKED:** none.

## 13. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/delivery_proof.dart` | alias the ceiling to `maxIdLength`; fail-safe `DeliveryEvidenceRef.toString`; the two doc comments the changes made stale |
| `packages/contracts/test/delivery_proof_test.dart` | **+6 tests** — source-coupling guard, valid rendering, three malformed-rendering cases, and the "rendering does not certify" case |
| `docs/decisions/ADR-0008-…md` | amended: `maxIdLength` is the source of truth; `commandType` is precedent only; divergence requires revisiting the ADR |
| `docs/contracts/delivery-proof-boundary.md` | alias, no separate numeric source, no grammar impact, malformed-instance rendering |
| `docs/contracts/version-history.md` | one short in-place-correction addition |
| `docs/task-ledger/TASK_LEDGER.md` | three-commit candidate chain |
| `docs/task-ledger/FND-003D1-FIX-001-completion-report.md` | §17 recheck — annotated, not erased |
| `docs/task-ledger/FND-003D1-FIX-002-completion-report.md` | this report |

**Verified untouched:** `ContractVersion.current`, `cp_contracts.dart` and its
exports, `AGENTS.md`, `Permission.values`, `permissionMatrix`, generated
permission docs, `LifecycleCommand`, `AssignmentCommand`, `CustodyCommand`,
event vocabularies, `OrderState`, `AssignmentState`, `CustodyHolderKind`, every
lifecycle evaluator, assignment revision arithmetic, `apps/`, `backend/`,
`infra/`, Firebase, and every pubspec/lockfile.

## 14. Ledger

**Corrected candidate chain: `913b1ac` + `f615ea6` + this commit.**

- **`913b1ac` alone is not accepted.**
- **`913b1ac` + `f615ea6` is also not the final accepted candidate** after
  FINAL-REVIEW-002.
- **FND-003D1-FIX-002 itself still requires read-only acceptance before merge.**

**FND-003D PARTIAL · FND-003B3 PARTIAL · FND-003B PARTIAL · FND-003B3B NOT
STARTED · FND-003D2 NOT STARTED · FND-003C BLOCKED on O6.**

## 15. Scope statement

Contract source, tests, one amended ADR and documentation only. Nothing pushed,
merged, rebased, amended, force-pushed or deployed; no PR created; no Firebase
or live data touched. **FND-003D2, FND-003B3B and FND-003C not started.**
