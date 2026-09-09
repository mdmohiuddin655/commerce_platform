# Contract version history

`ContractVersion` in `packages/contracts` is the single version marker for the
shared wire contract. `ContractVersion.current` is what a build compiled
against; every command and event envelope carries it.

## Compatibility rule

`canRead` keys on **major only**:

```dart
bool canRead(ContractVersion other) => other.major == major;
```

- **Same major** → readable in both directions. Unknown fields are ignored.
- **Different major** → refused, and surfaced to the user as an upgrade prompt.

So: **additive, backward-readable changes bump the minor. A change in meaning
bumps the major.**

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

**Why minor, not major.** Nothing defined at 0.1 changed meaning. `0.1` had no
envelopes, permissions or identity types, so nothing could be reinterpreted.
Every addition is new surface. Tested in `contract_version_test.dart`.

## Behaviour across versions

| Situation | Behaviour |
|---|---|
| 0.2 reader, 0.1 payload | Readable. Nothing at 0.1 was removed or redefined. |
| 0.1 reader, 0.2 payload | Readable by the same-major rule. A 0.1 build ignores fields it does not know. |
| Either reader, 1.x payload | **Refused.** Surfaced as an upgrade prompt, never silently partially parsed. |

### Unknown identifiers must fail safe

- **Unknown permission id** → `Permission.byId` returns `null`;
  `evaluateAuthorization` **denies**. Fail closed, never open. Tested.
- **Unknown command type** → the server rejects it. A build that does not
  implement a command must not guess.
- **Unknown event type** → a client **may** ignore it, and this is the one
  place ignoring is explicitly allowed: an event is a hint, so a client that
  does not understand a fact simply re-reads server state. It must not crash,
  and it must not infer meaning from the name.
- **Unknown envelope field** → ignored.

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
