# Five-app commerce — shared blueprint v1.0

Research date: 9 September 2026. Architecture proposal, not implemented or capacity-certified software.

## ব্যবহার পদ্ধতি

1. ChatGPT-তে ADMIN, USER, AGENT, PICKER, RIDER নামে পাঁচটি Project তৈরি করুন। সংশ্লিষ্ট MASTER_PROMPT.txt-এর সম্পূর্ণ content Project Instructions-এ paste করুন। ফাইলের নাম paste করবেন না।
2. এই SHARED_BLUEPRINT.md পাঁচটি Project-এর Files-এ upload করুন। প্রতিটি prompt স্বয়ংসম্পূর্ণ architecture baseline রাখে; এই file detailed shared workflow যোগ করে।
3. প্রথমে ADMIN Project-এ `start` লিখুন। পাওয়া task prompt একই Git repository-তে কাজ করা Codex/Claude Code-কে দিন।
4. Executor-এর completion report/commit/test results সংশ্লিষ্ট Project-এ ফেরত দিন, তারপর `recheck` বা `next` লিখুন। শুধু task পাঠানো মানে task completed নয়।
5. প্রত্যেক Project-এ latest task ledger, contract version এবং dependency report দিন। ChatGPT Projects পরস্পরের conversation দেখতে পায় না। Repository access না থাকলে executor-এর report/প্রয়োজনীয় files দিন।
6. Shared contract পরিবর্তন হলে reviewed Git version থেকে blueprint/contracts পাঁচটি Project-এ refresh করুন। একসঙ্গে একই shared file নিয়ে আলাদা coding session চালাবেন না; task ownership/branch নির্দিষ্ট রাখুন।

Commands: `start`/`next` selects one unblocked task; `continue` resumes; `recheck` reviews real evidence; `fix` requests root-cause repair; `add <requirement>` updates scope/dependencies. No manual programming expected, but account setup, credentials, business decisions and deployment authorization may require the owner.

## Architectural decision

Use a modular monorepo, layered Flutter features, shared design system/contracts, and a trusted command backend with transactional outbox. This is a project-specific synthesis, not a claim to reproduce a company's infrastructure. Shopify describes explicit module boundaries within its monolith; Uber describes centrally modeled fulfillment entities/lifecycles. These support boundaries and orchestration rather than independently invented app rules. [Shopify engineering](https://shopify.engineering/shopify-monolith), [Uber fulfillment](https://www.uber.com/us/en/blog/fulfillment-platform-rearchitecture/).

