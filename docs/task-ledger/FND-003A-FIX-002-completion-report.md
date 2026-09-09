# FND-003A-FIX-002 completion report

- **Task:** Close the authorization-to-idempotency trust-boundary defect found
  reviewing FND-003A-FIX-001
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `228409d64069604235621f56ef620f6a40be35bf`, branch
  `fnd/FND-003A-command-auth-contracts`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.2, corrected in place** (not bumped)
- **Status:** **DONE**

Neither published commit was amended. This is one new commit on the same
branch.

## 1. Root cause

Two distinct problems, both real.

**The success artifact was fabricable.** `AuthorizationDecision` exposed
`const AuthorizationDecision.allow()` publicly, and the class carried no
`final` modifier. So any caller could either construct a successful decision
outright or `implement` a look-alike, without ever running
`evaluateAuthorization`. The contract's own tests did precisely this:

```dart
const AuthorizationDecision allowed = AuthorizationDecision.allow();
```

The documentation nevertheless claimed *"there is no way to call this without
having evaluated authorization first."* That statement was false at `228409d`.
The API had a naming and comment boundary where it needed a type boundary.

**An allowed decision was unbound.** It recorded only "allowed", not *what* was
allowed. A success produced by authorizing principal A for resource X could be
presented while serving principal B's command on resource Y, and nothing in the
type or the check would notice.

## 2. Authorization artifact design

**Model chosen: the grant token (Option 1)** — fewer invalid states than a
bound-decision model, because a denial simply produces nothing to pass.

```dart
final class AuthorizationGrant {
  const AuthorizationGrant._({ ... });   // library-private
  final String principalId;
  final Permission permission;
  final String resourceId;
  bool covers({required String principalId, required String resourceId});
}
```

| Mechanism | Effect |
|---|---|
| `final class` | cannot be `extend`ed or `implement`ed outside its library — no look-alike |
| only constructor is `_`-private | cannot be constructed outside its library |
| produced solely by a successful `evaluateAuthorization` | the single source of truth |

`AuthorizationDecision` received the same treatment: `final`, with
library-private `_allow` / `_deny`. Its `grant` field is non-null **exactly
when** allowed, and `allowed` is derived from it — so there is no second
boolean that could disagree with the artifact.

This is a type-system guarantee. No `trusted` / `resolved` / `verified` naming
and no "server only" comment is relied on, because none of those stop anyone.

**Bindings:** principal id, resource id, and the permission that was evaluated
— all taken from the `AuthorizationRequest` the evaluator actually ran, never
from caller-supplied data. No tenant or actor wire field was introduced.

## 3. Idempotency integration

```dart
IdempotencyOutcome evaluateIdempotency({
  required AuthorizationGrant grant,
  required Principal principal,
  required CommandEnvelope incoming,
  StoredCommandRecord? stored,
})
```

- **How authorization is obtained:** only from `evaluateAuthorization`. A
  denied evaluation yields no grant, so *"replay while denied"* is not an
  expressible state — there is nothing to pass.
- **`rejectNotAuthorized` was removed.** Keeping it would have implied a
  reachable state that no longer exists. Its absence *is* the guarantee.
- **Binding checks:** `grant.covers(principalId:, resourceId:)` is verified
  against the acting principal and the incoming command's resource before
  anything else. Failure → `rejectAuthorizationMismatch`.
- **Permission is deliberately not checked here.** No command-type →
  permission mapping exists in the contract, so the check would be theatre. No
  registry was invented for appearances. The binding is retained on the grant
  for backend dispatch and audit, and the documentation states that the trusted
  router maps command type to required permission *before* authorization runs.
- **Namespace unchanged:** the lookup key remains `(principalId, commandId)`
  via `IdempotencyNamespace`, with `rejectNamespaceMismatch` as defence in
  depth.
- **Revoked/suspended actors:** cannot obtain a grant *now*, so cannot replay a
  command id from when they could. Verified by test.

## 4. Regression tests

`test/forgery_probe_test.dart` proves non-constructibility by **asking the
analyzer**, not by matching source strings. `test/support/forgery_probe.dart.txt`
holds six forgery attempts and is deliberately not a `.dart` file, so the
repository gate never analyzes it; the test copies it to a temporary `.dart`,
runs `dart analyze`, asserts each attempt is rejected, and deletes it in a
`finally`. All six are rejected:

| Attempt | Analyzer verdict |
|---|---|
| `AuthorizationGrant(...)` | `new_with_undefined_constructor_default` |
| `AuthorizationGrant._(...)` | `new_with_undefined_constructor` |
| `implements AuthorizationGrant` | can't be implemented outside its library |
| `extends AuthorizationGrant` | can't be extended outside its library |
| `AuthorizationDecision.allow()` | `undefined_method` |
| `implements AuthorizationDecision` | can't be implemented outside its library |

Other required coverage, in `test/idempotency_test.dart` against real grants
from `test/support/authz_fixtures.dart`:

- a genuine grant permits normal execution;
- same principal + same fingerprint replays; changed fingerprint is key reuse;
- **principal A's grant cannot be used for principal B** →
  `rejectAuthorizationMismatch`;
