# backend/workers

Scheduled and outbox-draining jobs. Empty at FND-001; owned by FND-004.

Required jobs, from the blueprint's invariants:

- **Outbox drain** — publishes events recorded inside the order transaction.
  At-least-once delivery, so consumers must be idempotent.
- **Reservation expiry** — restores inventory through an idempotent
  worker/transaction. A TTL deletion alone must not be relied on to restore
  inventory, and expiry racing an order acceptance must be tested.
- **Assignment offer timeout** — expires an unaccepted offer. A timeout never
  implies pickup, and never changes custody.
