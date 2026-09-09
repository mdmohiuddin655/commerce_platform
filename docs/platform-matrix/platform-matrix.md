# Platform matrix — claimed vs proven

Updated by **FND-002A**, 2026-09-09. Evidence and sources:
`FND-002A-capability-evidence.md`. Follow-up plan:
`FND-002-runtime-test-plan.md`.

Generic green checks are deliberately not used. Every cell names the **class**
of evidence behind it, because a documented claim and a device-proven claim are
different things.

| State | Meaning |
|---|---|
| `VERIFIED-DOC` | Current primary vendor documentation, dated |
| `VERIFIED-LOCAL` | Observed on this host (resolution, analysis, tests) |
| `VERIFIED-HOST-RUNTIME` | Observed in the installed browser on this host |
| `VERIFIED-DEVICE` | Observed on a physical device — **nothing qualifies yet** |
| `VERIFIED-RUNNER` | Observed on a platform runner — **nothing qualifies yet** |
| `BLOCKED` | Cannot be evidenced here; the missing resource is named |
| `NOT RUN` | Executable in principle, not yet executed |
| `UNSUPPORTED` | No supported path exists |
| `DECISION REQUIRED` | Needs an owner decision before evidence is possible |

## Capability × platform

| Capability | Android | iOS | Web | Windows |
|---|---|---|---|---|
| Core Flutter UI | `NOT RUN` — no platform folders yet (FND-004) | `NOT RUN` — same | `NOT RUN` — same | `BLOCKED` — no Windows runner |
| Platform build artifact | `BLOCKED` — Android licenses not accepted | `NOT RUN` — Xcode 26.6 present, no app target yet | `NOT RUN` | `BLOCKED` — no Windows runner |
| Firebase core / Auth approach | `VERIFIED-DOC` — `firebase_auth` 6.6.1 lists Android | `VERIFIED-DOC` — lists iOS | `VERIFIED-DOC` — lists web | `DECISION REQUIRED` → REST; Firebase docs: Windows "not intended for production use cases" |
| OAuth approach | plugin path, `VERIFIED-DOC` | plugin path, `VERIFIED-DOC` | browser flows, `VERIFIED-DOC` | system browser + PKCE + loopback, `VERIFIED-DOC` (RFC 8252) |
| Messaging transport | `VERIFIED-DOC` — `firebase_messaging` 16.6.0 lists Android | `VERIFIED-DOC` — lists iOS | `VERIFIED-DOC` — lists web; needs VAPID key | **`UNSUPPORTED`** — Windows not listed by `firebase_messaging` |
| Local notification display | `VERIFIED-DOC` | `VERIFIED-DOC` | `VERIFIED-DOC` | `VERIFIED-DOC` — Windows toast via a Windows-capable local plugin |
| **FCM + Awesome coexistence** | **`DECISION REQUIRED`** — vendor-prohibited | **`DECISION REQUIRED`** — vendor-prohibited | **`DECISION REQUIRED`** — Awesome FCM add-on has no web support | **`DECISION REQUIRED`** |
| Background message handling | `NOT RUN` — needs device; requirements documented | `NOT RUN` — needs device | `NOT RUN` — needs service worker + Firebase project | `UNSUPPORTED` — no transport |
| Terminated notification launch | `NOT RUN` — `getInitialMessage` documented | `NOT RUN` | `UNSUPPORTED` — no terminated launch on web | `UNSUPPORTED` |
| Token refresh / rotation | `NOT RUN` — needs device + project | `NOT RUN` — needs APNs key | `NOT RUN` — needs VAPID key + project | `UNSUPPORTED` |
| Web service worker | n/a | n/a | `VERIFIED-HOST-RUNTIME` — `serviceWorker` and `PushManager` present in Chrome 152 on a secure origin | n/a |
| Closed-app notification | `NOT RUN` | `NOT RUN` | `UNSUPPORTED` — browser must be running | **`DECISION REQUIRED`** — WNS needs Azure/Entra or Store registration |
| Drift / local persistence | `VERIFIED-DOC` + `VERIFIED-LOCAL` (resolution) | `VERIFIED-DOC` + `VERIFIED-LOCAL` | `VERIFIED-HOST-RUNTIME` — WASM, OPFS, IndexedDB, SharedWorker all present | `VERIFIED-DOC` — native FFI; `BLOCKED` for execution, no runner |
| Cross-origin isolation (Drift `opfsLocks`) | n/a | n/a | `VERIFIED-HOST-RUNTIME` — **`false` by default**; `true` once COOP/COEP headers are served | n/a |
| Active location | `NOT RUN` | `NOT RUN` | `NOT RUN` | `NOT RUN` |
| Runner / device evidence available | **none** — no physical Android | **none** — no physical iOS | Chrome 152 on macOS | **none** — no Windows runner |

## Evidence separation

| Class | What was actually done in FND-002A |
|---|---|
| Documentation | Firebase Flutter setup, FCM client/receive, `firebase_messaging`, `awesome_notifications`, `awesome_notifications_fcm`, `flutter_local_notifications`, `firebase_auth`, Drift (pub + platform docs), RFC 8252, Microsoft Learn WNS — all read 2026-09-09 |
| Compile / local | Workspace resolution, `flutter analyze` clean, 45 tests passing, four out-of-repo dependency-resolution probes |
| Browser runtime | Chrome 152 headless feature detection on `http://localhost`, plus a COOP/COEP comparison run |
| Physical device | **none** |
| Platform runner | **none** |

## Standing cautions, rechecked and still current

- Firebase, page updated 2026-09-08: **"Firebase on Windows is not intended for
  production use cases, only local development workflows."**
- `firebase_messaging` still does **not** list Windows.
- `awesome_notifications` broad platform metadata coexists with a README that
  **deprecates** its `firebase_messaging` support and warns that notification
  plugins conflict over global notification resources. Validate
  implementations, not badges.
- Pub resolved the vendor-forbidden plugin combination without complaint.
  Dependency resolution is not compatibility evidence.
- A foreground-only or local-toast-only fallback is **not** push parity.
- Business functionality must remain available with notification permission
  denied and with no push transport at all.
