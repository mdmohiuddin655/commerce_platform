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
4. **Scope** — owner / shop / region / assignment relationship.
5. **Procedure** — reason required? dual-control approval required?

## Deny reasons

`unauthenticated` · `systemPrincipalNotEligible` · `membershipMissing` ·
`membershipNotActive` · `roleNotEligible` · `regionMismatch` · `shopMismatch` ·
`resourceOwnerMismatch` · `assignmentMismatch` · `reasonRequired` ·
`approvalRequired`

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
6. **Dual control means a different principal.** Self-approval is denied.
7. **A reason must be non-blank** where the matrix requires one.
8. **Server authorization is unconditional.** It does not depend on App Check,
   on platform, or on the client having hidden a button.

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
