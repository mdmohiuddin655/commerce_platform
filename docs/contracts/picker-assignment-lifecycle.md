# Picker assignment lifecycle

**Contract version 0.4** (FND-003B2A). Pure Dart in `packages/contracts` — no
Flutter, no Firebase, no new dependency.

This slice owns the **picker** assignment lifecycle only. Rider assignment is
FND-003B2B; custody, pickup, handoff, delivery attempts and returns are
FND-003B3. None of them is defined, guessed or partially implemented here.

## Concepts

| Concept | Meaning |
|---|---|
| **Slot** | One logical picker-assignment position per order. Holds at most one attempt at a time. |
| **Attempt** | One offer and its outcome. Immutable history: never edited, never resurrected. |
| **`assignmentId`** | Opaque, server-generated identity of one attempt. **Never a global sequential counter.** |
| **`generation`** | Per-order version of the slot. Increases only when a **new attempt** is created. |
| **`slotRevision`** | Concurrency control. Increments on **every** applied mutation. |
| **Offer recipient** | The worker an offer was addressed to. Immutable history. |
| **Accepted assignee** | The worker who accepted. Null until acceptance. |

`generation` and `slotRevision` do different jobs, and conflating them loses
one of them: a decline advances the revision but *not* the generation, while a
re-offer advances both.

## Assignment states

| State | Executable here | Meaning |
|---|---|---|
| `offered` | yes | Live, unanswered, expirable |
| `accepted` | yes | Active assignment. **Not custody.** |
| `declined` | yes | Terminal for this attempt |
| `expired` | yes | Terminal — lapsed under its timeout policy |
| `revoked` | yes | Terminal — withdrawn under controlled reassignment |
| `completed` | **no** | Declared for enum/wire stability; depends on custody, owned by FND-003B3. No transition enters it, and a test proves none can. |

`AssignmentRole.rider` is likewise **declared but not executable**: no command
or event in this slice names a rider.

## Transition matrix

Every executable edge. Anything not listed fails closed.

| Command | Actor / permission | From | To | Order precondition | Assignment precondition | Revision / generation | Projection effect | Inventory | Financial | Custody | Event |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `assignment.offer_picker` | agent — `agent.assignment.offer_picker` | *(none or terminal)* | `offered` | `accepted`, `preparing` or `ready` | no live offer; no active accepted; target eligible; region matches; opaque new id; non-blank `timeoutPolicyRef` | `rev+1`; **generation +1** | `+offered{picker}` | none | none in this slice | none | `picker.assignment.offered` |
| `assignment.accept_picker` | picker — `picker.assignment.accept` | `offered` | `accepted` | still eligible | exact id + generation; actor **is** the offer recipient | `rev+1`; generation unchanged | `−offered{picker}`, `+assigned{picker}` | none | none in this slice | none | `picker.assignment.accepted` |
| `assignment.decline_picker` | picker — `picker.assignment.decline` | `offered` | `declined` | still eligible | exact id + generation; actor is the recipient | `rev+1` | `−offered{picker}` | none | none in this slice | none | `picker.assignment.declined` |
| `assignment.expire_picker_offer` | **trusted worker — no permission** | `offered` | `expired` | still eligible | exact id + generation; `expiryDue` determined by the backend | `rev+1` | `−offered{picker}` | none | none in this slice | none | `picker.assignment.expired` |
| `assignment.revoke_picker` | agent — `agent.assignment.revoke_picker` (reason required) | `accepted` | `revoked` | still eligible | exact id + generation; **proven-no-custody** | `rev+1` | `−assigned{picker}` | none | none in this slice | none | `picker.assignment.revoked` |

**Every row: inventory NONE, financial NONE IN THIS SLICE, custody NONE.**
Offering or accepting a worker does not release or reserve stock, move goods,
create COD liability, commission or settlement. The FND-003B1 reservation is
untouched.

## Offer recipient versus accepted assignee

