# Authorization invariants

**Contract version 0.2** (FND-003A). Implemented by `evaluateAuthorization`.

## The evaluator

Pure Dart. No I/O, no clock, no database, no Firebase, no Flutter, no App
Check. The same inputs always produce the same decision, which is what makes
every deny path unit-testable.

Evaluation order — cheapest and most fundamental first, and **no later check
can rescue an earlier failure**:

1. **Identity** — is there a verified principal? Is it a human?
2. **Standing** — does a membership exist *for this principal*, in an
   acceptable status?
3. **Role** — is the role eligible for this permission?
4. **Scope** — owner / shop / region / offer / assignment relationships. A
   rule may require several; **all must hold**, evaluated in
   `ScopeRequirement` declaration order for a deterministic deny reason.
5. **Procedure** — reason required? dual-control approval required?

## Three separate boundaries

Conflating these is how a type-system win gets mistaken for a security
guarantee. Each covers a different failure, and **only the first is enforced by
Dart**.

### 1. Type boundary — enforced by the compiler

`evaluateAuthorization` is the only entry point. `AuthorizationDecision` and
`AuthorizationGrant` are both `final` with library-private constructors, so no
external code can construct or impersonate either.
`AuthorizationDecision.grant` is non-null **exactly when** the request was
allowed; `allowed` derives from it, so no second flag can disagree.

Proven by a compile-failure regression test
(`packages/contracts/test/forgery_probe_test.dart`).

**What this proves, exactly:** `evaluateAuthorization` returned *allow* for the
inputs it was given, and nobody manufactured that result afterwards.

**What it does not prove — any of it:**

- that the auth token was verified;
- that `Principal` was derived from that verified token;
- that `Membership` was loaded from authoritative storage;
- that the membership status was **current**;
- that `ResourceScope` was freshly loaded;
- that offered/assigned relationships were current;
- that `ApprovalEvidence` came from a trusted approval record;
- that the required `Permission` was the correct one for the incoming command.

A grant computed from stale or attacker-influenced inputs is a perfectly valid
grant. **Garbage in, authentically-signed garbage out.**

### 2. Trust boundary — a server integration duty

The eight items above are the backend's responsibility, per request. The type
boundary prevents fabrication *after* evaluation; it says nothing about the
quality of the inputs *before* it. Client payload data remains never
authority — that rule is unchanged and still enforced by the evaluator taking
no payload.

### 3. Request-lifetime boundary — a discipline, not a type

An `AuthorizationGrant` is **ephemeral**. It is valid only inside the
command-processing flow of the request that produced it. See *Fresh
authorization on every request* below. Dart cannot enforce this: a retained
grant still "covers" a later matching request, and
`packages/contracts/test/idempotency_test.dart` demonstrates exactly that
rather than pretending otherwise.

> **History.** Until FND-003A-FIX-002 this section overclaimed in a different
> way: `AuthorizationDecision` had a public `allow()` constructor, so anyone —
> including the contract's own tests — could fabricate success. FIX-002 closed
> that. FND-003A-FIX-003 then corrected the remaining overclaim: the private
> constructor is a type boundary, **not** evidence that the evaluator's inputs
> were trustworthy or fresh.

## Fresh authorization on every request

**Every command request performs authorization from current, trusted inputs
before it either executes a new command or replays a stored idempotent
result.** There is no exception for retries.

Per request, the backend must:

1. verify the current authentication context;
2. derive the `Principal` from it;
3. resolve the current `Membership` from authoritative storage;
4. resolve current `ResourceScope` — owner, shop, region, offered and assigned
   relationships;
5. resolve required `ApprovalEvidence` from trusted storage where applicable;
6. map the incoming `commandType` to its required `Permission`;
7. call `evaluateAuthorization`;
8. use the resulting grant **only** within that request's command-processing
   flow.

### Prohibited

- Caching an `AuthorizationGrant` across requests.
- Persisting one.
- Reusing an earlier grant for a retry or replay.
- Treating a grant as a session capability.
- Authorizing once and replaying indefinitely.

**A previously valid grant does not mean authority is still valid.**

### Worked example — revocation

1. A rider executes a command successfully; the result is stored against
   `(principalId, commandId)`.
2. Their membership is later revoked.
3. The rider retries the **same** `commandId`.
4. The backend loads the **current** membership and authorizes again.
5. Fresh authorization denies — `membershipNotActive`, no grant.
6. The stored result is **not** replayed.

Step 4 is the whole mechanism. Skip it and step 6 fails silently: the retained
grant would still match, and the rider would receive a success they are no
longer entitled to.

The same sequence applies when an assignment is lost or reassigned, when shop
membership is removed, and when an admin privilege is revoked.

No grant expiry duration or timestamp policy is invented here. **Fresh
per-request evaluation is the rule** — a lifetime would only bound the window
in which a stale grant still works.

