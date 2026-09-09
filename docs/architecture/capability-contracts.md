# Capability contracts (FND-002A)

Three shared packages describe **what a platform can do**, separately from
**how it does it**. Feature code depends only on these; no adapter exists yet.

All three tables are populated from the dated evidence in
`docs/platform-matrix/FND-002A-capability-evidence.md`. They are documented
expectations, not runtime probes — which is why every entry carries an
evidence level rather than a boolean "supported".

## `CapabilityPlatform` (`cp_core`)

The platform axis every capability table is keyed by. It lives in `cp_core`
because auth, notifications and local storage all need it, and none of them may
depend on the others.

## `cp_notifications`

| Type | Purpose |
|---|---|
| `NotificationService` | The **only** notification surface business code may touch. No vendor type crosses it |
| `InboxEvent` | Normalised event with a server-assigned `eventId` and server time |
| `NotificationDeduplicator` | Collapses repeated deliveries; bounded memory |
| `NotificationCapabilities` + `notificationCapabilities` | Per-platform documented capability table |
| `assertPushTransportSupported` | **Throws** where no supported transport exists (Windows, Linux) |

Three rules the interface exists to protect:

1. **A notification is a hint, never an authorization.** Receiving one never
   advances an order, an assignment or a custody record. The app re-reads
   server state.
2. **Delivery is at-least-once and unordered.** Duplicates and reordering must
   be harmless — hence the `eventId` dedupe contract.
3. **The product works without push.** A durable server-backed inbox polled
   over the normal API is the floor; push only makes it timely. A local-toast
   or foreground-only fallback is **not** push parity.

No vendor SDK is imported, and `tools/check_layering.sh` fails the build on any
direct import of `firebase_messaging`, `awesome_notifications`,
`awesome_notifications_fcm` or `flutter_local_notifications` anywhere in
`apps/` or `packages/`. That guard exists because the stack choice is
undecided — see `docs/decisions/ADR-0005-notification-stack-decision-required.md`.

## `cp_auth`

`AuthCapabilities` maps each platform to an `AuthStrategy`:

| Platform | Strategy |
|---|---|
| Android, iOS, macOS | `firebaseNativePlugin` |
| Web | `firebaseWebSdk` |
| **Windows**, Linux | `restWithSystemBrowserPkce` |

Windows differs because Firebase documents Windows as local-development-only,
so the native plugin path is not production-eligible even though
`firebase_auth` lists Windows. A platform badge does not override the vendor's
production guidance.

Two invariants are encoded as properties and asserted by tests on **every**
platform:

- `serverAuthorizationRequired` is always `true`. Windows has no App Check
  path; that reduces **attestation**, never **authorization**. The server
  authorizes every command regardless.
- `embedsClientSecret` is always `false`. A secret shipped to many users is not
  a secret (RFC 8252 §8.5), so no client build carries one.

## `cp_local_store`

`PersistenceTier` mirrors the backends Drift reports through
`WasmDatabaseResult.chosenImplementation`, in Drift's documented order of
preference, plus the native backend.

The tier is **not knowable ahead of time on the web** — it depends on browser
features and on response headers the host sends. `expectedTierFor` returns the
best case; the real tier must be read at runtime and surfaced, because two of
the tiers are user-visible risks:

- `webUnsafeIndexedDb` — durable but **not cross-tab safe**; the user must be
  warned.
- `webInMemory` — **not durable**; everything is lost on reload.

`mayHoldAuthoritativeState` is `false` for every tier without exception. Local
storage is a cache and an outbox. Inventory, order status and money are server
truth; a local transaction cannot establish final commercial truth.

## What is deliberately absent

No Firebase, Awesome, local-notification or Drift dependency is declared. The
notification choice is an open owner decision (ADR-0005), and neither the web
Drift backend nor any push path can be exercised on this host. Adapters are
FND-004 work, after the decision and after device validation.
