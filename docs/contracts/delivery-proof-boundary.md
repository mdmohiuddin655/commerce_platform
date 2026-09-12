# Delivery-proof reference and privacy boundary

**Introduced at contract version 0.7** (FND-003D1). Source of truth:
`packages/contracts/lib/src/delivery_proof.dart`.

This is a **prerequisite contract, not a delivery slice**. It gives later work a
safe way to *refer to* proof policy and protected evidence without embedding
proof material in events, treating a reference as proof, or committing the
platform to a proof method.

> **Still true at 0.11** *(re-verified against the 0.11 tree, not merely
> restamped)*. FND-003D2A added a separate
> [delivery-proof **assessment**](delivery-proof-assessment.md) — a
> trusted-server-produced, immutable *result* stating whether the referenced
> policy was satisfied. It **does not weaken anything below**:
>
> ```text
> reference != proof
> structural validation != authorization
> structural validation != satisfaction
> ```
>
> A `DeliveryProofPolicyRef` still only says *which* policy applies, and a
> `DeliveryEvidenceRef` is still only a structurally valid, resource-bound
> pointer that proves neither authenticity nor satisfaction. The assessment is a
> **different object** that carries the verdict; the references never gained
> one. FND-003D2B then added the
> [fallback dispute](delivery-proof-dispute.md) for a missing, superseded or
> `notSatisfied` assessment — a **third** object, which carries no reference, no
> evidence handle and no verdict copy at all, only a pointer to the assessment
> being contested. Successful delivery is still **not executable**, and no
> dispute resolves.
>
> **What was re-checked to advance 0.9 → 0.11.** Two slices landed since 0.9:
> FND-003B3B (**0.10** — the delivery **attempt** and **return** lifecycles for
> the bounded non-success path) and FND-003C1 (**0.11** — the first money
> surface: COD collection and the balanced cash journal). Neither weakens a
> claim in this box. The two references still carry **no verdict field**
> (`DeliveryProofPolicyRef` holds only `value`; `DeliveryEvidenceRef` only
> `resourceId` and `evidenceId`); `DeliveryProofDisputeState` remains
> `open` / `underReview` **plus the unreachable `resolved`** — that third value
> **does exist**, declared for enum stability only, and it stays unreachable:
> **no command transitions into it** and `reachableDisputeRevisionFor` returns
> **null** for it, exactly as
> [delivery-proof-dispute.md](delivery-proof-dispute.md) records. **No
> resolution policy exists**, and none is implied by the value being declared;
> `dispute.resolve_delivery_proof` is still enumerated and always refused
> `resolutionPolicyDeferred`; **no `order.delivered` event exists**; and
> `OrderState.delivered`, customer custody and rider `completed` all remain
> unreachable, so `CONSTRAINTS.md` invariant 13 is still undischarged —
> **unchanged by the later acceptance of
> [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md)**,
> which decides the proof-satisfaction **policy** and implements none of it
> (§7, §8). B3B did
> take the permission count **38 → 39** at 0.10 by adding
> `agent.return.record_receipt` — that changes the *count* (§1, §5), not any
> claim above.

---

## 1. Successful delivery is NOT executable after FND-003D1

Nothing here delivers an order, confirms delivery, records an attempt, handles
refusal or failure, starts a return, moves custody to the customer, completes a
rider assignment, or touches money.

**No command, no state, no transition, no event and no permission was added by
FND-003D1.** A test sweeps every command type and every event id across
**every** vocabulary that exists, asserting nothing containing `deliver`,
`refus`, `return`, `proof`, `attempt` or `dispute` exists — with a short list of
deliberate exceptions, **every one pinned by name** so a new `order.delivered`
or `delivery.proof_submitted` would still fail.

The four permitted **events**:

- `order.in_delivery` — FND-003B3A's accepted dispatch boundary;
- `delivery.proof_assessed` — FND-003D2A's assessment fact, which reports that
  a trusted assessment happened and **not** that delivery succeeded;
- `delivery.proof_dispute_raised` and
  `delivery.proof_dispute_review_started` — FND-003D2B's fallback dispute
  facts, which report that a dispute was recorded and that review of it
  started. **Neither is a resolution, and no resolution event exists.**

The three permitted **commands**, all FND-003D2B's:
`dispute.raise_delivery_proof`, `dispute.record_delivery_proof_review` and
`dispute.resolve_delivery_proof` — the last of which is **enumerated and never
executable**, always refused `resolutionPolicyDeferred`.

