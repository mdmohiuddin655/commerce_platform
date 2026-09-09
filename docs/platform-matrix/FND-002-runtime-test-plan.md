# FND-002 runtime test plan (follow-up to FND-002A)

Every test FND-002A could not run, written so a later bounded task can execute
it **without rediscovering the requirements**. Each row names exactly what is
missing.

Prerequisite for almost everything below: a **Firebase project** with Cloud
Messaging enabled, plus the platform config files
(`google-services.json`, `GoogleService-Info.plist`) and a **VAPID key** for
web. None of these exists yet (owner action O5). They are secrets or
secret-adjacent and remain git-ignored.

Also blocking: the notification stack choice is undecided (ADR-0005, decisions
D1–D3). **Do not run the device suites until a path is chosen** — the tests
differ between Path A and Path B, and running them against a stack that is then
discarded wastes device time.

---

## A. Android — physical device

**Missing:** a physical Android device; accepted Android SDK licenses
(`flutter doctor --android-licenses`); a Firebase project + `google-services.json`.

| # | Test | Pass criterion |
|---|---|---|
| A1 | Notification permission prompt (Android 13+ runtime permission) | Prompt appears; denial is handled without a crash and the app stays usable |
| A2 | Token registration | A real FCM token is obtained and sent to the server. **Never fabricate a token** |
| A3 | Token refresh / rotation | `onTokenRefresh` fires; the server is updated; the stale token stops receiving |
| A4 | Foreground message | Message arrives; **no automatic OS notification** (documented); the app displays one itself |
| A5 | Background message | Handler runs as a top-level function annotated `@pragma('vm:entry-point')`, registered before `runApp` |
| A6 | Terminated delivery + launch | Tapping the notification launches the app; `getInitialMessage()` returns the message exactly once |
| A7 | Local display | The chosen local-display path renders the notification with the intended channel and importance |
| A8 | Notification action / deep link | Tapping an action routes to the correct screen from foreground, background and terminated |
| A9 | **Duplicate eventId** | The same `eventId` delivered twice (push + inbox poll) yields **one** inbox entry. Guarded by `NotificationDeduplicator` unit tests; this proves it end to end |
| A10 | Reordered delivery | Out-of-order arrival changes nothing — state still comes from the server |
| A11 | Process restart | Events received while dead are recovered from the durable inbox, not lost |
| A12 | Permission denied end to end | With notifications denied, orders/assignments still work through polling. **Business functionality must not depend on push** |
| A13 | No unsupported plugin initialized | Path A only: verify `firebase_messaging` and the local-display plugin do not fight over the notification channel |

## B. iOS — physical device

**Missing:** a physical iOS device; an Apple Developer account; an **APNs
authentication key** uploaded to Firebase; push + background-mode capabilities
enabled in Xcode; `GoogleService-Info.plist`. **A simulator is not evidence
for push.**

| # | Test | Pass criterion |
|---|---|---|
| B1 | Permission request | System prompt appears; denial handled gracefully |
| B2 | APNs → FCM token path | APNs token maps to an FCM token; method swizzling left enabled (Firebase documents it as required) |
| B3 | `UNUserNotificationCenter` delegate ownership | Exactly one component owns the delegate. **This is the specific place Path A and Path B conflict** |
| B4 | Foreground | Message arrives; presentation options are applied deliberately |
| B5 | Background | Delivered with the app backgrounded |
| B6 | Terminated | Delivered and launches; `getInitialMessage()` returns it once |
| B7 | Stack coexistence | Whichever path is chosen, confirm no duplicate banner and no swallowed notification |
| B8 | Notification actions | Actions route correctly in all three app states |
| B9 | Duplicate eventId | One inbox entry for a doubly-delivered event |
| B10 | Permission denied end to end | Product remains fully usable |

## C. Windows — runner

**Missing:** a Windows machine or CI runner (owner action O2). Additionally for
C6: an Azure/Entra app registration or Microsoft Store presence (decision D3).

