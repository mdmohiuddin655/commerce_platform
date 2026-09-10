# FND-003D1 completion report

- **Task:** Smallest dependency-safe prerequisite for delivery confirmation — a
  mechanism-neutral delivery-proof reference and privacy boundary
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `main` @ `e8dacfce96b3bf2c52c6cc7b3c826bd674a365f9`
- **Branch:** `fnd/FND-003D1-delivery-proof-reference-boundary`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.6 → **0.7**
- **Status:** **DONE** — as corrected by **FND-003D1-FIX-001** (2026-09-10).
  See [§22 Recheck](#22-recheck-final-review-001). `913b1ac` alone is **not**
  the accepted D1 candidate, and the slice still requires read-only acceptance
  before merge.

## 1. Baseline

`origin/main` matched the required SHA exactly, local `main` was `0 0` against
it, and the working tree was **clean including untracked files** — so **no
`git reset --hard` was used**. One new branch created with `git switch -c`.

## 2. Public surface added

| Type / function | Purpose |
|---|---|
| `DeliveryProofPolicyRef` | which immutable proof policy applies |
| `DeliveryEvidenceRef` | resource-bound pointer to protected evidence |
| `validateDeliveryProofPolicyRef` | structural validation |
| `validateDeliveryEvidenceRef` | structural validation + resource binding |
| `DeliveryProofDenial` | four **structural** denial values |

No deviation from the requested shape was needed; the pair maps directly onto
the two concepts, with the repository's usual `validate…` + denial-enum
convention for the structural rules.

## 3. Proof-policy reference semantics

Says **which** policy governs. It does **not** say the policy was satisfied and
does not say how proof would be captured.

**No grammar imposed** — the repository has no delivery-proof policy vocabulary
to reuse, and inventing a prefix, version suffix or namespace would be inventing
a contract rather than referring to one. A test asserts four quite different
shapes (`policy/delivery_proof@v1`, `dp-2026-01`, `a`, `urn:example:policy:7`)
are all accepted.

**Blank and whitespace-only fail closed** (`policyRefBlank`); `trim()` is used
*only* to reject them. **The exact value is preserved** — `' p/x@v1 '` and
`'p/x@v1'` are different references, asserted by test, because equating them
would let a corrupt stored value pass as a good one.

**Not client authority.** The backend resolves the authoritative policy from
trusted order and policy state; this is the shape that resolution fills.

## 4. Evidence-reference and resource binding

Carries `resourceId` + `evidenceId`, both validated with the canonical
opaque-id rule. `belongsTo` compares the resource **exactly**, so
**cross-resource substitution fails closed** with `evidenceResourceMismatch` —
evidence is not portable between orders. The resource travels *with* the id
rather than being supplied beside it at a call site, where the two could drift.

`evidenceId` is **not** a storage path, URL or signed URL, and deliberately not
shaped like one: a locator would imply a retrieval and access design no slice
has made. `toString` is identifier-only, so a log line cannot become a leak.

## 5. Structural validation

| Condition | Denial |
|---|---|
| blank / whitespace-only policy ref | `policyRefBlank` |
| non-opaque `resourceId` | `evidenceResourceIdInvalid` |
| non-opaque `evidenceId` | `evidenceIdInvalid` |
| evidence bound to a different order | `evidenceResourceMismatch` |

Fails closed. **Nothing is trimmed, normalised or repaired into equality** — a
padded id is rejected, not silently fixed, and a test asserts the value is
unchanged after refusal.

## 6. References are not proof, and not authority

Neither reference can move `OrderState`, move `CustodyHolder`, complete an
assignment, authorize a caller, or create/settle money. **Constructing or
passing one authenticates nobody and authorizes nothing.** The strongest
statement either type makes is *"well formed, and bound to this order"* — which
is not a claim about delivery.

There is deliberately **no** `DeliveryProofStatus`, `proofSatisfied`,
`delivered` flag, proof-result enum, success/failure evaluator, target order
state or proof-mechanism enum. A test asserts no `DeliveryProofDenial` name
contains `satisf`, `delivered`, `success`, `failed`, `refused` or `accepted`.

## 7. No proof mechanism selected

**None defined, required, implied or reserved:** OTP · QR · barcode · signature
· photograph · video · GPS · biometric · customer confirmation · picker
confirmation · device attestation · notification acknowledgement.

A test **strips the doc comments** from the source and asserts none of those
terms appears in the **code** — so the prose ruling them out cannot mask a real
declaration. The same test forbids `bytes`, `base64`, `blob`, `url`, `path`,
`address`, `phone`, `amount`, `retention`, `expires`, `duration`, `datetime`,
and the status vocabulary in §6.

## 8. Permission impact — none

`rider.delivery.submit_proof`, `customer.delivery.confirm_proof` and
`customer.dispute.raise` keep their exact ids, roles, scopes and restrictions.
**No permission added** — a test pins **38** for both `Permission.values` and
`permissionMatrix`, and asserts no id contains `evidence` or `proof_policy`.

**`customer.delivery.confirm_proof` was not reinterpreted.** A test asserts its
restriction still reads *"Participation in proof only"* and *"does not settle"*
— confirming does not settle cash and does not close a dispute.

## 9. Executable command / state impact — none

No command, state, transition, event or permission was added. A test sweeps
every command type across `LifecycleCommand`, `AssignmentCommand` and
`CustodyCommand`, and every event id across all three vocabularies, asserting
nothing containing `deliver`, `refus`, `return`, `proof`, `attempt` or `dispute`
exists.

One deliberate exception is pinned **by name**: `order.in_delivery`, FND-003B3A's
accepted dispatch boundary. Skipping it by name rather than by substring is
stronger — a new `order.delivered` or `delivery.proof_submitted` would still
fail, and a further assertion confirms `order.delivered` is absent. Event counts
pinned: Lifecycle **8**, Assignment **11**, Custody **2**.

## 10. Unreachable states — re-pinned

| State | Status |
|---|---|
| `OrderState.delivered` | **unreachable** — in `notYetImplemented`, absent from `executableInThisSlice`, absent from `aggregateShapeKnown` and from `canonicalAggregatePairs` |
| `CustodyHolderKind.customer` | **unreachable** — `notYetImplemented`, no custody command names it |
| rider `AssignmentState.completed` | **future** — `notYetImplementedForRole(rider)`, excluded from `executableForRole(rider)`, range **null** |

Picker completion's range is **unchanged** (`(min: 3, max: 3)` at generation 1),
asserted in the same test. **B3-C2 remains NOT RUN / FUTURE.**

## 11. Privacy and event boundary

`EventEnvelope.payload` remains **routing and display only**, unchanged.
**Raw evidence must never enter a notification or event payload** — a reference
may, the material may not. A notification proves nothing, authorizes nothing and
may be missed.

Evidence details are obtained later over an **authenticated, authorized
protected path**, which **this task does not implement**. **No claim** is made
about Firestore Rules, Storage Rules, upload security, retention, encryption at
rest, signed URLs or access policy. No sensitive example data was added to any
fixture — the test constants are opaque ids only.

## 12. Deferred, never defaulted

Retention period · visibility by role · deletion and legal-hold · proof
acceptance/satisfaction policy · fallback dispute workflow and outcome ·
whether customer participation is required. **No placeholder value that looks
authoritative was added.**

## 13. Refusal / failure / return boundary — documented, not implemented

Delivered / refused / failed remain the canonical attempt outcomes; no
"customer unavailable", "bad address" or "damaged goods" state was created.
**Refused and failed are attempt outcomes, not permission to make the ORDER
terminal.** Cancellation and refusal go through named permitted operations and
the server decides from current state. **No retry count, timer,
auto-cancellation or timeout.** After pickup, refusal requires return
processing — and this task does **not** choose `rider → picker` versus
`rider → shop`. `ReturnState.required` does not exist in code and was **not**
added. Custody stays explicit and singular. **No failed or refused attempt
restores stock**; stock cannot become available until shop receipt **and**
inspection (`CONSTRAINTS.md` invariant 12).

## 14. Financial boundary

No COD amount or state, delivery charge, refusal fee, refund, liability,
commission, journal posting, settlement or remittance. Future financial
consequence is **UNKNOWN / DEFERRED TO FND-003C**, blocked on **O6**.
**Zero is never used as a substitute for undecided policy.**

## 15. Future atomicity / race requirements — recorded, NOT PASS

Delivery success vs refusal · vs rider revoke · vs cancellation; failed attempt
vs reassignment; return initiation vs another attempt; duplicate/retried/
reordered commands; stale custody, order and rider-slot revisions.

A later final transition must read current trusted facts and commit its complete
cross-aggregate consequence as **one atomic backend transaction** with
principal-scoped dedupe and outbox, with **fresh authorization before every
execution and replay**. **No pure-Dart test can establish any of these, and none
is marked PASS.**

## 16. Future acceptance — unchanged

**CA1–CA23 NOT RUN · R33–R40 NOT RUN · L1–L13 NOT RUN · P1–P17 NOT RUN ·
RA1–RA18 NOT RUN.** **B3-C1** — contract-test evidence only, not persistence.
**B3-C2** — NOT RUN / FUTURE.

## 17. Validation

| Command | Result |
|---|---|
| baseline `origin/main` / clean tree / branch | **PASS** — `e8dacfc`, clean, no reset |
| `dart test test/delivery_proof_test.dart` | **PASS** — **25** |
| `dart test test/contract_version_test.dart` | **PASS** — **12** (was 11) |
| `dart test test/command_envelope_test.dart` | **PASS** — **8** |
| `dart test` all `cp_contracts` | **PASS** — **657** (was 631) |
| `flutter analyze` | **PASS** — `No issues found!` |
| `./tools/check_layering.sh` | **PASS** — 8 rules |
| `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| repository total | **PASS** — **698 across 10 of 15 members** (was 672) |

The accepted FND-003B3A focused suites were **not** deliberately rerun; the
repository gate naturally re-executes them, and that is **not** offered as fresh
evidence for those tasks. The regression assertions in §9–§10 are new claims
about *this* task and were written here.

**NOT RUN:** every FND-002 platform/device check, Firebase/emulator, Firestore
rules, indexes, backend persistence, deployment, and CA/R/L/P/RA. **BLOCKED:**
none. No Firebase, device, Windows or backend criterion became PASS — none is
required for a pure-Dart contract task.

**No GitHub CI evidence exists**; the repository has no configured checks. Local
gate evidence and CI evidence remain distinct.

## 18. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/delivery_proof.dart` | **new** — the two references, validators and denial enum |
| `packages/contracts/lib/cp_contracts.dart` | export + library doc records the reference-only surface and the still-future satisfaction/dispute work |
| `packages/contracts/lib/src/contract_version.dart` | 0.6 → 0.7 |
| `packages/contracts/test/delivery_proof_test.dart` | **new** — 25 tests |
| `packages/contracts/test/contract_version_test.dart` | version pin + a 0.6 ↔ 0.7 policy test |
| `packages/contracts/test/command_envelope_test.dart` | version pin |
| `docs/contracts/delivery-proof-boundary.md` | **new** — canonical doc, 13 sections |
| `docs/contracts/README.md`, `version-history.md` | index and 0.7 history |
| `docs/task-ledger/TASK_LEDGER.md` | FND-003D1 DONE, FND-003D PARTIAL, 0.7 |
| `docs/task-ledger/FND-003D1-completion-report.md` | this report |

**Verified untouched:** `permission.dart`, `permission_matrix.dart`, the
generated matrix, `docs/decisions/`, `order_lifecycle.dart`, `order_state.dart`,
`custody_lifecycle.dart`, `picker_assignment.dart`, `rider_assignment.dart`,
`assignment_state.dart`, `assignment_integrity.dart`, apps, backend, infra,
Firebase config, `pubspec.yaml`, `pubspec.lock`. **No dependency added**, and no
compile dependency forced any widening.

## 19. Ledger

**FND-003D1 DONE.** **FND-003D → PARTIAL** (was TODO): the reference/privacy
boundary is delivered; **proof satisfaction and the fallback dispute workflow
are still undone** and remain required before delivery confirmation is coded.

**Dependency note, recorded honestly.** FND-003D was previously listed as
depending on all of FND-003B. That was coarser than the work needs — this
reference boundary requires only the accepted FND-003B3A custody contract — so
the slice was taken now rather than waiting on delivery/refusal/return. The
ledger records that reasoning rather than silently relaxing the dependency.

**FND-003B3 PARTIAL · FND-003B PARTIAL · delivery/refusal/return NOT STARTED ·
FND-003C BLOCKED on O6.** **FND-003D is not complete**, and successful delivery
is **not** unblocked in full.

## 20. Migration and serialization

**Migration: NOT APPLICABLE / NOT RUN** — no persistence exists for this
vocabulary. **Firestore rules: NOT IMPLEMENTED. Indexes: NOT IMPLEMENTED.
Deployment: NOT RUN.** No Firebase resource created.

**No payload-decoding compatibility claim.** `cp_contracts` still has no
serialization, so a 0.6 build could not decode a 0.7 reference even if one were
serialized. Rollback is the ordinary Git revert of this commit before any merge.

## 21. Scope statement

Contract and tests only. No backend handler, no Firestore rule, no index, no
application feature, no platform dependency. Nothing merged, pushed,
force-pushed or deployed; no PR created. **No other task was started.**

## 22. Recheck (FINAL-REVIEW-001, 2026-09-10)

**The D1 boundary in this report is accepted and unchanged**: references only,
no proof mechanism, no satisfaction rule, no command, state, event or
permission, successful delivery still non-executable, and `delivered`,
customer custody and rider completion all still unreachable.

Strict final review found **three concrete defects**, all closed by
FND-003D1-FIX-001:

1. **`DeliveryProofPolicyRef` accepted an unbounded string, and its
   `toString()` emitted the raw value.** "No proof-mechanism grammar" had
   quietly become "no bound at all". On a wire-facing value that travels through
   commands, events, audit records and logs, that is an amplification surface —
   and echoing arbitrary content from `toString` made every `print`, crash
   report and error message a log-injection and content-leak route.

2. **`belongsTo` failed open for malformed instances.** It compared resources by
   raw equality with no validation of either side, so two identically-malformed
   values — an empty stored resource against an empty target, say — matched, and
   the public convenience API returned a misleading `true` certifying a broken
   reference.

3. **`cp_contracts.dart` still declared "Contract version 0.6"** while
   `ContractVersion.current` and the D1 surface were 0.7. §18 of this report
   listed that file as carrying the library doc, but the header line itself was
   not corrected when the version was bumped.

The validation counts recorded in §17 (25 / 657 / 698) were real at the time and
are **not** restated as current; FND-003D1-FIX-001 re-ran everything and records
its own. Full detail:
[FND-003D1-FIX-001 report](FND-003D1-FIX-001-completion-report.md).
