# docs/release-policy

Owner: **REL-***. Placeholder at FND-001.

Must eventually define, with evidence rather than intent:

- **Launch gates** — measured active users, concurrent sessions, search QPS,
  orders/s, SKU contention, p95/p99 latency, availability, crash-free sessions,
  cost per order and data-recovery targets. Steady traffic, promotions and
  reconnect storms are budgeted separately.
- **Staged rollout policy** — halting a Play rollout leaves already-updated
  users on that version; a higher-version hotfix is the remedy.
- **Remote Config policy** — safe defaults, staged enablement, server/client
  compatibility. Config rollback is not code rollback.
- **Kill-switch honesty** — no promise of uninterrupted service when the app
  cannot start.
- **Cost controls** — quotas, rate limits and emergency controls. Budget alerts
  do not cap spend.
- **Disaster recovery, support and operational ownership**, including drills
  with recorded outcomes.
- **Signing and distribution** for Android, iOS, web and Windows.
