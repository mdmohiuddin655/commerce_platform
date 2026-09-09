# Repository structure (FND-001)

The hierarchy follows `SHARED_BLUEPRINT.md` exactly. Directory names are not
negotiable by an individual task; changing them requires an ADR.

```text
apps/
  admin/ user/ agent/ picker/ rider/
packages/
  core/ design_system/ contracts/ auth/ networking/
  local_store/ sync/ notifications/ observability/ feature_flags/
backend/
  api/ workers/
  modules/
    identity/ shops/ catalog/ inventory/ orders/
    fulfillment/ cash/ notifications/ support/
infra/
  firebase/ ci/
docs/
  architecture/ contracts/ platform-matrix/ task-ledger/
  decisions/ release-policy/
tools/
```

## Apps

Each app has:

```text
apps/<app>/
  lib/bootstrap/          # composition root: platform init and wiring
  lib/app/                # root widget, theming hookup, routing shell
  lib/features/<feature>/ # domain/ application/ data/ presentation/
  lib/main.dart
  test/
  pubspec.yaml            # name: <app>_app, resolution: workspace
```

No feature directory exists yet. FND-001 delivers the foundation only; role
features are owned by the ROLE-* tasks and gated on FND-002/003/004.

## Package naming

Directory names match the blueprint (`packages/core`), while the Dart package
name is prefixed (`cp_core`). `core`, `auth`, `sync`, `contracts`,
`networking` and `notifications` are all real, unrelated packages on pub.dev;
without the prefix a typo or a dropped path dependency could silently resolve
to a stranger's package. See `docs/decisions/ADR-0003-package-name-prefix.md`.

| Directory | Dart package | Kind | Depends on |
|---|---|---|---|
| `packages/core` | `cp_core` | Dart | — |
| `packages/contracts` | `cp_contracts` | Dart | `cp_core` |
| `packages/networking` | `cp_networking` | Dart | `cp_core` |
| `packages/observability` | `cp_observability` | Dart | `cp_core` |
| `packages/feature_flags` | `cp_feature_flags` | Dart | `cp_core` |
| `packages/sync` | `cp_sync` | Dart | `cp_core`, `cp_contracts` |
| `packages/design_system` | `cp_design_system` | Flutter | `cp_core` |
| `packages/auth` | `cp_auth` | Flutter | `cp_core`, `cp_contracts` |
| `packages/local_store` | `cp_local_store` | Flutter | `cp_core`, `cp_contracts` |
| `packages/notifications` | `cp_notifications` | Flutter | `cp_core`, `cp_contracts` |

Only `cp_core` and `cp_contracts` carry real code at FND-001. The rest are
declared libraries with no implementation, so that dependency direction and
workspace resolution are verifiable before feature work begins.

## Backend

`backend/modules/*` expose **ports**; a module never writes another module's
collections directly. `backend/api` is the trusted command surface,
`backend/workers` holds scheduled and outbox-draining jobs. The backend is not
implemented at FND-001 — FND-003 defines its contracts, FND-004 builds the
shell. The installed admin *app* never embeds privileged server code or
service-account credentials; the ADMIN **ChatGPT Project** coordinating those
tasks is not the same thing as the admin app.

## One lockfile

`pubspec.yaml` at the root is a **pub workspace** (`workspace:` members with
`resolution: workspace` in each). One `pubspec.lock` at the root pins every
dependency for every app and package. Do not commit per-package lockfiles and
do not add `melos`; see `docs/decisions/ADR-0002-pub-workspace.md`.
