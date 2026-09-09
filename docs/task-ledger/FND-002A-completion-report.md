# FND-002A completion report

- **Task:** Host-available portion of FND-002 — upstream compatibility recheck,
  capability contracts, dated matrix, runtime test plan
- **Owner project:** ADMIN / shared foundation
- **Date:** 2026-09-09
- **Baseline:** commits `e82e932`, `3feb546`; branch `main`; tree clean at start
- **Contract baseline:** SHARED-BASELINE-v1.0 — **unchanged**
- **Host:** macOS 26.6.2 (25G83) darwin-arm64; Flutter 3.47.2; Dart 3.13.2
- **Status:** **DONE**

## 1. Headline finding

The blueprint's **mandatory `firebase_messaging` + `awesome_notifications`
coexistence** requirement is **DECISION REQUIRED** — not "untested".

Current upstream sources (checked 2026-09-09) show the pairing is
**vendor-prohibited**:

- `awesome_notifications` 0.12.1: *"The support for `firebase_messaging` plugin
  is now deprecated"*, and it *"is incompatible with
  `flutter_local_notifications` or any other notification plugin"* because such
  plugins *"conflict with each other when trying to acquire global notification
  resources"*.
- `awesome_notifications_fcm` 0.12.1: users *"MUST not use `firebase_messaging`
  with `awesome_notifications_fcm`."*

A local probe resolved the forbidden combination **successfully, exit 0**. Pub
cannot see a native-layer conflict, so that result is recorded as evidence of
nothing — a concrete instance of the blueprint's "validate implementations, not
badges" rule.

Per instruction, **no dependency was substituted**. The requirement is
reclassified and handed back as an owner decision
([ADR-0005](../decisions/ADR-0005-notification-stack-decision-required.md)).

## 2. What was verified upstream

Full register with URLs, versions, dates and verbatim quotes:
[`FND-002A-capability-evidence.md`](../platform-matrix/FND-002A-capability-evidence.md).
Summary — all checked **2026-09-09**, all `VERIFIED-DOC`:

