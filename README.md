# Commerce platform — shared monorepo

Five Flutter role applications (**admin, user, agent, picker, rider**) over one
shared commerce domain, plus a trusted command backend.

**Current state: foundation only.** No login, product, order or delivery
feature is implemented. See `docs/task-ledger/TASK_LEDGER.md` for what is done
and what is blocked.

## Quick start

```bash
flutter pub get          # resolve the whole workspace, from the root
./tools/run_checks.sh    # analyze + all tests + layering/secret guards
```

Run a role app (foundation placeholder shell, macOS or Chrome only until
FND-004 generates platform folders):

```bash
cd apps/admin && flutter run -d chrome
```

## Layout

```text
apps/       admin/ user/ agent/ picker/ rider/
packages/   core/ design_system/ contracts/ auth/ networking/
            local_store/ sync/ notifications/ observability/ feature_flags/
backend/    api/ workers/ modules/{identity,shops,catalog,inventory,orders,
                                   fulfillment,cash,notifications,support}/
infra/      firebase/ ci/
docs/       architecture/ contracts/ platform-matrix/ task-ledger/
            decisions/ release-policy/
tools/      run_checks.sh  check_layering.sh  templates/
```

Every feature is
`apps/<app>/lib/features/<feature>/{domain,application,data,presentation}`.
Copy `tools/templates/feature_template/` to start one.

## Read before writing code

| Document | Why |
|---|---|
| [`SHARED_BLUEPRINT.md`](SHARED_BLUEPRINT.md) | The architecture baseline. Everything else serves it. |
| [`CONSTRAINTS.md`](CONSTRAINTS.md) | Release-blocking constraints and non-negotiable invariants. |
| [`docs/architecture/layering-rules.md`](docs/architecture/layering-rules.md) | What may import what, and which rules a machine checks. |
| [`docs/architecture/toolchain.md`](docs/architecture/toolchain.md) | Pinned versions; what is missing on this machine. |
| [`docs/task-ledger/TASK_LEDGER.md`](docs/task-ledger/TASK_LEDGER.md) | Task status, dependencies, contract version, owner actions. |
| [`docs/platform-matrix/platform-matrix.md`](docs/platform-matrix/platform-matrix.md) | Claimed vs **proven** platform support. |
| [`docs/decisions/`](docs/decisions/) | ADRs 0001–0004. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Task workflow, branches, completion reports. |

## Non-negotiables, in one paragraph

The backend is the only authority: inventory is checked and reserved server
side, never from cached display, and there is no arbitrary patch-to-status
endpoint. Money is integer minor units with an explicit currency and balanced
postings; corrections are reversals, never edits of history. Assignment
notification, assignment acceptance and physical custody are three different
facts. Delivered is not equivalent to rider cash settled. Any check that cannot
be run is reported **NOT RUN** — never as a pass.

## Status

`docs/task-ledger/TASK_LEDGER.md` is authoritative. As of 2026-09-09: FND-001
DONE, FND-002 BLOCKED (no Windows runner, no physical device), FND-003 and
FND-004 TODO. This is bootstrapped scaffolding, not capacity-certified
software.
