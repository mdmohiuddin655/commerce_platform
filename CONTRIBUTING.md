# Contributing / task workflow

## How work arrives

Five ChatGPT Projects (ADMIN, USER, AGENT, PICKER, RIDER) each emit bounded
task prompts. An executor (Codex / Claude Code) implements one task in this
repository and returns a completion report. **Sending a task prompt is not
completion**; only a report with real command output is.

The Projects cannot see each other's conversations.
`docs/task-ledger/TASK_LEDGER.md` — not a chat history — is the shared state.

## One task, one branch

```text
fnd/FND-003-shared-contracts
role/ROLE-RIDER-004-handoff-proof
hard/HARD-002-assignment-expiry-race
```

Never run two coding sessions against the same shared file at once. Task
ownership and branch are stated up front. `main` stays green: `run_checks.sh`
must pass before a merge.

## Definition of done

A task is DONE only when all of these hold:

1. Its stated acceptance criteria are met — not a subset.
2. `./tools/run_checks.sh` passes, with the output pasted into the report.
3. Anything that could not be executed is listed as **NOT RUN**, with why.
4. Migration and rollback are stated where schema or contract changed.
5. `docs/task-ledger/TASK_LEDGER.md` is updated in the same commit.
6. A completion report is committed to `docs/task-ledger/<TASK-ID>-completion-report.md`.

## Completion report shape

```markdown
# <TASK-ID> completion report
## What was created        # files and directories, with paths
## What was verified       # exact commands and their real output
## What was NOT run        # and precisely why
## What remains            # follow-ups, with the task that owns each
## Owner actions needed    # anything a human must do
```

## Rules an executor may not relax on its own

- Do not weaken a lint or delete a guard rule to make a build green.
- Do not invent a field name, status string, fee amount or policy that
  `docs/contracts/` has not defined. If it is missing, the task is blocked on
  FND-003 — say so.
- Do not commit secrets, `google-services.json`, `GoogleService-Info.plist`,
  generated `firebase_options.dart` or service-account JSON.
- Do not claim a platform works because a package badge says so. Validate the
  implementation.
- Do not report a skipped check as a pass.

## Commit messages

```text
FND-003: add order transition table and permissions

- enumerate every allowed edge with actor + preconditions
- inventory and financial effects per edge

Refs: docs/contracts/order-transitions.md
```