| Component | Version | Key finding |
|---|---|---|
| Firebase Flutter setup | page updated **2026-09-08** | *"Firebase on Windows is not intended for production use cases, only local development workflows."* Blueprint claim **still current** |
| `firebase_messaging` | 16.6.0, BSD-3-Clause | Platforms: Android, iOS, macOS, web. **Windows NOT listed** — blueprint confirmed |
| FCM receive docs | updated 2026-09-08 | Background handler must be top-level, non-anonymous, `@pragma('vm:entry-point')`, registered before `runApp`; foreground messages *"won't display a visible notification by default"* |
| FCM client docs | updated 2026-09-08 | Web needs a VAPID key + service worker; Apple needs an APNs key, push/background capabilities and method swizzling |
| `awesome_notifications` | 0.12.1, **Apache-2.0** | Deprecates `firebase_messaging` support; incompatible with other notification plugins |
| `awesome_notifications_fcm` | 0.12.1, **license not stated** | **Android + iOS only** → choosing it loses web push. Forbids `firebase_messaging` |
| `flutter_local_notifications` | 22.3.0, BSD-3-Clause | Android/iOS/Linux/macOS/Web/**Windows**; FCM conflict *"resolved since version 6.0.13"* — the documented-compatible companion, and the only Windows toast path found |
| `drift` | 2.34.4, MIT | Native needs no extra setup since 2.32.0 with sqlite3 3.x; web needs `sqlite3.wasm` + `drift_worker.js`, served as `Content-Type: application/wasm`; five storage tiers; documented cross-tab and private-browsing caveats |
| `firebase_auth` | 6.6.1, BSD-3-Clause | *Lists* Windows — but Firebase's own production caution overrides the badge |
| RFC 8252 | — | §5 external user-agent MUST; §6 PKCE MUST; §7.3 loopback any port; §8.5 shipped secrets are not confidential |
| Microsoft Learn (WNS) | — | Closed-app Windows push needs Azure/Entra app registration or Store/PFN — an account and cost decision, not only code |

## 3. Dependency decisions

**No dependency was added, changed, or removed. `pubspec.lock` is unchanged.**

That is a deliberate outcome, not an omission:

- The notification stack choice is an open owner decision, so adding either
  candidate would prejudge it.
- `awesome_notifications_fcm`'s **license is not stated** on its package page.
  An unknown-license dependency is not adopted.
- Drift and the Firebase packages belong to FND-004, after the decision.

Candidate versions were instead **resolved against the exact repository SDK
baseline in scratch packages outside the repository**, so the committed
lockfile was untouched while still producing real evidence:

| Probe | Stack | Result |
|---|---|---|
| A | `firebase_core ^4.6.0` + `firebase_messaging ^16.6.0` + `flutter_local_notifications ^22.3.0` | **resolved** → 4.14.0 / 16.6.0 / 22.3.0 |
| B | `awesome_notifications ^0.12.1` + `awesome_notifications_fcm ^0.12.1` + `firebase_core` | **resolved** → 0.12.1 / 0.12.1 / 4.14.0 |
| C | forbidden combination (A + B together) | **resolved — proves nothing; see §1** |
| D | `drift ^2.34.4` + `sqlite3 ^3.4.0` | **resolved** → 2.34.4 / 3.5.2 |

Licenses verified for everything that could later be adopted: BSD-3-Clause
(`firebase_messaging`, `firebase_auth`, `flutter_local_notifications`),
Apache-2.0 (`awesome_notifications`), MIT (`drift`).
`awesome_notifications_fcm` — **unresolved, blocking its adoption**.

## 4. What was built

Platform-neutral capability contracts. No vendor SDK is imported anywhere.

**`cp_core`** — `CapabilityPlatform`, the platform axis shared by all three
capability packages (placed here so auth and notifications need not depend on
each other).

**`cp_notifications`** — `NotificationService` (the only surface business code
may touch), `InboxEvent` with a server-assigned `eventId`,
`NotificationDeduplicator`, the per-platform capability table, and
`assertPushTransportSupported` which **throws** on Windows and Linux so an
unsupported plugin cannot be initialized there.

Deduplication contract, implemented and tested: stable `eventId`; one durable
inbox entry per `eventId`; duplicates are a no-op; reordering is harmless;
**presentation never authorizes a state transition** — the app re-reads server
state.

**`cp_auth`** — `AuthCapabilities` per platform. Windows and Linux use
`restWithSystemBrowserPkce`; mobile uses the plugin; web uses the JS SDK. Two
invariants are properties asserted on **every** platform:
`serverAuthorizationRequired == true` (Windows has no App Check — that reduces
attestation, never authorization) and `embedsClientSecret == false`.

**`cp_local_store`** — `PersistenceTier` mirroring Drift's documented backends
in preference order, with `durable` / `crossTabSafe` / `requiresUserWarning`
per tier and `mayHoldAuthoritativeState == false` for all of them.

**`tools/check_layering.sh`** — new rule: any direct import of
`firebase_messaging`, `awesome_notifications`, `awesome_notifications_fcm` or
`flutter_local_notifications` in `apps/` or `packages/` **fails the build**.
Proven to fire.

**`tools/check_web_capabilities.sh`** — reusable browser capability probe
(also serves FND-002B).

## 5. Validation

| # | Command | Result | Host |
|---|---|---|---|
| V1 | `git status --short` (before) | **PASS** — empty | macOS |
| V2 | `git rev-parse HEAD` | **PASS** — `3feb546…`, branch `main` | macOS |
| V3 | `flutter --version` / `dart --version` | **PASS** — 3.47.2 / 3.13.2 | macOS |
| V4 | `flutter doctor -v` | **PASS with issues** — Android licenses not accepted; Xcode 26.6, Chrome OK | macOS |
| V5 | `flutter devices` | **PASS** — only `macOS (desktop)` and `Chrome (web)`; **no physical device** | macOS |
| V6 | `flutter pub get` | **PASS** | macOS |
| V7 | `./tools/check_workspace.sh` | **PASS** — 15 declared members | macOS |
| V8 | `flutter analyze` | **PASS** — `No issues found!` | macOS |
| V9 | `./tools/check_layering.sh` | **PASS** — 8 rules | macOS |
| V10 | `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 | macOS |
| V11 | Test suite | **PASS** — **45 tests across 10 of 15 members** (was 17 across 7) | macOS |
| V12 | New capability tests | **PASS** — notifications 15, local_store 7, auth 6 | macOS |
| V13 | Vendor-import guard negative control | **PASS (fired)** — planted `firebase_messaging` import → exit 1 | macOS |
| V14 | `./tools/check_web_capabilities.sh` | **PASS** — see §6 | Chrome 152 headless |
| V15 | COOP/COEP comparison run | **PASS** — `crossOriginIsolated` false → true with headers | Chrome 152 headless |
| V16 | Dependency resolution probes A–D | **PASS** — all resolved; repo lockfile untouched | macOS |

### Not run / blocked — no result was converted into a PASS

| Check | State | Missing |
|---|---|---|
| Android physical push (permission, token, fg/bg/terminated) | **BLOCKED** | physical device; Firebase project; accepted licenses |
| iOS physical push, delegate behaviour | **BLOCKED** | physical device; Apple Developer account; APNs key |
| Windows build, auth REST/PKCE, toast, Drift native | **BLOCKED** | Windows machine or CI runner |
| Windows closed-app push | **DECISION REQUIRED** | Azure/Entra or Store registration (D3) |
| Real FCM transport / token | **NOT RUN** | Firebase project. **No token was fabricated** |
| Firebase emulator, Firestore rules | **BLOCKED** | Firebase CLI, FlutterFire CLI |
| Web FCM delivery, Drift WASM end-to-end | **NOT RUN** | Firebase project, VAPID key, generated `web/` folders |
| Any platform build artifact | **NOT RUN** | platform folders are FND-004 |

## 6. Browser runtime evidence

`./tools/check_web_capabilities.sh`, Chrome 152.0.7977.83 headless, over
`http://localhost` (a secure context — `file://` would have produced false
negatives).

Present: `isSecureContext`, `serviceWorker`, `PushManager`, `Notification`
(permission `default`), `indexedDB`, `SharedWorker`, `navigator.storage.getDirectory`
(OPFS), `storage.estimate`/`persist` (~10.74 GB quota), `WebAssembly`,
`Atomics.wait`.

**`crossOriginIsolated` was `false`** and `SharedArrayBuffer` unavailable —
because COOP/COEP headers were not being sent. Re-serving the same page with
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` flipped both to `true`.

**Actionable for FND-004:** Drift's `opfsLocks` tier depends on cross-origin
isolation, which is off by default and is a *hosting configuration* matter.
Without those headers Drift degrades toward `unsafeIndexedDb`, which Drift
documents as not cross-tab safe. This must be verified on the real host.

**Limits:** feature detection is not delivery. This proves the APIs exist, not
that FCM registers a token or that a push arrives. Headless may also differ
from headed for permission prompting.

## 7. Files changed

| Path | Reason |
|---|---|
| `packages/core/lib/src/capability_platform.dart` | **new** — shared platform axis |
| `packages/core/lib/cp_core.dart` | export it |
| `packages/notifications/lib/src/notification_capability.dart` | **new** — capability table + `assertPushTransportSupported` |
| `packages/notifications/lib/src/notification_service.dart` | **new** — platform-neutral boundary, `InboxEvent` |
| `packages/notifications/lib/src/notification_dedupe.dart` | **new** — eventId dedupe contract |
| `packages/notifications/lib/cp_notifications.dart` | barrel |
| `packages/notifications/test/*.dart` | **new** — 15 tests |
| `packages/auth/lib/src/auth_capability.dart`, `cp_auth.dart` | **new** — strategy table + invariants |
| `packages/auth/test/auth_capability_test.dart` | **new** — 6 tests |
| `packages/local_store/lib/src/persistence_capability.dart`, `cp_local_store.dart` | **new** — Drift tier model |
| `packages/local_store/test/persistence_capability_test.dart` | **new** — 7 tests |
| `tools/check_layering.sh` | new vendor-SDK neutrality rule |
| `tools/check_web_capabilities.sh` | **new** — reusable browser probe |
| `docs/platform-matrix/FND-002A-capability-evidence.md` | **new** — dated evidence register |
| `docs/platform-matrix/FND-002-runtime-test-plan.md` | **new** — device/Windows/web follow-up plan |
| `docs/platform-matrix/platform-matrix.md` | rewritten with evidence classes |
| `docs/decisions/ADR-0005-notification-stack-decision-required.md` | **new** |
| `docs/architecture/capability-contracts.md` | **new** |
| `docs/task-ledger/TASK_LEDGER.md` | FND-002 split; D1–D3 added |
| `docs/task-ledger/FND-002A-completion-report.md` | this report |

**Not touched:** `pubspec.yaml`, `pubspec.lock`, all five apps, `backend/`,
`infra/`, `cp_contracts`. No commerce feature, state machine or business
contract was implemented. No Firebase config or secret was added.

## 8. Scope statement

FND-002A delivers documentation, static and host-available evidence only.
**No platform support is proven.** Every device, Windows and real-transport row
remains `NOT RUN`, `BLOCKED` or `DECISION REQUIRED`. FND-002 stays **PARTIAL**;
FND-002B carries the runtime work and is blocked on both hardware and owner
decisions D1–D3. FND-003 was not started.
