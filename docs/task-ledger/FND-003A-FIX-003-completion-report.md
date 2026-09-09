# FND-003A-FIX-003 completion report

- **Task:** Close the integration trust-boundary gap remaining after
  FND-003A-FIX-002
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-10
- **Baseline:** `25e6186a2171641907fec869408218945a03734b`, branch
  `fnd/FND-003A-command-auth-contracts`, working tree clean
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** **0.2, corrected in place** (no wire change)
- **Status:** **DONE**

No published commit was amended. One new commit on the same branch.

## 1. Type versus trust versus request lifetime

FIX-002's anti-forgery boundary is correct and untouched. What was overclaimed
was its **reach**. The contract now separates three boundaries, because only
the first is enforced by Dart.

### What `AuthorizationGrant` mechanically guarantees

Exactly one thing:

> `evaluateAuthorization` returned *allow* for the inputs it was given, and
> nobody manufactured that result afterwards.

### What it does not guarantee

- that the auth token was verified;
- that `Principal` was derived from that verified token;
- that `Membership` was loaded from authoritative storage;
- that the membership status was **current**;
- that `ResourceScope` was freshly loaded;
- that offered/assigned relationships were current;
- that `ApprovalEvidence` came from a trusted approval record;
- that the required `Permission` was the correct one for the command type.

A grant computed from stale or attacker-influenced inputs is a perfectly valid
grant. **Garbage in, authentically-signed garbage out.** The private
constructor stops fabrication *after* evaluation; it says nothing about the
quality of inputs *before* it.

### Trusted server inputs required

All eight items above are backend responsibilities, per request. The existing
rule that client payload data is never authority is unchanged and still
structurally enforced — `evaluateAuthorization` takes no payload.

### Request-lifetime boundary

A grant is **ephemeral**, valid only inside the command-processing flow that
produced it. Dart cannot enforce this, and the contract no longer implies it
can.

## 2. Fresh authorization on every request

**New canonical invariant.** Every command request authorizes from current
trusted inputs before it either executes a new command **or replays a stored
idempotent result**. There is no exception for retries.

Per request the backend must: verify the current authentication context →
derive the `Principal` → resolve current `Membership` from authoritative
storage → resolve current `ResourceScope` including offer and assignment facts
→ resolve `ApprovalEvidence` from trusted storage where applicable → map
`commandType` to its required `Permission` → call `evaluateAuthorization` → use
the grant only within that request's flow.

**Prohibited:** caching a grant across requests; persisting one; reusing an
earlier grant for a retry or replay; treating a grant as a session capability;
authorizing once and replaying indefinitely.

> **A previously valid grant does not mean authority is still valid.**

### Worked example — revocation

1. A rider executes a command successfully; the result is stored against
   `(principalId, commandId)`.
2. Their membership is later revoked.
3. The rider retries the **same** `commandId`.
4. The backend loads **current** membership and authorizes again.
5. Fresh authorization denies — `membershipNotActive`, no grant.
6. The stored result is **not** replayed.

Step 4 is the entire mechanism. Skip it and step 6 fails silently: the retained
grant still matches, and the rider receives a success they are no longer
entitled to. The same sequence covers a lost or reassigned assignment, removed
shop membership, and revoked admin privilege.

**No grant expiry duration or timestamp policy was invented.** A lifetime would
only bound the window in which a stale grant still works; fresh per-request
evaluation removes the window.

## 3. Command type → permission

```text
incoming commandType → trusted backend command router → exact required
Permission → fresh AuthorizationRequest → evaluateAuthorization →
AuthorizationGrant → idempotency / state / revision transaction
```

- The client **never** supplies the authoritative required `Permission`. A
  caller that could choose which permission is checked could choose one it
  holds.
- An unknown or unmapped `commandType` **fails closed** before any mutation.
- A grant's stored `permission` is binding and audit evidence. It is **not**
  proof the backend selected the correct permission for that command type.

The earlier decision stands: `evaluateIdempotency` does not check the
permission, and **no command-type registry was invented** in the contract to
make it look mechanical. It is trusted-server responsibility, now with required
backend tests.

## 4. Future implementation test checklist

Added to `docs/contracts/privacy-and-security-boundaries.md`. Existing R1–R32
were preserved — the file now holds R1–R40 with no gaps and no duplicates,
verified programmatically.

| # | Test |
|---|---|
| R33 | Every accepted `commandType` maps to exactly one expected `Permission` in the trusted backend command router. |
| R34 | An unknown or unmapped `commandType` fails closed and never reaches mutation. |
| R35 | A client cannot select or override the `Permission` used for authorization. |
| R36 | Every new command request authorizes from current trusted `Principal`/`Membership`/`ResourceScope` facts before execution. |
| R37 | Every idempotent retry or replay performs fresh authorization before the stored result is returned. |
| R38 | A command that originally succeeded cannot replay after the actor's membership is suspended or revoked. |
| R39 | A command cannot replay after the relevant assignment or resource scope is removed or reassigned. |
| R40 | `AuthorizationGrant` is request-local: backend code does not persist, cache or reuse it across command requests. |

