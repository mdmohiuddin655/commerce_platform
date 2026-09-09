# Command and event envelopes

**Contract version 0.2** (FND-003A). Implemented in `packages/contracts`.

## Command envelope

`CommandEnvelope` — the one shape every trusted backend command arrives in.

| Field | Type | Meaning |
|---|---|---|
| `commandId` | `String` | Client-generated, opaque, unique per intent. The idempotency key. |
| `commandType` | `String` | Named operation, e.g. `order.place`. Dot-separated lower_snake. **Never a status value.** |
| `resourceId` | `String` | Opaque id of the target resource. |
| `expectedRevision` | `int` | Revision the client believes the resource is at. `0` means "expected not to exist yet". |
| `payload` | `Map<String, Object?>` | Operation arguments. Unmodifiable once accepted. |
| `contractVersion` | `ContractVersion` | Version the sender compiled against. |

### The actor rule — the reason this envelope exists

There is **no actor, user, role, permission or membership field, and there
never will be.**

- The server derives the actor from the **verified authentication context**.
- Membership, role and scope are read from **trusted storage**.
- A client-supplied identity is data, not authority.

This is structural, not conventional: a field that does not exist cannot be
trusted by mistake. Anything actor-shaped a client puts in `payload` is inert,
because `evaluateAuthorization` takes no payload parameter at all. Tested in
`authorization_test.dart` → *"authorization ignores the command payload
entirely"*.

### Named commands, never patch-to-status

`commandType` names an operation. A client asks to *do* something; the server
decides whether that transition is permitted from the current state. There is
no endpoint that accepts a status to write. The permission vocabulary contains
no status-overwrite capability, and a test enforces that.

### Identifiers

Command, resource and event ids are opaque: 16–64 characters of
`[A-Za-z0-9_-]`, **never all digits**. An all-digit id is a sequential business
counter, which leaks volume, lets one actor guess another's resource ids, and
makes a stolen id useful. Rejected by `validateOpaqueId`.

### Structural validation only

`CommandEnvelope.create` returns `Result<CommandEnvelope>` and checks id shape,
command-type shape and `expectedRevision >= 0`. It does **not** check business
state — that belongs to authorization and to the lifecycle rules a later
FND-003 slice owns.

| Failure code | Cause |
|---|---|
| `ENVELOPE_COMMAND_ID_INVALID` | command id not opaque |
| `ENVELOPE_RESOURCE_ID_INVALID` | resource id not opaque |
| `ENVELOPE_COMMAND_TYPE_INVALID` | malformed command type |
| `ENVELOPE_REVISION_INVALID` | negative expected revision |

## Idempotency

Semantics every backend implementation must honour:

| Situation | Outcome | Why |
|---|---|---|
| New `commandId` | `executeNew` | Execute — but only after authorization, revision and state validation still pass. |
| Same `commandId`, **same** fingerprint | `replayStoredResult` | Return the stored original result. Do **not** re-execute: re-executing is how a COD receipt gets recorded twice. |
| Same `commandId`, **different** fingerprint | `rejectKeyReuse` | The client reused a key for a new intent. Executing would silently overwrite the meaning of an earlier command. |

`CommandFingerprint` is derived from `commandType`, `resourceId`,
`expectedRevision` and a canonicalised `payload` — and from **nothing else**.
No device clock, no request timestamp, no retry counter, no transport id. Two
honest retries of the same intent fingerprint identically however far apart
they are sent; otherwise replay detection breaks exactly when the network is
worst. Map key order is normalised; **list order is not**, because `[a,b]` is a
different request from `[b,a]`.

`StoredCommandRecord.recordedAtServerUtc` is server time. A device with a wrong
clock must never be able to shadow a real command.

`evaluateIdempotency` is a pure function. **Not in this task:** the transaction
boundary and outbox that apply it. Orders, reservations, commands and outbox
must share one transaction boundary — that is FND-004 implementation work.

## Event envelope

`EventEnvelope` — a fact the server recorded.

| Field | Type | Meaning |
|---|---|---|
| `eventId` | `String` | Server-assigned, opaque, stable. **The only deduplication key.** |
| `eventType` | `String` | Named fact, e.g. `order.accepted`. |
| `resourceId` | `String` | Resource the fact concerns. |
| `resourceRevision` | `int?` | Revision reached. Null when the event advances none. |
| `causedByCommandId` | `String?` | Command that caused it. Null for worker-raised events such as reservation expiry. |
| `serverTimeUtc` | `DateTime` | **Server** time, must be UTC. |
| `payload` | `Map<String, Object?>` | Small, routing-and-display only. |
| `contractVersion` | `ContractVersion` | Version the producer wrote. |

### The event id is the server's, never the transport's

There is **no `transportMessageId` field**. An FCM message id, an APNs id or a
push payload key is never the business event id:

- transport ids differ between a push copy and a polled copy of the same fact;
- they are absent entirely when a fact is read from the API;
- using one as the business id makes deduplication silently fail.

A transport adapter **maps** its id to this one; it never substitutes it.
Malformed transport ids also fail `validateOpaqueId` as a backstop — though a
UUID-shaped transport id would pass, which is exactly why the guarantee is
structural rather than a shape check.

### An event is a hint, never an authorization

Receiving an event — by push or by poll — advances nothing on its own. The
client re-reads server state; the server alone decides transitions. This is
what makes at-least-once, out-of-order delivery harmless, and it matches the
deduplication contract in `cp_notifications` (FND-002A), which keys on the same
server-assigned event id.

## Not defined by this task

Lifecycle transitions, inventory effects, payment and COD, the cash journal,
fees, refusal policy, commissions and settlement. No feature may guess them.
See `docs/contracts/README.md` for which slice owns what.
