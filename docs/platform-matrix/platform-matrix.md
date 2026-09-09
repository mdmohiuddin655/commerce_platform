# Platform matrix — claimed vs proven

The blueprint's matrix states what is *intended*. This file adds the only
column that matters before release: whether it has been **proven on this
repository**. At FND-001 nothing has been proven, because nothing has been
built yet. FND-002 fills the Status column with measured evidence.

Status values: `PROVEN` (measured here, with output) · `NOT RUN` (no evidence)
· `BLOCKED` (cannot be measured with current hardware) · `N/A`.

| Capability | Android/iOS | Web | Windows |
|---|---|---|---|
| Core commerce UI | Flutter — **NOT RUN** | Flutter with URL/navigation semantics — **NOT RUN** | Flutter resizable desktop UI — **BLOCKED** |
| Firebase access | Supported plugins after verification — **NOT RUN** | Supported plugins/API — **NOT RUN** | API adapter; no beta SDK in production — **BLOCKED** |
| Auth | Firebase Auth + OAuth adapters — **NOT RUN** | Firebase Auth browser flows — **NOT RUN** | Verified Firebase Auth REST + system-browser OAuth — **BLOCKED** |
| Notifications | FCM/Awesome coexistence spike is mandatory — **NOT RUN** | FCM/browser/service worker, verified display adapter — **NOT RUN** | Separate transport/toast + durable inbox fallback — **BLOCKED** |
| Local cache | Drift SQLite — **NOT RUN** | Drift WASM + browser limits — **NOT RUN** | Drift SQLite — **BLOCKED** |
| Active location | Permission/lifecycle/battery constrained — **NOT RUN** | Foreground capability/fallback — **NOT RUN** | Device-dependent capability/fallback — **BLOCKED** |

## Why Windows is BLOCKED, not merely untested

The bootstrap host is macOS (darwin-arm64). No Windows machine or CI runner is
available, so no Windows row can be measured here at any effort level. This is
owner action **O2** in the task ledger.

## Toolchain reality on the bootstrap host

Measured 9 September 2026 via `flutter doctor -v`:

| Target | Toolchain present | Note |
|---|---|---|
| Android | Android SDK 36.0.0, platform android-37.0, emulator 37.1.11.0 | **licenses not accepted** (owner action O1) |
| iOS / macOS | Xcode 26.6 (17F113), CocoaPods 1.17.0 | ✓ |
| Web | Chrome 152.0.7977.83 | ✓ |
| Windows | none | host is macOS |
| Devices attached | macOS desktop, Chrome web only | no physical phone — push evidence impossible |

## Standing cautions carried from the blueprint

- Firebase documents Windows SDK use as **local development, not production**.
- `firebase_messaging` does not list Windows.
- `awesome_notifications` exposes broad platform metadata while its README
  deprecates the Firebase integration. Validate the implementation, not badges.
  This is a **release-blocking compatibility question**, not a verified pair.
- A foreground-only notification fallback must never be described as full push
  parity.
- Business functionality must remain available without optional GPS or
  notification permissions.
- Flutter web satisfies the requested application codebase. If public catalog
  SEO becomes a business requirement, measure crawlability and metadata first
  and decide explicitly; do not silently add a second frontend stack.
