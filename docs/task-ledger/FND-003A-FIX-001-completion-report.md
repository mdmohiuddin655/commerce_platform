# FND-003A-FIX-001 completion report

- **Task:** Fix four security/compatibility defects found reviewing FND-003A
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `de19dc997d65d371b1bd8214916f58e5992c80c7`, branch
  `fnd/FND-003A-command-auth-contracts`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.2, corrected in place** (not bumped)
- **Status:** **DONE** — partially superseded by **FND-003A-FIX-002**
  (2026-09-10). Its §3 "authorization precedes replay" guarantee was weaker
  than this report stated. See [§9 Recheck](#9-recheck-fnd-003a-fix-002).

The published commit `de19dc9` was **not** amended. This is a new commit on the
same branch.

## 1. Assignment offer versus accepted assignment

**Preserved (the review's finding #1, which was correct):** accepting or
declining an offer must **not** require an already accepted assignment — that
would be circular.

**Fixed (finding #2):** accept/decline were scoped by `ownRegion` **alone**, so
any active worker in the same region could accept another worker's offer. The
contract had no way to say *"this offer was addressed to you"*.

Two distinct relationships now exist, and conflating them breaks authorization
in opposite directions:

| Requirement | Means | Used by |
|---|---|---|
| `offeredResource` | the work was **addressed to** this actor | accept, decline |
| `assignedResource` | this actor holds an **accepted** assignment | every post-acceptance action |

- `ResourceScope.offeredPrincipalIds` added, alongside the existing
  `assignedPrincipalIds`. Both are read from **trusted server storage**; if a
  caller could state who was offered the work, a caller could offer it to
  themselves.
- `PermissionRule.scope` became `PermissionRule.scopes`, a **set where all
  requirements must hold**. This was the clean extension the task asked for:
  accept/decline needs the targeted offer *and* the region, and neither
  constraint was dropped to fit a single-value field. Requirements are
  evaluated in `ScopeRequirement` declaration order, so the reported deny
  reason does not depend on how a set literal was written.
- New `DenyReason.offerMismatch`, distinct from `assignmentMismatch`: *"the
  offer was not addressed to you"* is a different fact from *"you have not
  accepted it"*.

The four rules `picker.assignment.accept`, `picker.assignment.decline`,
`rider.assignment.accept`, `rider.assignment.decline` now require
`offeredResource + ownRegion`.

**Deliberately not implemented:** whether an offer is still *live* — not
expired, declined or superseded — is assignment lifecycle state owned by
**FND-003B**. Authorization establishes *"this offer belongs to this actor and
is inside allowed scope"*; lifecycle then establishes *"this offer is still in
a state that may transition"*.

## 2. Approval trust boundary

**Fixed (finding #3).** The old check — non-empty reference, approver ≠
requester — meant **any** approval record satisfied **any** privileged action.

`ApprovalEvidence` now binds an approval to the exact request:

| Field | Purpose |
|---|---|
| `approvalRef` | auditable reference to the stored record; must be a valid opaque id |
| `requesterPrincipalId` | must be the acting principal |
| `approverPrincipalId` | must **not** be the acting principal |
| `permission` | must be the permission being exercised |
| `resourceId` | must be the resource being acted on |
| `approvedAtServerUtc` | server time the approval was recorded |

The only constructor is `ApprovalEvidence.resolved(...)`, named so every call
site states that a trusted lookup produced it. There is **no `fromJson`**, and
no caller-controlled `approverIsAuthorized` flag — a boolean an attacker can
set is not a check.

Documented trust boundary: a client may at most submit an approval
**reference**; the backend resolves it from trusted storage, verifies the
record and the approver's own authority and scope, and only then constructs the
evidence passed to the pure evaluator.

New `DenyReason.approvalMismatch` (evidence supplied but not bound) is distinct
from `approvalRequired` (none supplied).

**What remains for a future approval workflow, stated explicitly rather than
implied:** the evaluator does **not** verify the approver held the right
permission — that is a full authorization evaluation of a second principal, and
belongs to the workflow that issues the record. And **expiry is not specified**:
no arbitrary lifetime was invented; the owning workflow defines the policy, and
`approvedAtServerUtc` is what it will evaluate against.

## 3. Idempotency principal isolation

**Fixed (finding #4).** Replay keyed on the command id alone. Command ids are
client-generated, so one principal could receive another's stored result.

- **Lookup key is now `(principalId, commandId)`**, expressed as
  `IdempotencyNamespace.forPrincipal(...)`. `StoredCommandRecord` carries its
  namespace.
- The principal comes from **verified authentication**, never the wire
  envelope. `CommandEnvelope` still carries **no actor field**, so a client
  cannot choose the namespace it is deduplicated in, and payload spoofing
  cannot move a lookup. Tested.
- **Foreign-principal behaviour:** both designs the task offered, deliberately.
  The correct lookup makes a collision *unreachable*; `rejectNamespaceMismatch`
  is kept as defence in depth, so a lookup bug surfaces as an explicit
  rejection rather than a cross-principal data leak. Tested to confirm the
  stored `resultRevision` is never returned.
- **Authorization precedes replay:** `evaluateIdempotency` now takes the
  `AuthorizationDecision` itself — not a boolean a caller could set — and
  short-circuits to `rejectNotAuthorized`. There is no way to call it without
  having evaluated authorization first, so a stored result cannot outlive the
  authority that produced it: a revoked membership or a lost assignment stops
  replays too.

*Why principal and not shop/region/tenant:* resource isolation is already
enforced by authorization on every command, replays included. Principal is
therefore sufficient **and** the narrowest correct choice. **No `tenantId` wire
field was invented** — this architecture has not defined a tenant dimension. If
one appears, it extends `IdempotencyNamespace`, which is why that is a type
rather than a bare string.

## 4. Version policy versus payload compatibility

**Fixed (finding #5).** The old `canRead` name and the docs/tests claimed a 0.1
reader accepts 0.2 payloads and that unknown fields are ignored. **Neither was
demonstrated.** 0.1 had no command envelope, event envelope or permission
decoder — and `cp_contracts` has **no serialization at all**, so those claims
were untestable, not merely untested.

- `canRead` → **`isVersionCompatibleWith`** (plus `isSameMajor`). It answers
  only: *does the version policy permit attempting to decode?* A `true` result
  is **permission to try**, never proof a payload decodes.
- The false forward-compatibility test was **removed**, not reworded. A
  replacement test records that no decoder exists, guarding the claim from
  creeping back.
- Corrected 0.1 → 0.2 statement: additive **at the version-policy level**; no
  released 0.1 client exists; therefore **no deployed payload-compatibility
  claim**; and 0.1 cannot be cited as evidence for decoding types that did not
  exist in it.
- "Unknown fields are ignored" was removed. Unknown **permission** (denies) and
  unknown **command type** (rejected) remain documented, because the code
  actually implements them.

## 5. Contract version decision

**0.2 was corrected in place. It was not bumped.**

Evidence: the branch `fnd/FND-003A-command-auth-contracts` has never been
merged — `origin/main` is still at `2616a4c`, which predates 0.2 entirely. No
app has a platform folder or a build, and no Firebase project exists, so no
client and no stored datum has ever seen 0.2. The corrections are therefore
edits to an unreleased definition, not a wire change any consumer could
observe. A bump would imply an external event that did not occur.

## 6. Validation

| # | Command | Result |
|---|---|---|
| V1 | `git status --short` (before) | **PASS** — clean |
| V2 | branch / HEAD | **PASS** — `fnd/FND-003A-command-auth-contracts` @ `de19dc9` |
| V3 | `dart test --plain-name "assignment offer is addressed to one worker"` | **PASS** — 8 |
| V4 | `dart test --plain-name "approval is bound to this exact action"` | **PASS** — 8 |
| V5 | `dart test --plain-name "namespace isolation"` | **PASS** — 4 |
| V6 | `dart test --plain-name "authorization precedes replay"` | **PASS** — 3 |
| V7 | `dart test test/contract_version_test.dart` | **PASS** — 7 |
| V8 | `dart test` (all `cp_contracts`) | **PASS** — **113** (was 83) |
| V9 | `dart run tool/print_permission_matrix.dart` + diff | **PASS** — regenerated; **no drift**, generated table present verbatim in the doc |
| V10 | `flutter analyze` | **PASS** — `No issues found!` |
| V11 | `./tools/check_layering.sh` | **PASS** — 8 rules |
| V12 | `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| V13 | whole repository | **PASS** — **154 tests across 10 of 15 members** (was 124) |

Nothing BLOCKED or NOT RUN. No device, runner, credential or emulator was
needed, and no FND-002 platform check was repeated.

Two of my own tests failed on first run and were corrected: an outdated
expectation of `approvalRequired` where the more precise `approvalMismatch` is
now returned, and an idempotency test that compared a stored spoofed
fingerprint against a non-spoofed incoming envelope.

## 7. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/scope.dart` | `offeredPrincipalIds`, `isOfferedTo`, `ScopeRequirement.offeredResource` |
| `packages/contracts/lib/src/permission_matrix.dart` | `scopes` set; accept/decline require offer + region |
| `packages/contracts/lib/src/authorization.dart` | multi-scope evaluation, `offerMismatch`, bound `ApprovalEvidence.resolved`, `approvalMismatch` |
| `packages/contracts/lib/src/idempotency.dart` | `IdempotencyNamespace`, namespaced records, authorization-gated replay |
| `packages/contracts/lib/src/contract_version.dart` | `isVersionCompatibleWith` / `isSameMajor`; corrected claims |
| `packages/contracts/tool/print_permission_matrix.dart` | render the scope set |
| `packages/contracts/test/{authorization,idempotency,permission_matrix,contract_version}_test.dart` | new offer, approval, namespace and version coverage |
| `docs/contracts/{identity-membership-and-scope,permission-matrix,authorization-invariants,command-and-event-envelopes,version-history}.md` | brought into agreement with the code |
| `docs/task-ledger/TASK_LEDGER.md` | FND-003A-FIX-001 entry; FND-003A evidence chain |
| `docs/task-ledger/FND-003A-completion-report.md` | §9 corrective note — history annotated, not erased |
| `docs/task-ledger/FND-003A-FIX-001-completion-report.md` | this report |

Untouched: apps, backend, infra, all other packages, `pubspec.yaml`,
`pubspec.lock`. No dependency added.

## 8. Scope statement

No lifecycle state machine, inventory behaviour, custody transition,
payment/COD, cash journal, fee, commission, settlement, proof/dispute workflow,
backend handler or Firebase rule was introduced. **FND-003B remains NOT
STARTED.** Nothing was merged to `main`, pushed or deployed.

## 9. Recheck (FND-003A-FIX-002, 2026-09-10)

Findings 1–4 of this report stand: offer-recipient isolation, approval
binding, principal-scoped idempotency namespace and version-policy semantics
were all confirmed correct on recheck and are unchanged.

**One claim in §3 was wrong.** This report stated that taking the
`AuthorizationDecision` "rather than a boolean makes 'authorization precedes
replay' impossible to skip: there is no way to call this without having
evaluated authorization first."

That was false. `AuthorizationDecision.allow()` was a **public const
constructor**, and the class carried no `final` modifier, so any caller could
fabricate or impersonate a successful decision without ever running
`evaluateAuthorization` — and this repository's own idempotency tests did
exactly that (`const AuthorizationDecision allowed = AuthorizationDecision.allow();`).

Secondly, an allowed decision carried **no binding** to what had been
authorized, so a success produced for principal A on resource X could be
presented while serving principal B or resource Y.

Corrected by FND-003A-FIX-002: a `final`, library-privately-constructed
`AuthorizationGrant` is produced only by a successful evaluation and records
the principal, permission and resource; `evaluateIdempotency` requires one and
re-checks its bindings. `rejectNotAuthorized` was removed because a denial now
yields no grant at all, making "replay while denied" inexpressible rather than
merely rejected. Full detail:
[FND-003A-FIX-002 report](FND-003A-FIX-002-completion-report.md).

**Lesson recorded, since this is the second review to find it:** a guarantee
asserted in a doc comment is not a guarantee. FIX-001 wrote the claim into
prose and moved on; FIX-002 backs it with a compile-failure regression test
(`test/forgery_probe_test.dart`) that asks the analyzer whether the forgery
routes are actually closed.
