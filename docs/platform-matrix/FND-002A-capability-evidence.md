# FND-002A — capability evidence register

Every material compatibility claim used by this repository, with its primary
source and the date it was checked. **All entries checked 2026-09-09** on the
bootstrap host unless stated otherwise. Nothing here was copied from
`SHARED_BLUEPRINT.md`; each claim was rechecked against the current upstream
source, and where the blueprint's September-2026 statement still holds, that
is recorded as a confirmation rather than assumed.

## Evidence classification

| Class | Meaning |
|---|---|
| `VERIFIED-DOC` | Read from current primary vendor documentation on the date shown |
| `VERIFIED-LOCAL` | Observed on this host: dependency resolution, analysis, tests |
| `VERIFIED-HOST-RUNTIME` | Observed running in the installed browser on this host |
| `VERIFIED-DEVICE` | Observed on a physical device — **nothing in this task qualifies** |
| `VERIFIED-RUNNER` | Observed on a platform runner — **nothing in this task qualifies** |
| `BLOCKED` | Cannot be evidenced here; names the missing resource |
| `DECISION REQUIRED` | Needs an owner decision before it can be evidenced |

---

## 1. Toolchain

| Item | Value | Class |
|---|---|---|
| Flutter | 3.47.2 stable, framework `d3b14c8769`, engine `a804b26164` | `VERIFIED-LOCAL` |
| Dart | 3.13.2 | `VERIFIED-LOCAL` |
| Host | macOS 26.6.2 (25G83), darwin-arm64 | `VERIFIED-LOCAL` |
| Devices available | `macOS (desktop)`, `Chrome (web) 152.0.7977.83` — **no physical device** | `VERIFIED-LOCAL` |
| Android toolchain | SDK 36.0.0, platform android-37.0; **licenses not accepted** | `VERIFIED-LOCAL` |
| Xcode | 26.6 (17F113), CocoaPods 1.17.0 | `VERIFIED-LOCAL` |

Commands: `flutter --version`, `dart --version`, `flutter doctor -v`,
`flutter devices`.

---

## 2. Firebase on Flutter — platform guidance

| Field | Value |
|---|---|
| Source | *Add Firebase to your Flutter app* — Firebase (Google) |
| URL | https://firebase.google.com/docs/flutter/setup |
| Page last updated | **2026-09-08 UTC** |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

Verbatim: **"Caution: Firebase on Windows is not intended for production use
cases, only local development workflows."**

**Conclusion.** The blueprint's Windows caution is *still current*, restated on
a page updated the day before this check. Windows must not depend on the
Firebase native plugin path for production. This is the basis for the Windows
auth strategy in §8.

---

## 3. `firebase_messaging`

| Field | Value |
|---|---|
| Source | pub.dev package page (official FlutterFire package) |
| URL | https://pub.dev/packages/firebase_messaging |
| Version | **16.6.0** (published ~16 days before the check) |
| License | **BSD-3-Clause** |
| Platforms listed | **Android, iOS, macOS, web** |
| Windows | **NOT listed** |
| Linux | **NOT listed** |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

**Conclusion.** The blueprint's claim that `firebase_messaging` does not list
Windows is **confirmed as still true**. Any Windows notification capability
must come from somewhere else (§9).

### Message handling requirements

| Field | Value |
|---|---|
| Source | *Receive messages in a Flutter app* — Firebase |
| URL | https://firebase.google.com/docs/cloud-messaging/flutter/receive |
| Page last updated | 2026-09-08 UTC |
| Class | `VERIFIED-DOC` |

Background handler, verbatim requirements:

- "It must not be an anonymous function."
- "It must be a top-level function (e.g. not a class method which requires
  initialization)."
- "When using Flutter version 3.3.0 or higher, the message handler must be
  annotated with `@pragma('vm:entry-point')` right above the function
  declaration (otherwise it may be removed during tree shaking for release
  mode)."

Registered in `main()` before `runApp()`. It may not update app state or run
UI logic; it may do HTTP and IO; work beyond ~30 seconds risks OS termination.

Foreground, verbatim: notification messages "won't display a visible
notification by default, on both Android and iOS" — the app must show one
itself. **This is the structural reason a local-display plugin is needed
alongside FCM at all**, and therefore the reason the coexistence question in
§5 exists.

Terminated launch: `getInitialMessage()` returns the launching `RemoteMessage`
once and then clears it; `onMessageOpenedApp` covers background→foreground.