| # | Test | Pass criterion |
|---|---|---|
| C1 | `flutter build windows` | Builds and launches |
| C2 | Auth REST adapter | Firebase Auth REST sign-in succeeds over HTTPS |
| C3 | System-browser OAuth + PKCE | External browser (RFC 8252 §5), PKCE (§6), loopback redirect on an arbitrary port (§7.3). **No client secret in the binary** |
| C4 | Refresh-token persistence + secure storage | Token survives restart, stored in OS-protected storage, never in plain text |
| C5 | Local toast | A Windows toast displays while the app runs |
| C6 | Closed-app notification | **Blocked on D3.** Without WNS there is none; the durable inbox is the fallback and must be honestly labelled as such |
| C7 | **No unsupported plugin initialized** | Assert `firebase_messaging` is never initialized on Windows. `assertPushTransportSupported` already throws — confirm the app honours it and degrades to inbox + toast |
| C8 | Drift SQLite native | Database opens and persists via `NativeDatabase` |
| C9 | Resize / lifecycle | Adaptive layout at desktop sizes; minimise/restore and suspend/resume behave |
| C10 | App Check absent ≠ authorization bypass | Server still authorizes every command with no App Check token present |

## D. Web — with a real Firebase project

**Missing:** a Firebase project, a **VAPID key**, generated `web/` platform
folders, and a hosting setup that can set response headers.

| # | Test | Pass criterion |
|---|---|---|
| D1 | Service worker registration | `firebase-messaging-sw.js` registers on a secure origin. *(APIs already confirmed present — §11 of the evidence register)* |
| D2 | Token via VAPID key | `getToken(vapidKey: …)` returns a token after permission is granted |
| D3 | Foreground delivery | `onMessage` fires; app renders its own notification |
| D4 | Background delivery | Service worker handles the message with the tab backgrounded |
| D5 | Permission denied | App remains fully functional through polling |
| D6 | Token refresh | Rotation is observed and the server updated |
| D7 | **COOP/COEP headers** | Serve with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`; confirm `crossOriginIsolated === true`. *(Already proven on this host — the open question is the production hosting setup)* |
| D8 | Drift tier selection | `WasmDatabase.open()` reports `chosenImplementation`; assert it is not `unsafeIndexedDb` on the target browsers, and surface `missingFeatures` |
| D9 | `sqlite3.wasm` content type | Served as `Content-Type: application/wasm`, per Drift's documented requirement |
| D10 | Private / incognito browsing | Determine the tier chosen; if `inMemory`, the user is warned that data will not persist |
| D11 | Multi-tab safety | Two tabs against one database; no corruption. If the tier is `unsafeIndexedDb`, the documented warning must be shown |
| D12 | Storage eviction | Behaviour under quota pressure and after `storage.persist()`. Drift does not document eviction — this must be **measured** |

## E. Firebase emulator / rules

**Missing:** Firebase CLI and FlutterFire CLI (owner action O4).

| # | Test |
|---|---|
| E1 | Firestore security rules suite against the emulator |
| E2 | Auth emulator flows |
| E3 | Rules deny-by-default verification for every collection |

## Resource summary

| Resource | Unblocks | Owner action |
|---|---|---|
| Physical Android device | A1–A13 | O3 |
| Android SDK licenses accepted | Android builds | O1 |
| Physical iOS device + Apple Developer account + APNs key | B1–B10 | O3, O5 |
| Windows machine or CI runner | C1–C5, C7–C10 | O2 |
| Azure/Entra or Store registration | C6 | D3 |
| Firebase project + platform config + VAPID key | A2–A6, B2–B7, D1–D6, E1–E3 | O5 |
| Firebase CLI + FlutterFire CLI | E1–E3 | O4 |
| Notification stack decision (ADR-0005) | **all** A/B suites | D1, D2 |
| Hosting able to set response headers | D7, D9 | FND-004 |
