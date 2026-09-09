# Identity, membership and scope

**Contract version 0.2** (FND-003A).

## The four separate things

Collapsing any two of these is how authorization bugs happen.

| Concept | Type | Answers | Source |
|---|---|---|---|
| **Identity** | `Principal` | Who is this? | Verified auth context |
| **Standing** | `Membership.status` | May they act at all? | Trusted storage |
| **Role** | `CommerceRole` | In what capacity? | Trusted storage |
| **Scope** | `ResourceScope` + `ScopeRequirement` | Over which resources? | Trusted storage |

> **Authentication proves identity. Active membership + permission + scope
> authorize an operation.** A role name by itself authorizes nothing.

## Principal

`Principal` carries a kind and an opaque id — and **no role**.

| Kind | Meaning |
|---|---|
| `user` | A human, authenticated through the auth provider. |
| `systemWorker` | A trusted server-side process: outbox drain, reservation expiry, scheduled reconciliation. |

A trusted worker is **not** a user with a role. Modelling it separately keeps
human role membership honest: no background job is ever "an admin", and no
audit record has to pretend a cron run was a person. `evaluateAuthorization`
denies a system principal any human-role permission
(`DenyReason.systemPrincipalNotEligible`); workers act through their own
audited paths.

Construction is deliberately narrow:

- `Principal.fromVerifiedSubject(subjectId)` — the name forces every call site
  to state that the subject was verified, so an unverified one is visible in
  review.
- `Principal.systemWorker(workerId)` — backend only.
- **There is no `Principal.fromJson`.** If a client could deserialize one, a
  client could assert one.

There is no public worker directory. A worker's identity is visible only to
the parties an active assignment already connects them to, plus scoped
support/admin permissions.

## Roles

`customer`, `agent`, `picker`, `rider`, `admin` — the five user-facing roles of
the shared baseline. Each has a stable `id` string; `Enum.index` is never
serialized, because reordering the enum would silently change every stored
value.

## Membership status

| Status | May start new work? |
|---|---|
| `pending` | No — applied, not yet approved |
| `active` | **Yes** — the only status that may |
| `suspended` | No — reversible stop |
| `revoked` | No — permanent |

A valid token from a suspended rider is still a valid token, and still must not
start new work. That is the whole reason standing is separate from identity.

### What is deliberately *not* decided here

Whether a suspended worker may **finish** something already in their custody is
a controlled-resolution question owned by the **lifecycle slice**. The contract
keeps the two separable: `PermissionRule.acceptableStatuses` defaults to
`{active}` for every permission today, so a later slice can add a narrow
wind-down permission that also accepts `suspended` **without loosening
anything else**. A test asserts the default holds for all current permissions,
so adding one is a deliberate, visible act.

## Scopes

`Membership` carries `regionId` and `shopIds`. `ResourceScope` carries the
server's facts about the target: `ownerPrincipalId`, `shopId`, `regionId`,
`assignedPrincipalIds` and `offeredPrincipalIds`.

**Every field of `ResourceScope` is read from trusted storage, never from the
command payload** — owner, shop, region, assignments and offers alike. If the
caller could state the resource's owner, the caller could state that they own
it; if the caller could state who was offered the work, the caller could offer
it to themselves. Likewise `Principal` comes from verified authentication and
`Membership` from trusted records, and neither has a `fromJson`.

| `ScopeRequirement` | The actor must… |
|---|---|
| `none` | …need no resource relationship. Only for genuinely unscoped reads. |
| `ownResource` | …own the resource (customer ↔ their own order). |
| `ownShop` | …have the resource's shop in their membership. |
| `ownRegion` | …match the resource's region. |
| `offeredResource` | …have had the work **offered to them**. |
| `assignedResource` | …hold an **accepted** assignment on the resource. |

A `PermissionRule` carries a **set** of these and **all must hold**. That is
what lets assignment acceptance require both *"the offer was addressed to you"*
and *"you are in the right region"* without dropping either. Requirements are
evaluated in `ScopeRequirement` declaration order, so the reported deny reason
does not depend on how a rule's set literal was written.

### Offered is not assigned

`offeredPrincipalIds` and `assignedPrincipalIds` are separate sets, and
conflating them breaks authorization in opposite directions:

- **Accepting an offer must not require an accepted assignment** — that would
  be circular. Accept and decline use `offeredResource`.
- **An offer must not open post-acceptance work.** A picker who was merely
  offered a job cannot record a pickup. Those use `assignedResource`.

Assignment notification, assignment acceptance and physical custody remain
three different facts; an offer that timed out never implies pickup.

`offeredPrincipalIds` says only **who the offer was addressed to**. Whether it
is still live — not expired, declined or superseded — is assignment lifecycle
state owned by **FND-003B**. Authorization establishes *"this offer belongs to
this actor and is inside allowed scope"*; lifecycle then establishes *"this
offer is still in a state that may transition"*.

Two further rules, both tested:

- **An empty `shopIds` means no shop authority — never all shops.**
- **Region alone never authorizes accept or decline.** Until
  FND-003A-FIX-001 it did, which let any active worker in the same region take
  another worker's offer.

A null region on either side does not satisfy `ownRegion`. Absence is not a
match.