Flutter recommends separating UI/data responsibilities and repositories. Here a domain/application layer is justified by shared commerce workflows. BLoC/Cubit is our selected convention, not a requirement prescribed by Flutter. [Flutter recommendations](https://docs.flutter.dev/app-architecture/recommendations).

```text
apps/
  admin/ user/ agent/ picker/ rider/
packages/
  core/ design_system/ contracts/ auth/ networking/
  local_store/ sync/ notifications/ observability/ feature_flags/
backend/
  api/ workers/
  modules/
    identity/ shops/ catalog/ inventory/ orders/
    fulfillment/ cash/ notifications/ support/
infra/
  firebase/ ci/
docs/
  architecture/ contracts/ platform-matrix/ task-ledger/
  decisions/ release-policy/
tools/
```

Each app: `lib/bootstrap`, `lib/app`, `lib/features/<feature>/{domain,application,data,presentation}`. Packages do not import apps. Backend modules expose ports instead of writing each other's collections ad hoc. The ADMIN **ChatGPT Project** coordinates backend tasks; the installed admin **app** never embeds privileged server code or credentials.

One Firebase project per environment initially, with multiple app registrations. One logical source of truth does not mean permanently one physical database worldwide. Keep homeRegion and server routing boundaries so regional cells can be introduced through an ADR and migration; never attempt cross-region stock transactions casually.

## Canonical business state

Default: one shop per order, one active accepted picker/rider assignment per respective role, one current custodian. Multiple-shop carts create separately quoted orders; no implied all-or-nothing multi-shop checkout.

| Dimension | States / rules |
|---|---|
| Order | placed → accepted → preparing → ready → in_delivery → delivered; rejected/cancelled only via permitted transitions |
| Assignment (each role) | offered → accepted / declined / expired; accepted → completed or controlled revoked; versioned reassignment |
| Custody | shop → picker → rider → customer; approved bypass shop → rider; returns rider → picker or shop, recorded per handoff |
| Attempt | pending → out_for_delivery → delivered / refused / failed; refused/failed may require return |
| Return | not_required / required → in_transit → received → inspected → closed; damaged/quarantined disposition separate |
| Payment | due / partially_collected / collected / disputed; settlement/remittance is a separate lifecycle |

The contract task must enumerate every allowed edge, actor, precondition, inventory effect, financial effect and event; this table is not an executable state machine. Server revisions serialize incompatible actions. Events retain actor, command ID, order revision and server time. Do not allow arbitrary patch-to-status endpoints.

### Normal flow

Customer submits quote-confirmed checkout. Server validates active shop/service zone, SKU quantities, immutable item/fee/address snapshot, stock reservation and command ID. Agent receives inbox/push and accepts or rejects. Agent offers picker; picker accepts. Picker collects goods or records explicit direct-rider-pickup permission. Picker offers rider; rider accepts. Authorized receiver proves handoff, becoming custodian. Rider delivers, records proof and actual COD receipt; server atomically confirms permitted delivery and journal entry. Rider later remits cash with receiving-party confirmation.

Assignment notification, assignment acceptance and physical custody are three different facts. Offer timeout never implies pickup. Customer prices do not mutate when catalog prices change.

### Refusal / failure / cancellation

Customer or rider can request refusal/cancellation; server decides from current stage. Before dispatch, a permitted cancellation releases reservation once. After physical pickup, refusal opens return processing; stock cannot become available until shop receipt and inspection. Record original order value, cancellation reason, fee policy version, fee amount due, amount actually received, liability/dispute and return state separately. The requested default is customer pays delivery charge on refusal, but nonpayment must remain representable. Never fabricate payment to permit cancellation. Wrong/damaged goods and other exceptions require an explicit approved policy. Delivery failure does not automatically justify a customer fee.

Ledger entries use integer minor units, currency, unique business reference and balanced postings. Corrections use reversals, not editing history. Delivered is not equivalent to rider cash settled. Model commissions and who owns each amount before release; no invented fee amounts. Customer OTP/proof and fallback dispute workflow must be defined before coding delivery confirmation.

## Data and scaling decisions

Orders/reservations/commands/outbox must share a transaction boundary initially. Inventory is checked/reserved by the backend, never by cached display. Reservation expiration is handled by an idempotent worker/transaction; a TTL deletion alone must not be relied on to restore inventory. Order acceptance racing expiry must be tested. Cap item counts to bound transactions; high-contention SKUs need measured inventory allocation/serialization design, not naive stock-counter sharding.

Minimize index fanout, hotspots and global listeners; ramp load and measure contention. [Firestore best practices](https://firebase.google.com/docs/firestore/best-practices). Transaction failure offline means local actions cannot establish final commercial truth. [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions).

For the initial Standard edition use bounded geohash queries with exact-distance filtering and stable deduplication/pagination. [Geoquery guidance](https://firebase.google.com/docs/firestore/solutions/geoqueries). Do not assert all Firestore editions lack search: current Enterprise text search requires its own edition/indexes. Compare price, SDK/API availability and measured query behavior before switching; external search is an optional replaceable projection. [Enterprise text search](https://firebase.google.com/docs/firestore/enterprise/text-search).

Drift provides native and web adapters; browser WASM/workers/storage behavior must be tested, including eviction/private browsing. Persist only necessary customer information and disclose device-local persistence on shared browsers. [Drift platforms](https://drift.simonbinder.eu/platforms/).

Define measured gates before marketing scale: active users, concurrent sessions, search QPS, orders/s and SKU contention; p95/p99 latency, availability, crash-free sessions, cost/order and data recovery targets. Separate steady traffic, promotions and reconnect storms. Capacity progression is evidence-based. One billion registered accounts is not one billion simultaneous shoppers. Budget alerts do not cap spend; enforce quotas/rate limits and emergency controls. Plan disaster recovery, support and operational ownership.

## Platform and release constraints

| Capability | Android/iOS | Web | Windows |
|---|---|---|---|
| Core commerce UI | Flutter | Flutter with URL/navigation semantics | Flutter resizable desktop UI |
| Firebase access | Supported plugins after verification | Supported plugins/API | API adapter; do not depend on beta SDK for production |
| Auth | Firebase Auth + OAuth adapters | Firebase Auth browser flows | Verified Firebase Auth REST + system-browser OAuth integration |
| Notifications | Mandatory FCM/Awesome coexistence spike | FCM/browser/service worker; verified display adapter | Separate supported transport/toast; durable inbox fallback |
| Local cache | Drift SQLite | Drift WASM + browser limitations | Drift SQLite |
| Active location | Permission/lifecycle/battery constrained | Foreground capability/fallback | Device-dependent capability/fallback |

Firebase explicitly cautions that Windows SDK use is for local development, not production. [Firebase platform guidance](https://firebase.google.com/docs/flutter/setup). `firebase_messaging` does not list Windows; Awesome's README deprecates its integration even though the package exposes broad platform metadata. Validate actual implementation, not badges; this is a release-blocking compatibility question, not a verified working pair. [Firebase Messaging](https://pub.dev/packages/firebase_messaging), [Awesome Notifications](https://pub.dev/packages/awesome_notifications).

Windows OAuth needs a tested standards-based redirect/PKCE/provider flow and Firebase token exchange; no assumption that every mobile provider plugin works on desktop. Server authorization is always required even if App Check is unavailable. Define fallback error reporting/config fetching for platforms lacking Firebase plugins. Business functionality stays available without optional GPS or notifications; do not describe a foreground-only notification fallback as full push parity.

Remote Config rolls back configuration, not installed machine code. Use safe defaults, staged feature enablement and compatible server releases. [Remote Config rollouts](https://firebase.google.com/docs/remote-config/rollouts). Halting a Play rollout leaves already-updated users on that version; use a higher-version hotfix when needed. [Google Play staged rollouts](https://support.google.com/googleplay/android-developer/answer/6346149?hl=en). Never promise uninterrupted service from a kill switch when the app cannot start.

Flutter web satisfies the requested application codebase. If public catalog SEO becomes a business requirement, measure crawlability/metadata first and decide explicitly whether a separate rendered catalog is needed; do not silently introduce another frontend stack.

## Ordered execution roadmap

| Task group | Owner | Deliverable / dependency |
|---|---|---|
| FND-001 | ADMIN | Inspect/bootstrap repository, task ledger, pinned toolchain and constraints |
| FND-002 | ADMIN | Platform/auth/notification compatibility spikes, proven matrix and blockers |
| FND-003 | ADMIN | Shared schemas, exhaustive transitions, permissions, policies, money/custody invariants |
| FND-004 | ADMIN | CI/platform runners, emulator security tests, design system, auth, cache/queue/API shell |
| E2E-001 | ADMIN coordinates all | One seeded shop/SKU: checkout → assignment → handoff → COD → settlement; refusal/return branch |
| ROLE-* | Respective Project | Complete role features against tested shared contracts; dependency-gated tasks |
| HARD-* | ADMIN coordinates | Concurrency, auth/revocation, offline/restart, notifications, adaptive UI, profiling |
| REL-* | ADMIN coordinates | Capacity/cost evidence, recovery drills, signing/distribution, runbooks and launch gates |

Each group expands into bounded tasks, not one enormous coding request. ADMIN coordination does not imply other ChatGPT chats have received instructions automatically. Auth/notification spike uncertainty can block release without blocking independent design/contract work.

Minimum end-to-end failure evidence: competing checkouts for last SKU; duplicate/reordered commands/events; assignment expiry/reassignment; pickup/cancellation race; COD submitted twice; refusal without fee payment; returns damaged; offline restart and user switch; revoked worker; stolen/expired handoff proof; notification missed; older app reading newer schema. Physical-device notification and platform builds require suitable runners. Mark unavailable checks NOT RUN and withhold production-ready claims.

Deliver executor prompts with concrete acceptance criteria, dependency versions, scope, file boundaries, commands, migration/rollback requirements and a structured completion report. Finish each feature to its stated acceptance criteria; maintenance and future repairs remain necessary engineering work.
