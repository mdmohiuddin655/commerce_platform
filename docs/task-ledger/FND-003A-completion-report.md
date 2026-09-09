# FND-003A completion report

- **Task:** First bounded slice of FND-003 — command/event envelopes, identity
  and authorization vocabulary, permission matrix, security invariants
- **Owner project:** ADMIN / shared contracts
- **Date:** 2026-09-09
- **Baseline:** `2616a4cf98599bcfd4a7c9437833c58de2959f67`, branch `main`,
  working tree clean, in sync with `origin/main`
- **Branch:** `fnd/FND-003A-command-auth-contracts`
- **Contract baseline:** SHARED-BASELINE-v1.0 — unchanged
- **Contract version:** 0.1 → **0.2**
- **Status:** **DONE**

## 1. Baseline

Expected HEAD matched exactly. No discrepancy to report.

## 2. Contract version — evidence, not a guess

The task said to use 0.2 *if the implementation confirms it*, and to document
the evidence otherwise. Both sources agree:

- **Implementation** (`contract_version.dart`):
  `bool canRead(ContractVersion other) => other.major == major;` — readability
  keys on **major alone**.
- **Documented rule** (ledger): *"Bump the minor version for additive,
  backward-readable changes; bump the major version for a breaking one."*

0.1 defined only `ContractVersion` itself: no envelopes, permissions or
identity types existed, so nothing could be reinterpreted. Every addition is
new surface. **Additive → minor → 0.2.** Asserted by four tests, including both
read directions and a refused 1.x major.

## 3. What was built

Pure Dart in `packages/contracts`. **No new dependency** — no Freezed, no
json_serializable. Immutable hand-written classes were adequate, so nothing was
added that would need compatibility and licence verification.

### Command envelope

`commandId` · `commandType` · `resourceId` · `expectedRevision` · `payload` ·
`contractVersion`.

**There is no actor, user, role, permission or membership field, and there
never will be.** The server derives the actor from verified authentication and
reads membership from trusted storage. This is structural, not conventional: a
field that does not exist cannot be trusted by mistake — and the evaluator
takes no payload parameter, so actor-shaped payload keys are inert.

`commandType` names an **operation**, never a status to write. Ids are opaque
(16–64 chars of `[A-Za-z0-9_-]`, never all digits — an all-digit id is a
sequential counter, which leaks volume and makes a stolen id guessable).
Validation is structural only and returns `Result`, not exceptions.

### Idempotency

`CommandFingerprint` derives from type, resource, expected revision and
canonicalised payload — **and nothing else**. No device clock, no request
timestamp, no retry counter. Two honest retries fingerprint identically however
far apart they are sent; otherwise replay detection breaks exactly when the
network is worst. Map key order is normalised; **list order is not**, because
`[a,b]` is a different request from `[b,a]`.

`evaluateIdempotency`: new id → `executeNew`; same id + same fingerprint →
`replayStoredResult`; same id + different fingerprint → `rejectKeyReuse`. Pure
function. The transaction boundary and outbox that apply it are FND-004.

### Event envelope

`eventId` (server-assigned, the only dedupe key) · `eventType` · `resourceId` ·
`resourceRevision?` · `causedByCommandId?` · `serverTimeUtc` (must be UTC) ·
`payload` · `contractVersion`.

**No `transportMessageId` field exists.** An FCM or APNs id is never the
business event id: transport ids differ between a push copy and a polled copy
of the same fact and are absent when read from the API. An adapter *maps* its
id; it never substitutes it. A test states this honestly — malformed transport
ids are rejected as a backstop, but a UUID-shaped one would pass, which is
precisely why the guarantee is structural rather than a shape check.

### Identity, membership, scope

`Principal` (`user` | `systemWorker`) carries **no role**. There is no
`fromJson`: if a client could deserialize one, a client could assert one. A
trusted worker is modelled separately from human roles, so no audit record has
to pretend a cron run was a person — and a system principal is **denied** any
human-role permission.

`MembershipStatus` — `pending`, `active`, `suspended`, `revoked`. Only `active`
may start new work: a valid token from a suspended rider is still a valid
token.

`ResourceScope` is read from trusted storage, never the payload. `ScopeRequirement`
is `none` / `ownResource` / `ownShop` / `ownRegion` / `assignedResource`. Two
consequences, both tested: an empty `shopIds` means **no** shops, never all;
and `assignedPrincipalIds` holds **accepted** assignments only — being offered
work is not being assigned it.

### Permissions and matrix

**35 stable permission ids** across all five roles. Code asks *"does this actor
hold `agent.order.accept`"*, never *"is this actor an agent"*.

One canonical matrix: permission → role → acceptable statuses → scope → reason
required → approval required → restriction. `docs/contracts/permission-matrix.md`
is **generated from the code** by `tool/print_permission_matrix.dart`, so the
table cannot drift.

