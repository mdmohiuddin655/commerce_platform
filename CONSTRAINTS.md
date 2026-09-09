# Release-blocking constraints

Extracted from `SHARED_BLUEPRINT.md` at FND-001 so that no later task has to
rediscover them. None of these are resolved yet. Each names the task that owns
it. Nothing here may be downgraded by an implementing task on its own.

## Open compatibility questions (FND-002 spikes)

| # | Question | Why it blocks release | Status |
|---|---|---|---|
| C1 | Does `firebase_messaging` coexist with `awesome_notifications` on Android and iOS? | Both are proposed; Awesome's README deprecates its Firebase integration. Badges are not evidence. | **NOT RUN** |
| C2 | Windows notification transport | `firebase_messaging` does not list Windows. A durable inbox fallback is required and is not push parity. | **NOT RUN** — no Windows runner |
| C3 | Windows OAuth + Firebase token exchange | Needs a tested standards-based redirect/PKCE flow. No assumption that a mobile provider plugin works on desktop. | **NOT RUN** — no Windows runner |
| C4 | Firebase Windows SDK production status | Firebase documents Windows SDK use as local development, not production. | **NOT RUN** |
| C5 | Drift on web (WASM/workers/storage) | Eviction and private-browsing behaviour must be measured, and device-local persistence disclosed on shared browsers. | **NOT RUN** |
| C6 | Physical-device push delivery | Simulators are not evidence for push. | **NOT RUN** — no physical device attached |

## Non-negotiable invariants (FND-003 defines, FND-004+ enforces)

1. Orders, reservations, commands and outbox share one transaction boundary.
2. Inventory is checked and reserved by the backend, never by cached display.
3. Reservation expiry is restored by an idempotent worker/transaction. A TTL
   deletion alone must not be relied on to restore inventory.
4. Order acceptance racing expiry must be tested, not assumed.
5. Item counts per order are capped to bound transaction size.
6. Ledger entries use integer minor units, an explicit currency, a unique
   business reference and balanced postings. Corrections are reversals.
7. Delivered is not equivalent to rider cash settled.
8. Events retain actor, command id, order revision and server time.
9. No arbitrary patch-to-status endpoint exists.
10. Customer prices do not mutate when catalog prices change.
11. Nonpayment on refusal must remain representable. Never fabricate a payment
    to permit a cancellation. Delivery failure does not automatically justify a
    customer fee.
12. Stock cannot become available again until shop receipt **and** inspection.
13. Customer OTP/proof and the fallback dispute workflow must be defined before
    delivery confirmation is coded.
14. Server authorization is always required, even where App Check is
    unavailable.

## Operational constraints

- Remote Config rolls back configuration, not installed machine code. Use safe
  defaults and staged enablement; never promise uninterrupted service from a
  kill switch when the app cannot start.
- Halting a Play staged rollout leaves already-updated users on that version;
  ship a higher-version hotfix instead.
- Budget alerts do not cap spend. Enforce quotas, rate limits and emergency
  controls (REL-*).
- Capacity claims require measured evidence: active users, concurrent sessions,
  search QPS, orders/s, SKU contention, p95/p99 latency, availability,
  crash-free sessions, cost per order, recovery targets.

## Required end-to-end failure evidence (E2E-001 / HARD-*)

Competing checkouts for the last SKU; duplicate and reordered commands/events;
assignment expiry and reassignment; pickup/cancellation race; COD submitted
twice; refusal without fee payment; damaged returns; offline restart and user
switch; revoked worker; stolen or expired handoff proof; missed notification;
older app reading newer schema.

Any check that cannot be run must be reported **NOT RUN**. Production-ready
claims are withheld until the evidence exists.
