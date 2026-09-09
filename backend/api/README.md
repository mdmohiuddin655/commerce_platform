# backend/api

Trusted command surface. Empty at FND-001; shell is owned by FND-004.

Endpoints are **named commands** (`placeOrder`, `acceptAssignment`,
`recordHandoff`, `confirmDelivery`, `remitCash`, ...), each taking an
idempotent command id and the client's known order revision. There is no
generic patch-to-status endpoint, and a client-supplied status is never
trusted. Every command validates authorization server side, even where App
Check is unavailable.