### Client requirements

| Field | Value |
|---|---|
| Source | *Set up a Firebase Cloud Messaging client app on Flutter* |
| URL | https://firebase.google.com/docs/cloud-messaging/flutter/client |
| Page last updated | 2026-09-08 UTC |
| Class | `VERIFIED-DOC` |

- **Web** requires a VAPID public key passed to `getToken(vapidKey: ...)`, a
  service worker, and granted notification permission.
- **Apple** requires an uploaded APNs authentication key, push notifications
  and background modes enabled in Xcode, and method swizzling — verbatim:
  "method swizzling is required. Without it, key Firebase features such as FCM
  token handling won't function properly".
- **Android** requires Google Play services.

---

## 4. `awesome_notifications`

| Field | Value |
|---|---|
| Source | pub.dev package page / README |
| URL | https://pub.dev/packages/awesome_notifications |
| Version | **0.12.1** |
| License | **Apache-2.0** (https://pub.dev/packages/awesome_notifications/license) |
| Platforms listed | Android, iOS, Linux, macOS, Web, Windows |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

Verbatim deprecation notice:

> "Deprecated support for firebase_messaging plugin: The support for
> `firebase_messaging` plugin is now deprecated. You need to use the Awesome's
> FCM add-on plugin to achieve all Firebase Cloud Messaging features without
> violating the platform rules."

And: "The firebase_messaging plugin is not necessary. awesome_notifications_fcm
is a replacement for it".

Verbatim incompatibility notice:

> "The `awesome_notifications` plugin is incompatible with
> `flutter_local_notifications` or any other notification plugin. These plugins
> may conflict with each other when trying to acquire global notification
> resources."

**Conclusion.** The blueprint's warning — that Awesome's README deprecates its
Firebase integration despite broad platform metadata — is **confirmed and now
stronger than the blueprint stated**: it is not merely deprecated, the vendor
directs users to a different plugin and warns that notification plugins fight
over global notification resources.

---

## 5. `awesome_notifications_fcm`

| Field | Value |
|---|---|
| Source | pub.dev package page / README |
| URL | https://pub.dev/packages/awesome_notifications_fcm |
| Version | **0.12.1** |
| Publisher | carda.me (verified publisher) |
| Platforms listed | **Android, iOS only** |
| License | **not stated on the package page — UNRESOLVED** |
| Popularity | 168 likes, 140 pub points, ~6,420 weekly downloads |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

Verbatim: "This plugin is a replacement of `firebase_messaging`, built
specially to share and use all `awesome_notifications` features."

Verbatim prohibition: users **"MUST not use `firebase_messaging` with
`awesome_notifications_fcm`."**

Requires a Firebase project with Cloud Messaging enabled,
`google-services.json`, `GoogleService-Info.plist`, and an APNs certificate.

**Two conclusions.**

1. The vendor **forbids** the exact combination the blueprint calls mandatory.
2. This plugin covers **Android and iOS only** — choosing it leaves **web with
   no push transport from this vendor**, which the blueprint's web row assumes
   exists.

Its license is not stated on the package page. **No dependency may be added
until that is resolved** (§B of the dependency policy).

---

## 6. `flutter_local_notifications`

| Field | Value |
|---|---|
| Source | pub.dev package page / README |
| URL | https://pub.dev/packages/flutter_local_notifications |
| Version | **22.3.0** |
| License | **BSD-3-Clause** |
| Platforms listed | Android, iOS, Linux, macOS, Web, **Windows** |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

Verbatim on FCM coexistence:

> "Previously, there were issues that prevented this plugin working properly
> with the `firebase_messaging` plugin... This has been resolved since version
> 6.0.13 of the `firebase_messaging` plugin so please make sure you are using
> more recent versions."

Windows: provides "A full Dart API for all the options supported by toast
notifications".

**Conclusion.** This is the *documented-compatible* local-display companion for
`firebase_messaging`, and it is the only candidate in this register that
supplies a **Windows local toast** path.

---

## 7. Drift

| Field | Value |
|---|---|
| Source | pub.dev package page; Drift platform documentation |
| URLs | https://pub.dev/packages/drift · https://drift.simonbinder.eu/platforms/ · https://drift.simonbinder.eu/platforms/web/ |
| Version | **2.34.4** |
| License | **MIT** |
| Platforms listed | Android, iOS, Linux, macOS, web, Windows |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

**Native.** `NativeDatabase` over `dart:ffi` for Android, iOS, Windows, Linux,
macOS. Verbatim: "Starting from drift version 2.32.0 depending on versions 3.x
of the `sqlite3` package, no further setup is required and an up-to-date copy
of SQLite will automatically be bundled with your app." `sqlite3_flutter_libs`
is no longer required.

**Web.** `WasmDatabase` compiles SQLite to WebAssembly. Two files must be
served from `web/`: **`sqlite3.wasm`** and **`drift_worker.js`**, obtained from
the Drift GitHub release matching the resolved drift version, or self-compiled.
Verbatim serving requirement: "For browsers to accept the `sqlite3.wasm` file,
it must be served with `Content-Type: application/wasm`."

Storage implementations, in Drift's documented order of preference:

1. `opfsShared` — OPFS via shared workers
2. `opfsLocks` — OPFS without shared workers, **requires COOP/COEP headers**
3. `sharedIndexedDb` — IndexedDB with shared-worker synchronisation
4. `unsafeIndexedDb` — IndexedDB with no cross-tab safety
5. `inMemory` — fallback, nothing persists

`WasmDatabase.open()` reports `chosenImplementation` and `missingFeatures`, so
the tier is knowable at runtime and **must be surfaced, not ignored**.

Documented caveats, verbatim where quoted:

- Firefox does not support the FileSystem Access API in private browsing and
  falls back to IndexedDB from version 115 onward.
- Chrome on Android has no shared workers: "if the headers required for the
  preferred API are missing, there unfortunately is no way to prevent data
  races between tabs, which can lead to persistence issues".
- In `unsafeIndexedDb`, "It is not safe for multiple tabs of your app to access
  the same database" — the app should warn the user.
- "WAL is not supported on the web and WAL databases can't be imported with
  `initializeDatabase` either."

Storage **quota and eviction policy are not documented by Drift**. Treat
browser eviction as an open risk to be measured, not an assumption.

---

## 8. Firebase Auth and native-app OAuth

| Field | Value |
|---|---|
| Source | pub.dev `firebase_auth` |
| URL | https://pub.dev/packages/firebase_auth |
| Version | **6.6.1** |
| License | **BSD-3-Clause** |
| Platforms listed | Android, iOS, macOS, web, **Windows** |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

**Important tension, resolved explicitly.** `firebase_auth` *lists* Windows,
but Firebase's own setup page (§2) cautions that Firebase on Windows is for
local development, not production. A platform badge does not override the
vendor's production guidance. Windows therefore uses the REST +
system-browser + PKCE strategy, not the plugin.

| Field | Value |
|---|---|
| Source | RFC 8252, *OAuth 2.0 for Native Apps* (IETF) |
| URL | https://datatracker.ietf.org/doc/html/rfc8252 |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` |

- §5: "native apps MUST use an external user-agent to perform OAuth
  authorization requests."
- §6: "Public native app clients MUST implement the Proof Key for Code Exchange
  (PKCE [RFC7636]) extension to OAuth, and authorization servers MUST support
  PKCE for such clients."
- §7.3 loopback redirect: "The authorization server MUST allow any port to be
  specified at the time of the request."
- §8.5: "Secrets that are statically included as part of an app distributed to
  multiple users should not be treated as confidential secrets."

**Conclusion.** The blueprint's Windows auth approach is standards-supported:
system browser, PKCE, loopback redirect, **no embedded client secret**.

---

## 9. Windows push transport

| Field | Value |
|---|---|
| Source | Microsoft Learn — WNS overview, Windows App SDK push quickstart |
| URLs | https://learn.microsoft.com/en-us/windows/apps/develop/notifications/push-notifications/wns-overview · https://learn.microsoft.com/en-us/windows/apps/develop/notifications/push-notifications/push-quickstart |
| Date checked | 2026-09-09 |
| Class | `VERIFIED-DOC` + `DECISION REQUIRED` |

Findings:

- Closed-app push on Windows means **WNS**. Historically registration ran
  through Partner Center and required a Microsoft Store presence with a
  Package SID, so only packaged apps could use it.
- The Windows App SDK path uses an **Azure account and a Microsoft Entra ID app
  registration**; for packaged apps a Package Family Name mapping request may
  be needed, with lead time before launch.

**Conclusion.** A Windows *local toast* (app running) is available today via a
Windows-capable local notification plugin (§6). A Windows *closed-app push* is
**not an engineering-only decision**: it needs an Azure/Entra or Store
registration, i.e. an account, a cost and an owner sign-off. Recorded as
`DECISION REQUIRED`, and no vendor-specific production transport is selected in
this task.

The durable server-backed inbox, polled over the normal authenticated API,
remains the floor on every platform and is what keeps Windows usable while this
decision is open.

---

## 10. Local resolution evidence (`VERIFIED-LOCAL`)

Candidate stacks were resolved against the exact repository SDK baseline
(`sdk >=3.13.0 <4.0.0`, `flutter >=3.47.0`) in a scratch package **outside the
repository**, so the committed `pubspec.lock` was not touched.

| Probe | Constraints | Result | Resolved |
|---|---|---|---|
| A — FCM stack | `firebase_core ^4.6.0`, `firebase_messaging ^16.6.0`, `flutter_local_notifications ^22.3.0` | **resolved, exit 0** | firebase_core 4.14.0, firebase_messaging 16.6.0, flutter_local_notifications 22.3.0, timezone 0.11.1 |
| B — Awesome stack | `awesome_notifications ^0.12.1`, `awesome_notifications_fcm ^0.12.1`, `firebase_core ^4.6.0` | **resolved, exit 0** | awesome_notifications 0.12.1, awesome_notifications_fcm 0.12.1, firebase_core 4.14.0 |
| C — forbidden combination | Path A's `firebase_messaging` **plus** Path B's Awesome packages | **resolved, exit 0** | — |
| D — Drift native | `drift ^2.34.4`, `sqlite3 ^3.4.0` | **resolved, exit 0** | drift 2.34.4, sqlite3 3.5.2 |

**Probe C is the important one.** Pub resolved the combination the vendor
explicitly forbids, without a warning. Dependency resolution therefore proves
**nothing** about notification-plugin coexistence: the conflict is at the
native layer (Android service registration, iOS `UNUserNotificationCenter`
delegate ownership), which pub cannot see. This is a concrete instance of the
blueprint's rule to validate implementations rather than badges — and it is why
probe C must never be cited as coexistence evidence.

---

## 11. Browser runtime evidence (`VERIFIED-HOST-RUNTIME`)

Command: `./tools/check_web_capabilities.sh`
Browser: Google Chrome 152.0.7977.83 (headless), origin `http://localhost`
(a secure context). Date: 2026-09-09.

| API | Result | Relevance |
|---|---|---|
| `isSecureContext` | `true` | prerequisite for service workers and OPFS |
| `serviceWorker` | `true` | required by web FCM |
| `PushManager` | `true` | web push available in this browser |
| `Notification` | `true`, permission `default` | not yet granted; never assume granted |
| `indexedDB` | `true` | Drift `sharedIndexedDb` / `unsafeIndexedDb` tiers |
| `SharedWorker` | `true` | Drift `opfsShared` / `sharedIndexedDb` tiers |
| `navigator.storage.getDirectory` | `true` | OPFS present |
| `storage.estimate` / `persist` | `true` | quota introspection available |
| reported quota | ~10.74 GB (10,737,418,240 bytes) | ample for a cache; not a persistence guarantee |
| `WebAssembly` | `true` | Drift WASM prerequisite |
| `Atomics.wait` | `true` | worker synchronisation |
| `crossOriginIsolated` | **`false`** | **without COOP/COEP headers** |
| `SharedArrayBuffer` | **`false`** | follows from the above |

**Follow-up experiment.** The same probe re-served with
`Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` reported `crossOriginIsolated =
true` and `SharedArrayBuffer = true`.

**Conclusion — actionable for FND-004.** Every browser API the web
notification and persistence strategies need exists in the installed browser.
Drift's `opfsLocks` tier depends on cross-origin isolation, which is **off by
default** and is a *hosting configuration* matter: the web app must be served
with COOP/COEP headers, and that must be verified on the real host, not
assumed. Without it, Drift degrades down its tier list toward
`unsafeIndexedDb`, which is not cross-tab safe.

**Limits of this evidence.** Feature detection is not delivery. This proves the
APIs exist; it does not prove FCM registers a token, that a push arrives, or
that Drift's OPFS backend works end to end. Headless Chrome may also differ
from headed Chrome for permission prompting. Those remain `NOT RUN`.

---

## 12. What this register does *not* establish

- No notification was delivered to any device or browser.
- No FCM token was obtained. None was fabricated.
- No Firebase project, credential or emulator was used.
- No Windows code was built or executed.
- No app was built for any platform.
