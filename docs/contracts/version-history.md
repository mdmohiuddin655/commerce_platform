# Contract version history

`ContractVersion` in `packages/contracts` is the single version marker for the
shared wire contract. `ContractVersion.current` is what a build compiled
against; every command and event envelope carries it.

## Version policy is not a compatibility proof

`ContractVersion` answers **one narrow question**: does the version policy
permit attempting to decode a peer's payload at all?

```dart
bool isVersionCompatibleWith(ContractVersion other) => other.major == major;
bool isSameMajor(ContractVersion other) => other.major == major;
```

- **Same major** → an attempt is permitted.
- **Different major** → refuse, and surface an upgrade prompt rather than
  partially parsing.

A `true` result is **permission to try**. It is *not* evidence that a
particular payload decodes, that a field is understood, or that an unknown
field is safely ignored. Those are properties of a **decoder**, proven by that
decoder's own tests against real encoded payloads.

> The method was called `canRead` until FND-003A-FIX-001. That name read as a
> guarantee that a payload *would* be readable. It never was: the method
> compares two integers and knows nothing about any schema.

**There is no serialization in `cp_contracts` today** — no envelope has a
`toJson` or `fromJson`. So no payload-compatibility claim is made anywhere, and
none could be tested honestly. When serialization lands, its tests must use a
real encoded payload and a real decoder.

**Rule for bumping:** additive, non-meaning-changing definitions bump the
minor. A change in meaning bumps the major.

## Versions

### 0.1 — FND-001

`ContractVersion` itself. No vocabulary, no schemas, no transitions.

### 0.2 — FND-003A (2026-09-09) — additive

Added:

- `CommandEnvelope`, opaque-id rules, structural validation
- `CommandFingerprint`, `StoredCommandRecord`, `evaluateIdempotency`
- `EventEnvelope`
- `Principal`, `PrincipalKind`, `CommerceRole`, `Membership`,
  `MembershipStatus`, `ResourceScope`, `ScopeRequirement`
- `Permission` (35 ids), `PermissionRule`, `permissionMatrix`,
  `ProhibitedCapability`
- `AuthorizationRequest`, `AuthorizationDecision`, `DenyReason`,
  `ApprovalEvidence`, `evaluateAuthorization`

**Why minor, not major.** At the version-policy level the change is additive:
the major is unchanged, nothing defined at 0.1 changed meaning, and every
addition is new surface.

**What is *not* claimed.** 0.1 contained no command envelope, event envelope or
permission decoder, so a 0.1 build has nothing with which to read a 0.2
payload. 0.1 cannot be cited as evidence for decoding types that did not exist
in it. And no 0.1 client was ever released, so the question is theoretical
rather than a deployed compatibility obligation.

### Corrected by FND-003A-FIX-001

0.2 was corrected **in place**, not bumped again. It has never been merged to
`main` or released, so there is no external consumer of the earlier shape.
Corrections: assignment accept/decline now requires a targeted offer as well as
region; `ApprovalEvidence` is bound to requester, permission and resource;
idempotency is partitioned by trusted principal and gated on current
authorization; `canRead` became `isVersionCompatibleWith`.

## Behaviour across versions

| Situation | Version policy | Payload compatibility |
|---|---|---|
| 0.2 reader, 0.1 payload | Attempt permitted (same major) | **Not claimed.** No decoder exists to test. |
| 0.1 reader, 0.2 payload | Attempt permitted (same major) | **Not claimed, and not plausible** — 0.1 had no envelope or permission decoder at all. |
| Either reader, 1.x payload | **Refused** — surfaced as an upgrade prompt, never silently partially parsed | n/a |

The middle column is a statement about two integers. The right-hand column is
the one that would matter to a real client, and it is deliberately empty until
a decoder and its tests exist.

### Unknown identifiers must fail safe

- **Unknown permission id** → `Permission.byId` returns `null`;
  `evaluateAuthorization` **denies**. Fail closed, never open. Tested.
- **Unknown command type** → the server rejects it. A build that does not
  implement a command must not guess.
- **Unknown event type** → a client **may** ignore it, and this is the one
  place ignoring is explicitly allowed: an event is a hint, so a client that
  does not understand a fact simply re-reads server state. It must not crash,
  and it must not infer meaning from the name.
- **Unknown envelope field** → no behaviour is claimed. There is no decoder,
  so "unknown fields are ignored" would be an assertion about code that does
  not exist. The decoder that lands first must specify and test it.

## Migration status

**No migration is required, and none is invented.**

- There are no released clients: no app has a platform folder or a build
  (FND-002A), so nothing in the field reads any version of this contract.
- There is no production data: no Firebase project exists (owner action O5).
- 0.2 is purely additive, so no stored value changes shape or meaning.

**Rollback:** reverting the FND-003A commit returns the contract to 0.1 with no
data implications, because no data was written under 0.2.

The first version needing a real migration plan will be the one shipped to a
real client against a real database. That plan belongs to the task that ships
it, not to this one.