## Command type maps to permission on the server

```text
incoming commandType
  → trusted backend command router
  → exact required Permission
  → fresh AuthorizationRequest
  → evaluateAuthorization
  → AuthorizationGrant
  → idempotency / state / revision transaction
```

- **The client never supplies the authoritative required `Permission`.** A
  caller that could choose which permission is checked could choose one it
  holds.
- **An unknown or unmapped `commandType` fails closed** before any mutation.
- A grant's stored `permission` is **binding and audit evidence**. It is *not*
  proof that the backend selected the correct permission for that command type;
  it records which permission was evaluated, nothing more.

`evaluateIdempotency` deliberately does not check the permission, and no
command-type registry was invented in the contract to make it look mechanical.
That mapping is trusted-server responsibility, and it is a required backend
test (checklist R33–R35).

## Deny reasons

`unauthenticated` · `systemPrincipalNotEligible` · `membershipMissing` ·
`membershipNotActive` · `roleNotEligible` · `regionMismatch` · `shopMismatch` ·
`resourceOwnerMismatch` · `offerMismatch` · `assignmentMismatch` ·
`reasonRequired` · `approvalRequired` · `approvalMismatch`

`offerMismatch` ("the offer was not addressed to you") is distinct from
`assignmentMismatch` ("you have not accepted it"). `approvalRequired` (none
supplied) is distinct from `approvalMismatch` (supplied, but not bound to this
request).

These are **internal**. They are for server logs, tests and audit.

`AuthorizationDecision.publicMessage` is deliberately uniform for every denial:
*"You do not have permission to do this."* Telling an untrusted caller "wrong
region" rather than "not permitted" confirms the resource exists and hints
where it lives. A test asserts that three different internal reasons produce
one identical public message.

## Invariants

1. **Role alone never authorizes.** Every permission requires an active
   membership *and* a satisfied scope. Tested for each role.
2. **A membership must name the acting principal.** A membership record for
   someone else is inert (`membershipMissing`), even if it is otherwise perfect.
3. **Client data is never authority.** The evaluator has no payload parameter.
   An `actorId`, `role`, `permissions` or `membershipStatus` in a command
   payload changes nothing.
4. **Unknown permissions fail closed.** A newer client naming a permission this
   build does not know is denied, never treated as permitted.
5. **Suspended and revoked cannot start new work.**
6. **Approval is bound to the request.** Evidence must name this requester,
   this permission and this resource, carry an auditable reference, and come
   from a different approver. An unrelated approval record — for another
   action, or someone else's — satisfies nothing. Self-approval is denied.
   Approval evidence is **server-resolved**: a client may at most submit a
   reference, which the backend looks up and verifies before constructing the
   evidence. There is no `fromJson` and no caller-settable
   `approverIsAuthorized` flag, because a boolean an attacker can set is not a
   check.
7. **A reason must be non-blank** where the matrix requires one.
8. **Successful authorization is unforgeable and request-bound.**
   `evaluateAuthorization` is the only source of an `AuthorizationGrant`: the
   class is `final` (so it cannot be implemented or extended outside its
   library) and its only constructor is library-private. A denied evaluation
   produces **no grant**, so "proceed while denied" is not an expressible
   state. Each grant records the principal, permission and resource it was
   issued for, and consumers re-check those bindings — a grant for principal A
   on resource X cannot serve principal B or resource Y. Idempotency is also
   partitioned by trusted principal — see
   `docs/contracts/command-and-event-envelopes.md`. This is a **type**
   guarantee only: freshness and input trust are backend duties, described
   under *Three separate boundaries* below.
9. **Server authorization is unconditional.** It does not depend on App Check,
   on platform, or on the client having hidden a button.

## What approval does *not* yet establish

The evaluator proves an approval is **bound to this request**. It does not
verify that the approver held the right permission — that is a full
authorization evaluation of a second principal, and it belongs to the approval
workflow that issues the record. The backend must perform it when resolving the
reference, before constructing `ApprovalEvidence`.

**Approval expiry is not specified.** No arbitrary lifetime is invented here.
If approvals expire, the owning approval workflow defines and enforces the
policy; `approvedAtServerUtc` is what it will evaluate against.

## App Check is not authorization

App Check attests that a request came from a genuine app build. It says nothing
about *who* is asking or *whether they may*.

Windows has no supported App Check path (FND-002A). That reduces **attestation**
and must never reduce **authorization**: every command is authorized
server-side regardless of platform. `cp_auth`'s capability table encodes this —
`serverAuthorizationRequired` is `true` on every platform including the one
where `appCheckAvailable` is `false`, and a test asserts it.

A missing App Check token may raise risk scoring or rate limits. It may never
open a bypass.

## Client-side checks are UX, not security

Apps may hide actions a user cannot perform. That is a courtesy. The server
re-checks every command; a hidden button is not a control.