Two separate fields, because being offered work is not holding it.

| Attempt state | Offer recipient | Accepted assignee | Active projections |
|---|---|---|---|
| `offered` | P | **null** | offered: {P} |
| `accepted` | P (history) | P | assigned: {P} |
| `declined` | P (history) | null | none |
| `expired` | P (history) | null | none |
| `revoked` | P (history) | P (history) | none |

**Identities are never erased because an attempt ended.** A revoked assignment
still records who held it — that is the audit trail.

`ResourceScope.offeredPrincipalIds` and `assignedPrincipalIds` are
**authorization projections derived from the assignment record**, not a
replacement for it. They let `evaluateAuthorization` answer "is this actor the
recipient / the assignee" cheaply. A stale projection must never redefine
assignment history; it is rebuilt from the record.

## Order eligibility

Assignment work may exist only while the order is `accepted`, `preparing` or
`ready`. Offering before the shop accepted would assign work nobody agreed to
do. `placed`, `rejected` and `cancelled` are excluded; `inDelivery` and
`delivered` are not implemented anywhere.

**The order state is re-read for every command**, including acceptance of an
older offer — a stale offer must not be accepted after the order became
terminal. Client-cached order state is never used.

## Target eligibility

Loaded from **authoritative membership storage** for that request. The target
must be a human principal, whose membership names *them*, with role `picker`,
status `active`, in the **order's region**.

> The `PickerEligibility` object is **not itself proof of trust**. It is the
> shape the backend fills from current records. A caller never reaches this
> evaluator, so a caller cannot make a worker eligible by constructing one.

Deliberately **not** modelled: workload limits, ratings, distance thresholds,
availability scoring, shift rules. Those are **dispatch policy**, not lifecycle,
and none was invented.

## Timeout policy boundary

Each offer carries a **`timeoutPolicyRef`** — an immutable, versioned reference.

**No numeric duration exists anywhere in this contract.** Not 30 seconds, not 5
minutes, not any guess. The backend resolves the reference against **server
UTC** and supplies the resulting `expiryDue` determination.

`expiryDue` defaults to `false`, so expiry **fails closed**. A client cannot
force an early expiry: it never supplies this, and the boolean is not itself
proof of trust — it is the shape the backend fills.

Expiry is a **trusted worker transition**: `requiredPermission` is `null`, and
`evaluateAuthorization` denies a `systemWorker` every human-role permission, so
a worker cannot borrow one. It is **not** a picker command, an agent command, a
mobile timer, a notification callback or a TTL deletion.

## Accept versus expiry race

Both act on the same attempt and the same `slotRevision`. Exactly one wins;
**wall-clock and client arrival order are not concurrency control.**

- **Accept first** → `offered → accepted`, revision advances. A later expiry
  finds state `accepted` and is denied; the assignment stands.
- **Expiry first** → `offered → expired`, revision advances. A later accept is
  denied; no active accepted picker exists, and the agent may offer a **new
  generation**.

The loser holding the pre-race revision is refused with `slotRevisionConflict`.

## Controlled reassignment

**Two explicit transitions, never an assignee overwrite:**

```text
accepted --revoke--> revoked      (old attempt, history retained)
                          |
                          +--offer--> offered   (NEW assignmentId, generation+1)
```

`agent.assignment.revoke_picker` is agent-only, active membership, `ownShop`
scope, **reason required**. It is not a generic assignment mutation, not a
status overwrite, and not an assignee-replacement.

**It stays agent-only.** Administrative intervention is a *separate* audited
override workflow — its own permission family, scoped admin authority, reason,
approval/dual control, and an audit record — and it may not bypass custody
safety. Adding `admin` to this permission as a shortcut is explicitly ruled out
by [ADR-0006](../decisions/ADR-0006-admin-picker-assignment-override.md).
`admin.assignment.override_picker` is **RESERVED / PROPOSED only**: it is
deliberately absent from `Permission.values` and `permissionMatrix`, and a test
asserts it stays absent.

