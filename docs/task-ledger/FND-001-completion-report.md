# FND-001 completion report

- **Task:** Inspect/bootstrap repository, task ledger, pinned toolchain and constraints
- **Owner project:** ADMIN
- **Date:** 2026-09-09
- **Host:** macOS 26.6.2 (darwin-arm64), zsh
- **Status:** **DONE** — with the environment gaps below recorded as blockers for FND-002/FND-004

## 1. Repository inspection (before any change)

`/Users/mohiuddin/Projects/commerce_platform` contained exactly one file,
`SHARED_BLUEPRINT.md` (14,740 bytes), and was **not** a Git repository. Nothing
else existed. The blueprint was read in full before any file was written and
has not been modified (sha256
`f3c91eb52d1bd986208c39f92a076662eb0ac12d7792370acd510706ad6cc2fe`).

## 2. What was created

### Git

`git init -b main`. Committed identity was already configured globally
(`mohiuddin <mohiuddin655.bd@gmail.com>`). No remote is configured and nothing
was pushed anywhere.

### Directory hierarchy — exactly as the blueprint specifies

`apps/{admin,user,agent,picker,rider}` ·
`packages/{core,design_system,contracts,auth,networking,local_store,sync,notifications,observability,feature_flags}` ·
`backend/{api,workers,modules/{identity,shops,catalog,inventory,orders,fulfillment,cash,notifications,support}}` ·
`infra/{firebase,ci}` ·
`docs/{architecture,contracts,platform-matrix,task-ledger,decisions,release-policy}` ·
`tools/`

Each app: `lib/bootstrap/`, `lib/app/`, `lib/features/`, `lib/main.dart`,
`test/`. The feature path is
`lib/features/<feature>/{domain,application,data,presentation}`, documented in
each app's `lib/features/README.md` and shipped as a copyable template at
`tools/templates/feature_template/`.

### Workspace and configuration

| File | Purpose |
|---|---|
| `pubspec.yaml` | Pub **workspace** root; 15 members; one root `pubspec.lock` (committed) |
| `analysis_options.yaml` | Strict casts/inference/raw-types; `missing_required_param` and `missing_return` as **errors** |
| `.gitignore` | Dart/Flutter, native, Node, IDE, OS — and secrets: `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`, `.env`, service-account JSON, keystores, `*.pem` |
| `.gitattributes`, `.editorconfig`, `.nvmrc` | LF normalisation, 2-space/80-col Dart, Node 26.8.1 |

### Code (foundation only — no features)

- `packages/core` → `cp_core`: `Money` (integer minor units, explicit
  currency, **no `double` surface at all**, negative allowed for reversals,
  cross-currency arithmetic throws), sealed `Result`/`Ok`/`Err`, `Failure` with
  a `FailureKind` that separates `conflict` from `rejectedByPolicy`, and
  `Clock` documenting that client time is never commercial truth.
- `packages/contracts` → `cp_contracts`: `ContractVersion` with a `canRead`
  compatibility rule, addressing the blueprint's "older app reading newer
  schema" evidence requirement. **No schemas and no transition tables** — those
  are FND-003 and were deliberately not guessed.
- Eight remaining packages: declared libraries with documented ownership and no
  implementation, so dependency direction and resolution are verifiable now.
- Five app shells: `bootstrap()` composition seam + a placeholder screen naming
  the role and contract version. No login, product, order or delivery code.

### Tooling

- `tools/check_layering.sh` — six guard rules (packages↛apps, client↛backend,
  `domain`↛Flutter, `presentation`↛`data`, `application`↛`presentation`, no
  key-shaped secrets), non-zero exit on any hit.
- `tools/run_checks.sh` — the single gate: resolve → analyze → dart test →
  flutter test → guards. FND-004's CI must call this, not redefine it.

### Documentation

`README.md`, `CONSTRAINTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`;
`docs/architecture/{repository-structure,layering-rules,toolchain}.md`;
`docs/task-ledger/TASK_LEDGER.md`; `docs/platform-matrix/platform-matrix.md`;
ADR-0001 (modular monorepo), ADR-0002 (pub workspaces over melos), ADR-0003
(`cp_` package prefix), ADR-0004 (strict analysis + guard rails);
placeholders for `docs/contracts/` and `docs/release-policy/`; READMEs for
`backend/`, all nine backend modules, `backend/api`, `backend/workers`,
`infra/firebase`, `infra/ci`.

