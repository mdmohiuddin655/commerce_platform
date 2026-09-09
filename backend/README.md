# backend

Trusted command surface. **Not implemented at FND-001** — this is the agreed
skeleton only. FND-003 defines the contracts; FND-004 builds the API/worker
shell and the emulator security tests.

```text
backend/
  api/        # trusted command endpoints (named commands, never status PATCH)
  workers/    # scheduled + outbox-draining jobs
  modules/    # identity shops catalog inventory orders
              # fulfillment cash notifications support
```

## Rules that predate any code here

- A module **exposes ports**; it never writes another module's collections ad
  hoc.
- Orders, reservations, commands and the outbox share **one transaction
  boundary** initially.
- Inventory is checked and reserved here, never by a client's cached display.
- Reservation expiry is restored by an **idempotent worker/transaction**. A TTL
  deletion alone must not be relied upon to restore inventory.
- Every command carries an idempotent command id; every event retains actor,
  command id, order revision and **server** time.
- Server revisions serialize incompatible actions. Server authorization is
  always required, even where App Check is unavailable.
- There is **no arbitrary patch-to-status endpoint**.
- Ledger postings are balanced, in integer minor units, with an explicit
  currency and a unique business reference. Corrections are reversals.
- Keep `homeRegion` and server routing boundaries so regional cells can be
  introduced later through an ADR and a migration. Never attempt cross-region
  stock transactions casually.

## Runtime

Node.js is pinned in `.nvmrc` (26.8.1). No `package.json` exists yet on
purpose: adding one would imply a build that FND-001 does not deliver and
cannot test. The Firebase CLI is **not installed** on the bootstrap host, so
emulator-based rules and security tests cannot run yet (owner action O4).
