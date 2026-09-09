# Pinned toolchain and constraints (FND-001)

Measured on the bootstrap machine on **9 September 2026**. Every version below
was read from the tool itself, not assumed. Anything not present on this
machine is listed as **MISSING** rather than described as working.

## Host

| Item | Value |
|---|---|
| OS | macOS 26.6.2 (25G83), darwin-arm64 |
| Shell | zsh |

> zsh does not word-split unquoted variables. Repository scripts must quote or
> use explicit arrays; a `for x in $VAR` loop that works in bash silently
> creates one wrongly-named item here.

## Pinned versions

| Tool | Pinned version | Where pinned | Status |
|---|---|---|---|
| Flutter | 3.47.2 (stable) | `pubspec.yaml` `environment.flutter >=3.47.0` | VERIFIED |
| Dart | 3.13.2 | `pubspec.yaml` `environment.sdk >=3.13.0 <4.0.0` | VERIFIED |
| Flutter framework rev | `d3b14c8769` | this document | VERIFIED |
| Flutter engine rev | `a804b26164` | this document | VERIFIED |
| DevTools | 2.60.0 | — | VERIFIED |
| Node.js | 26.8.1 | `.nvmrc` | VERIFIED |
| npm | 11.19.0 | — | VERIFIED |
| Git | 2.50.1 (Apple Git-155) | — | VERIFIED |
| Xcode | 26.6 (build 17F113) | this document | VERIFIED |
| CocoaPods | 1.17.0 | — | VERIFIED |
| Android SDK | 36.0.0, platform android-37.0 | this document | VERIFIED |
| Android emulator | 37.1.11.0 | — | VERIFIED |
| JDK (Android Studio bundled) | OpenJDK 25.0.2 | Android Studio | VERIFIED |
| JDK (system `java`) | OpenJDK 26.0.2.1 | — | VERIFIED |
| Python | 3.9.6 (system) | — | VERIFIED |
| Chrome (web target) | 152.0.7977.83 | — | VERIFIED |

`pubspec.lock` is committed at the workspace root. It is the single resolved
dependency set for all five apps and all shared packages; do not add a second
lockfile.

## Not installed on this machine

| Tool | Needed for | Consequence now |
|---|---|---|
| Firebase CLI (`firebase`) | emulator suite, rules tests, deploys | FND-003/FND-004 emulator security tests **cannot run** until installed |
| FlutterFire CLI | `firebase_options.dart` generation | app Firebase wiring blocked (FND-004) |
| `gh` (GitHub CLI) | PR/CI automation | manual git only |
| Docker | containerised backend/emulator runs | not required yet |
| `melos` | not used — pub workspaces cover it (see ADR-0002) | none |
| Gradle wrapper | appears after `flutter create` platform folders | Android build not yet possible |

## Environment gaps that block later tasks

1. **Android licenses not accepted.** `flutter doctor` reports
   `Android license status unknown`. Run `flutter doctor --android-licenses`
   before the first Android build. Owner action — requires interactive accept.
2. **No Windows runner.** The host is macOS. The blueprint's Windows column
   (Auth REST + PKCE, notification transport, Drift SQLite) **cannot be tested
   here at all**. FND-002 needs a Windows machine or CI runner.
3. **No physical device connected.** Only `macOS (desktop)` and `Chrome (web)`
   are available. Physical-device push notification evidence is therefore
   **NOT RUN** and must stay marked so.
4. **No platform folders yet.** `android/`, `ios/`, `web/`, `windows/` are not
   generated for the five apps, so no app can be *built* yet — only analyzed
   and unit/widget tested. Generating them is FND-004, together with CI.

## Commands

```bash
flutter pub get                 # resolve the whole workspace (run at root)
flutter analyze                 # analyze every app and package
./tools/run_checks.sh           # analyze + all tests + layering guard
./tools/check_layering.sh       # structural guard rails only
```