### The no-custody safety gate

Revocation is permitted only when `ReassignmentSafety.provenNoCustody`.

`blockedOrUnknown` — which is the **default** — denies with
`reassignmentUnsafe`. **Unknown is not safe.** Silently reassigning goods
somebody is already carrying is how inventory and accountability are lost.

FND-003B2A implements **no custody state at all**. The backend supplies this
determination, and FND-003B3 will map real custody facts onto it.

## Exactly-one invariants

For one order:

- **At most one live `offered` attempt.** A second offer denies with
  `liveOfferExists`.
- **At most one active `accepted` assignment.** An offer while one exists
  denies with `activeAcceptedAssignmentExists`; the work must be
  controlled-revoked first.

This is an **initial foundation invariant**, not a claim that parallel-offer
dispatch can never exist. Supporting concurrent offers later would need an
explicit ADR plus lifecycle semantics for losing/superseded offers —
`expired` and `declined` must **not** be repurposed to simulate it, because
they mean different things.

## A new attempt needs a new identity

Re-offering after a terminal attempt requires an `assignmentId` **different from
the terminal attempt's own**. Denied with `assignmentIdReuse`.

Advancing the generation is **not** a substitute. Reusing the identifier would
make two attempts indistinguishable in every event stream, audit record and
stored document — a later generation would look like the earlier one that
failed.

### Historical uniqueness is a storage guarantee

The evaluator sees only the attempt **currently in the slot**, so it cannot
prove a proposed id was never used by an older archived attempt. That boundary
is stated rather than papered over: proving it in pure Dart would mean carrying
every historical id in the order aggregate, which is exactly the unbounded array
the storage note below warns against.

The backend must therefore generate attempt ids **server-side**, create attempt
records **create-if-absent**, reject reuse of **any** prior id, and never
overwrite history — criterion **P17**.

## Stale, duplicate and reordered commands

Identity is checked before generation, and both before state: **a command is
never applied to whatever happens to be in the slot just because the order id
matched.**

Worked example: generation 1 offered to picker A, expired; generation 2 offered
to picker B. A delayed *"accept generation 1"* from A arrives → denied with
`assignmentIdMismatch`. It cannot accept generation 2 and mutates nothing.

Every denied operation yields **no transition**, therefore no projection
change, no event and no effect. Duplicate accept, duplicate decline, duplicate
expiry, duplicate revoke, decline-after-accept, accept-after-decline,
accept-after-expiry, expiry-after-accept, expiry-after-decline and
revoke-before-accept are all covered by tests.

Command idempotency itself remains **FND-003A's**; this lifecycle protects the
aggregate's revision, generation and state.

## Aggregate integrity

As learned in FND-003B1: the transition graph never *creates* an impossible
aggregate, but facts arrive from **storage**. Validation runs **before any
effect**.

| State | Canonical shape |
|---|---|
| `offered` | recipient set; assignee **null** |
| `accepted` | recipient set; assignee set; **assignee == recipient** |
| `declined` | recipient set; assignee null |
| `expired` | recipient set; assignee null |
| `revoked` | recipient set; historical assignee set and equal to recipient |

Also required for any attempt: opaque `assignmentId`, `generation >= 1`,
non-blank `timeoutPolicyRef`, non-empty recipient. A slot with no attempt must
have `slotRevision == 0`.

### Generation and revision must describe a reachable history

`slotRevision >= 1` is not enough — it accepts histories this state machine
cannot produce, such as generation 2 at revision 1, or generation 1 at
revision 99.

Every attempt costs **at least two** mutations (offer + decline/expiry) and **at
most three** (offer + accept + revoke). So the `g-1` attempts before the current
one consumed between `2(g-1)` and `3(g-1)` revisions, and the current attempt
adds one, two or three depending on how far it has got:

