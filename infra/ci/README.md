# infra/ci

Empty at FND-001. Owner: **FND-004** ("CI/platform runners, emulator security
tests"). No pipeline is defined here yet, and none is claimed.

When it is written, it must:

- Run `tools/run_checks.sh` — the same gate developers run locally, not a
  second, drifting definition.
- Provide the runners the blueprint's platform matrix needs: Android, iOS,
  web and **Windows**. No Windows runner exists today (owner action O2), so
  every Windows row in `docs/platform-matrix/platform-matrix.md` is BLOCKED.
- Run Firestore rules/security tests against the Firebase emulator.
- Mark any check it could not execute as **NOT RUN** in the job summary rather
  than skipping it silently. A skipped check must never read as a pass.
