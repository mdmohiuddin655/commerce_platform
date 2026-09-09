# AGENTS.md — repository-wide executor instructions

**This file is the canonical rule set for every agent or executor working in
this repository** (Claude Code, Codex, or a human following the same process).
Tool-specific files such as `CLAUDE.md` may add tool-specific guidance, but
they must not restate or contradict the architecture rules below — they point
here instead.

Read before doing anything: [`SHARED_BLUEPRINT.md`](SHARED_BLUEPRINT.md)
(architecture baseline) → [`CONSTRAINTS.md`](CONSTRAINTS.md) (release-blocking
constraints) → [`docs/task-ledger/TASK_LEDGER.md`](docs/task-ledger/TASK_LEDGER.md)
(what is actually done).

Contract baseline: **SHARED-BASELINE-v1.0**.

---

## 1. Ownership and boundaries

One monorepo, five role apps, one shared domain.

```text
apps/       admin/ user/ agent/ picker/ rider/     role applications
packages/   cp_* shared libraries                  no app-specific logic
backend/    api/ workers/ modules/                 trusted server side
infra/      firebase/ ci/                          config, not app code
docs/       architecture contracts platform-matrix task-ledger decisions release-policy
tools/      the validation gate and templates
```

- Directory names come from the blueprint. Renaming one requires an ADR in
  `docs/decisions/`, not a unilateral change.
- **An app must never import another app.** `apps/admin` importing
  `package:user_app/...` is a build-failing violation. Shared behaviour goes
  into a `packages/cp_*` library.
- **A package must never import an app.** Shared code cannot depend on one
  role's application.
- **Client code must never import `backend/`.** The backend is a separate
  deployable with its own runtime.
- A backend module **exposes ports**; it never writes another module's
  collections directly.

Checked mechanically by `tools/check_layering.sh`.

## 2. Feature layering

Every feature is exactly:

```text
apps/<app>/lib/features/<feature>/{domain,application,data,presentation}
```

| Layer | May import | Must never import |
|---|---|---|
| `domain` | `cp_core`, `cp_contracts`, `dart:*` | Flutter, Firebase, Drift, `cp_design_system`, and the other three layers |
| `application` | `domain`, `cp_*` | `presentation` |
| `data` | `domain`, `cp_networking`, `cp_local_store` | `presentation`, `application` |
| `presentation` | `application`, `domain`, `cp_design_system` | `data` |

- **`domain` is pure Dart.** No widgets, no SDK clients, no UI packages. Its
  types must be testable with `dart test` and no Flutter binding.
- `domain` declares repository *interfaces*; `data` implements them, so the
  dependency points inward. Binding an implementation to a port happens in the
  app's `lib/bootstrap`, never inside a feature.
- **No business logic or Firebase access inside a widget.** A widget renders
  state and dispatches intent. Firestore/HTTP/auth calls live in `data` behind
  a `domain` port; decisions live in `domain`/`application`.
- Start a feature by copying `tools/templates/feature_template/`.

## 3. Server authority

- The backend is the only authority on commercial truth. Inventory is checked
  and reserved **server side**, never from cached display.
- There is **no arbitrary patch-to-status endpoint**. Clients call named
  commands carrying an idempotent command id and the known order revision.
- Privileged logic and credentials stay on the server. The installed admin
  **app** never embeds privileged server code, service-account keys or
  admin-SDK access. (The ADMIN *ChatGPT Project* coordinating backend tasks is
  not the admin app.)
- Money is `cp_core`'s `Money`: integer minor units with an explicit currency.
  Never a `double`, never a bare `int` passed around as "an amount".
  Corrections are reversal postings, never edits of history.
- Server authorization is required even where App Check is unavailable.

## 4. Contracts

- Never invent a field name, status string, fee amount, commission rule or
  permission. If `docs/contracts/` does not define it, the work is **blocked on
  FND-003** — report that instead of guessing.
- Order, assignment, custody, attempt, return, payment, COD, fee, commission,
  settlement and permission state machines are changed only by the task that
  owns them, under the contract baseline above.
- A contract change bumps `ContractVersion` in `packages/contracts` and is
  reflected in the ledger in the same commit.

## 5. Generated code

- Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `*.gr.dart`)
  are **git-ignored and never committed**; they are regenerated from source.
- Never hand-edit a generated file. Change the source and regenerate.
- The generator and its version are pinned in the owning package's `pubspec`
  and recorded in `docs/architecture/toolchain.md`.
- `firebase_options.dart` is generated **and secret-adjacent**: it is ignored,
  never committed.