## 3. What was verified — actually run, with results

| # | Command | Result |
|---|---|---|
| 1 | `flutter pub get` (workspace root) | **PASS** — 15 members resolved into one lockfile |
| 2 | `flutter analyze` (all apps + packages) | **PASS** — `No issues found!` |
| 3 | `dart test` in `packages/core` | **PASS** — 8/8 |
| 4 | `dart test` in `packages/contracts` | **PASS** — 4/4 |
| 5 | `flutter test` in each of the 5 apps | **PASS** — 1/1 each (5 total) |
| 6 | `./tools/check_layering.sh` | **PASS** |
| 7 | Negative control on the guard | **PASS** — a planted violation of each of the six rules produced exit 1 and named the file; a clean tree returned exit 0 |
| 8 | `./tools/run_checks.sh` (full gate) | **PASS** — `ALL CHECKS PASSED`, exit 0 |

**17 tests pass** (12 unit + 5 widget). Item 7 matters: a guard that has never
been shown to fail proves nothing, so each rule was proven to fire before being
reported as passing.

Two issues were found and fixed during verification rather than reported as
clean: `package_api_docs` was removed in Dart 3.7 and had to be dropped from
the lint set, and nine files violated `directives_ordering`.

## 4. What was NOT run — and why

| Check | Status | Reason |
|---|---|---|
| Any app **build** (APK/IPA/web/Windows) | **NOT RUN** | Platform folders (`android/`, `ios/`, `web/`, `windows/`) are not generated. That is FND-004. Only analysis and unit/widget tests are possible today. |
| Android build/emulator | **NOT RUN** | `flutter doctor`: *Android license status unknown*. Needs an interactive `flutter doctor --android-licenses` (owner action O1). |
| Windows anything — Auth REST/PKCE, notifications, Drift | **BLOCKED** | The host is macOS. No Windows machine or CI runner exists (O2). Not merely untested — unmeasurable here. |
| Physical-device push notifications | **NOT RUN** | Only `macOS (desktop)` and `Chrome (web)` are attached. Simulators are not push evidence (O3). |
| FCM / `awesome_notifications` coexistence spike | **NOT RUN** | FND-002. No notification code exists yet. |
| Firebase emulator, Firestore rules and security tests | **NOT RUN** | **Firebase CLI is not installed** on this machine (O4). FlutterFire CLI also absent. |
| Cloud deployment of any kind | **NOT DONE** | Out of scope by instruction, and no credentials exist. |
| Backend build/tests | **NOT RUN** | No backend code exists; no `package.json` was created, because adding one would imply a build FND-001 does not deliver. |

Tools confirmed **missing** on this host: `firebase`, FlutterFire CLI, `gh`,
`docker`, `gradle` wrapper, `melos` (not needed — ADR-0002).

## 5. What remains

| Next | Owner task | Gate |
|---|---|---|
| Compatibility spikes, proven platform matrix | FND-002 | **BLOCKED** on O2 (Windows runner) and O3 (physical device) |
| Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants | FND-003 | Ready to start — not blocked by hardware |
| CI, platform folders, emulator security tests, design system, auth, cache/queue/API shell | FND-004 | Needs FND-002 + FND-003, and O4 (Firebase CLI) |
| Seeded end-to-end flow + refusal/return branch | E2E-001 | After FND-003/004 |
| Role features | ROLE-* | After FND-003; **must not guess contract fields** before then |

FND-003 is the useful next task: it is the only foundation work not blocked by
missing hardware or a missing CLI.

## 6. Owner actions needed

O1 accept Android licenses · O2 provide a Windows machine or CI runner ·
O3 attach physical Android/iOS devices · O4 install Firebase + FlutterFire CLI
· O5 create Firebase projects per environment and supply config · O6 decide
currency, fee policy and commission ownership (FND-003 input) · O7 decide git
remote/hosting and branch protection.

## 7. Honest scope statement

This is bootstrapped scaffolding with a verified toolchain and mechanically
enforced boundaries. It is **not** capacity-certified software, no platform
support is proven, and no production-ready claim is made or implied. Every
unrun check above is recorded as NOT RUN rather than assumed to pass.