| Current state | Reachable `slotRevision` |
|---|---|
| `offered` | `2g-1` … `3g-2` |
| `accepted` / `declined` / `expired` | `2g` … `3g-1` |
| `revoked` | `2g+1` … `3g` |

Worked: gen 1 offered → rev 1; gen 1 accepted/declined/expired → rev 2; gen 1
revoked → rev 3. Gen 2 offered → rev 3 (previous attempt declined or expired)
or rev 4 (previous attempt revoked). Gen 2 revoked → rev 5 or 6.

Anything outside the range — **above the maximum as well as below the
minimum** — is `aggregateInconsistent`. `completed` is not range-checked; this
slice does not implement it, so its cost is unknown.

`reachableSlotRevisionRange(generation, state)` is exported so a backend
reconciliation job can apply the identical rule.

Anything else denies with `aggregateInconsistent`, producing no lifecycle
effect, no projection change and no event.

**The evaluator does not repair corrupt history.** It refuses and stops. Repair
without an audit trail is indistinguishable from a bug, and belongs to
reconciliation tooling.

## Order / assignment cross-aggregate boundary

This evaluator **reads** the current trusted order state; it does not implement
order transitions. The backend must transact and check order and assignment
state **together** where a race matters.

**Known unresolved interaction, recorded rather than guessed:** FND-003B1
permits order cancellation from `accepted`, so an order cancellation can race a
picker assignment operation. Once custody exists, the safety of cancellation
and reassignment is decided by **FND-003B3** and later policy. No backend may
assume "accepted assignment means custody" or the reverse. **This does not
block FND-003B2A** — it is a backend serialization requirement (P15).

## Future backend acceptance criteria

**All NOT RUN.** No backend implementation exists. These join the existing
R33–R40 and L1–L13, which are likewise unchanged and NOT RUN.

- [ ] P1 — Agent offer validates current order/shop scope and target picker eligibility from trusted storage.
- [ ] P2 — An inactive, suspended, revoked or wrong-role target cannot receive a new offer.
- [ ] P3 — A wrong-region picker cannot receive or accept the offer.
- [ ] P4 — Only the exact offer recipient may accept or decline.
- [ ] P5 — A live picker offer blocks a second live picker offer.
- [ ] P6 — An accepted picker blocks another offer or accept until controlled revoke.
- [ ] P7 — The accept-vs-expiry race commits exactly one outcome.
- [ ] P8 — A stale `assignmentId`, `generation` or `slotRevision` mutates nothing.
- [ ] P9 — After decline, expiry or revoke, a new offer uses a new `assignmentId` and the next generation.
- [ ] P10 — A delayed command from an older generation cannot affect the new generation.
- [ ] P11 — Controlled revoke requires a reason, current agent authorization and proven-no-custody safety.
- [ ] P12 — Custody unknown or started fails controlled reassignment closed.
- [ ] P13 — `ResourceScope` offered/assigned projections change atomically with the assignment record and the outbox event.
- [ ] P14 — Persisted assignment aggregate inconsistencies never drive a mutation and are surfaced for reconciliation.
- [ ] P15 — Order cancellation and assignment accept/revoke are serialized against current order/custody facts before the backend ships.
- [ ] P16 — Exactly one active accepted picker exists per order under concurrent commands.
- [ ] P17 — A newly generated `assignmentId` must not collide with or reuse **any** historical assignment attempt id; attempt creation is create-if-absent and never overwrites history.

Storage note for P14/P16: assignment attempts should be a bounded or paginated
indexed collection, **not** an unbounded array inside the order document.

## Out of scope

Not defined, guessed or partially implemented here:

- rider assignment lifecycle (FND-003B2B);
- physical custody, pickup and handoff;
- rider receipt;
- delivery attempts;
- returns;
- delivery confirmation;
- proof and dispute;
- payment and COD;
- cash journal, fees, commissions, settlement and remittance.

No timeout duration, fee amount, commission, COD rule or cash liability appears
anywhere in this slice.
