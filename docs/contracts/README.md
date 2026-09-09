# docs/contracts

Canonical shared contract. Owner: **FND-003**, delivered in slices.

**Current contract version: 0.2** (FND-003A).
**Contract baseline: SHARED-BASELINE-v1.0.**

## Delivered — FND-003A

| Document | Covers |
|---|---|
| [command-and-event-envelopes.md](command-and-event-envelopes.md) | Command envelope, the actor rule, idempotency semantics, event envelope, transport separation |
| [identity-membership-and-scope.md](identity-membership-and-scope.md) | Principal vs role vs membership vs scope |
| [permission-matrix.md](permission-matrix.md) | The one canonical least-privilege matrix (generated from code) |
| [authorization-invariants.md](authorization-invariants.md) | Evaluation order, deny reasons, App Check boundary |
| [privacy-and-security-boundaries.md](privacy-and-security-boundaries.md) | PII scope, push payload limits, FND-004 Rules checklist |
| [version-history.md](version-history.md) | 0.1 → 0.2, compatibility and migration status |

Implemented in `packages/contracts`, pure Dart, no Flutter or Firebase
dependency.

## Not yet defined — later FND-003 slices

**No feature may guess any of these.** If it is not written down, the work is
blocked, and saying so is the correct outcome.

| Slice | Owns | Blocked on |
|---|---|---|
| **Lifecycle** | Order, assignment, custody, delivery-attempt and return transitions: every allowed edge with actor, precondition, inventory effect, financial effect and emitted event. The `SHARED_BLUEPRINT.md` table lists *states*; it is not an executable state machine and is not sufficient. | — |
| **Inventory** | Reservation, expiry and restoration effects per transition; the rule that stock cannot become available again until shop receipt **and** inspection. | Lifecycle slice |
| **Money** | Payment/COD lifecycle, cash journal postings, fee amounts, refusal fee policy and versioning, commission ownership, settlement and remittance. | **Owner decision O6** (currency, fee policy, commission ownership) |
| **Proof and dispute** | Customer OTP/proof format and the fallback dispute workflow — required **before** delivery confirmation is coded. | Lifecycle slice |

## Rules that already bind every later slice

From FND-003A, tested in `packages/contracts/test/`:

- Commands are **named operations**, never a status to write. No
  patch-to-status endpoint exists and no permission grants one.
- The server derives the actor from verified authentication. A client-supplied
  actor, role or permission is inert.
- Command ids are idempotency keys: identical intent replays the stored result,
  changed intent is rejected as key reuse.
- Event ids are server-assigned. A transport id is never a business event id.
- An event is a hint; it never authorizes a transition.
- Role alone authorizes nothing — active membership **and** scope are required.
- No permission may grant arbitrary status overwrite, balance edit, journal
  edit, or unaudited impersonation.
