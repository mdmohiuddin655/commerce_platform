# Privacy and security boundaries

**Contract version 0.2** (FND-003A). Contract-level implications. Firestore
Rules are **not** written in this task — FND-004 owns them, and the checklist
below is what it must satisfy.

## No public directories

There is **no browsable directory of workers, customers or shops' staff.**

A picker's or rider's identity is visible only to the parties an *active
assignment* already connects them to, plus scoped support/admin permissions.
`Principal` carries no profile, and no permission in the matrix lists people.

## Customer personal data is not globally readable

Contact details and addresses are never world-readable, and never readable by
role alone.

| Who | May see |
|---|---|
| The customer | Their own data |
| Agent | What their own shop's order requires — never a customer's other orders |
| Picker | What the active assignment requires; typically no delivery address |
| Rider | The delivery address and contact **for their accepted assignment only**, while it is active |
| Admin/support | Region-scoped, reason-bearing, logged reads only |

Access follows `ScopeRequirement`, not role. `riderViewAssignedWork` is
`assignedResource`-scoped: an offer that was never accepted grants nothing, and
a completed assignment must not remain a standing key to the customer's
details.

## Push payloads carry no unnecessary personal data

`EventEnvelope.payload` is documented as routing-and-display only. A copy may
travel through a push transport and be rendered on a lock screen, cached by the
OS, and handled by a third-party service.

Rules for what may go in a push payload:

- Enough to route the app to the right screen — ids and an event type.
- Never a full address, phone number, order contents or amount owed.
- Never anything the recipient could not already read through an authorized
  API call.
- The client fetches details over the authenticated API after the user opens
  the notification.

This is consistent with FND-002A: **a notification is a hint, never an
authorization**. It also means a mis-delivered or duplicated push leaks
nothing.

## Server-side enforcement

Client apps may hide actions a user cannot perform. That is UX, not security.
Every command is authorized server-side; a hidden button is not a control.

## App Check does not replace authorization

App Check attests that a request came from a genuine app build. It says nothing
about **who** is asking or **whether they may**.

Windows has no supported App Check path (FND-002A evidence register §8). That
reduces **attestation**, never **authorization**:

- `AuthCapabilities.serverAuthorizationRequired` is `true` on **every**
  platform, including where `appCheckAvailable` is `false`. Tested.
- A missing App Check token may raise risk scoring or tighten rate limits. It
  may never open a bypass.
- No code path may branch on platform to skip an authorization check.

## Decision reasons are internal

`DenyReason` values are for logs, tests and audit. `publicMessage` is uniform
for every denial, so a caller cannot probe for a resource's existence, owner,
shop or region by comparing error messages. Tested.

## Checklist for FND-004 — Rules and API authorization tests

Each item is a test FND-004 — or the bounded backend slice implementing the
command pipeline — must write against the Firebase emulator or the API. **None
can run today**: no backend exists and the Firebase CLI is not installed (owner
action O4). Every item below is **NOT RUN**.

### Deny-by-default

- [ ] R1 — Every collection denies read and write by default; access is
      granted only by an explicit rule.
- [ ] R2 — An unauthenticated request is denied on every path.
- [ ] R3 — A path with no matching rule is denied, not silently allowed.

### Identity and standing

- [ ] R4 — A valid token whose membership is `pending`, `suspended` or
      `revoked` cannot start new work.
- [ ] R5 — A membership document naming a different principal grants nothing.
- [ ] R6 — A client cannot write its own membership, role or status.
- [ ] R7 — A client cannot write an `actor`, `role` or `permission` field into
      a command and gain authority.

### Scope

- [ ] R8 — Customer cannot read or write another customer's order.
- [ ] R9 — Agent cannot read or write an order for a shop outside their
      membership.
- [ ] R10 — Agent with an empty shop set reaches nothing.
- [ ] R11 — Picker/rider cannot read a resource they hold no accepted
      assignment on.
- [ ] R12 — A rider who was *offered* but never accepted reaches nothing.
- [ ] R13 — A completed or revoked assignment stops granting access.
- [ ] R14 — Cross-region access is denied.

### Least privilege

- [ ] R15 — Picker cannot invoke a rider-only command and vice versa.
- [ ] R16 — No client can write an order status field directly.
- [ ] R17 — No client can write a balance, posting or journal entry.
- [ ] R18 — Rider cannot modify settlement history or their own balance.
- [ ] R19 — Non-financial admin permission grants no financial mutation.
- [ ] R20 — No impersonation path exists.

### Procedure and audit

- [ ] R21 — A reason-required command is rejected without a stored reason.
- [ ] R22 — A dual-control command is rejected without a second, different
      approver.
- [ ] R23 — Every privileged admin action leaves an audit record with actor,
      command id, reason and server time.

### Envelope and idempotency

- [ ] R24 — A command with a mismatched `expectedRevision` is rejected.
- [ ] R25 — Replaying a command id with an identical fingerprint returns the
      stored result and does **not** re-execute.
- [ ] R26 — Reusing a command id with a changed fingerprint is rejected.
- [ ] R27 — A COD collection submitted twice records one receipt.
- [ ] R28 — Event ids are server-assigned; a client-supplied event id is
      ignored or rejected.

### Privacy

- [ ] R29 — No query can enumerate workers or customers.
- [ ] R30 — Push payloads contain no address, phone number, order contents or
      amount.
- [ ] R31 — Support reads are region-scoped, reason-bearing and logged.

### Platform

- [ ] R32 — Authorization succeeds and fails identically with and without an
      App Check token; absence never grants more.

### Command routing and authorization freshness

Added by **FND-003A-FIX-003**. These close the gap between what the contract's
*types* guarantee and what a correct backend must actually do: an
`AuthorizationGrant` being unforgeable says nothing about whether its inputs
were fresh, nor whether an application retained one from an earlier request.

- [ ] R33 — Every accepted `commandType` maps to exactly one expected
      `Permission` in the trusted backend command router.
- [ ] R34 — An unknown or unmapped `commandType` **fails closed** and never
      reaches mutation.
- [ ] R35 — A client cannot select or override the `Permission` used for
      authorization, by payload, header or any other route.
- [ ] R36 — Every new command request authorizes from **current** trusted
      `Principal` / `Membership` / `ResourceScope` facts before execution.
- [ ] R37 — Every idempotent retry or replay performs **fresh** authorization
      before the stored result is returned.
- [ ] R38 — A command that originally succeeded **cannot** replay after the
      actor's membership is suspended or revoked.
- [ ] R39 — A command **cannot** replay after the relevant assignment or
      resource scope is removed or reassigned.
- [ ] R40 — `AuthorizationGrant` is request-local: backend code does not
      persist, cache or reuse it across command requests.

**Owner:** FND-004, or the bounded backend slice that implements the command
pipeline — whichever lands first. They need a trusted backend and a suitable
emulator or integration runner.

**Status: all NOT RUN.** None of this can be executed today: no backend
implementation exists, and the Firebase CLI is not installed (owner action O4).
They are required future tests, not results.
