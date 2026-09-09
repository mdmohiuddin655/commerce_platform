# Working in this repository

Read `SHARED_BLUEPRINT.md` first — it is the architecture baseline. Then
`CONSTRAINTS.md` and `docs/task-ledger/TASK_LEDGER.md` for current state.

## Non-negotiable

- Structure comes from the blueprint. Features live at
  `apps/<app>/lib/features/<feature>/{domain,application,data,presentation}`.
  Renaming a blueprint directory requires an ADR in `docs/decisions/`.
- Packages never import apps. `domain` never imports Flutter. `presentation`
  never imports `data`. Run `./tools/check_layering.sh`.
- Money is `cp_core`'s `Money` — integer minor units, explicit currency. Never
  a `double`, never a bare `int` passed around as "amount".
- Never invent a contract field, status string, fee amount or policy. If
  `docs/contracts/` does not define it, the work is blocked on FND-003 — report
  that instead of guessing.
- Never claim a check passed without running it. Anything unrunnable is
  reported **NOT RUN**, with the reason.
- No cloud deployment, no Firebase project creation, no secret committed.

## Before finishing any task

```bash
./tools/run_checks.sh
```

Then update `docs/task-ledger/TASK_LEDGER.md` and write
`docs/task-ledger/<TASK-ID>-completion-report.md` in the shape given in
`CONTRIBUTING.md`.

## Environment notes

- The shell is **zsh**: `for x in $VAR` does not word-split. Quote, or use
  arrays, or `${=VAR}`.
- Pub **workspace**: run `flutter pub get` at the root; one root
  `pubspec.lock`. Do not add `melos` or per-package lockfiles (ADR-0002).
- Dart package names carry a `cp_` prefix while directories keep the blueprint
  names (ADR-0003).
- Not installed here: Firebase CLI, FlutterFire CLI, `gh`, Docker. No Windows
  runner, no physical device, Android licenses unaccepted. See
  `docs/architecture/toolchain.md`.
