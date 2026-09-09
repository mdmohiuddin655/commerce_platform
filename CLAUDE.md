# CLAUDE.md

**The repository-wide rules live in [`AGENTS.md`](AGENTS.md). Read it first.**

`AGENTS.md` is canonical for architecture, layering, server authority,
contracts, generated code, validation, evidence/honesty rules, task workflow
and operational limits. This file adds only Claude-Code-specific working notes
and deliberately does not restate those rules, so the two cannot drift apart.

## Claude-specific notes

- Before finishing any task run `./tools/run_checks.sh` and paste the real
  output into the completion report. Do not summarise a run you did not do.
- The Bash tool runs **zsh** here. `for x in $VAR` does not word-split — quote,
  use an array, or `${=VAR}`. The gate scripts themselves are bash.
- Prefer editing files with the dedicated tools over shell heredocs when a
  file already exists, so an accidental overwrite cannot lose committed work.
- Long commands: `flutter pub get`, `flutter analyze` and `flutter test` can
  each take minutes on a cold cache. Set a generous timeout rather than
  retrying and leaving two resolutions racing.
- Use the session scratchpad for logs and intermediate output. Never write
  scratch files into the repository tree.
- When a task's scope is bounded (a FIX task, for example), stay inside its
  declared file list and say so explicitly if a required repair falls outside
  it — do not silently widen scope.

## Quick map

| Need | File |
|---|---|
| All executor rules | [`AGENTS.md`](AGENTS.md) |
| Architecture baseline | [`SHARED_BLUEPRINT.md`](SHARED_BLUEPRINT.md) |
| Release-blocking constraints | [`CONSTRAINTS.md`](CONSTRAINTS.md) |
| Current task state | [`docs/task-ledger/TASK_LEDGER.md`](docs/task-ledger/TASK_LEDGER.md) |
| What is installed / missing | [`docs/architecture/toolchain.md`](docs/architecture/toolchain.md) |
| Report shape, branches | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