- Generated output is excluded from analysis (`analysis_options.yaml`), so a
  generator change must not be used to bypass a lint on hand-written code.

## 6. Validation — what "it works" means

Run the gate before declaring any task done:

```bash
./tools/run_checks.sh
```

It resolves the workspace, verifies workspace membership against
`pubspec.yaml`, analyzes every member, runs every member's tests, and runs the
layering and secret guards. CI (FND-004) must call this same script rather than
a second, drifting definition.

- Workspace members are discovered from the root `pubspec.yaml` `workspace:`
  block via `tools/check_workspace.sh`. **Adding a member without adding tests
  shows up as `NO TESTS` in the summary** — it is visible, not silent.
- Any package you add code to must gain tests in the same task.
- `tools/check_layering.sh` must keep failing on a planted violation. A guard
  that has never been shown to fail proves nothing: if you change it, re-run
  the negative controls and record the result.

## 7. Evidence and honesty rules

These are not style preferences. They are the reason this repository can be
trusted at all.

- **Never mark a check PASS that you did not run.** Use exactly:
  - `PASS` — ran here, succeeded, output available.
  - `FAIL` — ran here, failed.
  - `NOT RUN` — not executed; say why.
  - `BLOCKED` — cannot be executed on this host/runner at any effort; say what
    is missing.
- A skipped check must never read as a pass. A green summary that silently
  omitted a member is a defect in the gate, not a pass.
- **No fake completion.** Do not report a task DONE with a `TODO`, a stub
  returning a placeholder, a commented-out test, a disabled lint, or an
  acceptance criterion quietly dropped. If part of the scope is blocked,
  complete the rest and state plainly what was left and why.
- Do not weaken a lint, delete a guard rule, or add an ignore comment to make a
  build green. Fix the code or report the blocker.
- Distinguish claimed from proven. A package badge or a doc sentence is not
  evidence; a command with output is.
- If repository evidence contradicts an earlier completion report, say so
  explicitly and correct the report.

## 8. Task workflow

- Work arrives as bounded tasks from five ChatGPT Projects (ADMIN, USER, AGENT,
  PICKER, RIDER). They cannot see each other's conversations —
  `docs/task-ledger/TASK_LEDGER.md` is the shared state, not any chat history.
- **Sending a task prompt is not completion.** Only a completion report with
  real command output is.
- One task, one branch: `fnd/FND-003-...`, `role/ROLE-RIDER-004-...`,
  `hard/HARD-002-...`. Never run two sessions against the same shared file.
- A task is DONE only when: acceptance criteria are fully met;
  `./tools/run_checks.sh` passes with output pasted into the report; unrunnable
  checks are listed NOT RUN/BLOCKED with reasons; migration and rollback are
  stated for any contract change; the ledger is updated in the same commit; and
  `docs/task-ledger/<TASK-ID>-completion-report.md` exists.
- Report shape is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## 9. Operations — what an executor may not do unprompted

Never, without explicit authorization in the task:

- deploy anything, anywhere;
- create, modify or delete a Firebase project, Firestore data, rules or
  indexes in a live environment;
- push to a remote, force-push, rewrite history, or amend a published commit;
- change, rotate or exfiltrate credentials; commit a secret,
  `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`,
  a service-account JSON, a keystore or a `.env`;
- run a destructive command (`rm -rf` outside a scratch dir, `git clean -xdf`,
  dropping data);
- install SDKs, accept platform licenses, or add a new third-party dependency.

A new dependency additionally requires a recorded compatibility and licence
check, and — if it changes tooling strategy — an ADR.

## 10. Environment facts

- Shell is **zsh** on the bootstrap host: `for x in $VAR` does **not**
  word-split. Quote, use arrays, or `${=VAR}`. Gate scripts are `#!/usr/bin/env
  bash` and use bash-only syntax (process substitution) — see ADR-0002 for the
  Windows/CI implication.
- Pub **workspace**: run `flutter pub get` at the root; one root
  `pubspec.lock`. No `melos`, no per-package lockfiles (ADR-0002).
- Dart package names carry a `cp_` prefix while directories keep the blueprint
  names (ADR-0003).
- Not installed here: Firebase CLI, FlutterFire CLI, `gh`, Docker. No Windows
  runner, no physical device, Android licenses unaccepted. Full detail:
  [`docs/architecture/toolchain.md`](docs/architecture/toolchain.md).

## 11. Decisions

`docs/decisions/` — ADR-0001 modular monorepo · ADR-0002 pub workspaces without
Melos · ADR-0003 `cp_` package prefix · ADR-0004 strict analysis and guard
rails. Read the relevant ADR before changing what it decided.