- **a grant for resource X cannot serve a command on resource Y** → same;
- a borrowed grant cannot replay the grant-holder's stored result;
- a suspended actor's evaluation yields `grant == null` and
  `DenyReason.membershipNotActive`; a revoked actor likewise;
- a non-owner's evaluation yields no grant (`resourceOwnerMismatch`);
- foreign stored namespace still rejects;
- actor-shaped payload keys remain inert;
- replay identity still does not depend on any clock.

**No test fabricates a decision any more** — the fabrication pattern no longer
compiles, which is how the defect surfaced during this fix.

## 5. Prior findings — no regression

All four FIX-001 fixes were re-run and pass unchanged:

| Finding | Status | Evidence |
|---|---|---|
| Offer recipient isolation | **intact** | `assignment offer is addressed to one worker` 8/8; `assignment offer scoping` 5/5 |
| Approval requester/permission/resource binding | **intact** | `approval is bound to this exact action` 8/8 |
| Principal-scoped idempotency namespace | **intact** | `namespace isolation` 4/4 |
| Version policy vs payload compatibility | **intact** | `contract_version_test.dart` 7/7 |

Also unchanged: `CommandEnvelope` still has no authoritative actor field; the
permission matrix was not edited; `ContractVersion` semantics were not touched.

## 6. Validation

| # | Command | Result |
|---|---|---|
| V1 | `git status --short`, branch, HEAD (before) | **PASS** — clean, `fnd/FND-003A-command-auth-contracts` @ `228409d` |
| V2 | `dart test test/forgery_probe_test.dart` | **PASS** — 7 |
| V3 | `dart test --plain-name "authorization evidence cannot be forged or borrowed"` | **PASS** — 8 |
| V4 | `dart test --plain-name "namespace isolation"` | **PASS** — 4 |
| V5 | `dart test --plain-name "replay semantics within one namespace"` | **PASS** — 4 |
| V6 | `dart test --plain-name "assignment offer is addressed to one worker"` | **PASS** — 8 |
| V7 | `dart test --plain-name "approval is bound to this exact action"` | **PASS** — 8 |
| V8 | `dart test test/contract_version_test.dart` | **PASS** — 7 |
| V9 | `dart test` (all `cp_contracts`) | **PASS** — **125** (was 113) |
| V10 | `flutter analyze` | **PASS** — `No issues found!` |
| V11 | `./tools/check_layering.sh` | **PASS** — 8 rules |
| V12 | `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| V13 | whole repository | **PASS** — **166 tests across 10 of 15 members** (was 154) |

No FND-002 platform, device or browser check was repeated. Nothing BLOCKED or
NOT RUN.

## 7. Files changed

| Path | Purpose |
|---|---|
| `packages/contracts/lib/src/authorization.dart` | `AuthorizationGrant` (final, private ctor, bindings); `AuthorizationDecision` made final with private ctors |
| `packages/contracts/lib/src/idempotency.dart` | requires a grant; binding checks; `rejectNotAuthorized` → `rejectAuthorizationMismatch` |
| `packages/contracts/test/support/authz_fixtures.dart` | **new** — real-evaluator fixtures |
| `packages/contracts/test/support/forgery_probe.dart.txt` | **new** — six forgery attempts, not analyzed by the gate |
| `packages/contracts/test/forgery_probe_test.dart` | **new** — compile-failure regression guard |
| `packages/contracts/test/idempotency_test.dart` | real grants; cross-principal and cross-resource reuse tests |
| `docs/contracts/authorization-invariants.md` | corrected overclaim; documents the type boundary |
| `docs/contracts/command-and-event-envelopes.md` | corrected the false "no way to call this" claim; new outcome table |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-002 entry; three-commit evidence chain |
| `docs/task-ledger/FND-003A-FIX-001-completion-report.md` | §9 recheck note — history annotated, not erased |
| `docs/task-ledger/FND-003A-FIX-002-completion-report.md` | this report |

Untouched: `permission_matrix.dart`, `scope.dart`, `contract_version.dart`,
apps, backend, infra, `pubspec.yaml`, `pubspec.lock`. **No dependency added** —
the contract stays dependency-free.

## 8. Contract version

**0.2, corrected in place.** Evidence, re-verified today: the branch has never
been merged — `origin/main` is at `2616a4c`, which predates 0.2 entirely; no
app has a platform folder or a build; no Firebase project exists, so no stored
production datum uses 0.2. These remain edits to an unreleased definition, not
an observable wire change. A bump would imply an external event that did not
occur, and "another review fix was required" is not such an event.

## 9. Scope statement

No lifecycle state machine, inventory behaviour, custody transition,
payment/COD, cash journal, fee, commission, settlement, proof/dispute workflow,
backend handler or Firebase rule was introduced. Offer/assignment semantics,
approval binding and `ContractVersion` semantics were left as FIX-001 set them.
**FND-003B remains NOT STARTED.** Nothing was merged to `main`, pushed or
deployed.