**Owner:** FND-004, or the bounded backend slice implementing the command
pipeline — whichever lands first.

**Status: all NOT RUN**, and not marked otherwise. No backend implementation
exists and the Firebase CLI is not installed (owner action O4). Zero checklist
items in the file are ticked; these are required future tests, not results.

## 5. Test correction

The test named *"a revoked actor cannot obtain a grant to replay an old
success"* never exercised an old grant — it only checked that a **fresh**
evaluation of a revoked actor yields none. Renamed to *"fresh authorization
after revocation yields no grant"*, which is what it actually asserts.

A second test was added that demonstrates the real boundary **honestly**: it
obtains a grant while the actor is active, confirms fresh evaluation after
revocation yields no grant, and then shows that the **retained** grant still
passes `evaluateIdempotency` and replays. That is the gap, stated plainly —
the pure function has no clock, storage or freshness context, so it cannot
detect staleness.

**No fake clock or expiry field was added** to make the unit test look
mechanical. Stale-grant prevention is a backend integration duty, and it is
tested by R37–R40, not here.

## 6. Prior findings — unchanged

No production Dart code was modified. Confirmed by re-running the full suite:

| Finding | Status |
|---|---|
| Offer recipient isolation | **unchanged** |
| Approval requester/permission/resource binding | **unchanged** |
| Principal-scoped idempotency namespace | **unchanged** |
| Version-policy semantics | **unchanged** |
| `AuthorizationGrant` anti-forgery type boundary | **unchanged** — forgery probe still passes |

## 7. Validation

Production shared Dart code did **not** change (`git diff --name-only --
packages/contracts/lib/` is empty), so per this task's rules only the affected
checks were required. The full gate was additionally run because `AGENTS.md` §6
requires it before any task is declared done.

| # | Command | Result |
|---|---|---|
| V1 | branch / HEAD / `git status` before work | **PASS** — `fnd/FND-003A-command-auth-contracts` @ `25e6186`, clean |
| V2 | `git diff --name-only -- packages/contracts/lib/` | **PASS** — empty; docs and one test file only |
| V3 | `flutter analyze` | **PASS** — `No issues found!` |
| V4 | `dart test test/idempotency_test.dart` | **PASS** — **24** (was 23) |
| V5 | `dart test` (all `cp_contracts`) | **PASS** — **126** (was 125) |
| V6 | checklist continuity R1–R40 | **PASS** — 40 items, no gaps, no duplicates, **0 ticked** |
| V7 | `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0, **167 tests across 10 of 15 members** |

**V7 is a repository-policy gate run, not new evidence for FND-002 or for
already-completed FND-003A checks.** No platform, device or browser check was
repeated; none was affected by this task.

## 8. Files changed

| Path | Purpose |
|---|---|
| `docs/contracts/authorization-invariants.md` | three boundaries; fresh-authorization rule with worked revocation example; command-router section |
| `docs/contracts/command-and-event-envelopes.md` | fresh authorization precedes replay on every request; stale-grant limitation stated |
| `docs/contracts/privacy-and-security-boundaries.md` | R33–R40; existing items preserved |
| `packages/contracts/test/idempotency_test.dart` | misleading test renamed; retained-grant boundary test added |
| `docs/task-ledger/TASK_LEDGER.md` | FIX-003 entry; four-commit evidence chain |
| `docs/task-ledger/FND-003A-FIX-002-completion-report.md` | §10 recheck note — annotated, not erased |
| `docs/task-ledger/FND-003A-FIX-003-completion-report.md` | this report |

Untouched: all of `packages/contracts/lib/`, apps, backend, infra,
`pubspec.yaml`, `pubspec.lock`.

## 9. Contract version

**0.2, corrected in place. No wire-contract change.** This task clarified the
server integration semantics of an unreleased contract and changed no
production type. Re-verified: the branch has never been merged
(`origin/main` is `2616a4c`), no app has a build, no Firebase project exists —
so no client or stored datum has consumed 0.2.

## 10. Scope statement

No lifecycle state machine, inventory behaviour, payment/COD, cash journal,
fee, commission or settlement rule was introduced. Offer/assignment scope,
approval binding, the idempotency namespace, `ContractVersion` semantics and
the permission matrix were all left exactly as earlier fixes set them.
**FND-003B remains NOT STARTED.** Nothing was merged to `main`, pushed or
deployed.
