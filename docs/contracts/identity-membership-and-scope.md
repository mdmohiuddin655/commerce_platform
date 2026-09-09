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
server's facts about the target: `ownerPrincipalId`, `shopId`, `regionId` and
`assignedPrincipalIds`.

`ResourceScope` is read from trusted storage, **never from the command
payload**. If the caller could state the resource's owner, the caller could
state that they own it.

| `ScopeRequirement` | The actor must… |
|---|---|
| `none` | …need no resource relationship. Only for genuinely unscoped reads. |
| `ownResource` | …own the resource (customer ↔ their own order). |
| `ownShop` | …have the resource's shop in their membership. |
| `ownRegion` | …match the resource's region. |
| `assignedResource` | …hold an **accepted** assignment on the resource. |

Two rules that fall out of this, both tested:

- **An empty `shopIds` means no shop authority — never all shops.**
- **`assignedPrincipalIds` holds accepted assignments only.** Being *offered*
  work is not being assigned it. Assignment notification, assignment
  acceptance and physical custody are three different facts; an offer that
  timed out never implies pickup.

A null region on either side does not satisfy `ownRegion`. Absence is not a
match.