The sweep was widened to include `DeliveryProofAssessmentEventType` when that
vocabulary was introduced, and again to include `DeliveryProofDisputeEventType`
and `DeliveryProofDisputeCommand` at FND-003D2B. A guard that silently stops
covering a new surface would keep passing while proving nothing.

**Neither FND-003D2A nor FND-003D2B added a permission.** That clause is true
and is **not the same claim** as the total count, and conflating the two is what
let this paragraph go stale: `Permission.values` is **39**, not 38. The count
moved **38 → 39** at contract **0.10**, when FND-003B3B added
`agent.return.record_receipt` for shop-side receipt of returned goods — a slice
*later* than this document's own 0.7–0.9 subject matter. FND-003C1 (0.11) added
none either. **A count newer than this document's slice is normal, not a
defect**: this document carries a **fixed-origin** header ("Introduced at
contract version 0.7") and describes what D1, D2A and D2B did; it is not a
running snapshot of the whole contract. No `CustodyCommand`-style entry exists
for assessment, and both executable dispute operations map to the accepted
`customer.dispute.raise` and `admin.dispute.administer` rules, unchanged.

## 2. The two references

### `DeliveryProofPolicyRef`

Says **which** immutable proof policy applies. It does **not** say the policy
has been satisfied, and it does not say how proof would be captured.

- **No grammar is imposed.** The repository has no delivery-proof policy
  vocabulary to reuse, and inventing a prefix, version suffix or namespace would
  be inventing a contract rather than referring to one. A test asserts several
  quite different shapes are all accepted.
- **Bounded at 64 characters** *(FIX-001)* —
  `maxDeliveryProofPolicyRefLength`, denying `policyRefTooLong`. "No grammar"
  must not mean "no bound": this is a wire-facing value that travels through
  commands, events, audit records and logs, and an unbounded string on such a
  value is an amplification surface.
- **The constant aliases `maxIdLength`** *(FIX-002)* —
  `const int maxDeliveryProofPolicyRefLength = maxIdLength;`. There is **no
  separate numeric source** for this bound: writing `64` again would create a
  second constant free to drift from the canonical one, which no runtime test
  could detect. `CommandEnvelope.commandType` sharing the ceiling is supporting
  precedent, not a second source. A narrow source-shape regression pins the
  alias. **The coupling is numeric only** — a policy reference does *not* adopt
  opaque-id grammar: no minimum length, no alphabet, no prefix, namespace or URI
  requirement, no sequential-looking rejection. **It constrains how much, never
  what.** See
  [ADR-0008](../decisions/ADR-0008-bounded-delivery-proof-policy-reference.md).
- **Blank and whitespace-only values fail closed**, and take precedence: a
  65-character run of spaces reports `policyRefBlank`, not `policyRefTooLong`.
  `trim()` is used *only* to reject them; the stored value is untouched.
- **The exact value is preserved.** `' p/x@v1 '` and `'p/x@v1'` are different
  references, and `'POLICY/X@V1'` is a third. Equating any of them silently
  would let a corrupt stored value pass as a good one. Equality and `hashCode`
  use the exact underlying string.
- **`toString` does not reproduce the value** *(FIX-001)*. It renders
  `DeliveryProofPolicyRef(length=N)`. The reference has no character grammar by
  design, so its content is arbitrary — a `toString` that echoed it would make
  every `print`, crash report and error message a log-injection and content-leak
  route. The rendering is deliberately **lossy**: two different values of the
  same length render identically, which is exactly why equality does not go
  through it. The length is **not** a hash and derives no new identifier.
- **Not client authority.** A caller does not choose the governing policy by
  sending one. The backend resolves it from trusted order and policy state.

### `DeliveryEvidenceRef`

Points at protected evidence held for **one** order: a `resourceId` and an
`evidenceId`, both validated with the repository's canonical opaque-id rule.

- **Bound to its resource, and fail-closed** *(FIX-001)*. `belongsTo` returns
  true only when **all three** hold: this reference is well formed, the supplied
  target is itself a valid opaque id, and the two compare **exactly**. Raw
  equality alone failed open — two identically-malformed values, an empty stored
  resource against an empty target say, would have matched and the public
  convenience method would have certified a broken reference. It cannot now.
  The resource travels *with* the id rather than being supplied beside it,
  where the two could drift apart.
- **`evidenceId` is not a storage path, URL or signed URL**, and is deliberately
  not shaped like one: a locator would imply a retrieval and access design that
  no slice has made.
- **`toString` is fail-safe** *(FIX-002)*. A **well-formed** reference renders
  its two identifiers, which are canonical opaque ids and so already bounded and
  alphabet-restricted. A **malformed** one renders `DeliveryEvidenceRef(invalid)`
  and echoes **neither** field.

  The constructor is public and `const`, so malformed instances are deliberately
  representable — that is what makes the validator testable. Until
  `validateDeliveryEvidenceRef` has passed, those fields are just untrusted
  strings, and echoing them would make any `print`, crash report or error
  message an amplification and log-injection surface **before** validation,
  which is exactly the window that matters.

  Nothing is thrown, trimmed, hashed or repaired. **A rendering is a debug
  representation, never a validity claim** — `validateDeliveryEvidenceRef`
  remains the authoritative structural check.

## 2a. Structural validation and denial precedence

| Condition | Denial |
|---|---|
| blank / whitespace-only policy ref | `policyRefBlank` |
| policy ref longer than 64 | `policyRefTooLong` *(FIX-001)* |
| non-opaque **stored** `resourceId` | `evidenceResourceIdInvalid` |
| non-opaque `evidenceId` | `evidenceIdInvalid` |
| non-opaque **target** resource | `expectedResourceIdInvalid` *(FIX-001)* |
| both valid, but different orders | `evidenceResourceMismatch` |

**Deterministic precedence** for `validateDeliveryEvidenceRef`: stored
resource → evidence id → **target resource** → mismatch → null. The stored side
is inspected first because that is the corruption a caller cannot see, so a
malformed stored reference is never masked by a later check.

`expectedResourceIdInvalid` exists so three failures stay distinguishable:
*"the stored evidence names a broken resource"*, *"the caller asked about a
broken resource"*, and *"both are fine and they simply differ"*. Collapsing them
would hide which side is corrupt. `evidenceResourceMismatch` is therefore
reached **only** when both resources are valid opaque ids.

Everything here is **structural**. There is no denial meaning "the proof was not
satisfied", because no slice defines satisfaction.

## 3. What a reference cannot do

Neither reference can:

- move `OrderState`;
- move `CustodyHolder`;
- complete an assignment;
- authorize a caller;
- create, settle or imply money.

**Constructing or passing one authenticates nobody and authorizes nothing.** The
strongest statement either type can make is *"well formed, and bound to this
order"* — which is not a claim about delivery.

There is deliberately **no** `DeliveryProofStatus`, `proofSatisfied`,
`delivered` flag, proof-result enum, success/failure evaluator, target order
state or proof-mechanism enum. `DeliveryProofDenial` carries **structural**
values only; a test asserts none of its names contains `satisf`, `delivered`,
`success`, `failed`, `refused` or `accepted`.

## 4. No proof mechanism is selected

**None of these is defined, required, implied or reserved:** OTP · QR · barcode
· signature · photograph · video · GPS · biometric · customer confirmation ·
picker confirmation · device attestation · notification acknowledgement.

A test strips the doc comments from the source and asserts none of those terms
appears in the **code** — so the prose ruling them out cannot mask a real
declaration. The same test forbids `bytes`, `base64`, `blob`, `url`, `path`,
`address`, `phone`, `amount`, `retention`, `expires`, `duration` and `datetime`.

Choosing a mechanism was a later bounded task's decision, made against
`CONSTRAINTS.md` invariant 13. **It has since been made, at the policy level
only**, by
[ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md): a
**server-issued, single-use, resource-bound confirmation challenge**, verified
server-side and fail-closed. **Nothing in this section changes.** ADR-0012 adds
no code, so the source sweep above still passes unchanged — the challenge is
backend policy state, not contract vocabulary, and none of the terms listed
above is defined, required, implied or reserved *in this contract*. Naming a
mechanism in a decision document is not declaring one here.

## 5. Permissions — unchanged

`rider.delivery.submit_proof`, `customer.delivery.confirm_proof` and
`customer.dispute.raise` keep their exact ids, roles, scopes and restrictions.
**No permission was added by FND-003D1, FND-003D2A or FND-003D2B.** The count
is not 38 either: FND-003B3B took it to 39 at 0.10 by adding
`agent.return.record_receipt` (§1). The live figure, for
both `Permission.values` and `permissionMatrix`, is

> **Permission count: 39**

— written in that fixed form deliberately, so a machine can find it. It is the
**single** authoritative count claim in this document; §1 explains the history
in prose and states no competing figure.

Seven test files currently carry that count. Six pin the literal **39** for
both `Permission.values` and `permissionMatrix`:

| Guard | Note |
|---|---|
| [`delivery_proof_test.dart`](../../packages/contracts/test/delivery_proof_test.dart) | this document's own guard — the *"D1 added no permission; the only later addition is B3B's"* test |
| [`delivery_proof_assessment_regression_test.dart`](../../packages/contracts/test/delivery_proof_assessment_regression_test.dart) | D2A regression |
| [`delivery_proof_dispute_authority_test.dart`](../../packages/contracts/test/delivery_proof_dispute_authority_test.dart) | D2B authority |
| [`attempt_return_authority_test.dart`](../../packages/contracts/test/attempt_return_authority_test.dart) | B3B authority |
| [`cod_collection_authority_test.dart`](../../packages/contracts/test/cod_collection_authority_test.dart) | C1 authority |
| [`permission_matrix_doc_consistency_test.dart`](../../packages/contracts/test/permission_matrix_doc_consistency_test.dart) | also guards `permission-matrix.md` |

The seventh, [`permission_matrix_test.dart`](../../packages/contracts/test/permission_matrix_test.dart),
pins no literal: it asserts the id set length equals `Permission.values.length`.

An eighth,
[`delivery_proof_boundary_doc_consistency_test.dart`](../../packages/contracts/test/delivery_proof_boundary_doc_consistency_test.dart),
guards **this paragraph itself**. It derives the expected number from
`Permission.values.length` and hard-codes no count literal, so a 40th
permission fails it until this document is updated — which is exactly the
failure that did not happen when the count moved at 0.10.

**`customer.delivery.confirm_proof` is not reinterpreted.** The accepted matrix
says customer participation in proof **does not settle cash and does not close a
dispute**, and a test asserts that restriction text is still present. Whether
customer participation is *required* by any policy is **DEFERRED** (§7).

## 6. Privacy and the event boundary

`EventEnvelope.payload` remains **routing and display only** — unchanged by this
task. A copy may travel through a push transport, be rendered on a lock screen
and be cached by the OS.

- **Raw evidence must never enter a notification or event payload.** A
  reference may; the material may not.
- **A notification proves nothing and authorizes nothing.** It cannot establish
  delivery and cannot drive a state transition. It may simply be missed.
- Evidence details are obtained later over an **authenticated, authorized
  protected path**. **This task does not implement that path**, and makes no
  claim about Firestore Rules, Storage Rules, upload security, encryption at
  rest, signed URLs or access policy.

Everything a `DeliveryEvidenceRef` exposes is an opaque identifier — exactly the
class of value the payload rules already permit.

## 7. Deferred, and deliberately not defaulted

**None of these has a value here, and none is zero or "false by default".**
Writing a placeholder that looks authoritative would be worse than leaving the
question open:

- proof evidence **retention period**;
- evidence **visibility** for customer, rider, agent and admin;
- **deletion and legal-hold** policy;
- ~~**proof acceptance / satisfaction** policy — *what a policy actually
  requires*~~ — **DECIDED 2026-09-12** by
  [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md)
  (owner decision **O8**). FND-003D2A added a place to record the **result** of
  evaluating a policy, and deliberately not the policy itself; ADR-0012 now
  says what a v1 policy requires — a server-issued, short-lived, single-use
  challenge bound to one order, attempt, customer and assigned rider, fulfilled
  by the customer side and **verified by the trusted backend**, fail-closed.
  Rider photograph, GPS, timestamp, unbound signature, rider assertion, cash
  collection, customer non-response, attempt completion and custody possession
  are each **insufficient alone**. **The executable contract is still
  DEFERRED**: no challenge lifecycle, evaluator or delivery transaction exists;
- **the concrete challenge parameters** — length, alphabet, validity window and
  rate limits — **DEFERRED** as operational configuration within ADR-0012's
  bounds, which forbid a policy version from setting any of them to unlimited
  or from disabling single-use, binding or expiry;
- the **exception-review workflow and its permission** — ADR-0012 requires any
  accessibility or impossible-primary-method path to be separately authorized,
  reason- and reference-bearing and audited, and **does not create it**. No such
  permission exists. Its authority is bounded to **recording, classifying and
  auditing** an unresolved case: it **cannot mark proof satisfied, cannot mark an
  order delivered, cannot waive the proof requirement, cannot assign customer
  fault, cannot create a fee and cannot resolve a dispute**, and it may not
  substitute a photograph, GPS fix, signature, rider statement, cash collection
  or administrator judgement for a customer-side act. **Any future policy that
  would allow satisfaction without a customer-side act requires a superseding ADR
  and a contract migration, accepted before implementation;**
- the **authenticated customer retrieval surface** that displays the raw
  challenge to the customer — ADR-0012 specifies the required channel *class*
  (authenticated, customer-scoped, bound to the exact customer and resource; the
  rider never retrieves it; a notification may signal availability but never
  carries the value) and **implements none of it**, so that route is not
  executable until the surface exists;
- the **dispute outcome** — how a fallback dispute resolves, and whether any
  delivery, refusal, return, fee, refund, compensation or liability follows.
  The fallback dispute **workflow** itself is **done** (FND-003D2B, 0.9) and
  deliberately resolves nothing. Of the three things this bullet once said the
  outcome needed, **two are discharged**: **O6 is RESOLVED** (2026-09-11,
  [ADR-0011](../decisions/ADR-0011-o6-currency-fees-commission-and-cash-custody.md)
  — currency, fee policy, commission ownership and cash custody), and
  **FND-003B3B is DONE and integrated** (0.10, the attempt/return lifecycles),
  though it deliberately decides **no** dispute outcome, fault or money. Only
  the remaining **FND-003C** money work still applies: FND-003C1 (0.11)
  delivered COD collection and the cash journal, while remittance, settlement,
  reconciliation, refusal-fee collection, refunds, compensation and commission
  payout are **unimplemented**. **The outcome itself stays UNDECIDED** —
  discharging a prerequisite is not deciding the question, and a dedicated
  resolution slice must still do that;
- ~~whether **customer participation** is required by any policy~~ —
  **DECIDED 2026-09-12** by
  [ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md):
  customer participation is **MANDATORY and NOT SUFFICIENT**. There is no route
  to satisfaction in which the customer side does nothing, and fulfilling a
  challenge is an *input* the server still verifies rather than a verdict. It is
  **not a veto that ends the order**: non-participation yields no satisfaction
  and nothing else — no refusal, no fault, no fee. **No administrative act may
  supply the customer's part**: an ADMIN exception review records and audits an
  unresolved case and **cannot conclude satisfaction** (ADR-0012 Decision 9), and
  any future substitution requires a **superseding ADR and contract migration**.
  It was **POLICY-DEFINED / DEFERRED** through 0.9, and FND-003D2B did not decide it either — **raising a
  dispute is not participation in proof**. **No `customerConfirmed` flag was
  added by this decision**, and none exists: the requirement is a policy rule
  the implementing slice must satisfy, not a field on an existing type.
  `customer.delivery.confirm_proof` keeps its exact accepted meaning —
  participation only, settling no cash and closing no dispute (§5).

## 8. What the eventual delivery slice must reconcile

Before a successful-delivery command can exist, a later bounded task must first
define the **proof-satisfaction and fallback-dispute contract** that
`CONSTRAINTS.md` invariant 13 requires.

**Advanced by FND-003D2A, FND-003D2B and ADR-0012 — and still not complete.**
There is now a trusted, immutable place to record *whether* a policy was
satisfied ([delivery-proof-assessment.md](delivery-proof-assessment.md)), so a
later delivery transaction has something to consume; a defined fallback for when
that result is missing, superseded or `notSatisfied`
([delivery-proof-dispute.md](delivery-proof-dispute.md)) — which resolves
nothing and decides no outcome; and, since 2026-09-12, an accepted answer to
what a policy **requires**
([ADR-0012](../decisions/ADR-0012-delivery-proof-satisfaction-policy.md)).

**What is still missing is the executable contract.** ADR-0012 is a policy
decision and adds no type, command, event, state, permission or evaluator, so
**invariant 13 is not discharged and delivery confirmation still may not be
coded**. No current command can manufacture proof satisfaction: there is no
challenge lifecycle, no verifier evaluation against the policy, and no delivery
transaction. `OrderState.delivered`, `DeliveryAttemptState.delivered`, customer
custody and rider `completed` are exactly as unreachable as before. The
implementing slice **must conform to ADR-0012**, and weakening any part of it
needs a superseding ADR rather than a configuration change.

**Fail-closed conditions the implementing slice inherits** (ADR-0012 Decisions 6
and 11), each yielding **no satisfaction**: a missing, expired, replayed,
mismatched or mis-bound challenge; a rider who is not the currently assigned one,
or a moved assignment generation; a stale order, custody, rider-slot or
assessment revision; a malformed or inconsistent aggregate; **no customer-side
fulfilment at all**; and a governing policy version that is **missing, unknown,
unresolvable, unsupported or unverifiable**. **No default policy is inferred** —
no built-in fallback, no silent substitution of the latest or a previous
version — because an order keeps the policy version it was quoted under, and
evaluating it under another is worse than refusing.

That slice must then reconcile, in one design:

- order `in_delivery → delivered`;
- custody `rider → customer`;
- rider assignment completion and **B3-C2**;
- the exact current rider assignment and custody binding;
- current order, custody and rider-slot revisions;
- fresh authorization;
- command idempotency;
- atomic dedupe and outbox;
- any COD or payment consequence, which is **FND-003C's** — **O6 is resolved**
  (ADR-0011), and the remaining money lifecycle work is unimplemented.

**FND-003D1 decides none of those edges.**

## 9. Failure, refusal and return — documented, not implemented

- The canonical delivery-attempt vocabulary already distinguishes **delivered**,
  **refused** and **failed**. No separate attempt state for "customer
  unavailable", "bad address" or "damaged goods" exists, and none was created.
- **Refused and failed are attempt outcomes, not permission to make the ORDER
  terminal.**
- A customer or rider may request cancellation or refusal only through named
  permitted operations; **the server decides from current state**.
- **No retry count, retry timer, auto-cancellation or timeout** is defined here.
- After physical pickup, refusal requires **return processing** — and this task
  does **not** choose between `rider → picker` and `rider → shop`.
- A neutral `ReturnState.required` may be introduced **only** by the later
  return slice. It does not exist in code today and was not added.
- **Custody remains explicit and singular**, exactly as FND-003B3A defines it.
- **No failed or refused attempt restores stock.** Stock cannot become available
  again until **shop receipt AND inspection** — `CONSTRAINTS.md` invariant 12.

## 10. Financial boundary

No COD amount or state, delivery charge, refusal fee, refund, liability,
commission, journal posting, settlement or remittance exists here.

Any future financial consequence of delivery, refusal or return is
**UNKNOWN / DEFERRED TO FND-003C**, itself **blocked on owner decision O6**.
**Zero is never used as a substitute for undecided policy.**

## 11. Future atomicity and race requirements

Backend obligations, **not** current evidence, and **not PASS** — no pure-Dart
test can establish any of them:

- delivery success vs refusal;
- delivery success vs rider revoke;
- delivery success vs cancellation;
- failed attempt vs reassignment;
- return initiation vs another delivery attempt;
- duplicate, retried and reordered commands;
- stale custody revision;
- stale order revision;
- stale rider slot revision.

A later final transition must read current trusted facts and commit its complete
cross-aggregate consequence as **one atomic backend transaction**, together with
principal-scoped dedupe and the outbox. **Fresh authorization must occur before
every execution and every replay** — R33–R40, still NOT RUN.

## 12. Status carried forward, unchanged

**CA1–CA23 NOT RUN · R33–R40 NOT RUN · L1–L13 NOT RUN · P1–P17 NOT RUN ·
RA1–RA18 NOT RUN.**

**B3-C1** — satisfied by contract tests only (picker completion); **not**
persistence evidence. **B3-C2** — **NOT RUN / FUTURE**; rider completion remains
unreachable and its revision cost remains undefined.

A regression suite in this task re-pins that `OrderState.delivered`,
`CustodyHolderKind.customer` and rider `AssignmentState.completed` are all still
unreachable, and that picker completion's revision range is unchanged.

## 13. Out of scope

Not implemented, and **not guessed**: successful delivery · delivery
confirmation · delivery attempts · refusal and failure · returns and
post-dispatch inventory restoration · customer custody · rider completion ·
COD and payment · fees, commissions, settlement and remittance · dispute
resolution · proof mechanisms · retention, visibility and deletion policy ·
storage paths, URLs and access rules.
