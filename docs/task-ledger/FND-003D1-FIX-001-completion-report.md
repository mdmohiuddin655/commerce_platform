# FND-003D1-FIX-001 completion report

- **Task:** Correct the three defects found in the strict final review of
  FND-003D1
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `913b1ac5c5905fb6d27584d4abe4577b593429bb`, branch
  `fnd/FND-003D1-delivery-proof-reference-boundary`, working tree clean
- **Reviewed base main:** `e8dacfce96b3bf2c52c6cc7b3c826bd674a365f9`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.7 candidate, corrected in place** (no bump)
- **Status:** **DONE** — its corrections stand. **FINAL-REVIEW-002** found two
  further acceptance defects, closed by **FND-003D1-FIX-002**. See
  [§17 Recheck](#17-recheck-final-review-002).

`913b1ac` was not amended and its parent chain is intact (`913b1ac^ =
e8dacfce…`). One new commit on the same branch. The tree was clean, so **no
`git reset --hard` was used**, and no history was rewritten.

## 1. Root defects

**1. `DeliveryProofPolicyRef` was unbounded, and its `toString` emitted the raw
value.** "No proof-mechanism grammar" had quietly become "no bound at all" — the
only structural rule was non-blank. On a **wire-facing** value that travels
through commands, events, audit records and logs, that is an amplification
surface. And because the reference has no character grammar *by design*, its
content is arbitrary, so echoing it from `toString` made every `print`, crash
report and error message a log-injection and content-leak route.

**2. `belongsTo` failed open for malformed instances.** It was raw equality with
no validation of either side:

```dart
bool belongsTo(String resourceId) => this.resourceId == resourceId;
```

Two identically-malformed values — an empty stored resource against an empty
target — matched, and the **public convenience API returned a misleading
`true`**, certifying a structurally broken reference.

**3. `cp_contracts.dart` still declared "Contract version 0.6"** while
`ContractVersion.current` and the whole D1 surface were 0.7. The library doc's
bullet list was updated when D1 landed; the header line was not.

## 2. Policy-reference bound

`maxDeliveryProofPolicyRefLength = 64`, denying `policyRefTooLong`.

**64 is reused, not invented.** It is already the repository's ceiling for
bounded wire strings — `maxIdLength` for every opaque id, and the same limit on
`CommandEnvelope.commandType`. A second, differently-justified number would mean
two ceilings to keep aligned. A test asserts
`maxDeliveryProofPolicyRefLength == maxIdLength`.

**It constrains how much, never what.** No prefix, suffix, namespace, URI,
version convention, character set or proof-mechanism name was introduced, and
the **opaque-id rules are deliberately not applied** — no minimum length, no
alphabet, no sequential-looking rejection. A test drives five mechanism-neutral
shapes (`policy/delivery_proof@v1`, `dp-2026-01`, `urn:example:policy:7`,
`A_B.C~D`, `123456`) through the validator and requires all to pass.

Recorded as
**[ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md)**
— a technical anti-amplification decision that explicitly selects **no** proof
mechanism and **no** satisfaction policy.

## 3. Policy value semantics

| Property | Behaviour |
|---|---|
| blank / whitespace-only | `policyRefBlank`, and it **takes precedence** — 65 spaces reports blank, not too-long |
| length 1 | accepted |
| length 64 | accepted |
| length 65 | `policyRefTooLong` |
| exact value | **preserved** — never trimmed, case-folded, re-punctuated or repaired |
| equality / `hashCode` | exact underlying value; `'p/x@v1'` ≠ `' p/x@v1 '` ≠ `'POLICY/X@V1'` |
| `toString` | `DeliveryProofPolicyRef(length=N)` — **the raw value never appears** |

The rendering is **deliberately lossy**: two different values of the same length
render identically. A test asserts exactly that, and that they remain unequal —
which is precisely why equality does not go through `toString`. The length is
**not** a hash and derives no new business identifier.

A further test embeds `'a\nFAKE LOG LINE\tb\r'` and requires the rendering to
contain none of that content, and to remain a single line.

## 4. Evidence resource binding — fail-closed

`belongsTo(resourceId)` now returns true only when **all three** hold:

1. this reference is well formed (`resourceId` **and** `evidenceId` are valid
   opaque ids);
2. the supplied target `resourceId` is itself a valid opaque id;
3. the two compare **exactly**.

So all of these are now `false`: malformed stored resource against the same
malformed target · malformed `evidenceId` with a matching resource · valid
reference against a malformed target · valid reference against a padded target.
Nothing is normalised or repaired; the valid exact case still returns `true`,
and a valid-but-different order still returns `false`.

## 5. Explicit target-resource validation and precedence

`validateDeliveryEvidenceRef` now validates the **resource being acted on**, not
only the one stored inside the reference, with a distinct denial:

| Order | Condition | Denial |
|---|---|---|
| 1 | stored `resourceId` not opaque | `evidenceResourceIdInvalid` |
| 2 | `evidenceId` not opaque | `evidenceIdInvalid` |
| 3 | **target** resource not opaque | `expectedResourceIdInvalid` |
| 4 | both valid, different orders | `evidenceResourceMismatch` |
| 5 | otherwise | `null` |

**The stored side is inspected first**, because that is the corruption a caller
cannot see — so a malformed stored reference can never be masked by a later
check. A test walks all five steps in order to pin the precedence.

`expectedResourceIdInvalid` keeps three failures distinguishable: *"the stored
evidence names a broken resource"*, *"the caller asked about a broken
resource"*, and *"both are fine and they simply differ"*. Collapsing them would
hide which side is corrupt. `evidenceResourceMismatch` is consequently reached
**only** when both resources are valid opaque ids — it is no longer a catch-all,
which is a strengthening of the original semantics rather than a relaxation.

## 6. Public API regression

`DeliveryProofDenial` is now, in order: `policyRefBlank`, `policyRefTooLong`,
`evidenceResourceIdInvalid`, `evidenceIdInvalid`, `expectedResourceIdInvalid`,
`evidenceResourceMismatch` — pinned by test. **Every value remains structural**;
a test still asserts no name contains `satisf`, `delivered`, `success`,
`failed`, `refused` or `accepted`.

`DeliveryEvidenceRef` equality and `hashCode` include **both** identities, newly
tested directly: equal refs share a hash code; the same evidence on a different
order is unequal; the same order with different evidence is unequal.
`toString` remains identifier-only and both identifiers are already bounded at
`maxIdLength`.

**No satisfaction or authority semantics were added.** Neither reference can
authenticate a caller, authorize a command, assert a policy was satisfied,
establish delivery, move `OrderState` or custody, complete a rider assignment,
resolve a dispute, create financial consequences or imply customer
participation. The strongest successful structural statement is unchanged: *the
reference is structurally valid and bound to this resource.*

## 7. No mechanism

The size bound is **not** permission to introduce a grammar. Nothing was added
for OTP, QR, barcode, signature, photo/image/video, GPS, biometric, device
attestation, mandatory customer confirmation, proof-result state,
`proofSatisfied`, a `delivered` flag or a success/failure evaluator.

The comment-stripping source guard from D1 still runs, and remains
**supplementary** — the behavioural absence is carried by the denial-list pin,
the command/event sweeps and the unreachable-state assertions, not by text
matching alone.

## 8. Permissions and executability — unchanged

`Permission.values` **38** · `permissionMatrix` **38**, pinned by test.
`rider.delivery.submit_proof` (rider, `assignedResource`),
`customer.delivery.confirm_proof` (customer, participation only, **does not
settle cash, does not close a dispute** — restriction text asserted) and
`customer.dispute.raise` all keep their exact rules. **No permission is evidence
of proof satisfaction.**

No command, event or state-machine change. `OrderState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` all remain
**unreachable**; picker completion's revision range is unchanged at
`(min: 3, max: 3)`. **B3-C2 NOT RUN / FUTURE.**

## 9. Privacy

`EventEnvelope.payload` remains routing and display only. **Raw proof or
evidence never enters it**; a push is a hint that proves nothing and authorizes
nothing. No address, phone, order contents, amount, location trace, image,
signature or proof material was added.

**The bounded policy reference must not become an arbitrary logging channel** —
which is exactly what the `toString` fix prevents, and why the bound alone would
not have been sufficient.

Protected retrieval remains **future**. No claim is made about Firestore Rules,
Storage Rules, upload security, encryption policy, signed URLs, evidence ACLs,
retention or deletion/legal hold.

## 10. Deferred policy — unchanged

Proof satisfaction · required evidence type or count · whether customer
participation is mandatory · evidence visibility · retention · deletion and
legal hold · fallback dispute workflow · refusal/failure lifecycle · retry count
and window · return destination · post-dispatch inventory restoration · COD and
payment · delivery fee · refund · liability · commission · settlement.

Financial consequence remains **UNKNOWN / DEFERRED TO FND-003C / O6**.
**Unknown is never replaced with zero.**

## 11. Future acceptance — unchanged

All nine D1 race requirements remain **future backend obligations**, not PASS.

**CA1–CA23 NOT RUN · R33–R40 NOT RUN · L1–L13 NOT RUN · P1–P17 NOT RUN ·
RA1–RA18 NOT RUN.** **B3-C1** — contract-test evidence only. **B3-C2** — NOT
RUN / FUTURE. Fixtures and unit tests remain **non-persistence** evidence.

## 12. Version and documentation

**`ContractVersion.current` stays `0.7`.** 0.7 is an unmerged, unreleased
candidate — `origin/main` is `e8dacfce…`, which predates it — so this tightens
the structural definition **before** acceptance rather than being a second
release event. **No 0.8.**

`cp_contracts.dart` header corrected **0.6 → 0.7**; its description of
references-only, no delivery success, no proof satisfaction, no serialization
and no payload-compatibility claim is preserved verbatim. **No export changed.**

**No serialization exists.** No claim that 0.6 can decode 0.7, no payload
compatibility claim, no unknown-field compatibility claim.

## 13. Validation

| Command | Result |
|---|---|
| branch / HEAD / parent / `git status` before work | **PASS** — `913b1ac`, parent `e8dacfc`, clean, no reset |
| `dart test test/delivery_proof_test.dart` | **PASS** — **40** (was 25) |
| `dart test test/contract_version_test.dart` | **PASS** — **12** |
| `dart test test/command_envelope_test.dart` | **PASS** — **8** |
| `dart test test/permission_matrix_test.dart` | **PASS** — **23**, unmodified |
| `dart test test/authorization_test.dart` | **PASS** — **46**, unmodified |
| negative control — length bound removed | **PASS (fired)** |
| negative control — raw `toString` restored | **PASS (fired)**, three tests |
| negative control — `belongsTo` reverted to raw equality | **PASS (fired)**, three tests |
| `dart test` all `cp_contracts` | **PASS** — **672** (was 657) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **713 across 10 of 15 members** (was 698) |

Every count was **actually produced by these runs**; the previous 25 / 657 / 698
are recorded as history, not restated as current.

Production source was restored **byte-for-byte** after each negative control —
`delivery_proof.dart` checksum returned to `4268ab8720a9af18…`.

**GitHub CI: NONE.** The repository has no configured workflow or status check;
these are **local executor gate** results and are not described as CI.

**NOT RUN:** FND-002 platform/device checks, Firebase/emulator, Firestore rules,
indexes, backend persistence, deployment, and CA/R/L/P/RA. **NOT IMPLEMENTED:**
backend persistence, storage rules, retention. **BLOCKED:** none.

## 14. Files changed

**Production (2):** `lib/src/delivery_proof.dart` — bound constant, two denial
values, bounded `isWellFormed`, safe `toString`, fail-closed `belongsTo`,
target-resource validation with deterministic precedence, and the two class doc
comments that the changes made stale; `lib/cp_contracts.dart` — header 0.6 → 0.7
only.

**Tests (1):** `test/delivery_proof_test.dart` — denial-list pin updated,
**+15 tests** for the bound, the safe rendering, fail-closed `belongsTo`,
target-resource denial, precedence and both equality/`hashCode` contracts.

**Decision (1):** `docs/decisions/ADR-0008-bounded-delivery-proof-policy-reference.md`.

**Docs / evidence (5):** `docs/contracts/delivery-proof-boundary.md` (bound,
rendering, fail-closed binding, new §2a precedence table);
`docs/contracts/version-history.md` (in-place correction note);
`AGENTS.md` (§11 ADR index, which had drifted and listed only ADR-0001–0004);
`docs/task-ledger/TASK_LEDGER.md`; `docs/task-ledger/FND-003D1-completion-report.md`
(§22 recheck — annotated, not erased); this report.

> **Scope note.** `AGENTS.md` was not on the task's file list. Its §11 ADR index
> stopped at ADR-0004 and would have omitted ADR-0008 along with the already-
> missing 0005–0007, so a reader following the canonical rule file would not
> have found this decision. The edit is one index sentence and changes no rule.
> Recorded here rather than passed off as in-scope.

**Verified untouched:** `Permission.values`, `permissionMatrix`, the generated
permission documentation, `LifecycleCommand`, `AssignmentCommand`,
`CustodyCommand`, lifecycle event ids, `OrderState`, `AssignmentState`,
`CustodyHolderKind`, every custody/order/assignment evaluator, B3 revision
arithmetic, `contract_version.dart`, dependencies, `apps/`, `backend/`,
`infra/`, Firebase configuration.

## 15. Ledger

**Corrected D1 candidate chain: `913b1ac` + this commit.** **`913b1ac` alone is
NOT the accepted D1 candidate after FINAL-REVIEW-001**, and the slice **still
requires read-only acceptance before merge**.

**FND-003D1 DONE (as corrected candidate).** **FND-003D PARTIAL** — proof
satisfaction and the fallback dispute workflow remain undone. **FND-003B3
PARTIAL · FND-003B PARTIAL · FND-003B3B NOT STARTED · FND-003C BLOCKED on O6.**

## 16. Scope statement

Contract, tests, one ADR and documentation only. Nothing pushed, merged,
rebased, amended, force-pushed or deployed; no PR created; no Firebase or live
data touched. **FND-003D2, FND-003B3B and FND-003C not started.**

## 17. Recheck (FINAL-REVIEW-002, 2026-09-10)

**Every correction in this report stands**: the 64-character bound, the
non-echoing policy `toString`, the fail-closed `belongsTo`, the explicit
target-resource validation and its precedence, and the corrected package version
header. FND-003D1-FIX-002 changed none of that behaviour.

Two further defects were found, both in *how* this report's fixes were
implemented rather than in what they decided:

1. **The bound repeated the literal instead of aliasing the canonical
   constant.** §2 above says 64 is "reused, not invented" and cites
   `maxIdLength` — but the declaration was written
   `const int maxDeliveryProofPolicyRefLength = 64;`, a **second numeric source
   of truth** free to drift from the first. The runtime assertion
   `maxDeliveryProofPolicyRefLength == maxIdLength` could not detect that,
   because `= 64` and `= maxIdLength` are numerically identical. The declaration
   now aliases `maxIdLength`, and a narrow source-shape regression pins it.

2. **`DeliveryEvidenceRef.toString` was safe only for *valid* instances.** §6
   above describes it as "identifier-only and bounded", which is true of a
   well-formed reference — both fields are canonical opaque ids. But the
   constructor is public and `const`, and malformed instances are deliberately
   representable so the validator can be tested. For those, `toString` echoed
   the raw fields, which is an amplification and log-injection surface reachable
   **before** validation. A malformed instance now renders
   `DeliveryEvidenceRef(invalid)` and echoes neither field.

The validation counts recorded in §13 (40 / 672 / 713) were real at the time and
are **not** restated as current; FND-003D1-FIX-002 re-ran everything and records
its own. Full detail:
[FND-003D1-FIX-002 report](FND-003D1-FIX-002-completion-report.md).