`ProhibitedCapability.all` names four capabilities that must never exist —
arbitrary status overwrite, balance edit, historical journal edit, unaudited
impersonation — as **data with forbidden id fragments**, asserted by a test. A
future permission implementing one is a build failure, not a code review
someone was tired during.

**Admin is bounded.** `admin.support.view_order` is a region-scoped,
reason-bearing, logged read conferring no mutation authority.
`admin.cash.record_reconciliation` records *new balanced postings* under dual
control — not a balance edit, not a journal edit.

### Authorization evaluator

Pure Dart: no I/O, no clock, no database, no Firebase, no Flutter, no App
Check. Order — identity → standing → role → scope → procedure; no later check
can rescue an earlier failure.

`DenyReason` values are **internal**. `publicMessage` is uniform for every
denial, so a caller cannot probe for a resource's existence, owner, shop or
region by comparing messages. Tested with three different internal reasons
producing one identical message.

Dual control means a **different** principal: self-approval is denied. An
unknown permission **fails closed**.

## 4. Validation

| # | Command | Result |
|---|---|---|
| V1 | `git status --short` (before) | **PASS** — empty |
| V2 | `git rev-parse HEAD` | **PASS** — matched expected `2616a4c…` |
| V3 | `flutter pub get` | **PASS** |
| V4 | `./tools/check_workspace.sh` | **PASS** — 15 declared members |
| V5 | `flutter analyze` | **PASS** — `No issues found!` |
| V6 | `dart test` in `packages/contracts` | **PASS** — **83 tests** |
| V7 | `./tools/check_layering.sh` | **PASS** — 8 rules |
| V8 | `./tools/run_checks.sh` | **PASS** — `ALL CHECKS PASSED`, exit 0 |
| V9 | Whole suite | **PASS** — **124 tests across 10 of 15 members** (was 45) |
| V10 | `dart run tool/print_permission_matrix.dart` | **PASS** — 35 rows rendered from live code |

Nothing was BLOCKED or NOT RUN: this task needed no device, runner, credential
or emulator.

### Required test cases — all present and passing

Valid envelope acceptance · invalid ids, revision and command type · replay
with identical fingerprint · key reuse with changed fingerprint · fingerprint
independent of command id and of time · event id independent of transport ids ·
inactive/pending membership denial · suspended and revoked denial for new work ·
wrong-role denial (three directions) · region mismatch · shop mismatch ·
empty-shop-set denial · resource-owner mismatch · assignment mismatch ·
offered-but-not-accepted denial · reason required (including blank) · approval
required · self-approval denied · customer vs another customer's order · agent
cross-shop · picker using a rider permission · rider has no balance/settlement
permission · non-financial admin permission implies no financial authority ·
client actor/role payload spoof is inert · forged membership for another
principal is inert · deny messages do not leak.

### One pre-existing test updated

`contract_version_test.dart` pinned `'0.1'`. It now asserts `'0.2'` plus three
new compatibility cases. That is a deliberate, documented consequence of the
version bump, not a regression.

## 5. Out of scope — remaining FND-003

Nothing below was guessed.

| Slice | Owns | Blocked on |
|---|---|---|
| **FND-003B lifecycle** | Order, assignment, custody, attempt, return transitions; every edge with actor, precondition, inventory effect, financial effect, emitted event | — |
| **FND-003C money** | Payment/COD, cash journal, fees, refusal fee policy, commissions, settlement | **Owner decision O6** |
| **FND-003D proof/dispute** | Customer OTP/proof format and fallback workflow | FND-003B |

## 6. Ledger changes

- **FND-003A: DONE.** **FND-003 parent: PARTIAL** — not marked done.
- Added FND-003B (TODO), FND-003C (BLOCKED on O6), FND-003D (TODO).
- Contract version row: 0.1 → **0.2**.
- **O7 corrected.** The remote and hosting are settled
  (`github.com/mdmohiuddin655/commerce_platform`, pushed 2026-09-09). Only
  branch protection / CI governance remains, and it is recorded as
  **unverified** — no GitHub evidence was gathered, so it is not claimed
  configured.
- **D1–D3 untouched.**

## 7. Migration and compatibility

**No migration is required, and none was invented.** No released client exists
(no app has a platform folder or a build), and no production data exists (no
Firebase project). 0.2 is purely additive, so no stored value changes shape or
meaning.

Unknown identifiers fail safe: an unknown **permission** denies; an unknown
**command type** is rejected; an unknown **event type** may be ignored — the
one place ignoring is explicitly allowed, because an event is a hint and the
client re-reads server state.

**Rollback:** reverting this commit returns the contract to 0.1 with no data
implications.

## 8. Scope statement

Contract and tests only. No application feature, no backend handler, no
Firestore rule, no lifecycle transition, no fee, commission or cash rule. No
dependency added. Notification, auth and local-store capability work from
FND-002A is untouched and still passing. Nothing was pushed or deployed.
